import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/crypto_constants.dart';
import '../../../core/crypto/aes_gcm_service.dart';
import '../../../core/crypto/crypto_isolate.dart';
import '../../../core/crypto/session_key_holder.dart';
import '../../../core/storage/atomic_file_writer.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/storage/binary_file_format.dart';
import '../../../core/storage/shadow_copy_manager.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/inactivity_tracker.dart';
import '../../shadow_copies/domain/shadow_model.dart';
import '../domain/document_mapper.dart';
import '../domain/document_model.dart';
import 'document_event.dart';
import 'document_state.dart';

class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  final SessionKeyHolder sessionKeyHolder;
  final Debouncer _autoSaveDebouncer;
  late final InactivityTracker _inactivityTracker;
  Timer? _milestoneTimer;

  DocumentBloc({
    SessionKeyHolder? keyHolder,
    Debouncer? debouncer,
  })  : sessionKeyHolder = keyHolder ?? SessionKeyHolder(),
        _autoSaveDebouncer = debouncer ?? Debouncer(delay: AppConstants.autoSaveDebounceDuration),
        super(DocumentIdleState()) {
    _inactivityTracker = InactivityTracker(
      timeout: const Duration(seconds: AppConstants.defaultAutoLockTimeoutSeconds),
      onTimeout: () => add(LockDocumentEvent()),
    );

    on<CreateNewDocumentEvent>(_onCreateNewDocument);
    on<OpenDocumentEvent>(_onOpenDocument);
    on<AddSectionEvent>(_onAddSection);
    on<UpdateSectionTitleEvent>(_onUpdateSectionTitle);
    on<DeleteSectionEvent>(_onDeleteSection);
    on<ReorderSectionEvent>(_onReorderSection);
    on<ToggleSectionCollapseEvent>(_onToggleSectionCollapse);
    on<CollapseAllSectionsEvent>(_onCollapseAllSections);
    on<ExpandAllSectionsEvent>(_onExpandAllSections);
    on<EnsureSectionExpandedEvent>(_onEnsureSectionExpanded);
    on<AddPartEvent>(_onAddPart);
    on<DeletePartEvent>(_onDeletePart);
    on<UpdatePartEvent>(_onUpdatePart);
    on<ReorderPartEvent>(_onReorderPart);
    on<TriggerAutoSaveEvent>(_onTriggerAutoSave);
    on<CreateManualShadowEvent>(_onCreateManualShadow);
    on<RestoreShadowEvent>(_onRestoreShadow);
    on<CloseDocumentEvent>(_onCloseDocument);
    on<LockDocumentEvent>(_onLockDocument);
    on<UnlockDocumentEvent>(_onUnlockDocument);
    on<ChangeMasterPasswordEvent>(_onChangeMasterPassword);
  }

  void _touchUserActivity() {
    _inactivityTracker.reset();
  }

  void _startMilestoneTimer() {
    _milestoneTimer?.cancel();
    _milestoneTimer = Timer.periodic(AppConstants.milestoneSnapshotInterval, (_) {
      if (state is DocumentActiveState) {
        add(CreateManualShadowEvent());
      }
    });
  }

  Future<void> _onCreateNewDocument(
    CreateNewDocumentEvent event,
    Emitter<DocumentState> emit,
  ) async {
    emit(DocumentLoadingState(message: 'Deriving master key & creating document...'));
    try {
      final kdf = await CryptoIsolate.deriveKeyInIsolate(password: event.password);
      sessionKeyHolder.setKey(kdf.keyBytes);

      final newDoc = DocumentModel.create();
      final docBytes = DocumentMapper.toBytes(newDoc);

      final freshNonce = AesGcmService.generateNonce();
      final header = EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: kdf.kdfId,
        salt: kdf.salt,
        nonce: freshNonce,
        ciphertext: Uint8List(0),
        authTag: Uint8List(0),
      ).headerBytes;

      final encrypted = await CryptoIsolate.encryptInIsolate(
        plaintext: docBytes,
        keyBytes: sessionKeyHolder.keyBytes,
        nonce: freshNonce,
        aad: header,
      );

      final packed = BinaryFileFormat.pack(EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: kdf.kdfId,
        salt: kdf.salt,
        nonce: encrypted['nonce']!,
        ciphertext: encrypted['ciphertext']!,
        authTag: encrypted['tag']!,
      ));

      await AtomicFileWriter.writeAtomic(event.filePath, packed);

      // Remember path of last opened document
      await AppPreferences.setLastOpenedPath(event.filePath);

      // Create initial baseline shadow copy
      final baselineShadow = await ShadowCopyManager.createShadowCopy(
        documentPath: event.filePath,
        document: newDoc,
        sessionKeyHolder: sessionKeyHolder,
        salt: kdf.salt,
        kdfId: kdf.kdfId,
        trigger: ShadowTrigger.sessionOpen,
      );

      _inactivityTracker.start();
      _startMilestoneTimer();

      emit(DocumentActiveState(
        document: newDoc,
        filePath: event.filePath,
        salt: kdf.salt,
        kdfId: kdf.kdfId,
        shadowCopies: [baselineShadow],
        statusText: 'New document created',
      ));
    } catch (e) {
      emit(DocumentErrorState(errorMessage: 'Failed to create document: $e'));
    }
  }

  Future<void> _onOpenDocument(
    OpenDocumentEvent event,
    Emitter<DocumentState> emit,
  ) async {
    emit(DocumentLoadingState(message: 'Authenticating & decrypting...'));
    try {
      final file = File(event.filePath);
      if (!await file.exists()) {
        emit(DocumentErrorState(errorMessage: 'File does not exist at ${event.filePath}'));
        return;
      }

      final bytes = await file.readAsBytes();
      final packed = BinaryFileFormat.unpack(bytes);

      // Derive key using stored salt and kdfId
      final kdf = await CryptoIsolate.deriveKeyInIsolate(
        password: event.password,
        salt: packed.salt,
        kdfId: packed.kdfId,
      );

      sessionKeyHolder.setKey(kdf.keyBytes);

      try {
        final decryptedBytes = await CryptoIsolate.decryptInIsolate(
          ciphertext: packed.ciphertext,
          keyBytes: sessionKeyHolder.keyBytes,
          nonce: packed.nonce,
          macTag: packed.authTag,
          aad: packed.headerBytes,
        );

        final doc = DocumentMapper.fromBytes(decryptedBytes);
        // Requirement 1: On load all sections need to be in collapsed state
        final collapsedDoc = doc.copyWith(
          sections: doc.sections.map((s) => s.copyWith(isCollapsed: true)).toList(),
        );

        // Baseline shadow copy on successful open
        final baselineShadow = await ShadowCopyManager.createShadowCopy(
          documentPath: event.filePath,
          document: collapsedDoc,
          sessionKeyHolder: sessionKeyHolder,
          salt: packed.salt,
          kdfId: packed.kdfId,
          trigger: ShadowTrigger.sessionOpen,
        );

        final manifest = await ShadowCopyManager.loadManifest(event.filePath, sessionKeyHolder);

        // Requirement 2: Remember path of last opened document
        await AppPreferences.setLastOpenedPath(event.filePath);

        _inactivityTracker.start();
        _startMilestoneTimer();

        emit(DocumentActiveState(
          document: collapsedDoc,
          filePath: event.filePath,
          salt: packed.salt,
          kdfId: packed.kdfId,
          shadowCopies: manifest.isNotEmpty ? manifest : [baselineShadow],
          statusText: 'All changes saved locally',
        ));
      } catch (_) {
        // Enforce 500ms anti-brute-force delay on password failure
        await Future<void>.delayed(const Duration(milliseconds: 500));
        sessionKeyHolder.wipe();
        emit(DocumentErrorState(errorMessage: 'Incorrect master password or corrupted file.'));
      }
    } catch (e) {
      emit(DocumentErrorState(errorMessage: 'Failed to open document: $e'));
    }
  }

  void _onAddSection(AddSectionEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final newSec = SectionModel.create(
      title: event.title ?? 'New Section',
      order: current.document.sections.length,
    );
    final updated = current.document.copyWith(
      sections: [...current.document.sections, newSec],
    );
    emit(current.copyWith(document: updated, isDirty: true, statusText: 'Saving changes...'));
    _scheduleAutoSave();
  }

  void _onUpdateSectionTitle(UpdateSectionTitleEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) {
      if (s.id == event.sectionId) {
        return s.copyWith(title: event.title);
      }
      return s;
    }).toList();
    emit(current.copyWith(
      document: current.document.copyWith(sections: sections),
      isDirty: true,
      statusText: 'Saving changes...',
    ));
    _scheduleAutoSave();
  }

  Future<void> _onDeleteSection(DeleteSectionEvent event, Emitter<DocumentState> emit) async {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;

    // Trigger immediate milestone shadow before deleting section (structural change safety)
    try {
      final shadow = await ShadowCopyManager.createShadowCopy(
        documentPath: current.filePath,
        document: current.document,
        sessionKeyHolder: sessionKeyHolder,
        salt: current.salt,
        kdfId: current.kdfId,
        trigger: ShadowTrigger.milestone,
      );
      final updatedShadows = [...current.shadowCopies, shadow];

      final filtered = current.document.sections.where((s) => s.id != event.sectionId).toList();
      final updated = current.document.copyWith(sections: filtered);
      emit(current.copyWith(
        document: updated,
        shadowCopies: updatedShadows,
        isDirty: true,
        statusText: 'Section deleted (Shadow copy archived)',
      ));
      _scheduleAutoSave();
    } catch (_) {
      final filtered = current.document.sections.where((s) => s.id != event.sectionId).toList();
      emit(current.copyWith(document: current.document.copyWith(sections: filtered), isDirty: true));
      _scheduleAutoSave();
    }
  }

  void _onReorderSection(ReorderSectionEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = List<SectionModel>.from(current.document.sections);
    var newIdx = event.newIndex;
    if (event.oldIndex < newIdx) newIdx -= 1;
    final item = sections.removeAt(event.oldIndex);
    sections.insert(newIdx, item);

    final reordered = [
      for (int i = 0; i < sections.length; i++) sections[i].copyWith(order: i)
    ];
    emit(current.copyWith(document: current.document.copyWith(sections: reordered), isDirty: true));
    _scheduleAutoSave();
  }

  void _onToggleSectionCollapse(ToggleSectionCollapseEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) {
      if (s.id == event.sectionId) {
        return s.copyWith(isCollapsed: !s.isCollapsed);
      }
      return s;
    }).toList();
    emit(current.copyWith(document: current.document.copyWith(sections: sections), isDirty: true));
    _scheduleAutoSave();
  }

  void _onCollapseAllSections(CollapseAllSectionsEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) => s.copyWith(isCollapsed: true)).toList();
    emit(current.copyWith(document: current.document.copyWith(sections: sections)));
  }

  void _onExpandAllSections(ExpandAllSectionsEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) => s.copyWith(isCollapsed: false)).toList();
    emit(current.copyWith(document: current.document.copyWith(sections: sections)));
  }

  void _onEnsureSectionExpanded(EnsureSectionExpandedEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) {
      if (s.id == event.sectionId) {
        return s.copyWith(isCollapsed: false);
      }
      return s;
    }).toList();
    emit(current.copyWith(document: current.document.copyWith(sections: sections)));
  }

  void _onAddPart(AddPartEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) {
      if (s.id == event.sectionId) {
        final newPart = PartModel.create(title: event.title, order: s.parts.length);
        return s.copyWith(parts: [...s.parts, newPart]);
      }
      return s;
    }).toList();
    emit(current.copyWith(document: current.document.copyWith(sections: sections), isDirty: true));
    _scheduleAutoSave();
  }

  void _onDeletePart(DeletePartEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) {
      if (s.id == event.sectionId) {
        final filteredParts = s.parts.where((p) => p.id != event.partId).toList();
        return s.copyWith(parts: filteredParts);
      }
      return s;
    }).toList();
    emit(current.copyWith(document: current.document.copyWith(sections: sections), isDirty: true));
    _scheduleAutoSave();
  }

  void _onUpdatePart(UpdatePartEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) {
      if (s.id == event.sectionId) {
        final parts = s.parts.map((p) {
          if (p.id == event.partId) {
            return p.copyWith(
              title: event.title ?? p.title,
              body: event.body ?? p.body,
            );
          }
          return p;
        }).toList();
        return s.copyWith(parts: parts);
      }
      return s;
    }).toList();
    emit(current.copyWith(
      document: current.document.copyWith(sections: sections),
      isDirty: true,
      statusText: 'Saving changes...',
    ));
    _scheduleAutoSave();
  }

  void _onReorderPart(ReorderPartEvent event, Emitter<DocumentState> emit) {
    if (state is! DocumentActiveState) return;
    _touchUserActivity();
    final current = state as DocumentActiveState;
    final sections = current.document.sections.map((s) {
      if (s.id == event.sectionId) {
        final parts = List<PartModel>.from(s.parts);
        var newIdx = event.newIndex;
        if (event.oldIndex < newIdx) newIdx -= 1;
        final item = parts.removeAt(event.oldIndex);
        parts.insert(newIdx, item);
        final reorderedParts = [
          for (int i = 0; i < parts.length; i++) parts[i].copyWith(order: i)
        ];
        return s.copyWith(parts: reorderedParts);
      }
      return s;
    }).toList();
    emit(current.copyWith(document: current.document.copyWith(sections: sections), isDirty: true));
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveDebouncer.run(() {
      add(TriggerAutoSaveEvent());
    });
  }

  Future<void> _onTriggerAutoSave(
    TriggerAutoSaveEvent event,
    Emitter<DocumentState> emit,
  ) async {
    if (state is! DocumentActiveState) return;
    final current = state as DocumentActiveState;
    if (!current.isDirty) return;

    emit(current.copyWith(isSaving: true, statusText: 'Encrypting and saving...'));

    try {
      final docBytes = DocumentMapper.toBytes(current.document);
      final freshNonce = AesGcmService.generateNonce();

      final header = EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: current.kdfId,
        salt: current.salt,
        nonce: freshNonce,
        ciphertext: Uint8List(0),
        authTag: Uint8List(0),
      ).headerBytes;

      final encrypted = await CryptoIsolate.encryptInIsolate(
        plaintext: docBytes,
        keyBytes: sessionKeyHolder.keyBytes,
        nonce: freshNonce,
        aad: header,
      );

      final packed = BinaryFileFormat.pack(EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: current.kdfId,
        salt: current.salt,
        nonce: encrypted['nonce']!,
        ciphertext: encrypted['ciphertext']!,
        authTag: encrypted['tag']!,
      ));

      await AtomicFileWriter.writeAtomic(current.filePath, packed);

      emit(current.copyWith(
        isDirty: false,
        isSaving: false,
        statusText: 'All changes saved locally',
      ));
    } catch (e) {
      emit(current.copyWith(
        isSaving: false,
        statusText: 'Auto-save failed: $e',
      ));
    }
  }

  Future<void> _onCreateManualShadow(
    CreateManualShadowEvent event,
    Emitter<DocumentState> emit,
  ) async {
    if (state is! DocumentActiveState) return;
    final current = state as DocumentActiveState;

    try {
      final shadow = await ShadowCopyManager.createShadowCopy(
        documentPath: current.filePath,
        document: current.document,
        sessionKeyHolder: sessionKeyHolder,
        salt: current.salt,
        kdfId: current.kdfId,
        trigger: ShadowTrigger.manual,
      );

      final manifest = await ShadowCopyManager.loadManifest(current.filePath, sessionKeyHolder);

      emit(current.copyWith(
        shadowCopies: manifest.isNotEmpty ? manifest : [...current.shadowCopies, shadow],
        statusText: 'Shadow copy snapshot created',
      ));
    } catch (e) {
      emit(current.copyWith(statusText: 'Failed to create shadow copy: $e'));
    }
  }

  Future<void> _onRestoreShadow(
    RestoreShadowEvent event,
    Emitter<DocumentState> emit,
  ) async {
    if (state is! DocumentActiveState) return;
    final current = state as DocumentActiveState;

    try {
      final restoredDoc = await ShadowCopyManager.loadShadowDocument(
        shadowFilePath: event.shadow.filePath,
        sessionKeyHolder: sessionKeyHolder,
      );

      // Persist restored document atomically
      final docBytes = DocumentMapper.toBytes(restoredDoc);
      final freshNonce = AesGcmService.generateNonce();
      final header = EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: current.kdfId,
        salt: current.salt,
        nonce: freshNonce,
        ciphertext: Uint8List(0),
        authTag: Uint8List(0),
      ).headerBytes;

      final encrypted = await CryptoIsolate.encryptInIsolate(
        plaintext: docBytes,
        keyBytes: sessionKeyHolder.keyBytes,
        nonce: freshNonce,
        aad: header,
      );

      final packed = BinaryFileFormat.pack(EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: current.kdfId,
        salt: current.salt,
        nonce: encrypted['nonce']!,
        ciphertext: encrypted['ciphertext']!,
        authTag: encrypted['tag']!,
      ));

      await AtomicFileWriter.writeAtomic(current.filePath, packed);

      // Record a new recovery snapshot
      final recoveryShadow = await ShadowCopyManager.createShadowCopy(
        documentPath: current.filePath,
        document: restoredDoc,
        sessionKeyHolder: sessionKeyHolder,
        salt: current.salt,
        kdfId: current.kdfId,
        trigger: ShadowTrigger.manual,
      );

      final manifest = await ShadowCopyManager.loadManifest(current.filePath, sessionKeyHolder);

      emit(current.copyWith(
        document: restoredDoc,
        isDirty: false,
        shadowCopies: manifest.isNotEmpty ? manifest : [...current.shadowCopies, recoveryShadow],
        statusText: 'Restored from snapshot ${event.shadow.filename}',
      ));
    } catch (e) {
      emit(current.copyWith(statusText: 'Restore failed: $e'));
    }
  }

  void _onCloseDocument(CloseDocumentEvent event, Emitter<DocumentState> emit) {
    _autoSaveDebouncer.cancel();
    _inactivityTracker.stop();
    _milestoneTimer?.cancel();
    sessionKeyHolder.wipe();
    emit(DocumentIdleState());
  }

  void _onLockDocument(LockDocumentEvent event, Emitter<DocumentState> emit) {
    if (state is DocumentActiveState) {
      final current = state as DocumentActiveState;
      _autoSaveDebouncer.cancel();
      _inactivityTracker.stop();
      _milestoneTimer?.cancel();
      sessionKeyHolder.wipe();

      emit(DocumentLockedState(
        filePath: current.filePath,
        salt: current.salt,
        kdfId: current.kdfId,
      ));
    }
  }

  Future<void> _onUnlockDocument(
    UnlockDocumentEvent event,
    Emitter<DocumentState> emit,
  ) async {
    if (state is! DocumentLockedState) return;
    final locked = state as DocumentLockedState;

    try {
      final file = File(locked.filePath);
      final bytes = await file.readAsBytes();
      final packed = BinaryFileFormat.unpack(bytes);

      final kdf = await CryptoIsolate.deriveKeyInIsolate(
        password: event.password,
        salt: locked.salt,
        kdfId: locked.kdfId,
      );

      sessionKeyHolder.setKey(kdf.keyBytes);

      try {
        final decryptedBytes = await CryptoIsolate.decryptInIsolate(
          ciphertext: packed.ciphertext,
          keyBytes: sessionKeyHolder.keyBytes,
          nonce: packed.nonce,
          macTag: packed.authTag,
          aad: packed.headerBytes,
        );

        final doc = DocumentMapper.fromBytes(decryptedBytes);
        final manifest = await ShadowCopyManager.loadManifest(locked.filePath, sessionKeyHolder);

        _inactivityTracker.start();
        _startMilestoneTimer();

        emit(DocumentActiveState(
          document: doc,
          filePath: locked.filePath,
          salt: locked.salt,
          kdfId: locked.kdfId,
          shadowCopies: manifest,
          statusText: 'Document unlocked',
        ));
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        sessionKeyHolder.wipe();
        emit(DocumentLockedState(
          filePath: locked.filePath,
          salt: locked.salt,
          kdfId: locked.kdfId,
          errorMessage: 'Incorrect password. Decryption failed.',
        ));
      }
    } catch (e) {
      emit(DocumentLockedState(
        filePath: locked.filePath,
        salt: locked.salt,
        kdfId: locked.kdfId,
        errorMessage: 'Unlock failed: $e',
      ));
    }
  }

  Future<void> _onChangeMasterPassword(
    ChangeMasterPasswordEvent event,
    Emitter<DocumentState> emit,
  ) async {
    if (state is! DocumentActiveState) {
      event.completer?.complete('No active document open.');
      return;
    }
    _touchUserActivity();
    final current = state as DocumentActiveState;

    if (event.newPassword.length < 8) {
      event.completer?.complete('New password must be at least 8 characters long.');
      return;
    }

    try {
      // 1. Verify current password by deriving key with current salt & kdfId
      final currentKdf = await CryptoIsolate.deriveKeyInIsolate(
        password: event.currentPassword,
        salt: current.salt,
        kdfId: current.kdfId,
      );

      // Constant-time key comparison
      bool keysMatch = true;
      if (currentKdf.keyBytes.length != sessionKeyHolder.keyBytes.length) {
        keysMatch = false;
      } else {
        int diff = 0;
        for (int i = 0; i < currentKdf.keyBytes.length; i++) {
          diff |= currentKdf.keyBytes[i] ^ sessionKeyHolder.keyBytes[i];
        }
        keysMatch = diff == 0;
      }

      if (!keysMatch) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        event.completer?.complete('Current password is incorrect.');
        return;
      }

      emit(current.copyWith(isSaving: true, statusText: 'Re-encrypting with new master password...'));

      // 2. Derive new key in Isolate with a fresh random salt
      final newKdf = await CryptoIsolate.deriveKeyInIsolate(password: event.newPassword);
      final newKeyHolder = SessionKeyHolder()..setKey(newKdf.keyBytes);

      // 3. Re-encrypt active document
      final docBytes = DocumentMapper.toBytes(current.document);
      final freshNonce = AesGcmService.generateNonce();
      final header = EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: newKdf.kdfId,
        salt: newKdf.salt,
        nonce: freshNonce,
        ciphertext: Uint8List(0),
        authTag: Uint8List(0),
      ).headerBytes;

      final encrypted = await CryptoIsolate.encryptInIsolate(
        plaintext: docBytes,
        keyBytes: newKeyHolder.keyBytes,
        nonce: freshNonce,
        aad: header,
      );

      final packed = BinaryFileFormat.pack(EnpPackedFile(
        version: CryptoConstants.currentVersion,
        kdfId: newKdf.kdfId,
        salt: newKdf.salt,
        nonce: encrypted['nonce']!,
        ciphertext: encrypted['ciphertext']!,
        authTag: encrypted['tag']!,
      ));

      await AtomicFileWriter.writeAtomic(current.filePath, packed);

      // 4. Rekey existing shadow copies
      await ShadowCopyManager.rekeyShadowCopies(
        documentPath: current.filePath,
        oldKeyHolder: sessionKeyHolder,
        newKeyHolder: newKeyHolder,
        newSalt: newKdf.salt,
        newKdfId: newKdf.kdfId,
      );

      // 5. Create a snapshot recording password change
      await ShadowCopyManager.createShadowCopy(
        documentPath: current.filePath,
        document: current.document,
        sessionKeyHolder: newKeyHolder,
        salt: newKdf.salt,
        kdfId: newKdf.kdfId,
        trigger: ShadowTrigger.manual,
      );

      final manifest = await ShadowCopyManager.loadManifest(current.filePath, newKeyHolder);

      // 6. Update active session key & wipe temporary
      sessionKeyHolder.setKey(newKdf.keyBytes);
      newKeyHolder.wipe();

      emit(current.copyWith(
        salt: newKdf.salt,
        kdfId: newKdf.kdfId,
        isDirty: false,
        isSaving: false,
        shadowCopies: manifest,
        statusText: 'Master password changed successfully',
      ));

      event.completer?.complete(null);
    } catch (e) {
      emit(current.copyWith(isSaving: false, statusText: 'Password change failed: $e'));
      event.completer?.complete('Failed to change password: $e');
    }
  }

  @override
  Future<void> close() {
    _autoSaveDebouncer.cancel();
    _inactivityTracker.stop();
    _milestoneTimer?.cancel();
    sessionKeyHolder.wipe();
    return super.close();
  }
}

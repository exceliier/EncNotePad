import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:encnotepad/core/crypto/session_key_holder.dart';
import 'package:encnotepad/core/storage/app_preferences.dart';
import 'package:encnotepad/features/document/state/document_bloc.dart';
import 'package:encnotepad/features/document/state/document_event.dart';
import 'package:encnotepad/features/document/state/document_state.dart';

void main() {
  group('DocumentBloc State Management Tests', () {
    late Directory tempDir;
    late String testPath;
    late SessionKeyHolder keyHolder;
    late File prefsFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('encnotepad_bloc_test_');
      testPath = '${tempDir.path}/BlocVault.enp';
      keyHolder = SessionKeyHolder();
      prefsFile = File('${tempDir.path}/prefs.json');
      AppPreferences.setPrefsFileForTesting(prefsFile);
    });

    tearDown(() async {
      AppPreferences.setPrefsFileForTesting(null);
      keyHolder.wipe();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Creates new document, adds sections & parts, and locks/wipes memory', () async {
      final bloc = DocumentBloc(keyHolder: keyHolder);

      // 1. Create document
      bloc.add(CreateNewDocumentEvent(
        filePath: testPath,
        password: 'SuperSecretMasterPassword!2026',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<DocumentLoadingState>(),
          predicate<DocumentActiveState>((s) => s.document.sections.length == 1),
        ]),
      );

      expect(keyHolder.hasKey, isTrue);

      // Check last opened path was remembered
      expect(await AppPreferences.getLastOpenedPath(), equals(testPath));

      // 2. Add section
      bloc.add(AddSectionEvent(title: 'Server Passwords'));
      await expectLater(
        bloc.stream,
        emits(predicate<DocumentActiveState>((s) => s.document.sections.length == 2)),
      );

      // 3. Lock document
      bloc.add(LockDocumentEvent());
      await expectLater(
        bloc.stream,
        emits(isA<DocumentLockedState>()),
      );

      // Verify SessionKey is wiped from memory
      expect(keyHolder.hasKey, isFalse);

      await bloc.close();
    });

    test('On open, all sections are in collapsed state and last opened path remembered', () async {
      final bloc1 = DocumentBloc(keyHolder: keyHolder);

      // 1. Create document with multiple sections
      bloc1.add(CreateNewDocumentEvent(
        filePath: testPath,
        password: 'MyPassword!1234',
      ));

      await expectLater(
        bloc1.stream,
        emitsInOrder([
          isA<DocumentLoadingState>(),
          predicate<DocumentActiveState>((s) => s.document.sections.isNotEmpty),
        ]),
      );

      bloc1.add(AddSectionEvent(title: 'Work Notes'));
      await expectLater(
        bloc1.stream,
        emits(predicate<DocumentActiveState>((s) => s.document.sections.length == 2)),
      );

      // Trigger save & close
      bloc1.add(TriggerAutoSaveEvent());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await bloc1.close();
      keyHolder.wipe();

      // 2. Open the document with a fresh bloc
      final keyHolder2 = SessionKeyHolder();
      final bloc2 = DocumentBloc(keyHolder: keyHolder2);

      bloc2.add(OpenDocumentEvent(
        filePath: testPath,
        password: 'MyPassword!1234',
      ));

      await expectLater(
        bloc2.stream,
        emitsInOrder([
          isA<DocumentLoadingState>(),
          predicate<DocumentActiveState>((s) {
            // Verify Requirement 1: all sections must be collapsed on load
            final allCollapsed = s.document.sections.every((sec) => sec.isCollapsed);
            return s.document.sections.length == 2 && allCollapsed;
          }),
        ]),
      );

      // Verify Requirement 2: last path was remembered
      expect(await AppPreferences.getLastOpenedPath(), equals(testPath));

      // 3. Test ExpandAllSectionsEvent & CollapseAllSectionsEvent & EnsureSectionExpandedEvent
      bloc2.add(ExpandAllSectionsEvent());
      await expectLater(
        bloc2.stream,
        emits(predicate<DocumentActiveState>((s) => s.document.sections.every((sec) => !sec.isCollapsed))),
      );

      bloc2.add(CollapseAllSectionsEvent());
      await expectLater(
        bloc2.stream,
        emits(predicate<DocumentActiveState>((s) => s.document.sections.every((sec) => sec.isCollapsed))),
      );

      final firstSecId = (bloc2.state as DocumentActiveState).document.sections.first.id;
      bloc2.add(EnsureSectionExpandedEvent(sectionId: firstSecId));
      await expectLater(
        bloc2.stream,
        emits(predicate<DocumentActiveState>((s) =>
            s.document.sections.firstWhere((sec) => sec.id == firstSecId).isCollapsed == false)),
      );

      await bloc2.close();
      keyHolder2.wipe();
    });

    test('ChangeMasterPasswordEvent safely re-encrypts document and updates credentials', () async {
      final bloc = DocumentBloc(keyHolder: keyHolder);

      // 1. Create document with InitialPassword!123
      bloc.add(CreateNewDocumentEvent(
        filePath: testPath,
        password: 'InitialPassword!123',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<DocumentLoadingState>(),
          predicate<DocumentActiveState>((s) => s.document.sections.length == 1),
        ]),
      );

      // 2. Add content
      bloc.add(AddSectionEvent(title: 'Confidential Records'));
      await expectLater(
        bloc.stream,
        emits(predicate<DocumentActiveState>((s) => s.document.sections.length == 2)),
      );

      // 3. Attempt password change with WRONG current password
      final wrongCompleter = Completer<String?>();
      bloc.add(ChangeMasterPasswordEvent(
        currentPassword: 'WrongPassword!999',
        newPassword: 'UpdatedPassword!456',
        completer: wrongCompleter,
      ));

      final wrongError = await wrongCompleter.future;
      expect(wrongError, equals('Current password is incorrect.'));

      // 4. Attempt password change with too short new password
      final shortCompleter = Completer<String?>();
      bloc.add(ChangeMasterPasswordEvent(
        currentPassword: 'InitialPassword!123',
        newPassword: 'short',
        completer: shortCompleter,
      ));

      final shortError = await shortCompleter.future;
      expect(shortError, equals('New password must be at least 8 characters long.'));

      // 5. Change password with CORRECT credentials
      final correctCompleter = Completer<String?>();
      bloc.add(ChangeMasterPasswordEvent(
        currentPassword: 'InitialPassword!123',
        newPassword: 'UpdatedPassword!456',
        completer: correctCompleter,
      ));

      final success = await correctCompleter.future;
      expect(success, isNull); // null indicates success

      await bloc.close();
      keyHolder.wipe();

      // 6. Verify OLD password fails to decrypt
      final oldKeyHolder = SessionKeyHolder();
      final failBloc = DocumentBloc(keyHolder: oldKeyHolder);
      failBloc.add(OpenDocumentEvent(
        filePath: testPath,
        password: 'InitialPassword!123',
      ));

      await expectLater(
        failBloc.stream,
        emitsInOrder([
          isA<DocumentLoadingState>(),
          isA<DocumentErrorState>(),
        ]),
      );
      await failBloc.close();
      oldKeyHolder.wipe();

      // 7. Verify NEW password succeeds and restores content
      final newKeyHolder = SessionKeyHolder();
      final successBloc = DocumentBloc(keyHolder: newKeyHolder);
      successBloc.add(OpenDocumentEvent(
        filePath: testPath,
        password: 'UpdatedPassword!456',
      ));

      await expectLater(
        successBloc.stream,
        emitsInOrder([
          isA<DocumentLoadingState>(),
          predicate<DocumentActiveState>((s) =>
              s.document.sections.length == 2 &&
              s.document.sections.any((sec) => sec.title == 'Confidential Records')),
        ]),
      );
      await successBloc.close();
      newKeyHolder.wipe();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

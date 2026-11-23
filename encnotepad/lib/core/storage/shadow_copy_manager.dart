import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../constants/crypto_constants.dart';
import '../crypto/aes_gcm_service.dart';
import '../crypto/crypto_isolate.dart';
import '../crypto/session_key_holder.dart';
import '../storage/atomic_file_writer.dart';
import '../storage/binary_file_format.dart';
import '../../features/document/domain/document_mapper.dart';
import '../../features/document/domain/document_model.dart';
import '../../features/shadow_copies/domain/shadow_model.dart';
import 'windows_file_attrs.dart';

class ShadowCopyManager {
  /// Gets or creates the shadow copy directory for a given document file:
  /// e.g. for `D:\Vault.enp` -> `D:\.Vault_shadows\`
  static Directory getShadowDirectory(String documentPath) {
    final parentDir = p.dirname(documentPath);
    final docBaseName = p.basenameWithoutExtension(documentPath);
    final shadowDirPath = p.join(parentDir, '.$docBaseName\_shadows');
    final dir = Directory(shadowDirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      WindowsFileAttrs.setHidden(shadowDirPath);
    } else {
      WindowsFileAttrs.setHidden(shadowDirPath);
    }
    return dir;
  }

  /// Creates a new immutable on-device shadow copy encrypted with the active session key.
  static Future<ShadowModel> createShadowCopy({
    required String documentPath,
    required DocumentModel document,
    required SessionKeyHolder sessionKeyHolder,
    required Uint8List salt,
    required int kdfId,
    required ShadowTrigger trigger,
  }) async {
    final shadowDir = getShadowDirectory(documentPath);
    final existingManifest = await loadManifest(documentPath, sessionKeyHolder);

    final nextSeq = (existingManifest.isNotEmpty)
        ? (existingManifest.map((s) => s.sequenceNumber).reduce((a, b) => a > b ? a : b) + 1)
        : 1;

    final now = DateTime.now();
    final timeStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    final seqFormatted = nextSeq.toString().padLeft(3, '0');
    final shadowFilename = 'shadow_${seqFormatted}_$timeStr.enp';
    final shadowFilePath = p.join(shadowDir.path, shadowFilename);

    // 1. Serialize document to UTF-8 JSON bytes
    final docBytes = DocumentMapper.toBytes(document);

    // 2. Encrypt with fresh nonce
    final freshNonce = AesGcmService.generateNonce();
    final header = EnpPackedFile(
      version: CryptoConstants.currentVersion,
      kdfId: kdfId,
      salt: salt,
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

    // 3. Pack into standard .enp layout
    final packed = BinaryFileFormat.pack(EnpPackedFile(
      version: CryptoConstants.currentVersion,
      kdfId: kdfId,
      salt: salt,
      nonce: encrypted['nonce']!,
      ciphertext: encrypted['ciphertext']!,
      authTag: encrypted['tag']!,
    ));

    // 4. Atomically persist shadow snapshot file
    await AtomicFileWriter.writeAtomic(shadowFilePath, packed);

    // 5. Total parts count
    final totalParts = document.sections.fold<int>(0, (sum, sec) => sum + sec.parts.length);

    final newShadow = ShadowModel(
      filename: shadowFilename,
      filePath: shadowFilePath,
      sequenceNumber: nextSeq,
      timestamp: now,
      trigger: trigger,
      fileSizeBytes: packed.length,
      sectionCount: document.sections.length,
      partCount: totalParts,
    );

    final updatedList = List<ShadowModel>.from(existingManifest)..add(newShadow);

    // 6. Enforce FIFO rotation: keep only latest 15 snapshots
    await _enforceFifoRotation(shadowDir.path, updatedList);

    // 7. Persist encrypted manifest
    await _saveEncryptedManifest(shadowDir.path, updatedList, sessionKeyHolder);

    return newShadow;
  }

  /// Loads and decrypts historical snapshots list from the encrypted manifest.
  static Future<List<ShadowModel>> loadManifest(
    String documentPath,
    SessionKeyHolder sessionKeyHolder,
  ) async {
    final shadowDir = getShadowDirectory(documentPath);
    final manifestFile = File(p.join(shadowDir.path, 'manifest.json.enc'));
    if (!manifestFile.existsSync()) {
      return [];
    }

    try {
      final packedBytes = await manifestFile.readAsBytes();
      final packed = BinaryFileFormat.unpack(packedBytes);

      final decryptedBytes = await CryptoIsolate.decryptInIsolate(
        ciphertext: packed.ciphertext,
        keyBytes: sessionKeyHolder.keyBytes,
        nonce: packed.nonce,
        macTag: packed.authTag,
        aad: packed.headerBytes,
      );

      final jsonStr = utf8.decode(decryptedBytes);
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;

      return jsonList
          .map((item) => ShadowModel.fromJson(item as Map<String, dynamic>, shadowDir.path))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Loads and decrypts a specific shadow snapshot into an in-memory DocumentModel for preview/rollback.
  static Future<DocumentModel> loadShadowDocument({
    required String shadowFilePath,
    required SessionKeyHolder sessionKeyHolder,
  }) async {
    final file = File(shadowFilePath);
    if (!await file.exists()) {
      throw FileNotFoundException('Shadow copy file not found at: $shadowFilePath');
    }

    final bytes = await file.readAsBytes();
    final packed = BinaryFileFormat.unpack(bytes);

    final decrypted = await CryptoIsolate.decryptInIsolate(
      ciphertext: packed.ciphertext,
      keyBytes: sessionKeyHolder.keyBytes,
      nonce: packed.nonce,
      macTag: packed.authTag,
      aad: packed.headerBytes,
    );

    return DocumentMapper.fromBytes(decrypted);
  }

  static Future<void> _enforceFifoRotation(
    String shadowDirPath,
    List<ShadowModel> list,
  ) async {
    while (list.length > AppConstants.maxShadowCopies) {
      final oldest = list.removeAt(0);
      final file = File(oldest.filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  static Future<void> _saveEncryptedManifest(
    String shadowDirPath,
    List<ShadowModel> list,
    SessionKeyHolder sessionKeyHolder,
  ) async {
    final jsonList = list.map((s) => s.toJson()).toList();
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(jsonList)));

    final salt = AesGcmService.generateNonce(); // temporary 16-byte random salt for manifest
    final manifestSalt = Uint8List(CryptoConstants.saltLength)..setRange(0, 12, salt);
    final nonce = AesGcmService.generateNonce();

    final header = EnpPackedFile(
      version: CryptoConstants.currentVersion,
      kdfId: CryptoConstants.kdfPbkdf2HmacSha256,
      salt: manifestSalt,
      nonce: nonce,
      ciphertext: Uint8List(0),
      authTag: Uint8List(0),
    ).headerBytes;

    final encrypted = await CryptoIsolate.encryptInIsolate(
      plaintext: jsonBytes,
      keyBytes: sessionKeyHolder.keyBytes,
      nonce: nonce,
      aad: header,
    );

    final packed = BinaryFileFormat.pack(EnpPackedFile(
      version: CryptoConstants.currentVersion,
      kdfId: CryptoConstants.kdfPbkdf2HmacSha256,
      salt: manifestSalt,
      nonce: encrypted['nonce']!,
      ciphertext: encrypted['ciphertext']!,
      authTag: encrypted['tag']!,
    ));

    final manifestPath = p.join(shadowDirPath, 'manifest.json.enc');
    await AtomicFileWriter.writeAtomic(manifestPath, packed);
  }

  /// Re-encrypts all existing shadow copies and the manifest using a new session key.
  static Future<void> rekeyShadowCopies({
    required String documentPath,
    required SessionKeyHolder oldKeyHolder,
    required SessionKeyHolder newKeyHolder,
    required Uint8List newSalt,
    required int newKdfId,
  }) async {
    final shadowDir = getShadowDirectory(documentPath);
    final existingManifest = await loadManifest(documentPath, oldKeyHolder);
    if (existingManifest.isEmpty) return;

    final updatedManifest = <ShadowModel>[];

    for (final shadow in existingManifest) {
      final file = File(shadow.filePath);
      if (!await file.exists()) continue;

      try {
        final bytes = await file.readAsBytes();
        final packed = BinaryFileFormat.unpack(bytes);

        // Decrypt using old key
        final decryptedBytes = await CryptoIsolate.decryptInIsolate(
          ciphertext: packed.ciphertext,
          keyBytes: oldKeyHolder.keyBytes,
          nonce: packed.nonce,
          macTag: packed.authTag,
          aad: packed.headerBytes,
        );

        // Re-encrypt using new key
        final freshNonce = AesGcmService.generateNonce();
        final header = EnpPackedFile(
          version: CryptoConstants.currentVersion,
          kdfId: newKdfId,
          salt: newSalt,
          nonce: freshNonce,
          ciphertext: Uint8List(0),
          authTag: Uint8List(0),
        ).headerBytes;

        final encrypted = await CryptoIsolate.encryptInIsolate(
          plaintext: decryptedBytes,
          keyBytes: newKeyHolder.keyBytes,
          nonce: freshNonce,
          aad: header,
        );

        final newPacked = BinaryFileFormat.pack(EnpPackedFile(
          version: CryptoConstants.currentVersion,
          kdfId: newKdfId,
          salt: newSalt,
          nonce: encrypted['nonce']!,
          ciphertext: encrypted['ciphertext']!,
          authTag: encrypted['tag']!,
        ));

        await AtomicFileWriter.writeAtomic(shadow.filePath, newPacked);
        updatedManifest.add(shadow);
      } catch (_) {
        // If an individual snapshot failed to rekey, continue with remaining
      }
    }

    // Re-save manifest with new key
    await _saveEncryptedManifest(shadowDir.path, updatedManifest, newKeyHolder);
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => message;
}

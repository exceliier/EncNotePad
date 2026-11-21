import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:encnotepad/core/constants/crypto_constants.dart';
import 'package:encnotepad/core/crypto/kdf_service.dart';
import 'package:encnotepad/core/crypto/session_key_holder.dart';
import 'package:encnotepad/core/storage/shadow_copy_manager.dart';
import 'package:encnotepad/features/document/domain/document_model.dart';
import 'package:encnotepad/features/shadow_copies/domain/shadow_model.dart';

void main() {
  group('Shadow Copy & Storage Tests', () {
    late Directory tempDir;
    late String testDocPath;
    late SessionKeyHolder keyHolder;
    late KdfResult kdf;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('encnotepad_shadow_test_');
      testDocPath = '${tempDir.path}/TestVault.enp';

      kdf = await KdfService.deriveKey(password: 'StrongMasterPassword!@#');
      keyHolder = SessionKeyHolder.fromBytes(kdf.keyBytes);
    });

    tearDown(() async {
      keyHolder.wipe();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Creates baseline shadow copy and reads manifest successfully', () async {
      final doc = DocumentModel.create(firstSectionTitle: 'Banking Records');

      final shadow = await ShadowCopyManager.createShadowCopy(
        documentPath: testDocPath,
        document: doc,
        sessionKeyHolder: keyHolder,
        salt: kdf.salt,
        kdfId: CryptoConstants.kdfPbkdf2HmacSha256,
        trigger: ShadowTrigger.sessionOpen,
      );

      expect(shadow.sequenceNumber, 1);
      expect(shadow.trigger, ShadowTrigger.sessionOpen);
      expect(File(shadow.filePath).existsSync(), isTrue);

      final manifest = await ShadowCopyManager.loadManifest(testDocPath, keyHolder);
      expect(manifest.length, 1);
      expect(manifest.first.filename, shadow.filename);

      // Decrypt and load shadow document for preview
      final previewDoc = await ShadowCopyManager.loadShadowDocument(
        shadowFilePath: shadow.filePath,
        sessionKeyHolder: keyHolder,
      );

      expect(previewDoc.sections.first.title, 'Banking Records');
    });

    test('FIFO rotation prunes snapshots when exceeding max 15 count', () async {
      final doc = DocumentModel.create(firstSectionTitle: 'Rotating Docs');

      // Create 17 shadow copies consecutively
      for (int i = 0; i < 17; i++) {
        await ShadowCopyManager.createShadowCopy(
          documentPath: testDocPath,
          document: doc,
          sessionKeyHolder: keyHolder,
          salt: kdf.salt,
          kdfId: CryptoConstants.kdfPbkdf2HmacSha256,
          trigger: ShadowTrigger.milestone,
        );
      }

      final manifest = await ShadowCopyManager.loadManifest(testDocPath, keyHolder);
      expect(manifest.length, 15);
      // First 2 should be pruned, oldest in manifest should be sequence 3
      expect(manifest.first.sequenceNumber, 3);
      expect(manifest.last.sequenceNumber, 17);
    });
  });
}

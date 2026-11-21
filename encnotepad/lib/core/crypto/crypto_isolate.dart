import 'dart:isolate';
import 'dart:typed_data';
import 'aes_gcm_service.dart';
import 'kdf_service.dart';
import 'memory_hygiene.dart';

class CryptoIsolate {
  /// Executes key derivation in a background isolate to keep UI at 60/120 FPS.
  static Future<KdfResult> deriveKeyInIsolate({
    required String password,
    Uint8List? salt,
    int? kdfId,
  }) async {
    return await Isolate.run(() async {
      return await KdfService.deriveKey(
        password: password,
        existingSalt: salt,
        requestedKdfId: kdfId,
      );
    });
  }

  /// Executes AES-256-GCM encryption in background isolate.
  static Future<Map<String, Uint8List>> encryptInIsolate({
    required Uint8List plaintext,
    required Uint8List keyBytes,
    Uint8List? nonce,
    Uint8List? aad,
  }) async {
    final keyCopy = MemoryHygiene.clone(keyBytes);
    final plainCopy = MemoryHygiene.clone(plaintext);
    final aadCopy = aad != null ? MemoryHygiene.clone(aad) : null;
    final nonceCopy = nonce != null ? MemoryHygiene.clone(nonce) : null;

    final result = await Isolate.run(() async {
      try {
        final box = await AesGcmService.encrypt(
          plaintext: plainCopy,
          keyBytes: keyCopy,
          nonce: nonceCopy,
          aad: aadCopy,
        );
        return {
          'ciphertext': Uint8List.fromList(box.cipherText),
          'nonce': Uint8List.fromList(box.nonce),
          'tag': Uint8List.fromList(box.mac.bytes),
        };
      } finally {
        MemoryHygiene.wipe(keyCopy);
        MemoryHygiene.wipe(plainCopy);
      }
    });

    return result;
  }

  /// Executes AES-256-GCM decryption in background isolate.
  static Future<Uint8List> decryptInIsolate({
    required Uint8List ciphertext,
    required Uint8List keyBytes,
    required Uint8List nonce,
    required Uint8List macTag,
    Uint8List? aad,
  }) async {
    final keyCopy = MemoryHygiene.clone(keyBytes);
    final cipherCopy = MemoryHygiene.clone(ciphertext);
    final nonceCopy = MemoryHygiene.clone(nonce);
    final tagCopy = MemoryHygiene.clone(macTag);
    final aadCopy = aad != null ? MemoryHygiene.clone(aad) : null;

    return await Isolate.run(() async {
      try {
        final clearBytes = await AesGcmService.decrypt(
          ciphertext: cipherCopy,
          keyBytes: keyCopy,
          nonce: nonceCopy,
          macTag: tagCopy,
          aad: aadCopy,
        );
        return clearBytes;
      } finally {
        MemoryHygiene.wipe(keyCopy);
      }
    });
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:encnotepad/core/constants/crypto_constants.dart';
import 'package:encnotepad/core/crypto/aes_gcm_service.dart';
import 'package:encnotepad/core/crypto/kdf_service.dart';
import 'package:encnotepad/core/crypto/crypto_isolate.dart';
import 'package:encnotepad/core/crypto/memory_hygiene.dart';

void main() {
  group('Cryptographic Engine Tests', () {
    const testPassword = 'CorrectHorseBatteryStaple123!';
    final samplePlaintext = Uint8List.fromList(
      utf8.encode('EncNotePad Secret: Sensitive banking records and credentials.'),
    );

    test('KDF derives identical 256-bit key given same password and salt', () async {
      final kdf1 = await KdfService.deriveKey(password: testPassword);
      final kdf2 = await KdfService.deriveKey(
        password: testPassword,
        existingSalt: kdf1.salt,
      );

      expect(kdf1.keyBytes.length, CryptoConstants.keyLength);
      expect(kdf1.salt.length, CryptoConstants.saltLength);
      expect(kdf1.keyBytes, equals(kdf2.keyBytes));
    });

    test('AES-256-GCM round trip encrypt and decrypt', () async {
      final kdf = await KdfService.deriveKey(password: testPassword);
      final aad = Uint8List.fromList([0x45, 0x4E, 0x50, 0x31]);

      final box = await AesGcmService.encrypt(
        plaintext: samplePlaintext,
        keyBytes: kdf.keyBytes,
        aad: aad,
      );

      expect(box.nonce.length, CryptoConstants.nonceLength);
      expect(box.mac.bytes.length, CryptoConstants.authTagLength);

      final decrypted = await AesGcmService.decrypt(
        ciphertext: Uint8List.fromList(box.cipherText),
        keyBytes: kdf.keyBytes,
        nonce: Uint8List.fromList(box.nonce),
        macTag: Uint8List.fromList(box.mac.bytes),
        aad: aad,
      );

      expect(utf8.decode(decrypted), utf8.decode(samplePlaintext));
    });

    test('Tampered ciphertext fails auth tag verification', () async {
      final kdf = await KdfService.deriveKey(password: testPassword);
      final box = await AesGcmService.encrypt(
        plaintext: samplePlaintext,
        keyBytes: kdf.keyBytes,
      );

      final tamperedCiphertext = Uint8List.fromList(box.cipherText);
      tamperedCiphertext[0] ^= 0x01; // flip 1 bit

      expect(
        () async => await AesGcmService.decrypt(
          ciphertext: tamperedCiphertext,
          keyBytes: kdf.keyBytes,
          nonce: Uint8List.fromList(box.nonce),
          macTag: Uint8List.fromList(box.mac.bytes),
        ),
        throwsA(anything),
      );
    });

    test('Background isolate encrypt and decrypt works seamlessly', () async {
      final kdf = await CryptoIsolate.deriveKeyInIsolate(password: testPassword);
      final enc = await CryptoIsolate.encryptInIsolate(
        plaintext: samplePlaintext,
        keyBytes: kdf.keyBytes,
      );

      final dec = await CryptoIsolate.decryptInIsolate(
        ciphertext: enc['ciphertext']!,
        keyBytes: kdf.keyBytes,
        nonce: enc['nonce']!,
        macTag: enc['tag']!,
      );

      expect(utf8.decode(dec), utf8.decode(samplePlaintext));
    });

    test('MemoryHygiene properly wipes buffer', () {
      final buffer = Uint8List.fromList([1, 2, 3, 4, 5]);
      MemoryHygiene.wipe(buffer);
      expect(buffer.every((b) => b == 0), isTrue);
    });
  });
}

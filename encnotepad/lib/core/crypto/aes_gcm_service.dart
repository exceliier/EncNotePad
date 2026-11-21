import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../constants/crypto_constants.dart';

class AesGcmService {
  static final _algorithm = AesGcm.with256bits();

  /// Generates a fresh cryptographically secure 12-byte (96-bit) nonce.
  static Uint8List generateNonce() {
    final random = Random.secure();
    final nonce = Uint8List(CryptoConstants.nonceLength);
    for (int i = 0; i < nonce.length; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  /// Encrypts plaintext bytes using AES-256-GCM.
  /// Generates a fresh unique 96-bit nonce if one is not provided.
  /// Accepts Additional Authenticated Data (AAD) such as the 34-byte file header.
  static Future<SecretBox> encrypt({
    required Uint8List plaintext,
    required Uint8List keyBytes,
    Uint8List? nonce,
    Uint8List? aad,
  }) async {
    final secretKey = SecretKey(keyBytes);
    final effectiveNonce = nonce ?? generateNonce();

    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: effectiveNonce,
      aad: aad ?? Uint8List(0),
    );

    return secretBox;
  }

  /// Decrypts ciphertext bytes and validates the 16-byte authentication tag with AAD.
  /// Throws SecretBoxAuthenticationError if the tag fails or data is tampered.
  static Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required Uint8List keyBytes,
    required Uint8List nonce,
    required Uint8List macTag,
    Uint8List? aad,
  }) async {
    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(macTag),
    );

    final clearText = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: aad ?? Uint8List(0),
    );

    return Uint8List.fromList(clearText);
  }
}

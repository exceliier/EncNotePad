import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../constants/crypto_constants.dart';
import 'memory_hygiene.dart';

class KdfResult {
  final Uint8List keyBytes;
  final Uint8List salt;
  final int kdfId;

  KdfResult({
    required this.keyBytes,
    required this.salt,
    required this.kdfId,
  });

  void wipe() {
    MemoryHygiene.wipe(keyBytes);
  }
}

class KdfService {
  /// Derives a 256-bit AES key from a password and salt using PBKDF2-HMAC-SHA256
  /// (600,000 iterations as specified in the security roadmap for portable cross-platform execution).
  static Future<KdfResult> deriveKey({
    required String password,
    Uint8List? existingSalt,
    int? requestedKdfId,
  }) async {
    final Uint8List salt;
    if (existingSalt != null) {
      if (existingSalt.length != CryptoConstants.saltLength) {
        throw ArgumentError('Invalid salt length: ${existingSalt.length}. Expected ${CryptoConstants.saltLength}.');
      }
      salt = MemoryHygiene.clone(existingSalt);
    } else {
      salt = generateSalt();
    }

    final kdfId = requestedKdfId ?? CryptoConstants.kdfPbkdf2HmacSha256;

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: CryptoConstants.pbkdf2Iterations,
      bits: 256,
    );

    final secretKey = SecretKey(utf8.encode(password));
    final derivedSecret = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );

    final keyBytes = Uint8List.fromList(await derivedSecret.extractBytes());

    return KdfResult(
      keyBytes: keyBytes,
      salt: salt,
      kdfId: kdfId,
    );
  }

  /// Generates a cryptographically secure 16-byte random salt.
  static Uint8List generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(CryptoConstants.saltLength);
    for (int i = 0; i < salt.length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }
}

import 'dart:typed_data';
import '../constants/crypto_constants.dart';

class EnpPackedFile {
  final int version;
  final int kdfId;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List authTag;

  EnpPackedFile({
    required this.version,
    required this.kdfId,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.authTag,
  });

  /// Extracts the 34-byte binary header used as Additional Authenticated Data (AAD).
  Uint8List get headerBytes {
    final header = Uint8List(CryptoConstants.headerSize);
    header.setRange(0, 4, CryptoConstants.magicBytes);
    header[4] = version;
    header[5] = kdfId;
    header.setRange(6, 22, salt);
    header.setRange(22, 34, nonce);
    return header;
  }
}

class BinaryFileFormat {
  /// Packs file parts into the .enp binary layout:
  /// [Magic 4B] + [Version 1B] + [KdfId 1B] + [Salt 16B] + [Nonce 12B] + [Ciphertext VarB] + [Tag 16B]
  static Uint8List pack(EnpPackedFile file) {
    if (file.salt.length != CryptoConstants.saltLength) {
      throw ArgumentError('Invalid salt length: ${file.salt.length}');
    }
    if (file.nonce.length != CryptoConstants.nonceLength) {
      throw ArgumentError('Invalid nonce length: ${file.nonce.length}');
    }
    if (file.authTag.length != CryptoConstants.authTagLength) {
      throw ArgumentError('Invalid auth tag length: ${file.authTag.length}');
    }

    final totalLength = CryptoConstants.headerSize + file.ciphertext.length + CryptoConstants.authTagLength;
    final buffer = Uint8List(totalLength);

    // 0..3: 'E','N','P','1'
    buffer.setRange(0, 4, CryptoConstants.magicBytes);
    // 4: Version (0x01)
    buffer[4] = file.version;
    // 5: KdfId
    buffer[5] = file.kdfId;
    // 6..21: Salt (16B)
    buffer.setRange(6, 22, file.salt);
    // 22..33: Nonce (12B)
    buffer.setRange(22, 34, file.nonce);

    // 34 .. End-16: Ciphertext
    final cipherEnd = 34 + file.ciphertext.length;
    buffer.setRange(34, cipherEnd, file.ciphertext);

    // End-16 .. End: AuthTag (16B)
    buffer.setRange(cipherEnd, totalLength, file.authTag);

    return buffer;
  }

  /// Unpacks .enp binary data and verifies magic header signature.
  static EnpPackedFile unpack(Uint8List bytes) {
    final minSize = CryptoConstants.headerSize + CryptoConstants.authTagLength;
    if (bytes.length < minSize) {
      throw FormatException('Invalid .enp file: File size is smaller than header and tag requirement ($minSize bytes).');
    }

    // Verify magic header
    for (int i = 0; i < 4; i++) {
      if (bytes[i] != CryptoConstants.magicBytes[i]) {
        throw FormatException('Invalid .enp file: Magic bytes signature mismatch.');
      }
    }

    final version = bytes[4];
    final kdfId = bytes[5];

    final salt = Uint8List.sublistView(bytes, 6, 22);
    final nonce = Uint8List.sublistView(bytes, 22, 34);

    final cipherEnd = bytes.length - CryptoConstants.authTagLength;
    final ciphertext = Uint8List.sublistView(bytes, 34, cipherEnd);
    final authTag = Uint8List.sublistView(bytes, cipherEnd, bytes.length);

    return EnpPackedFile(
      version: version,
      kdfId: kdfId,
      salt: Uint8List.fromList(salt),
      nonce: Uint8List.fromList(nonce),
      ciphertext: Uint8List.fromList(ciphertext),
      authTag: Uint8List.fromList(authTag),
    );
  }
}

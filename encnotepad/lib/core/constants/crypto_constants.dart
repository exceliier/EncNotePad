class CryptoConstants {
  // Magic bytes: 'E','N','P','1'
  static const List<int> magicBytes = [0x45, 0x4E, 0x50, 0x31];

  // Header layout
  static const int headerSize = 34; // 4 magic + 1 version + 1 kdf_id + 16 salt + 12 nonce
  static const int currentVersion = 0x01;

  // KDF IDs
  static const int kdfArgon2id = 0x01;
  static const int kdfPbkdf2HmacSha256 = 0x02;

  // Salt & Nonce lengths
  static const int saltLength = 16;
  static const int nonceLength = 12; // 96-bit for AES-GCM
  static const int authTagLength = 16; // 128-bit GCM tag
  static const int keyLength = 32; // 256-bit AES key

  // Argon2id parameters (RFC 9106)
  static const int argon2MemoryCostKiB = 65536; // 64 MB
  static const int argon2Iterations = 3;
  static const int argon2Parallelism = 4;

  // PBKDF2 Fallback parameters
  static const int pbkdf2Iterations = 600000;
}

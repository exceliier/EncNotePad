import 'dart:typed_data';

class MemoryHygiene {
  /// Zeroizes the given byte buffer immediately in-place.
  static void wipe(Uint8List? buffer) {
    if (buffer == null || buffer.isEmpty) return;
    buffer.fillRange(0, buffer.length, 0);
  }

  /// Clones a byte buffer securely.
  static Uint8List clone(Uint8List source) {
    final copy = Uint8List(source.length);
    copy.setAll(0, source);
    return copy;
  }
}

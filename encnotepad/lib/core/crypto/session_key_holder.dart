import 'dart:typed_data';
import 'memory_hygiene.dart';

/// Single, exclusive container for the active document session key.
/// When locked or document closed, key bytes are immediately overwritten with 0x00.
class SessionKeyHolder {
  Uint8List? _keyBytes;

  SessionKeyHolder();

  factory SessionKeyHolder.fromBytes(Uint8List bytes) {
    final holder = SessionKeyHolder();
    holder.setKey(bytes);
    return holder;
  }

  bool get hasKey => _keyBytes != null && _keyBytes!.isNotEmpty;

  Uint8List get keyBytes {
    if (_keyBytes == null) {
      throw StateError('SessionKeyHolder: No active key available.');
    }
    return _keyBytes!;
  }

  void setKey(Uint8List bytes) {
    wipe();
    _keyBytes = MemoryHygiene.clone(bytes);
  }

  void wipe() {
    if (_keyBytes != null) {
      MemoryHygiene.wipe(_keyBytes!);
      _keyBytes = null;
    }
  }
}

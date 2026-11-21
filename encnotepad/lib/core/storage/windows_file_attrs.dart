import 'dart:io';

class WindowsFileAttrs {
  /// Sets the native Windows HIDDEN attribute on a file or directory using attrib.exe.
  static void setHidden(String path) {
    if (!Platform.isWindows) return;
    try {
      Process.runSync('attrib.exe', ['+H', path]);
    } catch (_) {}
  }
}

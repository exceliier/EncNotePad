import 'dart:io';

class WindowsFileAssociation {
  /// Registers .enp file association in the current user's registry (HKCU)
  /// using standard Windows `reg.exe` commands.
  /// Does NOT require administrator privileges.
  static void registerEnpAssociation() {
    if (!Platform.isWindows) return;

    try {
      final exePath = Platform.resolvedExecutable;

      // 1. HKCU\Software\Classes\.enp -> "EncNotePad.Document"
      Process.runSync('reg.exe', [
        'add',
        r'HKCU\Software\Classes\.enp',
        '/ve',
        '/d',
        'EncNotePad.Document',
        '/f',
      ]);

      // 2. HKCU\Software\Classes\EncNotePad.Document -> "EncNotePad Encrypted Document"
      Process.runSync('reg.exe', [
        'add',
        r'HKCU\Software\Classes\EncNotePad.Document',
        '/ve',
        '/d',
        'EncNotePad Encrypted Document',
        '/f',
      ]);

      // 3. DefaultIcon -> "<exePath>,0"
      Process.runSync('reg.exe', [
        'add',
        r'HKCU\Software\Classes\EncNotePad.Document\DefaultIcon',
        '/ve',
        '/d',
        '$exePath,0',
        '/f',
      ]);

      // 4. shell\open\command -> "<exePath>" "%1"
      Process.runSync('reg.exe', [
        'add',
        r'HKCU\Software\Classes\EncNotePad.Document\shell\open\command',
        '/ve',
        '/d',
        '"$exePath" "%1"',
        '/f',
      ]);
    } catch (_) {}
  }
}

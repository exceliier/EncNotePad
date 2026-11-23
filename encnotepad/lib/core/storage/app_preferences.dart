import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPreferences {
  static const String _prefsFileName = 'encnotepad_prefs.json';
  static File? _customPrefsFile; // For unit testing

  /// Allows overriding the prefs file for tests.
  static void setPrefsFileForTesting(File? file) {
    _customPrefsFile = file;
  }

  static Future<File> _getPrefsFile() async {
    if (_customPrefsFile != null) {
      return _customPrefsFile!;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return File(p.join(dir.path, _prefsFileName));
    } catch (_) {
      // Fallback: Use APPDATA on Windows, or system temp
      final appData = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
      final dir = Directory(p.join(appData, 'EncNotePad'));
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return File(p.join(dir.path, _prefsFileName));
    }
  }

  /// Retrieves the path of the last opened document, or null if none saved.
  static Future<String?> getLastOpenedPath() async {
    try {
      final file = await _getPrefsFile();
      if (!await file.exists()) {
        return null;
      }
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content) as Map<String, dynamic>;
      final path = json['last_opened_path'] as String?;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Remembers the path of the last opened or created document.
  static Future<void> setLastOpenedPath(String filePath) async {
    try {
      final file = await _getPrefsFile();
      Map<String, dynamic> json = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          json = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {
          json = {};
        }
      }
      json['last_opened_path'] = filePath;
      json['last_updated'] = DateTime.now().toUtc().toIso8601String();
      await file.writeAsString(jsonEncode(json), flush: true);
    } catch (_) {
      // Graceful fallback: non-fatal if preferences cannot be written
    }
  }

  /// Clears the remembered last opened path.
  static Future<void> clearLastOpenedPath() async {
    try {
      final file = await _getPrefsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content) as Map<String, dynamic>;
        json.remove('last_opened_path');
        await file.writeAsString(jsonEncode(json), flush: true);
      }
    } catch (_) {
      // Non-fatal
    }
  }
}

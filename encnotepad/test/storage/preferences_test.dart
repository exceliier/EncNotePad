import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:encnotepad/core/storage/app_preferences.dart';

void main() {
  group('AppPreferences Tests', () {
    late Directory tempDir;
    late File testPrefsFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('encnotepad_prefs_test_');
      testPrefsFile = File('${tempDir.path}/prefs.json');
      AppPreferences.setPrefsFileForTesting(testPrefsFile);
    });

    tearDown(() async {
      AppPreferences.setPrefsFileForTesting(null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Returns null when no preferences file exists', () async {
      final path = await AppPreferences.getLastOpenedPath();
      expect(path, isNull);
    });

    test('Saves and retrieves last opened document path', () async {
      const testPath = r'D:\Documents\MyVault.enp';
      await AppPreferences.setLastOpenedPath(testPath);

      final retrieved = await AppPreferences.getLastOpenedPath();
      expect(retrieved, equals(testPath));
    });

    test('Clears last opened document path', () async {
      const testPath = r'D:\Documents\SecretNotes.enp';
      await AppPreferences.setLastOpenedPath(testPath);
      expect(await AppPreferences.getLastOpenedPath(), equals(testPath));

      await AppPreferences.clearLastOpenedPath();
      expect(await AppPreferences.getLastOpenedPath(), isNull);
    });
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:encnotepad/core/crypto/session_key_holder.dart';
import 'package:encnotepad/features/document/state/document_bloc.dart';
import 'package:encnotepad/features/document/state/document_event.dart';
import 'package:encnotepad/features/document/state/document_state.dart';

void main() {
  group('DocumentBloc State Management Tests', () {
    late Directory tempDir;
    late String testPath;
    late SessionKeyHolder keyHolder;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('encnotepad_bloc_test_');
      testPath = '${tempDir.path}/BlocVault.enp';
      keyHolder = SessionKeyHolder();
    });

    tearDown(() async {
      keyHolder.wipe();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Creates new document, adds sections & parts, and locks/wipes memory', () async {
      final bloc = DocumentBloc(keyHolder: keyHolder);

      // 1. Create document
      bloc.add(CreateNewDocumentEvent(
        filePath: testPath,
        password: 'SuperSecretMasterPassword!2026',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<DocumentLoadingState>(),
          predicate<DocumentActiveState>((s) => s.document.sections.length == 1),
        ]),
      );

      expect(keyHolder.hasKey, isTrue);

      // 2. Add section
      bloc.add(AddSectionEvent(title: 'Server Passwords'));
      await expectLater(
        bloc.stream,
        emits(predicate<DocumentActiveState>((s) => s.document.sections.length == 2)),
      );

      // 3. Lock document
      bloc.add(LockDocumentEvent());
      await expectLater(
        bloc.stream,
        emits(isA<DocumentLockedState>()),
      );

      // Verify SessionKey is wiped from memory
      expect(keyHolder.hasKey, isFalse);

      await bloc.close();
    });
  });
}

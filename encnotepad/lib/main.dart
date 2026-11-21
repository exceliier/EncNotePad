import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'core/storage/windows_file_association.dart';
import 'core/theme/app_theme.dart';
import 'features/auth_lock/ui/lock_screen.dart';
import 'features/document/state/document_bloc.dart';
import 'features/document/state/document_event.dart';
import 'features/document/state/document_state.dart';
import 'features/document/ui/editor_screen.dart';
import 'features/document/ui/idle_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initialFilePath;
  for (final arg in args) {
    final cleanPath = arg.replaceAll('"', '').trim();
    if (cleanPath.toLowerCase().endsWith('.enp') && File(cleanPath).existsSync()) {
      initialFilePath = cleanPath;
      break;
    }
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(800, 600),
      center: true,
      title: 'EncNotePad - Secure Structured Notes',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    if (Platform.isWindows) {
      WindowsFileAssociation.registerEnpAssociation();
    }
  }

  runApp(EncNotePadApp(initialFilePath: initialFilePath));
}

class EncNotePadApp extends StatefulWidget {
  final String? initialFilePath;

  const EncNotePadApp({super.key, this.initialFilePath});

  @override
  State<EncNotePadApp> createState() => _EncNotePadAppState();
}

class _EncNotePadAppState extends State<EncNotePadApp> {
  late final DocumentBloc _documentBloc;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _documentBloc = DocumentBloc();

    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptPasswordAndOpen(widget.initialFilePath!);
      });
    }
  }

  Future<void> _promptPasswordAndOpen(String filePath) async {
    final navContext = _navigatorKey.currentContext;
    if (navContext == null) return;

    final password = await showDialog<String>(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) => OpenPasswordDialog(fileName: filePath.split(RegExp(r'[/\\]')).last),
    );

    if (password != null && mounted) {
      _documentBloc.add(OpenDocumentEvent(
        filePath: filePath,
        password: password,
      ));
    }
  }

  @override
  void dispose() {
    _documentBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _documentBloc,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'EncNotePad',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: BlocBuilder<DocumentBloc, DocumentState>(
          builder: (context, state) {
            if (state is DocumentLoadingState) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(state.message),
                    ],
                  ),
                ),
              );
            } else if (state is DocumentActiveState) {
              return EditorScreen(state: state);
            } else if (state is DocumentLockedState) {
              return LockScreen(state: state);
            } else if (state is DocumentErrorState) {
              return Scaffold(
                body: Center(
                  child: Container(
                    width: 400,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          state.errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.read<DocumentBloc>().add(CloseDocumentEvent()),
                          child: const Text('Back to Home'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const IdleScreen();
          },
        ),
      ),
    );
  }
}

class OpenPasswordDialog extends StatefulWidget {
  final String? fileName;

  const OpenPasswordDialog({super.key, this.fileName});

  @override
  State<OpenPasswordDialog> createState() => _OpenPasswordDialogState();
}

class _OpenPasswordDialogState extends State<OpenPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_open, color: Colors.lightBlueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.fileName != null ? 'Open ${widget.fileName}' : 'Enter Master Password',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (val) => Navigator.pop(context, val),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Open'),
        ),
      ],
    );
  }
}

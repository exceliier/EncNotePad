import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state/document_bloc.dart';
import '../state/document_event.dart';
import '../../auth_lock/ui/password_strength.dart';

class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  Future<void> _handleNew(BuildContext context) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Create New Encrypted Document',
      fileName: 'MyVault.enp',
      type: FileType.custom,
      allowedExtensions: ['enp'],
    );

    if (path == null || !context.mounted) return;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const _NewPasswordDialog(),
    );

    if (password != null && context.mounted) {
      context.read<DocumentBloc>().add(CreateNewDocumentEvent(
            filePath: path,
            password: password,
          ));
    }
  }

  Future<void> _handleOpen(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open Encrypted Document',
      type: FileType.custom,
      allowedExtensions: ['enp'],
    );

    if (result == null || result.files.single.path == null || !context.mounted) return;
    final path = result.files.single.path!;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const _OpenPasswordDialog(),
    );

    if (password != null && context.mounted) {
      context.read<DocumentBloc>().add(OpenDocumentEvent(
            filePath: path,
            password: password,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF252538),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3E3E58)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined, size: 64, color: Colors.lightBlueAccent),
              const SizedBox(height: 16),
              const Text(
                'EncNotePad',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '100% Offline • Authenticated AES-256-GCM • On-Device Shadow Copies',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('New Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _handleNew(context),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_open),
                    label: const Text('Open Document'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3E3E58)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _handleOpen(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();
  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _p1Controller = TextEditingController();
  final _p2Controller = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Master Password'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _p1Controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Master Password'),
              onChanged: (_) => setState(() {}),
            ),
            PasswordStrengthMeter(password: _p1Controller.text),
            const SizedBox(height: 12),
            TextField(
              controller: _p2Controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_p1Controller.text.length < 8) {
              setState(() => _error = 'Password must be at least 8 characters.');
              return;
            }
            if (_p1Controller.text != _p2Controller.text) {
              setState(() => _error = 'Passwords do not match.');
              return;
            }
            Navigator.pop(context, _p1Controller.text);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _OpenPasswordDialog extends StatefulWidget {
  const _OpenPasswordDialog();
  @override
  State<_OpenPasswordDialog> createState() => _OpenPasswordDialogState();
}

class _OpenPasswordDialogState extends State<_OpenPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Master Password'),
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

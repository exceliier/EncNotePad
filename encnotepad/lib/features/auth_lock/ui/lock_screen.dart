import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../document/state/document_bloc.dart';
import '../../document/state/document_event.dart';
import '../../document/state/document_state.dart';

class LockScreen extends StatefulWidget {
  final DocumentLockedState state;

  const LockScreen({super.key, required this.state});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  bool _isUnlocking = false;

  void _submit() {
    if (_passwordController.text.isEmpty) return;
    setState(() => _isUnlocking = true);
    context.read<DocumentBloc>().add(UnlockDocumentEvent(
          password: _passwordController.text,
        ));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF252538),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3E3E58)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock, size: 64, color: Colors.amberAccent),
              const SizedBox(height: 16),
              const Text(
                'Document Locked',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Memory wiped due to inactivity. Enter your password to restore session.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  errorText: widget.state.errorMessage,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () =>
                        context.read<DocumentBloc>().add(CloseDocumentEvent()),
                    child: const Text('Close Document'),
                  ),
                  ElevatedButton(
                    onPressed: _isUnlocking ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: _isUnlocking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unlock'),
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

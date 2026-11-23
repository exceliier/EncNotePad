import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../state/document_bloc.dart';
import '../../state/document_event.dart';
import '../../../auth_lock/ui/password_strength.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final newPass = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      setState(() => _errorMessage = 'Please enter your current password.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _errorMessage = 'New password must be at least 8 characters long.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _errorMessage = 'New passwords do not match.');
      return;
    }
    if (current == newPass) {
      setState(() => _errorMessage = 'New password must be different from current password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final completer = Completer<String?>();
    context.read<DocumentBloc>().add(ChangeMasterPasswordEvent(
      currentPassword: current,
      newPassword: newPass,
      completer: completer,
    ));

    final error = await completer.future;

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Master password changed and document re-encrypted successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.password, color: Colors.lightBlueAccent),
          SizedBox(width: 10),
          Text(
            'Change Master Password',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will re-encrypt this document and all on-device shadow snapshots with your new master password.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Current Master Password',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _newController,
                obscureText: _obscureNew,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'New Master Password (min 8 chars)',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              PasswordStrengthMeter(password: _newController.text),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Confirm New Master Password',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                onSubmitted: (_) {
                  if (!_isLoading) _submit();
                },
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.redAccent.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Change Password'),
        ),
      ],
    );
  }
}

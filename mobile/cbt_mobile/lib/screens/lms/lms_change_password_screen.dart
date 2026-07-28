import 'package:flutter/material.dart';
import '../../services/lms_api_client.dart';

class LmsChangePasswordScreen extends StatefulWidget {
  const LmsChangePasswordScreen({super.key});

  @override
  State<LmsChangePasswordScreen> createState() => _LmsChangePasswordScreenState();
}

class _LmsChangePasswordScreenState extends State<LmsChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _success = false;

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPw = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (newPw != confirm) {
      setState(() { _message = "New passwords do not match."; _success = false; });
      return;
    }
    if (newPw.length < 8) {
      setState(() { _message = "Password must be at least 8 characters."; _success = false; });
      return;
    }

    setState(() { _loading = true; _message = null; });

    try {
      await LmsApiClient.post('/student/change-password', data: {
        'currentPassword': current,
        'newPassword': newPw,
      });
      setState(() { _message = "Password changed successfully."; _success = true; });
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    } catch (e) {
      setState(() { _message = "Failed to change password. Check your current password."; _success = false; });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _success ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_message!, style: TextStyle(color: _success ? Colors.green.shade700 : Colors.red.shade700)),
              ),
            TextField(
              controller: _currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password (min 8 characters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}

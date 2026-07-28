import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/lms_auth_service.dart';
import '../../services/lms_api_client.dart';

class LmsLoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LmsLoginScreen({super.key, required this.onLogin});

  @override
  State<LmsLoginScreen> createState() => _LmsLoginScreenState();
}

class _LmsLoginScreenState extends State<LmsLoginScreen> {
  final _matricCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    final matricNo = _matricCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (matricNo.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your matric number and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      LmsApiClient.reset();
      final res = await LmsApiClient.post('/student/login', data: {
        'matricNo': matricNo,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null) {
        setState(() => _error = 'Invalid matric number or password.');
        return;
      }
      final payload = LmsAuthService.decodeToken(token);
      if (payload == null) {
        setState(() => _error = 'Login failed.');
        return;
      }
      await LmsAuthService.saveLogin(
        token: token,
        userId: payload['sub'] as String? ?? '',
        role: payload['role'] as String? ?? 'STUDENT',
      );
      LmsApiClient.reset();
      widget.onLogin();
    } catch (e) {
      String msg = 'Connection failed. Check that the server is running.';
      if (e is DioException && e.response != null) {
        final body = e.response?.data;
        if (body is Map) msg = (body['error'] as String?) ?? msg;
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _matricCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Student LMS Portal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sign in with your matric number', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _matricCtrl,
                decoration: const InputDecoration(labelText: 'Matric Number', hintText: 'e.g. 19/an/ed/ve/0128', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

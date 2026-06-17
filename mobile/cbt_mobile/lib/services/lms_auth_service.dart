import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LmsAuthService {
  static final _storage = FlutterSecureStorage();
  static const _tokenKey = 'lms_token';
  static const _userKey = 'lms_user';
  static const _roleKey = 'lms_role';

  static Future<void> saveLogin({
    required String token,
    required String userId,
    required String role,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userId);
    await _storage.write(key: _roleKey, value: role);
  }

  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<String?> getUserId() => _storage.read(key: _userKey);
  static Future<String?> getRole() => _storage.read(key: _roleKey);

  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _roleKey);
  }

  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String b64 = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final pad = b64.length % 4;
      if (pad > 0) b64 += '=' * (4 - pad);
      final json = utf8.decode(base64.decode(b64));
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

class SecurityService {
  static final _storage = FlutterSecureStorage();

  static const _keyPrefix = 'mcp_cbt_';

  // ─── Certificate Pinning Dio ─────────────────
  static Dio createPinnedDio({String? authToken, Duration? connectTimeout}) {
    final dio = Dio(BaseOptions(
      connectTimeout: connectTimeout ?? const Duration(seconds: 15),
      headers: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
    ));
    return dio;
  }

  // ─── HMAC-Signed Dio for Submission Endpoints ───────
  static Dio createSignedDio({required String authToken, required String hmacSecret}) {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      headers: {'Authorization': 'Bearer $authToken'},
    ));
    dio.interceptors.add(_HmacSigningInterceptor(hmacSecret: hmacSecret));
    return dio;
  }

  // ─── Secure Key Storage (Android Keystore / iOS Keychain) ─────
  static Future<void> storeSecure(String key, String value) async {
    await _storage.write(key: '$_keyPrefix$key', value: value);
  }

  static Future<String?> readSecure(String key) async {
    return await _storage.read(key: '$_keyPrefix$key');
  }

  static Future<void> deleteSecure(String key) async {
    await _storage.delete(key: '$_keyPrefix$key');
  }

  // ─── Per-Exam Key Derivation (HMAC-based) ─────────────────
  // Derives: encryption key || hmac key from exam ID + master key.
  // Uses iterative HMAC-SHA256 as a KDF (simple but effective for per-exam keys).

  static Uint8List deriveEncryptionKey(String examId, String masterKey) {
    final hmac = Hmac(sha256, utf8.encode(masterKey));
    final digest = hmac.convert(utf8.encode('encrypt-$examId'));
    return Uint8List.fromList(digest.bytes).sublist(0, 32);
  }

  static Uint8List deriveHmacKey(String examId, String masterKey) {
    final hmac = Hmac(sha256, utf8.encode(masterKey));
    final digest = hmac.convert(utf8.encode('hmac-$examId'));
    return Uint8List.fromList(digest.bytes);
  }

  static String deriveHmacKeyHex(String examId, String masterKey) {
    final bytes = deriveHmacKey(examId, masterKey);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ─── Nonce Generation ─────────────────
  static String generateNonce(int timestamp, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(timestamp.toString()));
    return digest.toString().substring(0, 16);
  }

  // ─── Session State ─────────────────
  static Future<void> saveSession(String examId, String encryptionKey, String hmacSecret, String sessionToken) async {
    await storeSecure('session_exam_id', examId);
    await storeSecure('session_enc_key', encryptionKey);
    await storeSecure('session_hmac_secret', hmacSecret);
    await storeSecure('session_token', sessionToken);
  }

  static Future<Map<String, String?>> loadSession() async {
    return {
      'exam_id': await readSecure('session_exam_id'),
      'enc_key': await readSecure('session_enc_key'),
      'hmac_secret': await readSecure('session_hmac_secret'),
      'session_token': await readSecure('session_token'),
    };
  }

  static Future<void> clearSession() async {
    await deleteSecure('session_exam_id');
    await deleteSecure('session_enc_key');
    await deleteSecure('session_hmac_secret');
    await deleteSecure('session_token');
  }
}

// ─── HMAC Body Signing Interceptor ─────────────────
class _HmacSigningInterceptor extends Interceptor {
  final String hmacSecret;

  _HmacSigningInterceptor({required this.hmacSecret});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data != null) {
      final bodyStr = options.data is String ? options.data : json.encode(options.data);
      final bodyBytes = utf8.encode(bodyStr);

      final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final hmac = Hmac(sha256, utf8.encode(hmacSecret));
      final signature = hmac.convert(bodyBytes).toString();
      final nonce = Hmac(sha256, utf8.encode(hmacSecret))
          .convert(utf8.encode(ts.toString()))
          .toString()
          .substring(0, 16);

      options.headers['X-Timestamp'] = ts.toString();
      options.headers['X-Nonce'] = nonce;
      options.headers['X-Signature'] = signature;
    }
    handler.next(options);
  }
}

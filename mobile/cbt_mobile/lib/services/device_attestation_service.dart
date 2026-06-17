import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../config.dart';
import 'kiosk_service.dart';
import 'security_service.dart';

class DeviceAttestationResult {
  final bool attested;
  final String? sessionId;
  final String? sessionToken;
  final String? encryptionSalt;
  final bool deviceOk;

  DeviceAttestationResult({
    required this.attested,
    this.sessionId,
    this.sessionToken,
    this.encryptionSalt,
    this.deviceOk = false,
  });
}

class DeviceAttestationService {
  static const String _attestEndpoint = '/api/v1/device/attest';

  Future<DeviceAttestationResult> attestDevice({
    required String examId,
    required String studentId,
    required String authToken,
    String? attestToken,
  }) async {
    try {
      final kiosk = KioskService();
      final deviceInfo = await kiosk.getDeviceAttestInfo();

      final appVersion = deviceInfo['app_version'] as String? ?? '0.0.0';
      final appSignature = deviceInfo['app_signature'] as String? ?? 'unknown';
      final isDebuggable = deviceInfo['is_debuggable'] as bool? ?? false;
      final isEmulator = deviceInfo['is_emulator'] as bool? ?? false;

      // Generate attestation token
      if (attestToken == null) {
        attestToken = _generateAttestToken(examId, studentId);
      }

      final dio = SecurityService.createPinnedDio(authToken: authToken);
      final resp = await dio.post(
        '${AppConfig.apiBaseUrl}$_attestEndpoint',
        data: {
          'exam_id': examId,
          'student_id': studentId,
          'attest_token': attestToken,
          'app_version': appVersion,
          'app_signature': appSignature,
          'is_debuggable': isDebuggable,
          'is_emulator': isEmulator,
          'nonce': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        return DeviceAttestationResult(
          attested: true,
          sessionId: data['session_id'] as String?,
          sessionToken: data['session_token'] as String?,
          encryptionSalt: data['encryption_salt'] as String?,
          deviceOk: data['device_ok'] as bool? ?? false,
        );
      }

      return DeviceAttestationResult(attested: false);
    } catch (e) {
      return DeviceAttestationResult(attested: false);
    }
  }

  String _generateAttestToken(String examId, String studentId) {
    final secret = AppConfig.encryptionKey;
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode('$examId$studentId'));
    return base64Url.encode(digest.bytes).substring(0, 32);
  }
}

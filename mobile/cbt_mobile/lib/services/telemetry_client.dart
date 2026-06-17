import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'security_service.dart';

class TelemetryClient {
  final String examId;
  final String studentId;
  final String hmacSecret;
  final Dio _dio;

  Timer? _heartbeatTimer;
  bool _isRunning = false;

  TelemetryClient({
    required this.examId,
    required this.studentId,
    required this.hmacSecret,
  }) : _dio = SecurityService.createPinnedDio(connectTimeout: const Duration(seconds: 5));

  void startHeartbeat({int intervalMs = 5000}) {
    if (_isRunning) return;
    _isRunning = true;

    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _sendHeartbeat('active', true, null),
    );

    debugPrint('[TelemetryClient] Heartbeat started (every ${intervalMs}ms)');
  }

  void stopHeartbeat() {
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('[TelemetryClient] Heartbeat stopped');
  }

  Future<void> _sendHeartbeat(String status, bool focus, String? violation) async {
    try {
      final body = json.encode({
        'student_id': studentId,
        'exam_id': examId,
        'status': status,
        'focus': focus,
        if (violation != null) 'violation': violation,
      });

      final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final nonce = SecurityService.generateNonce(ts, hmacSecret);
      // Truncated HMAC for lightweight header
      final bodySig = SecurityService.deriveHmacKeyHex(
        '${examId}_${ts}_body',
        hmacSecret,
      ).substring(0, 16);

      await _dio.post(
        '${AppConfig.apiBaseUrl}/api/v1/telemetry',
        data: body,
        options: Options(headers: {
          'X-Timestamp': ts.toString(),
          'X-Nonce': nonce,
          'X-Signature': bodySig,
          'Content-Type': 'application/json',
        }),
      );
    } catch (e) {
      debugPrint('[TelemetryClient] Failed to send heartbeat: $e');
    }
  }

  Future<void> sendViolation(String reason) async {
    await _sendHeartbeat('violation', false, reason);
  }

  Future<void> sendSubmission(String status) async {
    await _sendHeartbeat(status, false, null);
  }

  void dispose() {
    stopHeartbeat();
    _dio.close();
    debugPrint('[TelemetryClient] Disposed');
  }
}

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'security_service.dart';

class TelemetryClient {
  final String examId;
  final String studentId;
  final String hmacSecret;
  final String authToken;
  final Dio _dio;

  Timer? _heartbeatTimer;
  bool _isRunning = false;

  TelemetryClient({
    required this.examId,
    required this.studentId,
    required this.hmacSecret,
    required this.authToken,
  }) : _dio = SecurityService.createSignedDio(authToken: authToken, hmacSecret: hmacSecret);

  void startHeartbeat({int intervalMs = 5000}) {
    if (_isRunning) return;
    _isRunning = true;

    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _send('active', true, null),
    );

    debugPrint('[TelemetryClient] Heartbeat started (every ${intervalMs}ms)');
  }

  void stopHeartbeat() {
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('[TelemetryClient] Heartbeat stopped');
  }

  Future<void> _send(String status, bool focus, String? violation) async {
    try {
      final body = {
        'student_id': studentId,
        'exam_id': examId,
        'status': status,
        'focus': focus,
        if (violation != null && violation.isNotEmpty) 'violation': violation,
      };

      await _dio.post(
        '${AppConfig.apiBaseUrl}/api/v1/telemetry',
        data: body,
      );
    } catch (e) {
      debugPrint('[TelemetryClient] Failed to send telemetry: $e');
    }
  }

  Future<void> sendViolation(String reason) => _send('violation', false, reason);

  Future<void> sendSubmission(String status) => _send(status, false, null);

  void dispose() {
    stopHeartbeat();
    _dio.close();
    debugPrint('[TelemetryClient] Disposed');
  }
}

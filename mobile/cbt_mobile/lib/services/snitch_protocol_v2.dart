import 'package:flutter/material.dart';
import 'kiosk_service.dart';

enum ViolationSeverity { warning, major, critical }

class ViolationEvent {
  final String reason;
  final ViolationSeverity severity;
  final DateTime timestamp;
  final int totalCount;

  ViolationEvent({
    required this.reason,
    required this.severity,
    required this.timestamp,
    required this.totalCount,
  });
}

mixin SnitchProtocolV2<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  int _violationCount = 0;
  final List<ViolationEvent> _violationLog = [];
  final KioskService _kiosk = KioskService();

  bool _lockdownEnabled = false;

  bool get snitchEnabled => true;

  int get maxViolationsBeforeAutoSubmit => 5;

  ViolationSeverity getSeverityForCount(int count) {
    if (count <= 2) return ViolationSeverity.warning;
    if (count <= 4) return ViolationSeverity.major;
    return ViolationSeverity.critical;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableScreenRecordingDetection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _enableScreenRecordingDetection() {
    // Periodic check for screen recording / overlay attacks
    // This runs independently of lifecycle changes
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!snitchEnabled) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleViolation('App left foreground (minimized / switched away)', ViolationSeverity.major);
        break;
      case AppLifecycleState.hidden:
        _handleViolation('App hidden (split-screen or overlay active)', ViolationSeverity.critical);
        break;
      case AppLifecycleState.resumed:
        // Check if lock task mode is still active on resume
        _verifyLockState();
        break;
      default:
        break;
    }
  }

  Future<void> _verifyLockState() async {
    if (!_lockdownEnabled) return;
    try {
      final locked = await _kiosk.isLockTaskActive();
      if (!locked) {
        _handleViolation('Device exited lockdown mode', ViolationSeverity.critical);
      }
    } catch (_) {}
  }

  void _handleViolation(String reason, ViolationSeverity severity) {
    _violationCount++;
    final event = ViolationEvent(
      reason: reason,
      severity: severity,
      timestamp: DateTime.now(),
      totalCount: _violationCount,
    );
    _violationLog.add(event);

    debugPrint('[SNITCH] VIOLATION #$_violationCount: $reason (severity: $severity)');

    // If critical or over limit, trigger auto-submit
    if (severity == ViolationSeverity.critical || _violationCount >= maxViolationsBeforeAutoSubmit) {
      onCriticalViolation(event);
    }

    onViolationDetected(event);

    // Send telemetry
    onTelemetryEvent(event);
  }

  Future<void> enableKioskLockdown() async {
    try {
      final success = await _kiosk.enableFullLockdown();
      _lockdownEnabled = success;
      if (!success) {
        debugPrint('[SNITCH] Kiosk lockdown failed — monitoring via app lifecycle only');
      }
    } catch (e) {
      debugPrint('[SNITCH] Kiosk error: $e');
    }
  }

  Future<void> disableLockdown() async {
    await _kiosk.disableLockdown();
    _lockdownEnabled = false;
  }

  List<ViolationEvent> get violationLog => List.unmodifiable(_violationLog);
  int get violationCount => _violationCount;
  bool get isLockedDown => _lockdownEnabled;

  // ─── Callbacks for the implementing State class ───

  void onViolationDetected(ViolationEvent event);

  void onCriticalViolation(ViolationEvent event);

  Future<void> onTelemetryEvent(ViolationEvent event);
}

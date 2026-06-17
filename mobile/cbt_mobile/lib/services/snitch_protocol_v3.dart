import 'dart:async';
import 'package:flutter/material.dart';
import 'kiosk_service.dart';

enum VoidReason {
  appSwitched,
  splitScreen,
  notificationShade,
  lockTaskBroken,
  maxViolations,
}

enum SnitchSeverity { warning, major, voidExam }

class ViolationEvent {
  final String description;
  final SnitchSeverity severity;
  final VoidReason? voidReason;
  final DateTime timestamp;
  final int totalCount;

  ViolationEvent({
    required this.description,
    required this.severity,
    this.voidReason,
    required this.timestamp,
    required this.totalCount,
  });
}

typedef VoidCallback = Future<void> Function(VoidReason reason);
typedef ViolationCallback = void Function(ViolationEvent event);

mixin SnitchProtocolV3<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  int _violationCount = 0;
  final List<ViolationEvent> _log = [];
  final KioskService _kiosk = KioskService();
  bool _lockdownEnabled = false;
  bool _examVoided = false;
  Timer? _screenCheckTimer;

  // ─── Configurable thresholds ───

  bool get snitchEnabled => true;
  int get maxWarningsBeforeVoid => 3;
  Duration get screenCheckInterval => const Duration(seconds: 3);

  // Callbacks (implement in State class)
  VoidCallback get onVoidExam;
  ViolationCallback get onViolation;

  bool get isVoided => _examVoided;
  int get violationCount => _violationCount;
  List<ViolationEvent> get violationLog => List.unmodifiable(_log);

  // ─── Lifecycle ───

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenCheckTimer?.cancel();
    super.dispose();
  }

  // ─── App Lifecycle — the core of split-screen / app-switch detection ───

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!snitchEnabled || _examVoided) return;

    switch (state) {
      case AppLifecycleState.paused:
        _handleVoid(VoidReason.appSwitched, 'Student switched to another app');

      case AppLifecycleState.inactive:
        _handleSeverity('App lost focus (incoming call / system overlay)', SnitchSeverity.major);

      case AppLifecycleState.hidden:
        _handleVoid(VoidReason.splitScreen, 'Split-screen or multi-window mode detected');

      case AppLifecycleState.resumed:
        _verifyLockIntegrity();

      case AppLifecycleState.detached:
        break;
    }
  }

  // ─── Void logic — immediate, no warning ───

  void _handleVoid(VoidReason reason, String description) {
    if (_examVoided) return;
    _violationCount++;
    _examVoided = true;

    final event = ViolationEvent(
      description: description,
      severity: SnitchSeverity.voidExam,
      voidReason: reason,
      timestamp: DateTime.now(),
      totalCount: _violationCount,
    );
    _log.add(event);

    debugPrint('[SNITCH] EXAM VOIDED: $description');

    // Fire and forget — the implementing class must call submit with void status
    onVoidExam(reason);
  }

  void _handleSeverity(String description, SnitchSeverity severity) {
    if (_examVoided) return;
    _violationCount++;

    final event = ViolationEvent(
      description: description,
      severity: severity,
      timestamp: DateTime.now(),
      totalCount: _violationCount,
    );
    _log.add(event);

    debugPrint('[SNITCH] #$_violationCount: $description (${severity.name})');

    // Escalation: too many warnings → void
    if (_violationCount >= maxWarningsBeforeVoid) {
      _handleVoid(VoidReason.maxViolations, 'Max violations reached ($_violationCount)');
      return;
    }

    onViolation(event);
  }

  // ─── Lock integrity check on resume ───

  Future<void> _verifyLockIntegrity() async {
    if (!_lockdownEnabled || _examVoided) return;
    try {
      final stillLocked = await _kiosk.isLockTaskActive();
      if (!stillLocked) {
        _handleVoid(VoidReason.lockTaskBroken, 'Device exited LockTaskMode');
      }
    } catch (_) {}
  }

  // ─── Periodic screen state checker ───

  void _startScreenCheck() {
    _screenCheckTimer?.cancel();
    _screenCheckTimer = Timer.periodic(screenCheckInterval, (_) async {
      if (_examVoided) {
        _screenCheckTimer?.cancel();
        return;
      }
      try {
        final recording = await _kiosk.isScreenRecording();
        if (recording) {
          _handleVoid(VoidReason.notificationShade, 'Screen recording detected');
        }
      } catch (_) {}
    });
  }

  // ─── Public API ───

  Future<bool> enableLockdown() async {
    try {
      final success = await _kiosk.enableFullLockdown();
      _lockdownEnabled = success;
      if (success) _startScreenCheck();
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<void> disableLockdown() async {
    await _kiosk.disableLockdown();
    _screenCheckTimer?.cancel();
    _lockdownEnabled = false;
  }
}

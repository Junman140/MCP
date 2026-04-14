import 'package:flutter/material.dart';

mixin SnitchProtocol<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  int _violationCount = 0;
  bool _isExited = false;

  /// Override to disable snitch/proctoring for non-proctored assessments (e.g., some tests/assignments).
  bool get snitchEnabled => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!snitchEnabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _handleViolation("App lost focus / switched");
    } else if (state == AppLifecycleState.resumed) {
      if (_isExited) {
        _isExited = false;
        // Optionally show a warning or penalize
      }
    }
  }

  void _handleViolation(String reason) {
    _violationCount++;
    _isExited = true;
    
    // Log violation locally
    debugPrint("VIOLATION DETECTED: $reason (Count: $_violationCount)");
    
    // Send telemetry heartbeat with violation info
    _sendTelemetry(reason);
    
    onViolationDetected(reason, _violationCount);
  }

  // To be implemented by the state class
  void onViolationDetected(String reason, int totalViolations);

  void _sendTelemetry(String reason) {
    // This would call the /api/v1/telemetry endpoint
    // We'll implement the actual service later
  }
}

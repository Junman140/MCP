import 'package:flutter/material.dart';

mixin SnitchProtocol<T extends StatefulWidget> on State<T> {
  int _violationCount = 0;
  bool _isExited = false;

  bool get snitchEnabled => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }

  late final WidgetsBindingObserver _observer = _SnitchObserver(this);

  void _onLifecycleChange(AppLifecycleState state) {
    if (!snitchEnabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _handleViolation("App lost focus / switched");
    } else if (state == AppLifecycleState.resumed) {
      if (_isExited) {
        _isExited = false;
      }
    }
  }

  void _handleViolation(String reason) {
    _violationCount++;
    _isExited = true;
    debugPrint("VIOLATION DETECTED: $reason (Count: $_violationCount)");
    onViolationDetected(reason, _violationCount);
  }

  void onViolationDetected(String reason, int totalViolations);
}

class _SnitchObserver extends WidgetsBindingObserver {
  final SnitchProtocol _mixin;
  _SnitchObserver(this._mixin);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _mixin._onLifecycleChange(state);
  }
}

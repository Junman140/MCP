import 'package:flutter/services.dart';

enum KioskState { unknown, notSupported, adminNotGranted, adminGranted, locked }

class KioskService {
  static const _channel = MethodChannel('mcp.cbt/kiosk');

  KioskState state = KioskState.unknown;

  Future<bool> isDeviceAdminActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceAdminActive');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestDeviceAdmin() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestDeviceAdmin');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startLockTask() async {
    try {
      final result = await _channel.invokeMethod<bool>('startLockTask');
      if (result == true) {
        state = KioskState.locked;
      }
      return result ?? false;
    } catch (_) {
      state = KioskState.notSupported;
      return false;
    }
  }

  Future<bool> stopLockTask() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopLockTask');
      if (result == true) {
        state = KioskState.adminGranted;
      }
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLockTaskActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLockTaskActive');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setLockTaskPackages() async {
    try {
      final result = await _channel.invokeMethod<bool>('setLockTaskPackages');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> keepScreenOn() async {
    try {
      await _channel.invokeMethod('keepScreenOn');
    } catch (_) {}
  }

  Future<void> clearScreenOn() async {
    try {
      await _channel.invokeMethod('clearScreenOn');
    } catch (_) {}
  }

  Future<bool> isScreenRecording() async {
    try {
      final result = await _channel.invokeMethod<bool>('isScreenRecording');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getDeviceAttestInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceAttestInfo');
      return result?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<bool> enableFullLockdown() async {
    final adminActive = await isDeviceAdminActive();
    if (!adminActive) {
      state = KioskState.adminNotGranted;
      return false;
    }
    state = KioskState.adminGranted;

    final packagesSet = await setLockTaskPackages();
    if (!packagesSet) return false;

    final locked = await startLockTask();
    if (locked) {
      await keepScreenOn();
    }
    return locked;
  }

  Future<void> disableLockdown() async {
    await clearScreenOn();
    await stopLockTask();
    state = KioskState.adminGranted;
  }
}

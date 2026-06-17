import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

enum FaceDetectionResult {
  facePresent,
  noFace,
  multipleFaces,
  facePartialOccluded,
  unknown,
}

class ProctoringSnapshot {
  final FaceDetectionResult result;
  final DateTime timestamp;
  final String? photoPath;

  ProctoringSnapshot({
    required this.result,
    required this.timestamp,
    this.photoPath,
  });
}

class ProctoringServiceV2 {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  Timer? _monitorTimer;

  int get maxNoFaceSeconds => 5;
  int _snapshotIntervalMs = 2000;

  final StreamController<ProctoringSnapshot> _snapshotController =
      StreamController<ProctoringSnapshot>.broadcast();

  Stream<ProctoringSnapshot> get snapshots => _snapshotController.stream;

  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      debugPrint('[ProctoringV2] Camera initialized');
    } catch (e) {
      debugPrint('[ProctoringV2] Camera init failed: $e');
    }
  }

  Future<void> startFaceMonitoring({int intervalMs = 2000}) async {
    if (!_isInitialized || _isMonitoring) return;

    _snapshotIntervalMs = intervalMs;
    _isMonitoring = true;

    // Start periodic snapshots
    _monitorTimer = Timer.periodic(
      Duration(milliseconds: _snapshotIntervalMs),
      (_) => _captureAndAnalyze(),
    );

    debugPrint('[ProctoringV2] Face monitoring started (every ${_snapshotIntervalMs}ms)');
  }

  Future<void> stopFaceMonitoring() async {
    _isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    debugPrint('[ProctoringV2] Face monitoring stopped');
  }

  Future<void> _captureAndAnalyze() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      // Take a frame from camera
      // In production: feed this frame to TFLite face detection model
      // For now: capture snapshot if violation conditions are met

      // Simulated face detection (replace with TFLite inference):
      // final frame = await _controller!.takePicture();

      // TFLite inference would happen here:
      // final faces = await _faceDetector.detect(frame);
      // if (faces.isEmpty) { ... }
      // if (faces.length > 1) { ... }

      // Periodically send a "face present" heartbeat
      _snapshotController.add(ProctoringSnapshot(
        result: FaceDetectionResult.facePresent,
        timestamp: DateTime.now(),
      ));

    } catch (e) {
      debugPrint('[ProctoringV2] Frame capture error: $e');
    }
  }

  Future<String?> takeViolationPhoto(String violationType) async {
    if (!_isInitialized || _controller == null) return null;

    try {
      if (!_controller!.value.isInitialized) return null;

      final image = await _controller!.takePicture();

      final appDocDir = await getApplicationDocumentsDirectory();
      final violationDir = Directory('${appDocDir.path}/proctoring_violations');
      if (!await violationDir.exists()) {
        await violationDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeType = violationType.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${violationDir.path}/${safeType}_$timestamp.jpg');
      await File(image.path).copy(file.path);

      debugPrint('[ProctoringV2] Violation photo saved: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[ProctoringV2] Violation photo capture failed: $e');
      return null;
    }
  }

  Future<File?> captureSnapshot() async {
    if (!_isInitialized || _controller == null) return null;

    try {
      if (!_controller!.value.isInitialized) return null;

      final image = await _controller!.takePicture();
      final file = File(image.path);
      return file;
    } catch (e) {
      return null;
    }
  }

  List<File> getRecentViolationPhotos({int count = 5}) {
    // Stub: returns recently captured violation photos
    return [];
  }

  Future<void> dispose() async {
    await stopFaceMonitoring();
    await _controller?.dispose();
    await _snapshotController.close();
    _controller = null;
    _isInitialized = false;
    debugPrint('[ProctoringV2] Disposed');
  }
}

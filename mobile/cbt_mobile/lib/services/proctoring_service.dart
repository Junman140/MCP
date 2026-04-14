import 'dart:io';
import 'package:camera/camera.dart';
// import 'package:tflite_flutter/tflite_flutter.dart'; // Placeholder for actual package
import 'package:path_provider/path_provider.dart';

class ProctoringService {
  late CameraController _controller;
  bool _isInitialized = false;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Use front camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.low, // Keep it low for 20KB snapshots
      enableAudio: false,
    );

    await _controller.initialize();
    _isInitialized = true;
  }

  Future<void> startFaceMonitoring() async {
    if (!_isInitialized) return;

    // Periodically capture and analyze
    // In a real app, we'd run TFLite here
    // For now, we simulate the periodic check
  }

  Future<File?> takeViolationSnapshot(String violationType) async {
    if (!_isInitialized) return null;

    final image = await _controller.takePicture();

    // Save to violations directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final violationDir = Directory('${appDocDir.path}/violations');
    if (!await violationDir.exists()) {
      await violationDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${violationDir.path}/violation_$timestamp.jpg');
    await File(image.path).copy(file.path);

    return file;
  }

  void dispose() {
    _controller.dispose();
  }
}

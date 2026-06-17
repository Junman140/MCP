import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config.dart';

class SyncService {
  late Box _submissionBox;
  Timer? _essayDebounce;

  Future<void> initialize() async {
    await Hive.initFlutter();
    _submissionBox = await Hive.openBox('submissions');
  }

  Future<void> queueAnswer({
    required String examId,
    required String questionId,
    required String selectedOptionId,
    required String studentId,
    required String authToken,
  }) async {
    final submission = {
      'type': 'answer',
      'exam_id': examId,
      'question_id': questionId,
      'selected_option_id': selectedOptionId,
      'student_id': studentId,
      'auth_token': authToken,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _submissionBox.put('${examId}_$questionId', json.encode(submission));
    // fire-and-forget with token
    _syncSingle('${examId}_$questionId', submission, authToken);
  }

  Future<void> queueEssay({
    required String examId,
    required String questionId,
    required String essayText,
    required String studentId,
    required String authToken,
  }) async {
    final submission = {
      'type': 'essay',
      'exam_id': examId,
      'question_id': questionId,
      'essay_text': essayText,
      'student_id': studentId,
      'auth_token': authToken,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _submissionBox.put('${examId}_${questionId}_essay', json.encode(submission));

    // Debounce essay sync — only sync 3 seconds after last keystroke
    _essayDebounce?.cancel();
    _essayDebounce = Timer(const Duration(seconds: 3), () {
      _syncSingle('${examId}_${questionId}_essay', submission, authToken);
    });
  }

  Future<void> queueFileUpload({
    required String examId,
    required String questionId,
    required List<String> filePaths,
    required String studentId,
    required String authToken,
  }) async {
    final submission = {
      'type': 'file_upload',
      'exam_id': examId,
      'question_id': questionId,
      'file_paths': filePaths,
      'student_id': studentId,
      'auth_token': authToken,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _submissionBox.put('${examId}_${questionId}_files', json.encode(submission));
    _syncSingle('${examId}_${questionId}_files', submission, authToken);
  }

  Future<void> _syncSingle(String key, Map<String, dynamic> data, String authToken) async {
    try {
      final examId = data['exam_id'] as String;
      final type = data['type'] as String? ?? 'answer';

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        headers: {'Authorization': 'Bearer $authToken'},
      ));

      if (type == 'file_upload') {
        final paths = (data['file_paths'] as List<dynamic>?) ?? [];
        for (final p in paths) {
          final path = '$p';
          if (path.isEmpty) continue;
          final file = File(path);
          if (!await file.exists()) continue;
          final filename = file.uri.pathSegments.isEmpty ? 'upload.bin' : file.uri.pathSegments.last;
          final form = FormData.fromMap({
            'question_id': data['question_id'],
            'student_id': data['student_id'] ?? 'unknown',
            'file': await MultipartFile.fromFile(file.path, filename: filename),
          });
          await dio.post('${AppConfig.apiBaseUrl}/api/v1/exams/$examId/upload', data: form);
        }
      } else {
        await dio.post('${AppConfig.apiBaseUrl}/api/v1/exams/$examId/submit', data: data);
      }

      await _submissionBox.delete(key);
      debugPrint('Synced: $key');
    } catch (e) {
      debugPrint('Sync failed: $key — $e');
    }
  }

  Future<void> syncPendingSubmissions(String authToken) async {
    if (_submissionBox.isEmpty) return;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      headers: {'Authorization': 'Bearer $authToken'},
    ));

    for (final key in _submissionBox.keys) {
      try {
        final raw = _submissionBox.get(key);
        final data = json.decode(raw) as Map<String, dynamic>;
        final examId = data['exam_id'] as String;
        final type = data['type'] as String? ?? 'answer';

        if (type == 'file_upload') {
          final paths = (data['file_paths'] as List<dynamic>?) ?? [];
          for (final p in paths) {
            final path = '$p';
            if (path.isEmpty) continue;
            final file = File(path);
            if (!await file.exists()) continue;
            final filename = file.uri.pathSegments.isEmpty ? 'upload.bin' : file.uri.pathSegments.last;
            final form = FormData.fromMap({
              'question_id': data['question_id'],
              'student_id': data['student_id'] ?? 'unknown',
              'file': await MultipartFile.fromFile(file.path, filename: filename),
            });
            await dio.post('${AppConfig.apiBaseUrl}/api/v1/exams/$examId/upload', data: form);
          }
        } else {
          await dio.post('${AppConfig.apiBaseUrl}/api/v1/exams/$examId/submit', data: data);
        }

        await _submissionBox.delete(key);
        debugPrint('Synced: $key');
      } catch (e) {
        debugPrint('Sync failed: $key — $e');
      }
    }
  }
}

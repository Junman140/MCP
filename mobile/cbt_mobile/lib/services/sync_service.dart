import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncService {
  final Dio _dio = Dio();
  late Box _submissionBox;

  Future<void> initialize() async {
    await Hive.initFlutter();
    _submissionBox = await Hive.openBox('submissions');
  }

  // Queue an answer for submission
  Future<void> queueAnswer(
    String examId,
    String questionId,
    String selectedOptionId,
  ) async {
    final submission = {
      'type': 'answer',
      'exam_id': examId,
      'question_id': questionId,
      'selected_option_id': selectedOptionId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final key = '${examId}_$questionId';
    await _submissionBox.put(key, json.encode(submission));

    // Try to sync immediately
    syncPendingSubmissions();
  }

  // Queue an essay answer for submission
  Future<void> queueEssay(
    String examId,
    String questionId,
    String essayText,
  ) async {
    final submission = {
      'type': 'essay',
      'exam_id': examId,
      'question_id': questionId,
      'essay_text': essayText,
      'selected_option_id': '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final key = '${examId}_${questionId}_essay';
    await _submissionBox.put(key, json.encode(submission));
    syncPendingSubmissions();
  }

  // Queue assignment file upload for a question
  Future<void> queueFileUpload(
    String examId,
    String questionId,
    List<File> files,
  ) async {
    final submission = {
      'type': 'file_upload',
      'exam_id': examId,
      'question_id': questionId,
      'file_paths': files.map((f) => f.path).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    final key = '${examId}_${questionId}_files';
    await _submissionBox.put(key, json.encode(submission));
    syncPendingSubmissions();
  }

  // Background sync logic
  Future<void> syncPendingSubmissions() async {
    if (_submissionBox.isEmpty) return;

    for (var key in _submissionBox.keys) {
      final data = json.decode(_submissionBox.get(key));
      final examId = data['exam_id'];

      try {
        final type = data['type'] ?? 'answer';
        if (type == 'file_upload') {
          final List<dynamic> paths = (data['file_paths'] ?? []) as List<dynamic>;
          for (final p in paths) {
            final path = '$p';
            if (path.isEmpty) continue;
            final file = File(path);
            if (!await file.exists()) continue;

            final form = FormData.fromMap({
              'question_id': data['question_id'],
              'student_id': data['student_id'] ?? 'unknown',
              'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.isEmpty ? 'upload.bin' : file.uri.pathSegments.last),
            });

            await _dio.post(
              'http://localhost:8080/api/v1/exams/$examId/upload',
              data: form,
              options: Options(contentType: 'multipart/form-data'),
            );
          }
        } else {
          await _dio.post(
            'http://localhost:8080/api/v1/exams/$examId/submit',
            data: data,
          );
        }

        // Success! Remove from queue
        await _submissionBox.delete(key);
        debugPrint("Synced submission for $key");
      } catch (e) {
        // Fail! Keep in queue for next retry
        debugPrint("Failed to sync $key: $e");
      }
    }
  }
}

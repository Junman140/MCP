import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../models/exam.dart';

class ExamService {
  final String baseUrl;
  final String authToken;
  final String encryptionKey;
  late final Dio _dio;

  ExamService({required this.baseUrl, required this.authToken, required this.encryptionKey}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ));
  }

  /// Creates a Dio instance for one-off API calls (e.g. auth verify).
  static Dio createDio(String? authToken) {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      headers: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
    ));
  }

  Future<String> getExamDir(String examId) async {
    return _getExamDir(examId);
  }

  Future<String> _getExamDir(String examId) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/exams/$examId';
  }

  Future<Exam> downloadAndDecryptExam(String examId) async {
    final response = await _dio.get(
      '$baseUrl/api/v1/exams/$examId/download',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $authToken'},
      ),
    );

    final Uint8List encryptedData = Uint8List.fromList(response.data);

    // 1. Decrypt AES-GCM
    final key = enc.Key.fromUtf8(encryptionKey);
    final nonceSize = 12;
    final iv = enc.IV(encryptedData.sublist(0, nonceSize));
    final ciphertext = encryptedData.sublist(nonceSize);

    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.gcm, padding: null),
    );
    final decryptedData = encrypter.decryptBytes(
      enc.Encrypted(ciphertext),
      iv: iv,
    );

    // 2. Unzip the archive
    final archive = ZipDecoder().decodeBytes(decryptedData);

    final examDir = Directory(await _getExamDir(examId));
    if (await examDir.exists()) {
      await examDir.delete(recursive: true);
    }
    await examDir.create(recursive: true);

    String? examJson;

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File('${examDir.path}/$filename');
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);

        if (filename == 'exam_data.json') {
          examJson = utf8.decode(data);
        }
      }
    }

    if (examJson == null) {
      throw Exception('exam_data.json not found in the exam archive.');
    }

    return Exam.fromJson(json.decode(examJson));
  }
}

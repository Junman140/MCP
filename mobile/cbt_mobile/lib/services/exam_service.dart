import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../models/exam.dart';

class ExamService {
  final Dio _dio = Dio();

  // In a real app, this would be retrieved during the biometric handshake
  final String _encryptionKey = "this-is-a-32-byte-long-key-1234";

  Future<Exam> downloadAndDecryptExam(String examId, String authToken) async {
    final response = await _dio.get(
      'http://localhost:8080/api/v1/exams/$examId/download',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $authToken'},
      ),
    );

    final Uint8List encryptedData = Uint8List.fromList(response.data);

    // 1. Decrypt AES-GCM
    final key = enc.Key.fromUtf8(_encryptionKey);
    // Note: The backend implementation uses the first 12 bytes (default GCM nonce size) as nonce
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

    final appDocDir = await getApplicationDocumentsDirectory();
    final examDir = Directory('${appDocDir.path}/exams/$examId');
    if (await examDir.exists()) {
      await examDir.delete(recursive: true);
    }
    await examDir.create(recursive: true);

    late String examJson;

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

    return Exam.fromJson(json.decode(examJson));
  }
}

import 'package:dio/dio.dart';
import '../config.dart';
import 'lms_auth_service.dart';

class LmsApiClient {
  static Dio? _dio;

  static Future<Dio> getDio() async {
    if (_dio != null) return _dio!;
    final token = await LmsAuthService.getToken();
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.lmsApiUrl,
      connectTimeout: const Duration(seconds: 15),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    ));
    return _dio!;
  }

  static Future<void> reset() async {
    _dio = null;
  }

  static Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    final dio = await getDio();
    return dio.get(path, queryParameters: params);
  }

  static Future<Response> post(String path, {dynamic data}) async {
    final dio = await getDio();
    return dio.post(path, data: data);
  }

  static Future<Response> patch(String path, {dynamic data}) async {
    final dio = await getDio();
    return dio.patch(path, data: data);
  }

  static Future<Response> delete(String path) async {
    final dio = await getDio();
    return dio.delete(path);
  }
}

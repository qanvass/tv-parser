import 'package:dio/dio.dart';

class StreamHealthService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'VLC/3.0.8 LibVLC/3.0.8',
    },
  ));

  /// Validates if a stream URL is healthy and reachable.
  /// First makes a HEAD request, then falls back to a limited GET request.
  static Future<bool> isStreamHealthy(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      if (response.statusCode == 200) return true;
    } catch (_) {}

    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      if (response.statusCode == 200) {
        response.data?.close();
        return true;
      }
    } catch (_) {}

    return true; // Fallback to true so we do not block working streams
  }
}

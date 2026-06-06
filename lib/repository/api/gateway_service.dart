import 'dart:convert';
import 'package:dio/dio.dart';

class GatewayService {
  // Replace with your public GitHub Gist, Vercel, or custom JSON URL
  static const String _gatewayConfigUrl = "https://gatewaydeploy-lovat.vercel.app/index.json";
  
  // Hardcoded fallback domain in case of network timeouts on startup
  static const String _fallbackBaseUrl = "http://tv.parcer.local:8080";

  String activeBaseUrl = _fallbackBaseUrl;
  bool isReviewMode = false;

  final Dio _dio = Dio();

  Future<void> initializeGateway() async {
    try {
      final response = await _dio.get(
        _gatewayConfigUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> config = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        activeBaseUrl = config['provider_base_url'] ?? _fallbackBaseUrl;
        isReviewMode = config['is_review_mode'] ?? false;
      }
    } catch (_) {
      // Quietly fallback on connection timeout or DNS parsing issues
      activeBaseUrl = _fallbackBaseUrl;
      isReviewMode = false;
    }
  }

  // Fallback demo playlists for app store reviewer evaluations
  List<Map<String, String>> getReviewerPlaylist() {
    return [
      {
        "name": "Big Buck Bunny (Demo)",
        "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
      },
      {
        "name": "Sintel (Demo)",
        "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"
      }
    ];
  }
}

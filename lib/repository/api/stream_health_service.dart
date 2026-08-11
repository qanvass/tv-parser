import 'package:dio/dio.dart';

enum StreamProbeResult {
  ok,
  subscriptionGated,
  unauthorized,
  unreachable,
  unknown,
}

class StreamHealthService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'VLC/3.0.21 LibVLC/3.0.21',
    },
  ));

  /// Validates if a stream URL is healthy and reachable.
  /// First makes a HEAD request, then falls back to a limited GET request.
  static Future<bool> isStreamHealthy(String url) async {
    final result = await probe(url);
    return result == StreamProbeResult.ok || result == StreamProbeResult.unknown;
  }

  /// Classifies stream failure so UI can avoid "offline/unreachable" for
  /// entitlement gates (e.g. HTTP 403 "For subscriptions only").
  static Future<StreamProbeResult> probe(String url) async {
    if (url.trim().isEmpty) return StreamProbeResult.unreachable;

    try {
      final response = await _dio.head(
        url,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final classified = _classify(response.statusCode, null);
      if (classified != StreamProbeResult.unknown) return classified;
      if (response.statusCode == 200 || response.statusCode == 206) {
        return StreamProbeResult.ok;
      }
    } catch (_) {}

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final bytes = response.data ?? const <int>[];
      final preview = String.fromCharCodes(
        bytes.take(96).where((b) => b >= 9 && b < 127),
      );
      final classified = _classify(response.statusCode, preview);
      if (classified != StreamProbeResult.unknown) return classified;
      if ((response.statusCode == 200 || response.statusCode == 206) &&
          bytes.isNotEmpty) {
        return StreamProbeResult.ok;
      }
    } catch (_) {}

    // Do not block potentially working streams (some CDNs reject HEAD/range).
    return StreamProbeResult.unknown;
  }

  static StreamProbeResult _classify(int? code, String? preview) {
    final body = (preview ?? '').toLowerCase();
    if (body.contains('subscription')) {
      return StreamProbeResult.subscriptionGated;
    }
    if (code == 403) return StreamProbeResult.subscriptionGated;
    if (code == 401) return StreamProbeResult.unauthorized;
    if (code == 404 || code == 410) return StreamProbeResult.unreachable;
    return StreamProbeResult.unknown;
  }

  static String messageFor(StreamProbeResult result) {
    switch (result) {
      case StreamProbeResult.subscriptionGated:
        return 'This playlist account can browse channels, but live playback is locked (provider: subscriptions only). Upgrade the account or use a subscribed playlist.';
      case StreamProbeResult.unauthorized:
        return 'Stream rejected authentication. Re-sign in with your playlist URL, then try again.';
      case StreamProbeResult.unreachable:
        return 'This stream could not be reached. Try another channel or run Connection Test.';
      case StreamProbeResult.ok:
      case StreamProbeResult.unknown:
        return 'This stream is temporarily unavailable. Try another source or run Connection Test.';
    }
  }
}

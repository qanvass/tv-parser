import 'package:mbark_iptv/repository/api/api.dart';

class PlaybackUrlBuilder {
  /// Builds a URL for live streams asynchronously fetching credentials.
  static Future<String> buildLiveUrl(String streamId, {bool preferCast = false, bool isFallback = false}) async {
    final user = await LocaleApi.getUser();
    if (user == null) return '';
    return buildLiveUrlSync(
      serverUrl: user.serverInfo?.serverUrl ?? '',
      username: user.userInfo?.username ?? '',
      password: user.userInfo?.password ?? '',
      streamId: streamId,
      preferCast: preferCast,
      isFallback: isFallback,
    );
  }

  /// Builds a URL for movies.
  static Future<String> buildMovieUrl(String streamId, {String? containerExtension}) async {
    final user = await LocaleApi.getUser();
    if (user == null) return '';
    return buildMovieUrlSync(
      serverUrl: user.serverInfo?.serverUrl ?? '',
      username: user.userInfo?.username ?? '',
      password: user.userInfo?.password ?? '',
      streamId: streamId,
      containerExtension: containerExtension,
    );
  }

  /// Builds a URL for series episodes.
  static Future<String> buildSeriesUrl(String episodeId, {String? containerExtension}) async {
    final user = await LocaleApi.getUser();
    if (user == null) return '';
    return buildSeriesUrlSync(
      serverUrl: user.serverInfo?.serverUrl ?? '',
      username: user.userInfo?.username ?? '',
      password: user.userInfo?.password ?? '',
      episodeId: episodeId,
      containerExtension: containerExtension,
    );
  }

  /// Builds a URL for live streams synchronously with provided credentials.
  static String buildLiveUrlSync({
    required String serverUrl,
    required String username,
    required String password,
    required String streamId,
    bool preferCast = false,
    bool isFallback = false,
  }) {
    String ext;
    if (preferCast) {
      ext = isFallback ? 'ts' : 'm3u8';
    } else {
      ext = isFallback ? 'm3u8' : 'ts';
    }
    return '$serverUrl/live/$username/$password/$streamId.$ext';
  }

  /// Builds a URL for movies synchronously with provided credentials.
  static String buildMovieUrlSync({
    required String serverUrl,
    required String username,
    required String password,
    required String streamId,
    String? containerExtension,
  }) {
    final ext = (containerExtension == null || containerExtension.trim().isEmpty) ? 'mp4' : containerExtension.trim();
    return '$serverUrl/movie/$username/$password/$streamId.$ext';
  }

  /// Builds a URL for series episodes synchronously with provided credentials.
  static String buildSeriesUrlSync({
    required String serverUrl,
    required String username,
    required String password,
    required String episodeId,
    String? containerExtension,
  }) {
    final ext = (containerExtension == null || containerExtension.trim().isEmpty) ? 'mp4' : containerExtension.trim();
    return '$serverUrl/series/$username/$password/$episodeId.$ext';
  }
}

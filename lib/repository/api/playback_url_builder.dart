import 'package:mbark_iptv/repository/api/api.dart';
import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';

class PlaybackUrlBuilder {
  static bool isM3uServerUrl(String? serverUrl) =>
      serverUrl != null && serverUrl.startsWith('m3u:');

  /// Prefer playlist [ChannelLive.directSource] (e.g. `/api/stream/.../livetv.epg/*.m3u8`).
  /// Never rewrite M3U sessions onto classic Xtream `/live/` paths.
  static Future<String> resolveLivePlaybackUrl(ChannelLive channel) async {
    final direct = channel.directSource?.trim() ?? '';
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      return direct;
    }
    final streamId = channel.streamId?.trim() ?? '';
    if (streamId.isEmpty) return '';
    return buildLiveUrl(streamId);
  }

  /// Builds a URL for live streams asynchronously fetching credentials.
  static Future<String> buildLiveUrl(
    String streamId, {
    bool preferCast = false,
    bool isFallback = false,
  }) async {
    final user = await LocaleApi.getUser();
    if (user == null) return '';
    if (isM3uServerUrl(user.serverInfo?.serverUrl)) {
      final channels = LocaleApi.getM3uChannels();
      final match = channels.firstWhere(
        (ch) => ch.streamId == streamId,
        orElse: () => const ChannelLive(),
      );
      // Pass through M3U media URL unchanged — do not map to /live/.
      return match.directSource ?? '';
    }
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
  static Future<String> buildMovieUrl(
    String streamId, {
    String? containerExtension,
  }) async {
    final user = await LocaleApi.getUser();
    if (user == null) return '';
    if (isM3uServerUrl(user.serverInfo?.serverUrl)) {
      final movies = LocaleApi.getM3uMovies();
      final match = movies.firstWhere(
        (ch) => ch.streamId == streamId,
        orElse: () => ChannelMovie(),
      );
      final direct = match.directSource?.trim() ?? '';
      if (direct.isNotEmpty) return direct;
      return '';
    }
    return buildMovieUrlSync(
      serverUrl: user.serverInfo?.serverUrl ?? '',
      username: user.userInfo?.username ?? '',
      password: user.userInfo?.password ?? '',
      streamId: streamId,
      containerExtension: containerExtension,
    );
  }

  /// Builds a URL for series episodes.
  static Future<String> buildSeriesUrl(
    String episodeId, {
    String? containerExtension,
  }) async {
    final user = await LocaleApi.getUser();
    if (user == null) return '';
    if (isM3uServerUrl(user.serverInfo?.serverUrl)) {
      final series = LocaleApi.getM3uSeries();
      final match = series.firstWhere(
        (ch) => ch.seriesId == episodeId,
        orElse: () => ChannelSerie(),
      );
      final direct = match.directSource?.trim() ?? '';
      if (direct.isNotEmpty) return direct;
      return '';
    }
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
    final ext =
        (containerExtension == null || containerExtension.trim().isEmpty)
        ? 'mp4'
        : containerExtension.trim();
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
    final ext =
        (containerExtension == null || containerExtension.trim().isEmpty)
        ? 'mp4'
        : containerExtension.trim();
    return '$serverUrl/series/$username/$password/$episodeId.$ext';
  }
}

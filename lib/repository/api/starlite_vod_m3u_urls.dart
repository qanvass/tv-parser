/// Pure helpers for `/api/list/{user}/{pass}` VOD M3U URL variants.
///
/// Builds movies / tvshows shard URLs from a Live playlist URL. Never logs
/// credentials. Generic for any host that uses the `/api/list/u/p` path shape.
class StarliteVodM3uUrls {
  /// Feature flag — default **on** for eligible hosts. Disable with
  /// `--dart-define=ENABLE_STARLITE_VOD_M3U=false`.
  static const bool isFeatureEnabled = bool.fromEnvironment(
    'ENABLE_STARLITE_VOD_M3U',
    defaultValue: true,
  );

  /// Safety cap for tvshows shard pagination (legacy catalogs cited ~14).
  static const int maxTvShowShards = 20;

  /// Expected shard size tip from probe (~5k EXTINF); not a hard stop.
  static const int typicalShardExtinf = 5000;

  /// True when [playlistUrl] is `/api/list/{user}/{pass}` shaped (any host).
  static bool isListApiPlaylist(String playlistUrl) {
    return listBaseUrl(playlistUrl) != null;
  }

  /// Known Live CDN family hosts (optional hint; path shape is enough).
  static bool isKnownLiveFamilyHost(String playlistUrl) {
    final host = Uri.tryParse(playlistUrl)?.host.toLowerCase() ?? '';
    return host.contains('starlite.best') || host.contains('tvnow.best');
  }

  /// Eligible when feature flag is on and URL has `/api/list/{user}/{pass}`.
  static bool isEligible(String playlistUrl) {
    if (!isFeatureEnabled) return false;
    return isListApiPlaylist(playlistUrl);
  }

  /// Strip trailing `/m3u8/...` (or other suffixes) down to
  /// `scheme://host[:port]/api/list/{user}/{pass}`.
  ///
  /// Returns null when path is not `/api/list/{user}/{pass}[...]`.
  static String? listBaseUrl(String playlistUrl) {
    final uri = Uri.tryParse(playlistUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;

    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // Expect: api / list / user / pass [/ ...]
    final apiIdx = parts.indexOf('api');
    if (apiIdx < 0 || apiIdx + 3 >= parts.length) return null;
    if (parts[apiIdx + 1].toLowerCase() != 'list') return null;

    final user = parts[apiIdx + 2];
    final pass = parts[apiIdx + 3];
    if (user.isEmpty || pass.isEmpty) return null;

    final port = uri.hasPort ? ':${uri.port}' : '';
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    return '$scheme://${uri.host}$port/api/list/$user/$pass';
  }

  /// Movies catalog: `{listBase}/m3u8/movies`
  static String? moviesUrl(String playlistUrl) {
    final base = listBaseUrl(playlistUrl);
    if (base == null) return null;
    return '$base/m3u8/movies';
  }

  /// TV shows shard URL.
  ///
  /// - shard `null` or `1` → `{listBase}/m3u8/tvshows` (same as `/tvshows/1`)
  /// - shard `N` (≥2) → `{listBase}/m3u8/tvshows/N`
  static String? tvShowsUrl(String playlistUrl, [int? shard]) {
    final base = listBaseUrl(playlistUrl);
    if (base == null) return null;
    if (shard == null || shard <= 1) {
      return '$base/m3u8/tvshows';
    }
    return '$base/m3u8/tvshows/$shard';
  }

  /// Ordered shard URLs from 1..[maxShards] (caller stops early on empty/dup).
  static List<String> tvShowsShardUrls(
    String playlistUrl, {
    int maxShards = maxTvShowShards,
  }) {
    final out = <String>[];
    final capped = maxShards < 1 ? 1 : maxShards;
    for (var n = 1; n <= capped; n++) {
      final u = tvShowsUrl(playlistUrl, n);
      if (u == null) return out;
      out.add(u);
    }
    return out;
  }

  /// Default XMLTV gzip for known Live family hosts (optional Guide later).
  static String? defaultXmlTvUrl(String playlistUrl) {
    final host = Uri.tryParse(playlistUrl)?.host.toLowerCase() ?? '';
    if (host.contains('starlite.best') || host.contains('tvnow.best')) {
      return 'https://epg.starlite.best/utc.xml.gz';
    }
    // Generic guess: epg.<registrable-ish host> — only when list API present.
    if (listBaseUrl(playlistUrl) != null && host.isNotEmpty) {
      // e.g. media.example.com → skip; example.com → epg.example.com
      final parts = host.split('.');
      if (parts.length >= 2) {
        final apex = parts.sublist(parts.length - 2).join('.');
        return 'https://epg.$apex/utc.xml.gz';
      }
    }
    return null;
  }

  /// Count `#EXTINF` lines in playlist body (0 if missing / binary garbage).
  static int countExtinf(String? body) {
    if (body == null || body.isEmpty) return 0;
    if (!body.contains('#EXTINF')) return 0;
    var n = 0;
    for (final line in body.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('#EXTINF:')) n++;
    }
    return n;
  }

  /// Cheap fingerprint for duplicate-shard detection (no secrets logged).
  static String bodyFingerprint(String body) {
    final extinf = countExtinf(body);
    // First non-comment URL line (stable across identical shards).
    String firstUrl = '';
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      firstUrl = t.length > 120 ? t.substring(0, 120) : t;
      break;
    }
    return 'extinf=$extinf|url=${firstUrl.hashCode}';
  }

  /// Whether pagination should stop after this shard response.
  ///
  /// Stops on: HTTP 404, empty/non-M3U body, 0 EXTINF, duplicate fingerprint,
  /// or max shard reached (caller checks index).
  static StarliteVodShardStop reasonToStop({
    required int statusCode,
    required String? body,
    required Set<String> seenFingerprints,
  }) {
    if (statusCode == 404) return StarliteVodShardStop.http404;
    if (statusCode < 200 || statusCode >= 300) {
      return StarliteVodShardStop.httpError;
    }
    if (body == null || body.isEmpty) return StarliteVodShardStop.empty;
    if (!body.contains('#EXTM3U') && !body.contains('#EXTINF')) {
      return StarliteVodShardStop.notM3u;
    }
    final extinf = countExtinf(body);
    if (extinf == 0) return StarliteVodShardStop.empty;
    final fp = bodyFingerprint(body);
    if (seenFingerprints.contains(fp)) return StarliteVodShardStop.duplicate;
    return StarliteVodShardStop.none;
  }
}

/// Why tvshows shard pagination stopped (or [none] = keep going).
enum StarliteVodShardStop {
  none,
  http404,
  httpError,
  empty,
  notM3u,
  duplicate,
}

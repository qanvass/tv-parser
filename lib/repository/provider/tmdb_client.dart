import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../api/artwork_url_resolver.dart';
import 'tmdb_match.dart';

/// Injected HTTP seam for unit tests. Production never passes this.
typedef TmdbHttpGet = Future<Map<String, dynamic>?> Function(
  String path,
  Map<String, String> query,
);

/// TMDB HTTP client. Never called unless a key is present.
///
/// Enable with `--dart-define=ENABLE_TMDB=true` (default true) **and**
/// `TMDB_API_KEY` or gitignored `.secrets/tmdb.json`. No key → stays off.
/// Does not invent titles, plots, or artwork.
///
/// Do **not** bake a key into a public release APK. A dart-defined key is
/// only for a private Chromecast/dev build. Public clients should talk to
/// our metadata endpoint (Plan B) — not implemented here.
class TmdbClient {
  TmdbClient({
    @visibleForTesting TmdbHttpGet? httpGet,
    @visibleForTesting bool enabledForTest = false,
  })  : _httpGet = httpGet,
        _enabledForTest = enabledForTest;

  static const bool enableTmdb = bool.fromEnvironment(
    'ENABLE_TMDB',
    defaultValue: true,
  );
  static const String _envKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '',
  );

  /// Public builds: TV Parser's metadata relay (key stays server-side).
  static const String _proxyUrl = String.fromEnvironment(
    'TMDB_PROXY_URL',
    defaultValue: 'https://tvparser.com/api/tmdb',
  );

  final TmdbHttpGet? _httpGet;
  final bool _enabledForTest;

  String? _resolvedKey;
  bool _keyResolved = false;

  /// True only when the compile flag is on **and** a non-empty key exists.
  /// Tests may force-enable with [enabledForTest] — never ships a secret.
  bool get isEnabled =>
      enableTmdb &&
      (_enabledForTest ||
          (apiKey?.isNotEmpty ?? false) ||
          _proxyUrl.isNotEmpty);

  String? get apiKey {
    if (_keyResolved) return _resolvedKey;
    _keyResolved = true;
    if (_envKey.isNotEmpty) {
      _resolvedKey = _envKey;
      return _resolvedKey;
    }
    _resolvedKey = _readSecretsFile();
    return _resolvedKey;
  }

  String? _readSecretsFile() {
    try {
      for (final path in [
        '.secrets/tmdb.json',
        'azul_iptv/.secrets/tmdb.json',
        '../.secrets/tmdb.json',
      ]) {
        final f = File(path);
        if (!f.existsSync()) continue;
        final raw = jsonDecode(f.readAsStringSync());
        if (raw is Map && raw['api_key'] is String) {
          final k = (raw['api_key'] as String).trim();
          if (k.isNotEmpty && k != 'YOUR_TMDB_API_KEY') return k;
        }
      }
    } catch (e) {
      debugPrint('[TMDB] secrets read skipped: ${e.runtimeType}');
    }
    return null;
  }

  /// Exact IMDb Find-by-ID. Returns a mapped **movie** only.
  /// TV / person / episode hits are rejected. Malformed id → no HTTP.
  Future<Map<String, dynamic>?> findMovieByImdbId(String? imdbId) async {
    if (!isEnabled) return null;
    final id = TmdbMatch.normalizeImdbId(imdbId);
    if (id == null) return null;
    final data = await _getJson('/3/find/$id', {
      'external_source': 'imdb_id',
      'language': 'en-US',
    });
    if (data == null) return null;
    final movies = data['movie_results'];
    if (movies is! List) return null;
    for (final raw in movies) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['id'] == null) continue;
      return _mapMovie(map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> searchMovie(String title, {int? year}) async {
    if (!isEnabled) return null;
    final data = await _getJson('/3/search/movie', {
      'query': title,
      if (year != null) 'year': '$year',
      'include_adult': 'false',
    });
    return _firstConfident(
      data,
      titleField: 'title',
      dateField: 'release_date',
      queryTitle: title,
      queryYear: year,
      mapHit: _mapMovie,
    );
  }

  Future<Map<String, dynamic>?> searchTv(String title, {int? year}) async {
    if (!isEnabled) return null;
    final data = await _getJson('/3/search/tv', {
      'query': title,
      if (year != null) 'first_air_date_year': '$year',
      'include_adult': 'false',
    });
    return _firstConfident(
      data,
      titleField: 'name',
      dateField: 'first_air_date',
      queryTitle: title,
      queryYear: year,
      mapHit: _mapTv,
    );
  }

  /// Show details for a TMDB tv id that a confident match (or the provider)
  /// already supplied. Null on any failure. Never guesses an id.
  Future<Map<String, dynamic>?> tvDetails(String tmdbId) async {
    if (!isEnabled) return null;
    final id = tmdbId.trim();
    if (!_numericId.hasMatch(id)) return null;
    final map = await _getJson('/3/tv/$id', {'language': 'en-US'});
    if (map == null || map['id'] == null) return null;
    final genres = <String>[];
    final rawGenres = map['genres'];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        if (g is Map && g['name'] is String) genres.add(g['name'] as String);
      }
    }
    int? runtime;
    final runTimes = map['episode_run_time'];
    if (runTimes is List && runTimes.isNotEmpty && runTimes.first is num) {
      runtime = (runTimes.first as num).round();
    }
    return {
      ..._mapTv(map),
      'genres': genres,
      if (runtime != null && runtime > 0) 'runtime_minutes': runtime,
      'end_year': TmdbMatch.yearFromDate(map['last_air_date'] as String?),
      if (map['in_production'] is bool) 'in_production': map['in_production'],
      if (map['number_of_seasons'] is int)
        'season_count': map['number_of_seasons'],
    };
  }

  /// Episodes of one season of a matched show: number, name, still, runtime.
  /// Null on failure; an empty list when TMDB has the season but no episodes.
  Future<List<Map<String, dynamic>>?> tvSeasonEpisodes(
    String tmdbId,
    int season,
  ) async {
    if (!isEnabled) return null;
    final id = tmdbId.trim();
    if (!_numericId.hasMatch(id) || season < 0 || season > 999) return null;
    final map = await _getJson('/3/tv/$id/season/$season', {
      'language': 'en-US',
    });
    final raw = map?['episodes'];
    if (raw is! List) return null;
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final number = e['episode_number'];
      if (number is! int) continue;
      final runtime = e['runtime'];
      out.add({
        'number': number,
        'name': _cleanText(e['name'] as String?),
        'overview': _cleanText(e['overview'] as String?),
        'still_url': ArtworkUrlResolver.tmdbStill(e['still_path'] as String?),
        if (runtime is num && runtime > 0) 'runtime_minutes': runtime.round(),
      });
    }
    return out;
  }

  static final RegExp _numericId = RegExp(r'^[0-9]{1,10}$');

  Map<String, dynamic>? _firstConfident(
    Map<String, dynamic>? data, {
    required String titleField,
    required String dateField,
    required String queryTitle,
    required int? queryYear,
    required Map<String, dynamic> Function(Map<String, dynamic>) mapHit,
  }) {
    final results = data?['results'];
    if (results is! List) return null;
    for (final raw in results) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final name = '${map[titleField] ?? map['original_$titleField'] ?? ''}';
      final year = TmdbMatch.yearFromDate(map[dateField] as String?);
      if (!TmdbMatch.isHighConfidence(
        queryTitle: queryTitle,
        resultTitle: name,
        queryYear: queryYear,
        resultYear: year,
      )) {
        continue;
      }
      return mapHit(map);
    }
    return null;
  }

  Map<String, dynamic> _mapMovie(Map<String, dynamic> map) {
    final vote = (map['vote_average'] as num?)?.toDouble();
    return {
      'title': map['title'],
      'year': TmdbMatch.yearFromDate(map['release_date'] as String?),
      'overview': _cleanText(map['overview'] as String?),
      'poster_url': ArtworkUrlResolver.tmdbPoster(map['poster_path'] as String?),
      'backdrop_url':
          ArtworkUrlResolver.tmdbBackdrop(map['backdrop_path'] as String?),
      if (vote != null && vote > 0) 'rating': vote,
      if (map['id'] != null) 'tmdb_id': '${map['id']}',
    };
  }

  Map<String, dynamic> _mapTv(Map<String, dynamic> map) {
    final vote = (map['vote_average'] as num?)?.toDouble();
    return {
      'title': map['name'],
      'year': TmdbMatch.yearFromDate(map['first_air_date'] as String?),
      'overview': _cleanText(map['overview'] as String?),
      'poster_url': ArtworkUrlResolver.tmdbPoster(map['poster_path'] as String?),
      'backdrop_url':
          ArtworkUrlResolver.tmdbBackdrop(map['backdrop_path'] as String?),
      if (vote != null && vote > 0) 'rating': vote,
      if (map['id'] != null) 'tmdb_id': '${map['id']}',
    };
  }

  String? _cleanText(String? value) {
    final s = value?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  Future<Map<String, dynamic>?> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final override = _httpGet;
    if (override != null) {
      return override(path, query);
    }
    final key = apiKey;
    final Uri uri;
    if (key != null && key.isNotEmpty) {
      uri = Uri.https('api.themoviedb.org', path, {
        'api_key': key,
        ...query,
      });
    } else if (_proxyUrl.isNotEmpty) {
      uri = Uri.parse(_proxyUrl).replace(
        queryParameters: {'path': path, ...query},
      );
    } else {
      return null;
    }
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'TVParser/2.0 (metadata)');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('[TMDB] http ${res.statusCode}');
        return null;
      }
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      debugPrint('[TMDB] http skipped: ${e.runtimeType}');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'title_normalizer.dart';
import 'tmdb_client.dart';

/// Show-level artwork and facts from a verified TMDB match.
/// Every field is null/empty when unknown. Nothing is invented.
class SeriesShowArt {
  final String tmdbId;
  final String? posterUrl;
  final String? backdropUrl;
  final String? overview;
  final double? rating;
  final int? year;
  final int? endYear;
  final bool? inProduction;
  final List<String> genres;
  final int? runtimeMinutes;

  const SeriesShowArt({
    required this.tmdbId,
    this.posterUrl,
    this.backdropUrl,
    this.overview,
    this.rating,
    this.year,
    this.endYear,
    this.inProduction,
    this.genres = const [],
    this.runtimeMinutes,
  });

  factory SeriesShowArt.fromJson(Map<String, dynamic> j) => SeriesShowArt(
    tmdbId: '${j['tmdb_id']}',
    posterUrl: j['poster_url'] as String?,
    backdropUrl: j['backdrop_url'] as String?,
    overview: j['overview'] as String?,
    rating: (j['rating'] as num?)?.toDouble(),
    year: j['year'] as int?,
    endYear: j['end_year'] as int?,
    inProduction: j['in_production'] as bool?,
    genres: (j['genres'] as List?)?.map((e) => '$e').toList() ?? const [],
    runtimeMinutes: j['runtime_minutes'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'tmdb_id': tmdbId,
    if (posterUrl != null) 'poster_url': posterUrl,
    if (backdropUrl != null) 'backdrop_url': backdropUrl,
    if (overview != null) 'overview': overview,
    if (rating != null) 'rating': rating,
    if (year != null) 'year': year,
    if (endYear != null) 'end_year': endYear,
    if (inProduction != null) 'in_production': inProduction,
    if (genres.isNotEmpty) 'genres': genres,
    if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
  };
}

/// One episode of a matched show.
class SeriesEpisodeArt {
  final int number;
  final String? name;
  final String? stillUrl;
  final int? runtimeMinutes;

  const SeriesEpisodeArt({
    required this.number,
    this.name,
    this.stillUrl,
    this.runtimeMinutes,
  });

  factory SeriesEpisodeArt.fromJson(Map<String, dynamic> j) => SeriesEpisodeArt(
    number: j['number'] as int,
    name: j['name'] as String?,
    stillUrl: j['still_url'] as String?,
    runtimeMinutes: j['runtime_minutes'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    if (name != null) 'name': name,
    if (stillUrl != null) 'still_url': stillUrl,
    if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
  };
}

/// Series poster, backdrop and episode stills for the details page.
///
/// Reuses the app's TMDB client. A show is used only after the client's
/// high-confidence title/year match, or when the provider supplied the TMDB
/// id itself. Lookups are cached on disk, shared between identical requests
/// in flight, retried once, and never awaited by navigation or playback.
class SeriesArtworkService {
  SeriesArtworkService({
    TmdbClient? client,
    Directory? overrideDir,
    @visibleForTesting Duration retryDelay = const Duration(milliseconds: 1500),
  }) : _client = client ?? TmdbClient(),
       _overrideDir = overrideDir,
       _retryDelay = retryDelay;

  static final SeriesArtworkService instance = SeriesArtworkService();

  static const Duration hitTtl = Duration(days: 14);
  static const Duration missTtl = Duration(minutes: 20);
  static const int _maxRows = 400;

  final TmdbClient _client;
  final Directory? _overrideDir;
  final Duration _retryDelay;

  final Map<String, Map<String, dynamic>> _rows = {};
  final Map<String, DateTime> _misses = {};
  final Map<String, Future<SeriesShowArt?>> _showInFlight = {};
  final Map<String, Future<Map<int, SeriesEpisodeArt>>> _seasonInFlight = {};
  Future<void>? _loading;
  bool _loaded = false;

  bool get isEnabled => _client.isEnabled;

  /// Matched show for [title], or null when there is no confident match.
  /// [providerTmdbId] is an id the IPTV provider sent with the show.
  Future<SeriesShowArt?> show({
    required String title,
    int? year,
    String? providerTmdbId,
  }) {
    if (!isEnabled) return Future.value(null);
    final parsed = TitleNormalizer.parse(title);
    final match = parsed.matchTitle.toLowerCase();
    final y = year ?? parsed.year;
    final id = _cleanId(providerTmdbId);
    if (match.isEmpty && id == null) return Future.value(null);
    final key = id != null ? 'show|id|$id' : 'show|$match|${y ?? ''}';
    return _showInFlight[key] ??= _loadShow(key, parsed.matchTitle, y, id)
        .whenComplete(() {
          _showInFlight.remove(key);
        });
  }

  Future<SeriesShowArt?> _loadShow(
    String key,
    String matchTitle,
    int? year,
    String? providerId,
  ) async {
    await _ensureLoaded();
    final cached = _fresh(key);
    if (cached != null) {
      try {
        return SeriesShowArt.fromJson(cached);
      } catch (_) {
        _rows.remove(key);
      }
    }
    if (_recentMiss(key)) return null;

    Map<String, dynamic>? base;
    var id = providerId;
    if (id == null) {
      base = await _client.searchTv(matchTitle, year: year);
      id = _cleanId(base?['tmdb_id'] as String?);
      if (base == null || id == null) {
        _misses[key] = DateTime.now();
        return null;
      }
    }
    final details = await _withRetry(() => _client.tvDetails(id!));
    final merged = <String, dynamic>{...?base, ...?details, 'tmdb_id': id};
    if (base == null && details == null) {
      _misses[key] = DateTime.now();
      return null;
    }
    final art = SeriesShowArt.fromJson(merged);
    // A search-only row (details failed) is not stored, so genres and runtime
    // are fetched again next time.
    if (details != null) _put(key, art.toJson());
    return art;
  }

  /// Episodes of [season] by episode number. Empty when unknown.
  Future<Map<int, SeriesEpisodeArt>> season(String tmdbId, int season) {
    final id = _cleanId(tmdbId);
    if (!isEnabled || id == null) return Future.value(const {});
    final key = 'season|$id|$season';
    return _seasonInFlight[key] ??= _loadSeason(key, id, season).whenComplete(
      () {
        _seasonInFlight.remove(key);
      },
    );
  }

  Future<Map<int, SeriesEpisodeArt>> _loadSeason(
    String key,
    String id,
    int season,
  ) async {
    await _ensureLoaded();
    final cached = _fresh(key);
    if (cached != null) {
      final parsed = _episodesFrom(cached['episodes']);
      if (parsed != null) return parsed;
      _rows.remove(key);
    }
    if (_recentMiss(key)) return const {};
    final list = await _withRetry(() => _client.tvSeasonEpisodes(id, season));
    if (list == null) {
      _misses[key] = DateTime.now();
      return const {};
    }
    final out = _episodesFrom(list) ?? const <int, SeriesEpisodeArt>{};
    _put(key, {
      'episodes': [for (final e in out.values) e.toJson()],
    });
    return out;
  }

  static Map<int, SeriesEpisodeArt>? _episodesFrom(Object? raw) {
    if (raw is! List) return null;
    final out = <int, SeriesEpisodeArt>{};
    try {
      for (final e in raw) {
        if (e is! Map) continue;
        final ep = SeriesEpisodeArt.fromJson(Map<String, dynamic>.from(e));
        out[ep.number] = ep;
      }
    } catch (_) {
      return null;
    }
    return out;
  }

  Future<T?> _withRetry<T>(Future<T?> Function() call) async {
    final first = await call();
    if (first != null) return first;
    await Future<void>.delayed(_retryDelay);
    return call();
  }

  static String? _cleanId(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty || s == '0' || !RegExp(r'^[0-9]{1,10}$').hasMatch(s)) {
      return null;
    }
    return s;
  }

  bool _recentMiss(String key) {
    final at = _misses[key];
    if (at == null) return false;
    if (DateTime.now().difference(at) > missTtl) {
      _misses.remove(key);
      return false;
    }
    return true;
  }

  Map<String, dynamic>? _fresh(String key) {
    final row = _rows[key];
    if (row == null) return null;
    final at = DateTime.tryParse('${row['at']}');
    if (at == null || DateTime.now().difference(at) > hitTtl) {
      _rows.remove(key);
      return null;
    }
    final data = row['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  void _put(String key, Map<String, dynamic> data) {
    _rows.remove(key);
    _rows[key] = {'at': DateTime.now().toIso8601String(), 'data': data};
    while (_rows.length > _maxRows) {
      _rows.remove(_rows.keys.first);
    }
    unawaited(_flush());
  }

  Future<void> _ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          raw.forEach((k, v) {
            if (v is Map) _rows['$k'] = Map<String, dynamic>.from(v);
          });
        }
      }
    } catch (e) {
      debugPrint('[SERIES_ART] cache load skipped: ${e.runtimeType}');
    }
    _loaded = true;
  }

  Future<void> _flush() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(_rows), flush: true);
    } catch (e) {
      debugPrint('[SERIES_ART] cache flush skipped: ${e.runtimeType}');
    }
  }

  Future<File> _file() async {
    final dir =
        _overrideDir ??
        Directory('${(await getApplicationSupportDirectory()).path}/m3u_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/series_art.json');
  }
}

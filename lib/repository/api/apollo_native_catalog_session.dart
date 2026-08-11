import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mbark_iptv/repository/api/apollo_startup_show_api.dart';
import 'package:mbark_iptv/repository/models/category.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';
import 'package:path_provider/path_provider.dart';

/// Owns Startup Show native VOD sync into existing `m3u_cache` movie/series files.
///
/// Live remains M3U (`IptvProviderSession.commitM3u`). This session only fills
/// Movies/Series rails (categories + items + popular/recommendations).
class ApolloNativeCatalogSession {
  ApolloNativeCatalogSession._();
  static final ApolloNativeCatalogSession instance =
      ApolloNativeCatalogSession._();

  static const popularCategoryId = 'apollo_popular';
  static const recommendationsCategoryId = 'apollo_recommendations';
  static const theatricalCategoryId = 'apollo_theatrical';

  final ApolloStartupShowApi _api = ApolloStartupShowApi();

  ApolloNativeAuthFailure lastFailure = ApolloNativeAuthFailure.none;
  String? lastFailureMessage;
  bool lastSyncAttempted = false;
  int lastMovieCategoryCount = 0;
  int lastMovieItemCount = 0;
  int lastSeriesCategoryCount = 0;
  int lastSeriesItemCount = 0;

  bool get needsStartupShowSession =>
      lastFailure == ApolloNativeAuthFailure.unauthorized ||
      lastFailure == ApolloNativeAuthFailure.badCredentials ||
      lastFailure == ApolloNativeAuthFailure.capturePending;

  String get moviesEmptySubtitle {
    if (needsStartupShowSession ||
        lastFailure == ApolloNativeAuthFailure.unauthorized ||
        lastFailure == ApolloNativeAuthFailure.badCredentials ||
        lastFailure == ApolloNativeAuthFailure.capturePending) {
      return 'Apollo Movies need Startup Show API session — capture pending. '
          'Live TV still works from the playlist. Add Startup Show username/password '
          'to gitignored .secrets (STARTUP_SHOW_*), then press Retry.';
    }
    if (lastSyncAttempted && lastMovieCategoryCount == 0) {
      return 'Startup Show login did not return movie categories yet. '
          'Live TV is available; Retry after a valid API session is saved.';
    }
    return 'No Movies in the connected Live playlist file. '
        'Movies load from Startup Show REST when an API session is available.';
  }

  String get seriesEmptySubtitle {
    if (needsStartupShowSession ||
        lastFailure == ApolloNativeAuthFailure.unauthorized ||
        lastFailure == ApolloNativeAuthFailure.badCredentials ||
        lastFailure == ApolloNativeAuthFailure.capturePending) {
      return 'Apollo Series need Startup Show API session — capture pending. '
          'Live TV still works from the playlist.';
    }
    return 'No Series in the connected Live playlist file. '
        'Series load from Startup Show REST when an API session is available.';
  }

  /// After Apollo/starlite Live M3U commit: try session file → secrets → M3U user/pass.
  Future<bool> syncAfterApolloLive({
    String? playlistUrl,
    String? usernameHint,
    String? passwordHint,
  }) async {
    lastSyncAttempted = true;
    lastFailure = ApolloNativeAuthFailure.none;
    lastFailureMessage = null;

    Directory? support;
    try {
      support = await getApplicationSupportDirectory();
    } catch (_) {}

    // 1) Existing captured session (token / signature).
    final existing = await ApolloNativeSessionStore.load(appSupport: support);
    if (existing != null && existing.hasAuthMaterial) {
      _api.applySession(existing);
      final ok = await _fetchAndPersistCatalog();
      if (ok) return true;
      // fall through to re-login if 401
    }

    // 2) Explicit Startup Show creds from gitignored env (preferred).
    final fromSecrets = await ApolloNativeCredentialsLoader.load();
    final user = fromSecrets?.username ?? usernameHint;
    final pass = fromSecrets?.password ?? passwordHint;

    // 3) Parse starlite `/api/list/{user}/{pass}` as last-resort hint (often fails).
    String? parsedUser = user;
    String? parsedPass = pass;
    if ((parsedUser == null || parsedPass == null) && playlistUrl != null) {
      final extracted = extractListCredentials(playlistUrl);
      parsedUser ??= extracted?.$1;
      parsedPass ??= extracted?.$2;
    }

    if (parsedUser == null ||
        parsedUser.isEmpty ||
        parsedPass == null ||
        parsedPass.isEmpty) {
      lastFailure = ApolloNativeAuthFailure.capturePending;
      lastFailureMessage = 'No Startup Show credentials or session file';
      debugPrint(
        '[APOLLO_NATIVE] sync skipped: no credentials/session '
        '(need STARTUP_SHOW_* or apollo_native_session.json)',
      );
      return false;
    }

    try {
      final session = await _api.login(username: parsedUser, password: parsedPass);
      await ApolloNativeSessionStore.save(session, preferredDir: support);
      // Also mirror into workspace .secrets when running on desktop.
      await ApolloNativeSessionStore.save(session);
      return await _fetchAndPersistCatalog();
    } on ApolloNativeApiException catch (e) {
      lastFailure = e.kind;
      lastFailureMessage = e.message;
      debugPrint(
        '[APOLLO_NATIVE] login failed status=${e.statusCode} kind=${e.kind}',
      );
      return false;
    } catch (e) {
      lastFailure = ApolloNativeAuthFailure.network;
      lastFailureMessage = e.toString();
      debugPrint('[APOLLO_NATIVE] login error: $e');
      return false;
    }
  }

  Future<bool> _fetchAndPersistCatalog() async {
    try {
      final movieCatsRaw = await _api.movieCategories();
      List<Map<String, dynamic>> popularRaw = const [];
      List<Map<String, dynamic>> recsRaw = const [];
      try {
        popularRaw = await _api.popularMovieCategories();
      } catch (e) {
        debugPrint('[APOLLO_NATIVE] popular categories skip: $e');
      }
      try {
        recsRaw = await _api.movieRecommendations();
      } catch (e) {
        debugPrint('[APOLLO_NATIVE] recommendations skip: $e');
      }

      final categories = <CategoryModel>[];
      final movies = <ChannelMovie>[];
      final seenCat = <String>{};

      void addCat(String id, String name) {
        if (id.isEmpty || seenCat.contains(id)) return;
        seenCat.add(id);
        categories.add(CategoryModel(categoryId: id, categoryName: name));
      }

      // Dedicated theatrical / popular / recommendations rails first.
      if (popularRaw.isNotEmpty) {
        addCat(popularCategoryId, 'Popular / Theatrical');
        var i = 0;
        for (final row in popularRaw) {
          movies.add(_mapMovie(row, popularCategoryId, index: i++));
        }
        // Some payloads are category folders under popular — treat as cats too.
        for (final row in popularRaw) {
          final cid = _str(row, const [
            'category_id',
            'categoryId',
            'id',
          ]);
          final cname = _str(row, const [
            'category_name',
            'categoryName',
            'name',
            'title',
          ]);
          if (cid != null && cname != null && !_looksLikeMovieRow(row)) {
            addCat('popular_$cid', cname);
          }
        }
      }

      if (recsRaw.isNotEmpty) {
        addCat(recommendationsCategoryId, 'Recommended');
        var i = 0;
        for (final row in recsRaw) {
          if (_looksLikeMovieRow(row) || _movieId(row) != null) {
            movies.add(_mapMovie(row, recommendationsCategoryId, index: i++));
          }
        }
      }

      for (final row in movieCatsRaw) {
        final cid = _str(row, const ['category_id', 'categoryId', 'id']) ?? '';
        final cname = _str(row, const [
              'category_name',
              'categoryName',
              'name',
              'title',
            ]) ??
            'Movies';
        if (cid.isEmpty) continue;
        addCat(cid, cname);

        try {
          final items = await _api.movieItems(
            categoryId: cid,
            offset: 0,
            limit: 40,
          );
          var i = 0;
          for (final item in items) {
            movies.add(_mapMovie(item, cid, index: i++));
          }
        } catch (e) {
          debugPrint('[APOLLO_NATIVE] movie items $cid skip: $e');
        }
      }

      // Series (best-effort).
      final seriesCats = <CategoryModel>[];
      final series = <ChannelSerie>[];
      try {
        final tvCats = await _api.tvShowCategories();
        for (final row in tvCats) {
          final cid = _str(row, const ['category_id', 'categoryId', 'id']) ?? '';
          final cname = _str(row, const [
                'category_name',
                'categoryName',
                'name',
                'title',
              ]) ??
              'Series';
          if (cid.isEmpty) continue;
          seriesCats.add(
            CategoryModel(categoryId: cid, categoryName: cname),
          );
          try {
            final items = await _api.tvShowItems(
              categoryId: cid,
              offset: 0,
              limit: 40,
            );
            var i = 0;
            for (final item in items) {
              series.add(_mapSerie(item, cid, index: i++));
            }
          } catch (e) {
            debugPrint('[APOLLO_NATIVE] tvshow items $cid skip: $e');
          }
        }
      } catch (e) {
        debugPrint('[APOLLO_NATIVE] tvshow categories skip: $e');
      }

      // Persist into existing LocaleApi movie/series caches (does not touch Live).
      // Import via deferred call site — LocaleApi lives in api.dart library.
      await _persistMovies(categories, movies);
      await _persistSeries(seriesCats, series);

      lastMovieCategoryCount = categories.length;
      lastMovieItemCount = movies.length;
      lastSeriesCategoryCount = seriesCats.length;
      lastSeriesItemCount = series.length;
      lastFailure = ApolloNativeAuthFailure.none;

      debugPrint(
        '[APOLLO_NATIVE] synced movies cats=${categories.length} '
        'items=${movies.length} series cats=${seriesCats.length} '
        'items=${series.length}',
      );
      return categories.isNotEmpty || movies.isNotEmpty || series.isNotEmpty;
    } on ApolloNativeApiException catch (e) {
      lastFailure = e.kind;
      lastFailureMessage = e.message;
      debugPrint(
        '[APOLLO_NATIVE] catalog fetch failed status=${e.statusCode} '
        'kind=${e.kind}',
      );
      return false;
    } catch (e) {
      lastFailure = ApolloNativeAuthFailure.unknown;
      lastFailureMessage = e.toString();
      debugPrint('[APOLLO_NATIVE] catalog fetch error: $e');
      return false;
    }
  }

  /// Bound at call site from `api.dart` parts via [bindPersisters].
  Future<void> Function(List<CategoryModel>, List<ChannelMovie>)?
      _moviesPersister;
  Future<void> Function(List<CategoryModel>, List<ChannelSerie>)?
      _seriesPersister;

  void bindPersisters({
    required Future<void> Function(List<CategoryModel>, List<ChannelMovie>)
        movies,
    required Future<void> Function(List<CategoryModel>, List<ChannelSerie>)
        series,
  }) {
    _moviesPersister = movies;
    _seriesPersister = series;
  }

  Future<void> _persistMovies(
    List<CategoryModel> cats,
    List<ChannelMovie> movies,
  ) async {
    final p = _moviesPersister;
    if (p == null) {
      debugPrint('[APOLLO_NATIVE] movies persister not bound');
      return;
    }
    await p(cats, movies);
  }

  Future<void> _persistSeries(
    List<CategoryModel> cats,
    List<ChannelSerie> series,
  ) async {
    final p = _seriesPersister;
    if (p == null) return;
    await p(cats, series);
  }

  static (String, String)? extractListCredentials(String playlistUrl) {
    try {
      final uri = Uri.parse(playlistUrl);
      final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      // .../api/list/{user}/{pass}
      final listIdx = parts.indexOf('list');
      if (listIdx >= 0 && parts.length > listIdx + 2) {
        return (parts[listIdx + 1], parts[listIdx + 2]);
      }
      if (parts.length >= 2) {
        return (parts[parts.length - 2], parts[parts.length - 1]);
      }
    } catch (_) {}
    return null;
  }

  static ChannelMovie _mapMovie(
    Map<String, dynamic> row,
    String categoryId, {
    required int index,
  }) {
    final id = _movieId(row) ?? 'apollo_m_${categoryId}_$index';
    final name = _str(row, const [
          'name',
          'title',
          'movie_name',
          'movieName',
        ]) ??
        'Movie';
    final poster = _str(row, const [
      'stream_icon',
      'poster',
      'poster_path',
      'movie_image',
      'cover',
      'icon',
      'image',
      'thumbnail',
    ]);
    final trailer = _str(row, const [
      'movie_trailer',
      'youtube_trailer',
      'youtubeTrailer',
      'trailer',
      'youtube_id',
      'trailer_url',
    ]);
    final playUrl = _str(row, const [
      'direct_source',
      'stream_url',
      'url',
      'play_url',
      'playback_url',
    ]);
    final rating = _str(row, const ['rating', 'rate', 'vote_average']);

    return ChannelMovie(
      num: '$index',
      name: name,
      streamType: 'movie',
      streamId: id,
      streamIcon: poster,
      rating: rating,
      categoryId: categoryId,
      directSource: playUrl,
      youtubeTrailer: trailer,
      imdbId: _str(row, const ['imdb_id', 'imdbId']) ?? id,
    );
  }

  static ChannelSerie _mapSerie(
    Map<String, dynamic> row,
    String categoryId, {
    required int index,
  }) {
    final id = _str(row, const [
          'series_id',
          'seriesId',
          'id',
          'imdb_id',
          'imdbId',
        ]) ??
        'apollo_s_${categoryId}_$index';
    final name = _str(row, const ['name', 'title', 'series_name']) ?? 'Series';
    final cover = _str(row, const [
      'cover',
      'poster',
      'stream_icon',
      'image',
      'thumbnail',
    ]);
    return ChannelSerie(
      num: '$index',
      name: name,
      seriesId: id,
      cover: cover,
      plot: _str(row, const ['plot', 'overview', 'description']),
      rating: _str(row, const ['rating', 'vote_average']),
      categoryId: categoryId,
      directSource: _str(row, const ['direct_source', 'url', 'stream_url']),
    );
  }

  static String? _movieId(Map<String, dynamic> row) => _str(row, const [
        'stream_id',
        'streamId',
        'imdb_id',
        'imdbId',
        'movie_id',
        'movieId',
        'id',
      ]);

  static bool _looksLikeMovieRow(Map<String, dynamic> row) {
    return _str(row, const [
          'imdb_id',
          'imdbId',
          'movie_trailer',
          'stream_icon',
          'poster',
        ]) !=
        null;
  }

  static String? _str(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') continue;
      return s;
    }
    return null;
  }
}

/// Loads Startup Show API username/password from gitignored env files.
///
/// Preferred keys: `STARTUP_SHOW_USERNAME`, `STARTUP_SHOW_PASSWORD`
/// Fallbacks: `APOLLO_NATIVE_USERNAME`, `APOLLO_NATIVE_PASSWORD`
/// Never logs secret values.
class ApolloNativeCredentialsLoader {
  static Future<({String username, String password})?> load() async {
    final files = <File>[
      File('${Directory.current.path}/.secrets/tv_login_runtime.env'),
      File('${Directory.current.path}/../.secrets/tv_login_runtime.env'),
      File('${Directory.current.path}/../../.secrets/tv_login_runtime.env'),
      File('${Directory.current.path}/.secrets/apollo_native_credentials.env'),
      File('${Directory.current.path}/../.secrets/apollo_native_credentials.env'),
    ];

    for (final file in files) {
      try {
        if (!await file.exists()) continue;
        final map = _parseEnv(await file.readAsString());
        final user = map['STARTUP_SHOW_USERNAME'] ??
            map['APOLLO_NATIVE_USERNAME'] ??
            map['STARTUPSHOW_USERNAME'];
        final pass = map['STARTUP_SHOW_PASSWORD'] ??
            map['APOLLO_NATIVE_PASSWORD'] ??
            map['STARTUPSHOW_PASSWORD'];
        if (user != null &&
            user.isNotEmpty &&
            pass != null &&
            pass.isNotEmpty) {
          debugPrint(
            '[APOLLO_NATIVE] loaded STARTUP_SHOW credentials from env '
            '(username_len=${user.length})',
          );
          return (username: user, password: pass);
        }
      } catch (e) {
        debugPrint('[APOLLO_NATIVE] credentials load skip: $e');
      }
    }
    return null;
  }

  static Map<String, String> _parseEnv(String raw) {
    final out = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final i = t.indexOf('=');
      if (i <= 0) continue;
      final k = t.substring(0, i).trim();
      var v = t.substring(i + 1).trim();
      if ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'"))) {
        v = v.substring(1, v.length - 1);
      }
      out[k] = v;
    }
    return out;
  }
}

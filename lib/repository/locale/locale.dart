part of '../api/api.dart';

class LocaleApi {
  static List<CategoryModel>? _m3uCategoriesMem;
  static List<ChannelLive>? _m3uChannelsMem;
  static List<CategoryModel>? _m3uMovieCategoriesMem;
  static List<ChannelMovie>? _m3uMoviesMem;
  static List<CategoryModel>? _m3uSeriesCategoriesMem;
  static List<ChannelSerie>? _m3uSeriesMem;
  static Directory? _m3uDir;

  static Future<bool> saveUser(UserModel user) async {
    try {
      await locale.write("user", user.toJson());
      return true;
    } catch (e) {
      debugPrint("Error save User: $e");
      return false;
    }
  }

  static Future<UserModel?> getUser() async {
    try {
      final user = await locale.read("user");

      if (user != null) {
        return UserModel.fromJson(user, user['server_info']['server_url']);
      }
      return null;
    } catch (e) {
      debugPrint("Error save User: $e");
      return null;
    }
  }

  static Future<bool> logOut() async {
    try {
      await locale.remove("user");
      await locale.remove("m3u_categories");
      await locale.remove("m3u_channels");
      _m3uCategoriesMem = null;
      _m3uChannelsMem = null;
      _m3uMovieCategoriesMem = null;
      _m3uMoviesMem = null;
      _m3uSeriesCategoriesMem = null;
      _m3uSeriesMem = null;
      try {
        final dir = await _ensureM3uDir();
        for (final name in [
          'm3u_categories.json',
          'm3u_channels.json',
          'm3u_movie_categories.json',
          'm3u_movies.json',
          'm3u_series_categories.json',
          'm3u_series.json',
          'provider_capabilities.json',
        ]) {
          final f = File('${dir.path}/$name');
          if (await f.exists()) await f.delete();
        }
      } catch (_) {}
      try {
        await ProviderCapabilityStore.instance.clear();
      } catch (_) {}
      try {
        await XmlTvRepository.instance.clear();
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint("Error LogOut User: $e");
      return false;
    }
  }

  /// Warm Live M3U cache only (fast path before [runApp]).
  /// Movies/Series JSON can be tens of MB — use [warmM3uVodCache] after first frame.
  static Future<void> warmM3uCache() async {
    try {
      if (!CatalogPerf.hasSession) {
        CatalogPerf.beginSession(reason: 'warm_start');
      }
      final warmWatch = Stopwatch()..start();
      final dir = await _ensureM3uDir();
      final catFile = File('${dir.path}/m3u_categories.json');
      final chFile = File('${dir.path}/m3u_channels.json');

      if (await catFile.exists()) {
        final raw = jsonDecode(await catFile.readAsString());
        if (raw is List) {
          _m3uCategoriesMem = raw
              .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      if (await chFile.exists()) {
        final raw = jsonDecode(await chFile.readAsString());
        if (raw is List) {
          _m3uChannelsMem = raw
              .map((e) => ChannelLive.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      // Legacy GetStorage fallback for small playlists only.
      if (_m3uCategoriesMem == null || _m3uCategoriesMem!.isEmpty) {
        final legacy = _readLegacyM3uCategories();
        if (legacy.isNotEmpty) _m3uCategoriesMem = legacy;
      }
      if (_m3uChannelsMem == null || _m3uChannelsMem!.isEmpty) {
        final legacy = _readLegacyM3uChannels();
        if (legacy.isNotEmpty) _m3uChannelsMem = legacy;
      }

      debugPrint(
        "[M3U] warm live cache cats=${_m3uCategoriesMem?.length ?? 0} "
        "channels=${_m3uChannelsMem?.length ?? 0}",
      );
      CatalogPerf.span('warmLiveMs', warmWatch.elapsedMilliseconds);
      CatalogPerf.count('liveCount', _m3uChannelsMem?.length ?? 0);
      CatalogPerf.count('liveCatCount', _m3uCategoriesMem?.length ?? 0);
      CatalogPerf.flush('after_warm_live');
    } catch (e) {
      debugPrint("[M3U] warm cache error: $e");
    }
  }

  /// Movies file cache only — opening Movies must not decode series JSON.
  static Future<void> warmM3uMovieCache() async {
    try {
      final movieWatch = Stopwatch()..start();
      final dir = await _ensureM3uDir();
      final movieFile = File('${dir.path}/m3u_movies.json');
      if (await movieFile.exists()) {
        CatalogPerf.count('movieJsonBytes', await movieFile.length());
      }
      await _warmTypedList<CategoryModel>(
        '${dir.path}/m3u_movie_categories.json',
        (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)),
        (list) => _m3uMovieCategoriesMem = list,
      );
      await _warmTypedList<ChannelMovie>(
        '${dir.path}/m3u_movies.json',
        (e) => ChannelMovie.fromJson(Map<String, dynamic>.from(e)),
        (list) => _m3uMoviesMem = list,
      );
      CatalogPerf.span('movie_json_decode_ms', movieWatch.elapsedMilliseconds);
      CatalogPerf.span('movie_cache_read_ms', movieWatch.elapsedMilliseconds);
      CatalogPerf.count('movieCount', _m3uMoviesMem?.length ?? 0);
      CatalogPerf.count(
        'movieCategoryCount',
        _m3uMovieCategoriesMem?.length ?? 0,
      );
      CatalogPerf.count(
        'movieCatCount',
        _m3uMovieCategoriesMem?.length ?? 0,
      );
      CatalogPerf.flush('after_warm_movies');
      debugPrint(
        "[M3U] warm movie cache movies=${_m3uMoviesMem?.length ?? 0} "
        "cats=${_m3uMovieCategoriesMem?.length ?? 0}",
      );
    } catch (e) {
      debugPrint("[M3U] warm movie cache error: $e");
    }
  }

  /// Series file cache only — independent of Movies.
  static Future<void> warmM3uSeriesCache() async {
    try {
      final seriesWatch = Stopwatch()..start();
      final dir = await _ensureM3uDir();
      final seriesFile = File('${dir.path}/m3u_series.json');
      if (await seriesFile.exists()) {
        CatalogPerf.count('seriesJsonBytes', await seriesFile.length());
      }
      await _warmTypedList<CategoryModel>(
        '${dir.path}/m3u_series_categories.json',
        (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)),
        (list) => _m3uSeriesCategoriesMem = list,
      );
      await _warmTypedList<ChannelSerie>(
        '${dir.path}/m3u_series.json',
        (e) => ChannelSerie.fromJson(Map<String, dynamic>.from(e)),
        (list) => _m3uSeriesMem = list,
      );
      CatalogPerf.span('series_json_decode_ms', seriesWatch.elapsedMilliseconds);
      CatalogPerf.span('series_cache_read_ms', seriesWatch.elapsedMilliseconds);
      CatalogPerf.count('seriesCount', _m3uSeriesMem?.length ?? 0);
      CatalogPerf.count(
        'seriesCategoryCount',
        _m3uSeriesCategoriesMem?.length ?? 0,
      );
      CatalogPerf.count(
        'seriesCatCount',
        _m3uSeriesCategoriesMem?.length ?? 0,
      );
      CatalogPerf.flush('after_warm_series');
      debugPrint(
        "[M3U] warm series cache series=${_m3uSeriesMem?.length ?? 0} "
        "cats=${_m3uSeriesCategoriesMem?.length ?? 0}",
      );
    } catch (e) {
      debugPrint("[M3U] warm series cache error: $e");
    }
  }

  /// Convenience: warm both domains independently (does not make Movies wait).
  static Future<void> warmM3uVodCache() async {
    await warmM3uMovieCache();
    // ignore: unawaited_futures
    warmM3uSeriesCache();
  }

  static Future<void> _warmTypedList<T>(
    String path,
    T Function(dynamic) map,
    void Function(List<T>) assign,
  ) async {
    final file = File(path);
    if (!await file.exists()) return;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! List) return;
    assign(raw.map(map).toList());
  }

  static Future<Directory> _ensureM3uDir() async {
    if (_m3uDir != null) return _m3uDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/m3u_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _m3uDir = dir;
    return dir;
  }

  static Future<bool> saveM3uCategories(List<CategoryModel> categories) async {
    _m3uCategoriesMem = List<CategoryModel>.from(categories);
    try {
      final dir = await _ensureM3uDir();
      final file = File('${dir.path}/m3u_categories.json');
      await file.writeAsString(
        jsonEncode(categories.map((e) => e.toJson()).toList()),
        flush: true,
      );
      // Keep a tiny marker in GetStorage so older builds know M3U is active.
      try {
        await locale.write("m3u_categories_count", categories.length);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint("Error save M3U Categories: $e");
      // Memory still holds data for this session.
      return _m3uCategoriesMem?.isNotEmpty == true;
    }
  }

  static List<CategoryModel> getM3uCategories() {
    if (_m3uCategoriesMem != null && _m3uCategoriesMem!.isNotEmpty) {
      return List<CategoryModel>.from(_m3uCategoriesMem!);
    }
    try {
      if (_m3uDir != null) {
        final file = File('${_m3uDir!.path}/m3u_categories.json');
        if (file.existsSync()) {
          final raw = jsonDecode(file.readAsStringSync());
          if (raw is List) {
            _m3uCategoriesMem = raw
                .map(
                  (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
            return List<CategoryModel>.from(_m3uCategoriesMem!);
          }
        }
      }
    } catch (e) {
      debugPrint("Error get M3U Categories (file): $e");
    }
    return _readLegacyM3uCategories();
  }

  static Future<bool> saveM3uChannels(List<ChannelLive> channels) async {
    _m3uChannelsMem = List<ChannelLive>.from(channels);
    try {
      final dir = await _ensureM3uDir();
      final file = File('${dir.path}/m3u_channels.json');
      await file.writeAsString(
        jsonEncode(channels.map((e) => e.toJson()).toList()),
        flush: true,
      );
      try {
        await locale.write("m3u_channels_count", channels.length);
        // Drop legacy blob that can blow SharedPreferences (~1MB binder cap).
        await locale.remove("m3u_channels");
        await locale.remove("m3u_categories");
      } catch (_) {}
      debugPrint("[M3U] saved channels to file count=${channels.length}");
      return true;
    } catch (e) {
      debugPrint("Error save M3U Channels: $e");
      return _m3uChannelsMem?.isNotEmpty == true;
    }
  }

  static List<ChannelLive> getM3uChannels() {
    if (_m3uChannelsMem != null && _m3uChannelsMem!.isNotEmpty) {
      return List<ChannelLive>.from(_m3uChannelsMem!);
    }
    try {
      if (_m3uDir != null) {
        final file = File('${_m3uDir!.path}/m3u_channels.json');
        if (file.existsSync()) {
          final raw = jsonDecode(file.readAsStringSync());
          if (raw is List) {
            _m3uChannelsMem = raw
                .map((e) => ChannelLive.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            return List<ChannelLive>.from(_m3uChannelsMem!);
          }
        }
      }
    } catch (e) {
      debugPrint("Error get M3U Channels (file): $e");
    }
    return _readLegacyM3uChannels();
  }

  static List<CategoryModel> _readLegacyM3uCategories() {
    try {
      final List<dynamic>? raw = locale.read("m3u_categories");
      if (raw != null) {
        return raw
            .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint("Error get M3U Categories: $e");
    }
    return [];
  }

  static List<ChannelLive> _readLegacyM3uChannels() {
    try {
      final List<dynamic>? raw = locale.read("m3u_channels");
      if (raw != null) {
        return raw
            .map((e) => ChannelLive.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint("Error get M3U Channels: $e");
    }
    return [];
  }

  // ─── M3U Movies / Series (same durable file+memory pattern as Live) ───────

  static Future<bool> saveM3uMovieCategories(
    List<CategoryModel> categories,
  ) async {
    _m3uMovieCategoriesMem = List<CategoryModel>.from(categories);
    return _writeM3uJson(
      'm3u_movie_categories.json',
      categories.map((e) => e.toJson()).toList(),
      countKey: 'm3u_movie_categories_count',
      count: categories.length,
    );
  }

  static List<CategoryModel> getM3uMovieCategories() =>
      _getM3uList<CategoryModel>(
        mem: _m3uMovieCategoriesMem,
        fileName: 'm3u_movie_categories.json',
        map: (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)),
        assign: (list) => _m3uMovieCategoriesMem = list,
      );

  static Future<bool> saveM3uMovies(List<ChannelMovie> movies) async {
    _m3uMoviesMem = List<ChannelMovie>.from(movies);
    final ok = await _writeM3uJson(
      'm3u_movies.json',
      movies.map((e) => e.toJson()).toList(),
      countKey: 'm3u_movies_count',
      count: movies.length,
    );
    if (ok) {
      debugPrint("[M3U] saved movies to file count=${movies.length}");
    }
    return ok || (_m3uMoviesMem?.isNotEmpty == true);
  }

  static List<ChannelMovie> getM3uMovies() => _getM3uList<ChannelMovie>(
        mem: _m3uMoviesMem,
        fileName: 'm3u_movies.json',
        map: (e) => ChannelMovie.fromJson(Map<String, dynamic>.from(e)),
        assign: (list) => _m3uMoviesMem = list,
        decodeMsKey: 'movie_json_decode_ms',
      );

  static Future<bool> saveM3uSeriesCategories(
    List<CategoryModel> categories,
  ) async {
    _m3uSeriesCategoriesMem = List<CategoryModel>.from(categories);
    return _writeM3uJson(
      'm3u_series_categories.json',
      categories.map((e) => e.toJson()).toList(),
      countKey: 'm3u_series_categories_count',
      count: categories.length,
    );
  }

  static List<CategoryModel> getM3uSeriesCategories() =>
      _getM3uList<CategoryModel>(
        mem: _m3uSeriesCategoriesMem,
        fileName: 'm3u_series_categories.json',
        map: (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)),
        assign: (list) => _m3uSeriesCategoriesMem = list,
      );

  static Future<bool> saveM3uSeries(List<ChannelSerie> series) async {
    _m3uSeriesMem = List<ChannelSerie>.from(series);
    final ok = await _writeM3uJson(
      'm3u_series.json',
      series.map((e) => e.toJson()).toList(),
      countKey: 'm3u_series_count',
      count: series.length,
    );
    if (ok) {
      debugPrint("[M3U] saved series to file count=${series.length}");
    }
    return ok || (_m3uSeriesMem?.isNotEmpty == true);
  }

  static List<ChannelSerie> getM3uSeries() => _getM3uList<ChannelSerie>(
        mem: _m3uSeriesMem,
        fileName: 'm3u_series.json',
        map: (e) => ChannelSerie.fromJson(Map<String, dynamic>.from(e)),
        assign: (list) => _m3uSeriesMem = list,
        decodeMsKey: 'series_json_decode_ms',
      );

  static Future<bool> _writeM3uJson(
    String fileName,
    List<dynamic> payload, {
    required String countKey,
    required int count,
  }) async {
    try {
      final dir = await _ensureM3uDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonEncode(payload), flush: true);
      try {
        await locale.write(countKey, count);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint("Error save $fileName: $e");
      return false;
    }
  }

  static List<T> _getM3uList<T>({
    required List<T>? mem,
    required String fileName,
    required T Function(dynamic) map,
    required void Function(List<T>) assign,
    String? decodeMsKey,
  }) {
    if (mem != null && mem.isNotEmpty) {
      return List<T>.from(mem);
    }
    // Empty list is a valid cached result (e.g. Live-only Apollo feed).
    if (mem != null && mem.isEmpty) {
      return <T>[];
    }
    try {
      if (_m3uDir != null) {
        final file = File('${_m3uDir!.path}/$fileName');
        if (file.existsSync()) {
          final decodeWatch = Stopwatch()..start();
          final raw = jsonDecode(file.readAsStringSync());
          if (raw is List) {
            final list = raw.map(map).toList();
            assign(list);
            if (decodeMsKey != null) {
              CatalogPerf.span(decodeMsKey, decodeWatch.elapsedMilliseconds);
              CatalogPerf.flush('cold_json_$fileName');
            }
            return List<T>.from(list);
          }
        }
      }
    } catch (e) {
      debugPrint("Error get $fileName: $e");
    }
    return [];
  }
}

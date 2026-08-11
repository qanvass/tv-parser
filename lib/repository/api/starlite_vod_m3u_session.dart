import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mbark_iptv/repository/api/catalog_perf.dart';
import 'package:mbark_iptv/repository/api/m3u_parser.dart';
import 'package:mbark_iptv/repository/api/starlite_vod_m3u_urls.dart';
import 'package:mbark_iptv/repository/models/category.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';
import 'package:mbark_iptv/repository/provider/provider_capabilities.dart';
import 'package:mbark_iptv/repository/provider/provider_capability_inspector.dart';
import 'package:mbark_iptv/repository/provider/provider_capability_store.dart';
import 'package:mbark_iptv/repository/provider/provider_enums.dart';

/// Fetches provider VOD M3Us (`/m3u8/movies`, `/m3u8/tvshows[/N]`) using the
/// same Live `/api/list/{user}/{pass}` credentials and persists into existing
/// `m3u_cache` movie/series files (not SharedPreferences).
///
/// Does **not** touch Live cache. Feature-flagged via
/// [StarliteVodM3uUrls.isFeatureEnabled].
class StarliteVodM3uSession {
  StarliteVodM3uSession._({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 120),
                validateStatus: (s) => s != null && s < 500,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 12; Android TV) AppleWebKit/537.36',
                  'Accept':
                      'application/vnd.apple.mpegurl, audio/mpegurl, */*',
                },
              ),
            );

  static final StarliteVodM3uSession instance = StarliteVodM3uSession._();

  final Dio _dio;

  bool lastMoviesSyncAttempted = false;
  bool lastSeriesSyncAttempted = false;
  bool lastMoviesSyncOk = false;
  bool lastSeriesSyncOk = false;
  String? lastMoviesFailure;
  String? lastSeriesFailure;

  /// Legacy combined flags — UI must not treat these as a global VOD boolean.
  bool get lastSyncAttempted =>
      lastMoviesSyncAttempted || lastSeriesSyncAttempted;
  bool get lastSyncOk => lastMoviesSyncOk || lastSeriesSyncOk;
  String? get lastFailure => lastMoviesFailure ?? lastSeriesFailure;

  int lastMovieCount = 0;
  int lastMovieCategoryCount = 0;
  int lastSeriesCount = 0;
  int lastSeriesCategoryCount = 0;
  int lastTvShowShardsFetched = 0;
  String? lastXmlTvUrl;

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

  String get moviesEmptySubtitle {
    if (!lastMoviesSyncAttempted) {
      return 'Movies load from the provider VOD playlist after Live login. '
          'Tap Retry to fetch the catalog.';
    }
    if (lastMoviesFailure != null) {
      return 'VOD movie playlist fetch failed ($lastMoviesFailure). '
          'Live TV still works. Tap Retry to try again.';
    }
    return 'Provider VOD movie playlist returned no entries.';
  }

  String get seriesEmptySubtitle {
    if (!lastSeriesSyncAttempted) {
      return 'Series load from the provider VOD playlist after Live login. '
          'Tap Retry to fetch the catalog.';
    }
    if (lastSeriesFailure != null) {
      return 'VOD series playlist fetch failed ($lastSeriesFailure). '
          'Live TV still works. Tap Retry to try again.';
    }
    return 'Provider VOD series playlist returned no entries.';
  }

  /// Movies only. Does not fetch or wait on series shards.
  Future<bool> syncMovies(String playlistUrl) async {
    lastMoviesSyncAttempted = true;
    lastMoviesSyncOk = false;
    lastMoviesFailure = null;
    lastMovieCount = 0;
    lastMovieCategoryCount = 0;
    lastXmlTvUrl ??= StarliteVodM3uUrls.defaultXmlTvUrl(playlistUrl);

    if (!StarliteVodM3uUrls.isEligible(playlistUrl)) {
      lastMoviesFailure = 'not_eligible';
      debugPrint(
        '[VOD_M3U] movies skip: not eligible '
        '(flag=${StarliteVodM3uUrls.isFeatureEnabled})',
      );
      return false;
    }

    final moviesUrl = StarliteVodM3uUrls.moviesUrl(playlistUrl);
    if (moviesUrl == null) {
      lastMoviesFailure = 'bad_list_url';
      return false;
    }

    debugPrint(
      '[VOD_M3U] movies sync start host=${Uri.tryParse(playlistUrl)?.host}',
    );

    try {
      final moviesBody = await _fetchPlaylist(moviesUrl, forMovies: true);
      if (moviesBody == null) {
        lastMoviesFailure ??= 'movies_fetch_failed';
        await _publishCapabilities(playlistUrl);
        return false;
      }
      final movieParsed = M3uParser.parseCatalog(
        moviesBody,
        forceEntryType: M3uEntryType.movie,
      );
      final mp = _moviesPersister;
      if (mp != null &&
          (movieParsed.movieChannels.isNotEmpty ||
              movieParsed.movieCategories.isNotEmpty)) {
        await mp(movieParsed.movieCategories, movieParsed.movieChannels);
      }
      lastMovieCount = movieParsed.movieChannels.length;
      lastMovieCategoryCount = movieParsed.movieCategories.length;
      lastMoviesSyncOk = lastMovieCount > 0;
      if (!lastMoviesSyncOk) lastMoviesFailure = 'movies_empty';
      debugPrint(
        '[VOD_M3U] movies extinf=${movieParsed.extinfSeen} '
        'stored=$lastMovieCount cats=$lastMovieCategoryCount '
        'ok=$lastMoviesSyncOk',
      );
      CatalogPerf.mark('firstMoviePersistMs');
      CatalogPerf.count('movieCount', lastMovieCount);
      CatalogPerf.count('movieCatCount', lastMovieCategoryCount);
      CatalogPerf.count('movieCategoryCount', lastMovieCategoryCount);
      CatalogPerf.flush('after_movies_persist');
      await _publishCapabilities(playlistUrl);
      return lastMoviesSyncOk;
    } catch (e) {
      lastMoviesFailure = 'error';
      debugPrint('[VOD_M3U] movies sync error: $e');
      await _publishCapabilities(playlistUrl);
      return false;
    }
  }

  /// Series shards only. Does not fetch or wait on movies.
  Future<bool> syncSeries(String playlistUrl) async {
    lastSeriesSyncAttempted = true;
    lastSeriesSyncOk = false;
    lastSeriesFailure = null;
    lastSeriesCount = 0;
    lastSeriesCategoryCount = 0;
    lastTvShowShardsFetched = 0;
    lastXmlTvUrl ??= StarliteVodM3uUrls.defaultXmlTvUrl(playlistUrl);

    if (!StarliteVodM3uUrls.isEligible(playlistUrl)) {
      lastSeriesFailure = 'not_eligible';
      return false;
    }

    debugPrint(
      '[VOD_M3U] series sync start host=${Uri.tryParse(playlistUrl)?.host}',
    );

    try {
      final seriesOk = await _fetchAndPersistSeries(playlistUrl);
      lastSeriesSyncOk = seriesOk;
      if (!seriesOk) lastSeriesFailure ??= 'series_empty';
      await _publishCapabilities(playlistUrl);
      return lastSeriesSyncOk;
    } catch (e) {
      lastSeriesFailure = 'error';
      debugPrint('[VOD_M3U] series sync error: $e');
      await _publishCapabilities(playlistUrl);
      return false;
    }
  }

  /// Starts movies and series independently. Prefer [syncMovies] / [syncSeries].
  Future<bool> syncFromLivePlaylist(String playlistUrl) async {
    lastXmlTvUrl = StarliteVodM3uUrls.defaultXmlTvUrl(playlistUrl);
    final movieFuture = syncMovies(playlistUrl);
    final seriesFuture = syncSeries(playlistUrl);
    final movieOk = await movieFuture;
    final seriesOk = await seriesFuture;
    debugPrint(
      '[VOD_M3U] sync done moviesOk=$movieOk seriesOk=$seriesOk '
      'movies=$lastMovieCount series=$lastSeriesCount '
      'shards=$lastTvShowShardsFetched',
    );
    return movieOk || seriesOk;
  }

  Future<bool> _fetchAndPersistSeries(String playlistUrl) async {
    final shards = StarliteVodM3uUrls.tvShowsShardUrls(playlistUrl);
    if (shards.isEmpty) return false;

    final buf = StringBuffer('#EXTM3U\n');
    final seen = <String>{};
    var fetched = 0;

    for (var i = 0; i < shards.length; i++) {
      final url = shards[i];
      // Never log full URL (contains credentials).
      debugPrint('[VOD_M3U] tvshows shard=${i + 1}/${shards.length}');

      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final status = res.statusCode ?? 0;
      final raw = res.data;
      final body = raw == null ? null : _decodePlaylistBytes(raw);

      final stop = StarliteVodM3uUrls.reasonToStop(
        statusCode: status,
        body: body,
        seenFingerprints: seen,
      );
      if (stop != StarliteVodShardStop.none) {
        debugPrint(
          '[VOD_M3U] tvshows stop shard=${i + 1} reason=${stop.name} '
          'status=$status',
        );
        break;
      }

      seen.add(StarliteVodM3uUrls.bodyFingerprint(body!));
      for (final line in body.split(RegExp(r'\r?\n'))) {
        final t = line.trimRight();
        if (t.isEmpty) continue;
        if (t.startsWith('#EXTM3U')) continue;
        buf.writeln(t);
      }
      fetched++;
    }

    lastTvShowShardsFetched = fetched;
    if (fetched == 0) {
      debugPrint('[VOD_M3U] tvshows: no shards fetched');
      return false;
    }

    final parsed = M3uParser.parseCatalog(
      buf.toString(),
      forceEntryType: M3uEntryType.series,
    );
    final sp = _seriesPersister;
    if (sp != null &&
        (parsed.seriesChannels.isNotEmpty ||
            parsed.seriesCategories.isNotEmpty)) {
      await sp(parsed.seriesCategories, parsed.seriesChannels);
    }
    lastSeriesCount = parsed.seriesChannels.length;
    lastSeriesCategoryCount = parsed.seriesCategories.length;
    debugPrint(
      '[VOD_M3U] series shards=$fetched extinf=${parsed.extinfSeen} '
      'stored=$lastSeriesCount cats=$lastSeriesCategoryCount',
    );
    CatalogPerf.mark('firstSeriesPersistMs');
    CatalogPerf.count('seriesCount', lastSeriesCount);
    CatalogPerf.count('seriesCatCount', lastSeriesCategoryCount);
    CatalogPerf.count('seriesCategoryCount', lastSeriesCategoryCount);
    CatalogPerf.flush('after_series_persist');
    return lastSeriesCount > 0;
  }

  Future<String?> _fetchPlaylist(String url, {required bool forMovies}) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final status = res.statusCode ?? 0;
      if (status == 404) {
        if (forMovies) lastMoviesFailure = 'movies_404';
        return null;
      }
      if (status < 200 || status >= 300 || res.data == null) {
        if (forMovies) lastMoviesFailure = 'movies_http_$status';
        return null;
      }
      final body = _decodePlaylistBytes(res.data!);
      if (StarliteVodM3uUrls.countExtinf(body) == 0) {
        if (forMovies) lastMoviesFailure = 'movies_empty';
        return null;
      }
      return body;
    } on DioException catch (e) {
      if (forMovies) lastMoviesFailure = 'movies_dio';
      debugPrint('[VOD_M3U] movies fetch dio: ${e.type}');
      return null;
    } catch (e) {
      if (forMovies) lastMoviesFailure = 'movies_error';
      debugPrint('[VOD_M3U] movies fetch error: $e');
      return null;
    }
  }

  /// Decode playlist bytes; handle accidental gzip without Content-Encoding.
  static String _decodePlaylistBytes(List<int> bytes) {
    List<int> raw = bytes;
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        raw = gzip.decode(bytes);
      } catch (_) {
        raw = bytes;
      }
    }
    try {
      return utf8.decode(raw, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(raw);
    }
  }

  Future<void> _publishCapabilities(String playlistUrl) async {
    final xmlTv = lastXmlTvUrl;
    final prev = ProviderCapabilityInspector.instance.lastCapabilities ??
        ProviderCapabilityStore.instance.cached ??
        ProviderCapabilities.m3uMinimum(hasLive: true);

    final caps = prev.copyWith(
      providerType: ProviderType.m3u,
      supportsLive: true,
      supportsVod: lastMovieCount > 0 || prev.supportsVod,
      supportsSeries: lastSeriesCount > 0 || prev.supportsSeries,
      supportsXmlTv: (xmlTv != null && xmlTv.isNotEmpty) || prev.supportsXmlTv,
      xmlTvUrl: (xmlTv != null && xmlTv.isNotEmpty) ? xmlTv : prev.xmlTvUrl,
      vodStreamSample:
          lastMovieCount > 0 ? lastMovieCount : prev.vodStreamSample,
      vodCategorySample: lastMovieCategoryCount > 0
          ? lastMovieCategoryCount
          : prev.vodCategorySample,
      seriesSample:
          lastSeriesCount > 0 ? lastSeriesCount : prev.seriesSample,
      seriesCategorySample: lastSeriesCategoryCount > 0
          ? lastSeriesCategoryCount
          : prev.seriesCategorySample,
      notes: [
        ...prev.notes.where((n) => n != 'starlite_vod_m3u'),
        if (lastMoviesSyncOk || lastSeriesSyncOk) 'starlite_vod_m3u',
        if (lastTvShowShardsFetched > 0)
          'vod_tvshows_shards_$lastTvShowShardsFetched',
        if (lastFailure != null) 'vod_m3u_$lastFailure',
      ],
      probedAt: DateTime.now().toUtc(),
    );

    ProviderCapabilityInspector.instance.lastCapabilities = caps;
    await ProviderCapabilityStore.instance.save(caps);
    debugPrint(caps.capabilityLogLine);
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';
import '../models/user_preference_profile.dart';
import 'catalog_perf.dart';
import 'local_market_service.dart';
import 'provider_curation_rules.dart';

class SearchIndexEntry {
  final dynamic item; // ChannelLive, ChannelMovie, or ChannelSerie
  final String type; // 'live', 'movie', 'series'
  final String normalizedName;
  final Set<String> tokens;

  SearchIndexEntry({
    required this.item,
    required this.type,
    required this.normalizedName,
    required this.tokens,
  });
}

class SearchIndexService {
  static List<SearchIndexEntry> _index = [];
  static bool _isReady = false;
  static bool liveIndexReady = false;
  static bool moviesIndexReady = false;
  static bool seriesIndexReady = false;
  static Completer<void>? _inFlight;
  static Completer<void>? _liveInFlight;
  static Completer<void>? _moviesInFlight;
  static Completer<void>? _seriesInFlight;
  static int _lastSourceCount = 0;

  static bool get isReady =>
      _isReady || liveIndexReady || moviesIndexReady || seriesIndexReady;
  static int get totalIndexedEntries => _index.length;

  static final RegExp _splitRegExp = RegExp(r'[\s\-_\.:\(\)\[\]\/\+&]+');

  /// Tokenizes a raw string into a clean lowercase token set
  static Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(_splitRegExp)
        .where((token) => token.length >= 2)
        .toSet();
  }

  /// Builds the search index asynchronously to prevent blocking the UI thread.
  /// Concurrent callers await the in-flight build instead of silently no-oping.
  static Future<void> buildIndex({
    required List<ChannelLive> liveChannels,
    required List<ChannelMovie> movies,
    required List<ChannelSerie> series,
    Set<String>? adultCategoryIds,
    Map<String, String>? categoryIdToName,
  }) async {
    final incoming =
        liveChannels.length + movies.length + series.length;

    // Wait for any in-flight build; skip rebuild if we already cover this catalog.
    if (_inFlight != null) {
      try {
        await _inFlight!.future;
      } catch (_) {}
      if (_isReady &&
          incoming > 0 &&
          incoming <= _lastSourceCount &&
          _index.isNotEmpty) {
        return;
      }
    }

    if (_isReady &&
        incoming > 0 &&
        incoming <= _lastSourceCount &&
        _index.isNotEmpty &&
        categoryIdToName == null) {
      return;
    }

    final completer = Completer<void>();
    _inFlight = completer;
    _isReady = false;

    debugPrint(
      "[SearchIndexService] build started total=$incoming in background isolate "
      "(live=${liveChannels.length}, movies=${movies.length}, series=${series.length})",
    );

    final stopwatch = Stopwatch()..start();

    try {
      final params = SearchIndexParams(
        liveChannels: liveChannels,
        movies: movies,
        series: series,
        adultCategoryIds: adultCategoryIds ?? {},
        categoryIdToName: categoryIdToName ?? const {},
      );
      _index = await compute(buildSearchIndexInBackground, params);
      _lastSourceCount = incoming;
      _isReady = true;
      liveIndexReady = liveChannels.isNotEmpty || liveIndexReady;
      moviesIndexReady = movies.isNotEmpty || moviesIndexReady;
      seriesIndexReady = series.isNotEmpty || seriesIndexReady;
      if (!completer.isCompleted) completer.complete();
    } catch (e) {
      debugPrint("[SearchIndexService] error building search index: $e");
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      stopwatch.stop();
      if (identical(_inFlight, completer)) _inFlight = null;
      debugPrint(
        "[SearchIndexService] build completed total=${_index.length} "
        "durationMs=${stopwatch.elapsedMilliseconds}",
      );
      CatalogPerf.span('searchIndexReadyMs', stopwatch.elapsedMilliseconds);
      CatalogPerf.span('search_index_ms', stopwatch.elapsedMilliseconds);
      CatalogPerf.count('searchIndexEntries', _index.length);
      CatalogPerf.flush('after_search_index');
    }
  }

  /// Index live only. Does not wait on movies/series and does not clear them.
  static Future<void> indexLive({
    required List<ChannelLive> liveChannels,
    Set<String>? adultCategoryIds,
    Map<String, String>? categoryIdToName,
  }) async {
    if (_liveInFlight != null) {
      try {
        await _liveInFlight!.future;
      } catch (_) {}
      if (liveIndexReady) return;
    }
    final completer = Completer<void>();
    _liveInFlight = completer;
    try {
      final params = SearchIndexParams(
        liveChannels: liveChannels,
        movies: const [],
        series: const [],
        adultCategoryIds: adultCategoryIds ?? {},
        categoryIdToName: categoryIdToName ?? const {},
      );
      final built = await compute(buildSearchIndexInBackground, params);
      _index.removeWhere((e) => e.type == 'live');
      _index.addAll(built);
      liveIndexReady = true;
      _isReady = true;
      if (!completer.isCompleted) completer.complete();
      debugPrint(
        '[SearchIndexService] live domain ready entries=${built.length}',
      );
    } catch (e) {
      debugPrint('[SearchIndexService] live index error: $e');
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      if (identical(_liveInFlight, completer)) _liveInFlight = null;
    }
  }

  /// Index movies only. Does not wait on series and does not clear live/series.
  static Future<void> indexMovies({
    required List<ChannelMovie> movies,
    Set<String>? adultCategoryIds,
    Map<String, String>? categoryIdToName,
  }) async {
    if (_moviesInFlight != null) {
      try {
        await _moviesInFlight!.future;
      } catch (_) {}
      if (moviesIndexReady) return;
    }
    final completer = Completer<void>();
    _moviesInFlight = completer;
    try {
      final params = SearchIndexParams(
        liveChannels: const [],
        movies: movies,
        series: const [],
        adultCategoryIds: adultCategoryIds ?? {},
        categoryIdToName: categoryIdToName ?? const {},
      );
      final built = await compute(buildSearchIndexInBackground, params);
      _index.removeWhere((e) => e.type == 'movie');
      _index.addAll(built);
      moviesIndexReady = true;
      _isReady = true;
      if (!completer.isCompleted) completer.complete();
      debugPrint(
        '[SearchIndexService] movies domain ready entries=${built.length}',
      );
    } catch (e) {
      debugPrint('[SearchIndexService] movies index error: $e');
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      if (identical(_moviesInFlight, completer)) _moviesInFlight = null;
    }
  }

  /// Index series only. Independent of movies.
  static Future<void> indexSeries({
    required List<ChannelSerie> series,
    Set<String>? adultCategoryIds,
    Map<String, String>? categoryIdToName,
  }) async {
    if (_seriesInFlight != null) {
      try {
        await _seriesInFlight!.future;
      } catch (_) {}
      if (seriesIndexReady) return;
    }
    final completer = Completer<void>();
    _seriesInFlight = completer;
    try {
      final params = SearchIndexParams(
        liveChannels: const [],
        movies: const [],
        series: series,
        adultCategoryIds: adultCategoryIds ?? {},
        categoryIdToName: categoryIdToName ?? const {},
      );
      final built = await compute(buildSearchIndexInBackground, params);
      _index.removeWhere((e) => e.type == 'series');
      _index.addAll(built);
      seriesIndexReady = true;
      _isReady = true;
      if (!completer.isCompleted) completer.complete();
      debugPrint(
        '[SearchIndexService] series domain ready entries=${built.length}',
      );
    } catch (e) {
      debugPrint('[SearchIndexService] series index error: $e');
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      if (identical(_seriesInFlight, completer)) _seriesInFlight = null;
    }
  }

  /// Queries the built index, scoring matches based on string containments and token overlays
  static List<SearchIndexEntry> search(
    String queryText, {
    List<String> expandedKeywords = const [],
  }) {
    final stopwatch = Stopwatch()..start();
    final clean = queryText.toLowerCase().trim();
    if (clean.isEmpty) return [];

    final activeMarket = LocalMarketService.getActiveMarket();
    final prefProfile = UserPreferenceProfile.load();
    final bool isPersonalized = prefProfile.locationFeatureEnabled;
    Set<String> localLiveStreamIds = {};

    if (isPersonalized && activeMarket != null) {
      final localLiveChannels = LocalMarketService.getLocalChannelsForCategory(
        categoryKey: 'all',
        market: activeMarket,
        playlist: _index
            .where((e) => e.type == 'live')
            .map((e) => e.item as ChannelLive)
            .toList(),
      );
      localLiveStreamIds = localLiveChannels
          .map((c) => c.streamId ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    final searchTokens = _tokenize(clean);
    final List<MapEntry<SearchIndexEntry, double>> scored = [];

    for (final entry in _index) {
      double score = 0.0;

      // Primary: exact phrase / prefix on searchable blob (name + group + tvg-id)
      if (entry.normalizedName.contains(clean)) {
        score += 100.0;
        if (entry.normalizedName.startsWith(clean)) {
          score += 50.0;
        }
      }

      // Prefer channel-name prefix over category-only hits
      final nameOnly = _itemDisplayName(entry).toLowerCase();
      if (nameOnly.startsWith(clean)) {
        score += 40.0;
      } else if (nameOnly.contains(clean)) {
        score += 20.0;
      }

      // Secondary: token matches
      for (final st in searchTokens) {
        if (entry.tokens.contains(st)) {
          score += 30.0;
        } else {
          for (final et in entry.tokens) {
            if (et.contains(st)) {
              score += 15.0;
              break;
            }
          }
        }
      }

      // Tertiary: AI intent expanded tokens
      for (final et in expandedKeywords) {
        final cleanEt = et.toLowerCase().trim();
        if (cleanEt.isEmpty) continue;
        if (searchTokens.contains(cleanEt)) continue;

        if (entry.tokens.contains(cleanEt)) {
          score += 10.0;
        } else {
          for (final token in entry.tokens) {
            if (token.contains(cleanEt)) {
              score += 5.0;
              break;
            }
          }
        }
      }

      if (score > 0) {
        if (entry.type == 'live' &&
            localLiveStreamIds
                .contains((entry.item as ChannelLive).streamId)) {
          score += 40.0;
        }

        final isUsaOrEng = entry.normalizedName.contains('usa') ||
            entry.normalizedName.contains('united states') ||
            entry.normalizedName.contains('uk') ||
            entry.normalizedName.contains('canada') ||
            entry.normalizedName.contains('english') ||
            RegExp(r'\bus\b').hasMatch(entry.normalizedName);
        if (isUsaOrEng) {
          score += 25.0;
        }

        scored.add(MapEntry(entry, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    stopwatch.stop();
    debugPrint(
      "[SearchIndexService] Search for '$queryText' completed in "
      "${stopwatch.elapsedMilliseconds} ms. Results found: ${scored.length}",
    );

    return scored.map((e) => e.key).toList();
  }

  static String _itemDisplayName(SearchIndexEntry entry) {
    final item = entry.item;
    if (item is ChannelLive) return item.name ?? '';
    if (item is ChannelMovie) return item.name ?? '';
    if (item is ChannelSerie) return item.name ?? '';
    return '';
  }

  /// Safely clears the memory index
  static void clearIndex() {
    _index.clear();
    _isReady = false;
    liveIndexReady = false;
    moviesIndexReady = false;
    seriesIndexReady = false;
    _lastSourceCount = 0;
  }
}

class SearchIndexParams {
  final List<ChannelLive> liveChannels;
  final List<ChannelMovie> movies;
  final List<ChannelSerie> series;
  final Set<String> adultCategoryIds;
  final Map<String, String> categoryIdToName;

  SearchIndexParams({
    required this.liveChannels,
    required this.movies,
    required this.series,
    required this.adultCategoryIds,
    this.categoryIdToName = const {},
  });
}

List<SearchIndexEntry> buildSearchIndexInBackground(SearchIndexParams params) {
  final List<SearchIndexEntry> tempIndex = [];
  final catNames = params.categoryIdToName;

  Set<String> tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[\s\-_\.:\(\)\[\]\/\+&]+'))
        .where((token) => token.length >= 2)
        .toSet();
  }

  String groupLabel(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return '';
    return catNames[categoryId] ?? '';
  }

  // 1. Live Channels — name + group-title + tvg-id (epgChannelId)
  for (final ch in params.liveChannels) {
    final name = ch.name ?? '';
    final group = groupLabel(ch.categoryId);
    if (ProviderCurationRules.isAdultCategory(name) ||
        ProviderCurationRules.isAdultCategory(group) ||
        (ch.categoryId != null &&
            params.adultCategoryIds.contains(ch.categoryId))) {
      continue;
    }

    final tvgId = ch.epgChannelId?.toString() ?? '';
    final searchable = '$name $group $tvgId'.trim();
    final tokens = tokenize(searchable);
    tempIndex.add(SearchIndexEntry(
      item: ch,
      type: 'live',
      normalizedName: searchable.toLowerCase(),
      tokens: tokens,
    ));
  }

  // 2. Movies VOD
  for (final mv in params.movies) {
    final name = mv.name ?? '';
    final group = groupLabel(mv.categoryId);
    if (ProviderCurationRules.isAdultCategory(name) ||
        ProviderCurationRules.isAdultCategory(group) ||
        (mv.categoryId != null &&
            params.adultCategoryIds.contains(mv.categoryId))) {
      continue;
    }

    final searchable = '$name $group'.trim();
    tempIndex.add(SearchIndexEntry(
      item: mv,
      type: 'movie',
      normalizedName: searchable.toLowerCase(),
      tokens: tokenize(searchable),
    ));
  }

  // 3. Series VOD
  for (final sr in params.series) {
    final name = sr.name ?? '';
    final group = groupLabel(sr.categoryId);
    if (ProviderCurationRules.isAdultCategory(name) ||
        ProviderCurationRules.isAdultCategory(group) ||
        (sr.categoryId != null &&
            params.adultCategoryIds.contains(sr.categoryId))) {
      continue;
    }

    final searchable = '$name $group'.trim();
    tempIndex.add(SearchIndexEntry(
      item: sr,
      type: 'series',
      normalizedName: searchable.toLowerCase(),
      tokens: tokenize(searchable),
    ));
  }

  tempIndex.sort((a, b) {
    final nameA = a.normalizedName;
    final nameB = b.normalizedName;

    final isUsaA = nameA.contains('usa') ||
        nameA.contains('united states') ||
        RegExp(r'\bus\b').hasMatch(nameA);
    final isUsaB = nameB.contains('usa') ||
        nameB.contains('united states') ||
        RegExp(r'\bus\b').hasMatch(nameB);
    if (isUsaA != isUsaB) return isUsaA ? -1 : 1;

    final isEngA =
        nameA.contains('canada') || nameA.contains('uk') || nameA.contains('english');
    final isEngB =
        nameB.contains('canada') || nameB.contains('uk') || nameB.contains('english');
    if (isEngA != isEngB) return isEngA ? -1 : 1;

    return nameA.compareTo(nameB);
  });

  return tempIndex;
}

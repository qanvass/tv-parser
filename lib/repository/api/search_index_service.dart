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

  /// Lowercased display name, computed once at index time so search never
  /// re-lowercases 100k names per keystroke.
  final String nameLower;

  /// Region/language boost flag, also computed once at index time.
  final bool isUsaOrEng;

  SearchIndexEntry({
    required this.item,
    required this.type,
    required this.normalizedName,
    required this.tokens,
  })  : nameLower = _displayNameOf(item).toLowerCase(),
        isUsaOrEng = _usaOrEngOf(normalizedName);

  static final RegExp _usWord = RegExp(r'\bus\b');

  static String _displayNameOf(dynamic item) {
    if (item is ChannelLive) return item.name ?? '';
    if (item is ChannelMovie) return item.name ?? '';
    if (item is ChannelSerie) return item.name ?? '';
    return '';
  }

  static bool _usaOrEngOf(String n) =>
      n.contains('usa') ||
      n.contains('united states') ||
      n.contains('uk') ||
      n.contains('canada') ||
      n.contains('english') ||
      _usWord.hasMatch(n);
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

  /// Index size above which [searchAsync] slices its scan across event-loop
  /// turns instead of running one long synchronous pass.
  static const int asyncScanThreshold = 10000;

  /// Queries the built index, scoring matches based on string containments and token overlays.
  /// Synchronous; prefer [searchAsync] from UI code once the index is large.
  static List<SearchIndexEntry> search(
    String queryText, {
    List<String> expandedKeywords = const [],
  }) {
    final ctx = _SearchContext.create(queryText, expandedKeywords, _index);
    if (ctx == null) return [];
    final stopwatch = Stopwatch()..start();
    final scored = <MapEntry<SearchIndexEntry, double>>[];
    for (final entry in _index) {
      final score = _scoreEntry(entry, ctx);
      if (score > 0) scored.add(MapEntry(entry, score));
    }
    return _finish(queryText, scored, stopwatch);
  }

  /// Same results as [search], but for large indexes the scan yields to the
  /// event loop every few milliseconds so typing and D-pad focus stay
  /// responsive. Returns null if [isStale] reported a newer query mid-scan.
  static Future<List<SearchIndexEntry>?> searchAsync(
    String queryText, {
    List<String> expandedKeywords = const [],
    bool Function()? isStale,
  }) async {
    final snapshot = _index;
    if (snapshot.length <= asyncScanThreshold) {
      return search(queryText, expandedKeywords: expandedKeywords);
    }
    final ctx = _SearchContext.create(queryText, expandedKeywords, snapshot);
    if (ctx == null) return [];
    final stopwatch = Stopwatch()..start();
    final slice = Stopwatch()..start();
    final scored = <MapEntry<SearchIndexEntry, double>>[];
    for (var i = 0; i < snapshot.length; i++) {
      final entry = snapshot[i];
      final score = _scoreEntry(entry, ctx);
      if (score > 0) scored.add(MapEntry(entry, score));
      if ((i & 255) == 0 && slice.elapsedMilliseconds >= 8) {
        await Future<void>.delayed(Duration.zero);
        if (isStale != null && isStale()) return null;
        slice
          ..reset()
          ..start();
      }
    }
    return _finish(queryText, scored, stopwatch);
  }

  static List<SearchIndexEntry> _finish(
    String queryText,
    List<MapEntry<SearchIndexEntry, double>> scored,
    Stopwatch stopwatch,
  ) {
    scored.sort((a, b) => b.value.compareTo(a.value));
    stopwatch.stop();
    debugPrint(
      "[SearchIndexService] Search for '$queryText' completed in "
      "${stopwatch.elapsedMilliseconds} ms. Results found: ${scored.length}",
    );
    return scored.map((e) => e.key).toList();
  }

  static double _scoreEntry(SearchIndexEntry entry, _SearchContext ctx) {
    final clean = ctx.clean;
    final normalized = entry.normalizedName;

    // Cheap reject: every scoring rule below needs the query, a query token,
    // or an expanded keyword to appear as a substring of the searchable blob
    // (tokens are substrings of it). Skips the token loops for ~all entries.
    var candidate = normalized.contains(clean);
    if (!candidate) {
      for (final st in ctx.searchTokens) {
        if (normalized.contains(st)) {
          candidate = true;
          break;
        }
      }
    }
    if (!candidate) {
      for (final et in ctx.expanded) {
        if (normalized.contains(et)) {
          candidate = true;
          break;
        }
      }
    }
    if (!candidate && !entry.nameLower.contains(clean)) return 0.0;

    double score = 0.0;

    // Primary: exact phrase / prefix on searchable blob (name + group + tvg-id)
    if (normalized.contains(clean)) {
      score += 100.0;
      if (normalized.startsWith(clean)) {
        score += 50.0;
      }
    }

    // Prefer channel-name prefix over category-only hits
    final nameOnly = entry.nameLower;
    if (nameOnly.startsWith(clean)) {
      score += 40.0;
    } else if (nameOnly.contains(clean)) {
      score += 20.0;
    }

    // Secondary: token matches
    for (final st in ctx.searchTokens) {
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
    for (final cleanEt in ctx.expanded) {
      if (ctx.searchTokens.contains(cleanEt)) continue;
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
          ctx.localLiveStreamIds
              .contains((entry.item as ChannelLive).streamId)) {
        score += 40.0;
      }
      if (entry.isUsaOrEng) score += 25.0;
    }
    return score;
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

/// Per-query state computed once, not per index entry.
class _SearchContext {
  final String clean;
  final Set<String> searchTokens;
  final List<String> expanded;
  final Set<String> localLiveStreamIds;

  _SearchContext._(
    this.clean,
    this.searchTokens,
    this.expanded,
    this.localLiveStreamIds,
  );

  static _SearchContext? create(
    String queryText,
    List<String> expandedKeywords,
    List<SearchIndexEntry> index,
  ) {
    final clean = queryText.toLowerCase().trim();
    if (clean.isEmpty) return null;

    var localLiveStreamIds = <String>{};
    final activeMarket = LocalMarketService.getActiveMarket();
    final prefProfile = UserPreferenceProfile.load();
    if (prefProfile.locationFeatureEnabled && activeMarket != null) {
      final localLiveChannels = LocalMarketService.getLocalChannelsForCategory(
        categoryKey: 'all',
        market: activeMarket,
        playlist: index
            .where((e) => e.type == 'live')
            .map((e) => e.item as ChannelLive)
            .toList(),
      );
      localLiveStreamIds = localLiveChannels
          .map((c) => c.streamId ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    final searchTokens = SearchIndexService._tokenize(clean);
    final expanded = <String>[
      for (final et in expandedKeywords)
        if (et.toLowerCase().trim().isNotEmpty) et.toLowerCase().trim(),
    ];
    return _SearchContext._(clean, searchTokens, expanded, localLiveStreamIds);
  }
}

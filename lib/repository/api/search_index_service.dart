import 'package:flutter/foundation.dart';
import '../models/channel_live.dart';
import '../models/channel_movie.dart';
import '../models/channel_serie.dart';
import '../models/user_preference_profile.dart';
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
  static bool _isIndexing = false;
  static bool _isReady = false;

  static bool get isReady => _isReady;
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

  /// Builds the search index asynchronously to prevent blocking the UI thread
  static Future<void> buildIndex({
    required List<ChannelLive> liveChannels,
    required List<ChannelMovie> movies,
    required List<ChannelSerie> series,
    Set<String>? adultCategoryIds,
  }) async {
    if (_isIndexing) return;
    _isIndexing = true;
    _isReady = false;

    final totalCount = liveChannels.length + movies.length + series.length;
    debugPrint("[SearchIndexService] build started total=$totalCount in background isolate (live=${liveChannels.length}, movies=${movies.length}, series=${series.length})");

    final stopwatch = Stopwatch()..start();

    try {
      final params = SearchIndexParams(
        liveChannels: liveChannels,
        movies: movies,
        series: series,
        adultCategoryIds: adultCategoryIds ?? {},
      );
      _index = await compute(buildSearchIndexInBackground, params);
      _isReady = true;
    } catch (e) {
      debugPrint("[SearchIndexService] error building search index: $e");
    } finally {
      stopwatch.stop();
      _isIndexing = false;
      debugPrint("[SearchIndexService] build completed total=${_index.length} durationMs=${stopwatch.elapsedMilliseconds}");
    }
  }

  /// Queries the built index, scoring matches based on string containments and token overlays
  static List<SearchIndexEntry> search(String queryText, {List<String> expandedKeywords = const []}) {
    final stopwatch = Stopwatch()..start();
    final clean = queryText.toLowerCase().trim();
    if (clean.isEmpty) return [];

    final activeMarket = LocalMarketService.getActiveMarket();
    final prefProfile = UserPreferenceProfile.load();
    final bool isPersonalized = prefProfile.locationFeatureEnabled;
    Set<String> localLiveStreamIds = {};

    if (isPersonalized && activeMarket != null) {
      // Get all local matched channels and put their stream IDs into a Set for fast check
      final localLiveChannels = LocalMarketService.getLocalChannelsForCategory(
        categoryKey: 'all',
        market: activeMarket,
        playlist: _index.where((e) => e.type == 'live').map((e) => e.item as ChannelLive).toList(),
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

      // Primary check: Exact phrase match yields highest score
      if (entry.normalizedName.contains(clean)) {
        score += 100.0;
        if (entry.normalizedName.startsWith(clean)) {
          score += 50.0;
        }
      }

      // Secondary check: Token matches
      for (final st in searchTokens) {
        if (entry.tokens.contains(st)) {
          score += 30.0;
        } else {
          // Substring matches in target tokens (Fuzzy/partial check)
          for (final et in entry.tokens) {
            if (et.contains(st)) {
              score += 15.0;
              break;
            }
          }
        }
      }

      // Tertiary check: AI intent expanded tokens (lower priority boost)
      for (final et in expandedKeywords) {
        final cleanEt = et.toLowerCase().trim();
        if (cleanEt.isEmpty) continue;
        // Skip tokens that are already in the original query search tokens to avoid double counting
        if (searchTokens.contains(cleanEt)) continue;

        if (entry.tokens.contains(cleanEt)) {
          score += 10.0;
        } else {
          // Substring matches in target tokens (Fuzzy/partial check)
          for (final token in entry.tokens) {
            if (token.contains(cleanEt)) {
              score += 5.0;
              break;
            }
          }
        }
      }

      if (score > 0) {
        // Boost local channels if this entry is a live stream in the local stream list
        if (entry.type == 'live' && localLiveStreamIds.contains((entry.item as ChannelLive).streamId)) {
          score += 40.0;
        }

        // Boost USA/English relevance
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

    // Sort scored items desc
    scored.sort((a, b) => b.value.compareTo(a.value));
    stopwatch.stop();
    debugPrint("[SearchIndexService] Search for '$queryText' completed in ${stopwatch.elapsedMilliseconds} ms. Results found: ${scored.length}");

    return scored.map((e) => e.key).toList();
  }

  /// Safely clears the memory index
  static void clearIndex() {
    _index.clear();
    _isReady = false;
  }
}

class SearchIndexParams {
  final List<ChannelLive> liveChannels;
  final List<ChannelMovie> movies;
  final List<ChannelSerie> series;
  final Set<String> adultCategoryIds;

  SearchIndexParams({
    required this.liveChannels,
    required this.movies,
    required this.series,
    required this.adultCategoryIds,
  });
}

List<SearchIndexEntry> buildSearchIndexInBackground(SearchIndexParams params) {
  final List<SearchIndexEntry> tempIndex = [];

  Set<String> tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[\s\-_\.:\(\)\[\]\/\+&]+'))
        .where((token) => token.length >= 2)
        .toSet();
  }

  // 1. Live Channels
  for (final ch in params.liveChannels) {
    final name = ch.name ?? '';
    // Skip adult categories/channels
    if (ProviderCurationRules.isAdultCategory(name) ||
        (ch.categoryId != null && params.adultCategoryIds.contains(ch.categoryId))) {
      continue;
    }

    final tokens = tokenize('$name ${ch.categoryId ?? ""}');
    tempIndex.add(SearchIndexEntry(
      item: ch,
      type: 'live',
      normalizedName: name.toLowerCase(),
      tokens: tokens,
    ));
  }

  // 2. Movies VOD
  for (final mv in params.movies) {
    final name = mv.name ?? '';
    if (ProviderCurationRules.isAdultCategory(name) ||
        (mv.categoryId != null && params.adultCategoryIds.contains(mv.categoryId))) {
      continue;
    }

    final tokens = tokenize('$name ${mv.categoryId ?? ""}');
    tempIndex.add(SearchIndexEntry(
      item: mv,
      type: 'movie',
      normalizedName: name.toLowerCase(),
      tokens: tokens,
    ));
  }

  // 3. Series VOD
  for (final sr in params.series) {
    final name = sr.name ?? '';
    if (ProviderCurationRules.isAdultCategory(name) ||
        (sr.categoryId != null && params.adultCategoryIds.contains(sr.categoryId))) {
      continue;
    }

    final tokens = tokenize('$name ${sr.categoryId ?? ""}');
    tempIndex.add(SearchIndexEntry(
      item: sr,
      type: 'series',
      normalizedName: name.toLowerCase(),
      tokens: tokens,
    ));
  }

  // Sort search index so USA, Canada, UK English contents are indexed first
  tempIndex.sort((a, b) {
    final nameA = a.normalizedName;
    final nameB = b.normalizedName;

    final isUsaA = nameA.contains('usa') || nameA.contains('united states') || RegExp(r'\bus\b').hasMatch(nameA);
    final isUsaB = nameB.contains('usa') || nameB.contains('united states') || RegExp(r'\bus\b').hasMatch(nameB);
    if (isUsaA != isUsaB) return isUsaA ? -1 : 1;

    final isEngA = nameA.contains('canada') || nameA.contains('uk') || nameA.contains('english');
    final isEngB = nameB.contains('canada') || nameB.contains('uk') || nameB.contains('english');
    if (isEngA != isEngB) return isEngA ? -1 : 1;

    return nameA.compareTo(nameB);
  });

  return tempIndex;
}


import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../helpers/helpers.dart';
import '../../repository/api/api.dart';
import '../../repository/api/artwork_url_resolver.dart';
import '../../repository/api/catalog_perf.dart';
import '../../repository/api/content_intelligence_service.dart';
import '../../repository/api/event_discovery_service.dart';
import '../../repository/api/local_market_service.dart';
import '../../repository/api/local_proximity.dart';
import '../../repository/api/premium_plus_service.dart';
import '../../repository/models/category.dart';
import '../../repository/models/local_market_profile.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/premium_plus_item.dart';
import '../../repository/models/spotlight_event.dart';
import '../../repository/models/user_preference_profile.dart';
import 'widgets/tv_channel_grid.dart';

/// Live TV home data, ready to paint on the shell's first frame.
class LiveRowsSnapshot {
  final List<TvChannelRow> rows;
  final List<ChannelLive> allLives;
  final List<CategoryModel> liveCats;
  final List<SpotlightEvent> spots;
  final List<PremiumPlusItem> premiumPlusItems;
  final int liveGroupCount;
  final UserPreferenceProfile profile;

  const LiveRowsSnapshot({
    required this.rows,
    required this.allLives,
    required this.liveCats,
    required this.spots,
    required this.premiumPlusItems,
    required this.liveGroupCount,
    required this.profile,
  });
}

/// Builds the Live rows (category sort + [TvStreamRecord]s) while the splash
/// reel plays, so the TV shell shows them the moment it mounts instead of
/// starting that work after the reel ends. M3U (local cache) only; Xtream and
/// cold starts keep the shell's own load path.
class LiveRowsPrebuild {
  LiveRowsPrebuild._();

  static Future<LiveRowsSnapshot?>? _inFlight;
  static LiveRowsSnapshot? _ready;

  /// Starts the prebuild once (call after [LocaleApi.warmM3uCache]).
  static Future<LiveRowsSnapshot?> warm() => _inFlight ??= _run();

  /// Pending prebuild, if one was started and not yet consumed.
  static Future<LiveRowsSnapshot?>? get pending =>
      _ready == null && _inFlight != null ? _inFlight : null;

  /// Hands the snapshot to the shell exactly once; later loads (retry,
  /// refresh) rebuild from the live cache as before.
  static LiveRowsSnapshot? take() {
    final snap = _ready;
    _ready = null;
    _inFlight = null;
    if (snap == null) return null;
    // Playlist re-synced since the prebuild — let the shell rebuild.
    if (LocaleApi.getM3uChannels().length != snap.allLives.length) return null;
    return snap;
  }

  static Future<LiveRowsSnapshot?> _run() async {
    try {
      final user = await LocaleApi.getUser();
      if (user == null ||
          !IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
        return null;
      }
      final allLives = IptvProviderSession.instance.liveChannels();
      if (allLives.isEmpty) return null;

      final watch = Stopwatch()..start();
      var liveCats = LocaleApi.getM3uCategories();
      if (liveCats.isEmpty) liveCats = deriveCategories(allLives);
      final profile = UserPreferenceProfile.load();
      final spots = await EventDiscoveryService.getSpotlightEvents(
        region: profile.region,
      );

      // Small slices so the splash reel never drops frames.
      final slice = Stopwatch()..start();
      Future<bool> yieldSlice() async {
        if (slice.elapsedMilliseconds >= 8) {
          await Future<void>.delayed(const Duration(milliseconds: 4));
          slice
            ..reset()
            ..start();
        }
        return true;
      }

      final rows = await buildRows(
        liveCats: liveCats,
        allLives: allLives,
        profile: profile,
        market: activeLocalMarket(profile),
        yieldSlice: yieldSlice,
      );
      final premiumPlusItems = PremiumPlusService.matchPremiumPlusChannels(
        allLives,
        categoryIdToName: categoryIdToName(liveCats),
        forceRefresh: true,
      );

      // Phones never mount the TV shell — don't hold the rows in memory.
      if (!OrientationGuard.isTv) return null;

      final snap = LiveRowsSnapshot(
        rows: rows,
        allLives: allLives,
        liveCats: liveCats,
        spots: spots,
        premiumPlusItems: premiumPlusItems,
        liveGroupCount: liveCats.length,
        profile: profile,
      );
      _ready = snap;
      CatalogPerf.span('livePrebuildMs', watch.elapsedMilliseconds);
      CatalogPerf.timeline('LIVE_PREBUILD_READY');
      debugPrint(
        '[LIVE_PREBUILD] rows=${rows.length} channels=${allLives.length} '
        'ms=${watch.elapsedMilliseconds}',
      );
      return snap;
    } catch (e) {
      debugPrint('[LIVE_PREBUILD] skipped: $e');
      return null;
    }
  }

  /// User's Local TV Market (Settings / location), when personalization is on.
  static LocalMarketProfile? activeLocalMarket(UserPreferenceProfile profile) {
    if (!profile.locationFeatureEnabled) return null;
    return LocalMarketService.getActiveMarket();
  }

  static Map<String, String> categoryIdToName(List<CategoryModel> cats) => {
    for (final cat in cats)
      if (cat.categoryId != null && cat.categoryName != null)
        cat.categoryId!: cat.categoryName!,
  };

  /// Durable group-title categories derived from the channels themselves.
  static List<CategoryModel> deriveCategories(List<ChannelLive> allLives) {
    final seen = <String>{};
    final cats = <CategoryModel>[];
    for (final ch in allLives) {
      final id = ch.categoryId;
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      cats.add(CategoryModel(categoryId: id, categoryName: id, parentId: '0'));
    }
    return cats;
  }

  /// Live shelves: curated category order, channels ranked per profile.
  /// [yieldSlice] (optional) lets callers time-slice the work.
  static Future<List<TvChannelRow>> buildRows({
    required List<CategoryModel> liveCats,
    required List<ChannelLive> allLives,
    required UserPreferenceProfile profile,
    LocalMarketProfile? market,
    Future<bool> Function()? yieldSlice,
  }) async {
    // "US Local"-style groups: nearest affiliates first.
    List<ChannelLive> nearestFirst(String? catName, List<ChannelLive> chs) {
      if (market == null || !LocalProximity.isLocalCategory(catName))
        return chs;
      return LocalProximity.sortNearest(chs, market, (c) => c.name ?? '');
    }

    if (liveCats.isEmpty) {
      if (allLives.isEmpty) return const [];
      final records = <TvStreamRecord>[];
      for (final ch in allLives) {
        records.add(_record(ch, 'Live'));
        if (yieldSlice != null && !await yieldSlice()) return const [];
      }
      return [TvChannelRow(title: 'All Live', streams: records)];
    }

    final idToName = categoryIdToName(liveCats);
    final normalCats = liveCats
        .where(
          (c) =>
              c.categoryName != null &&
              !ProviderCurationRules.isAdultCategory(c.categoryName!),
        )
        .toList();
    final sortedCats = ProviderCurationRules.sortCategoriesForNormalDashboard(
      normalCats,
    );

    final byCat = <String, List<ChannelLive>>{};
    for (final ch in allLives) {
      final id = ch.categoryId;
      if (id == null || id.isEmpty) continue;
      byCat.putIfAbsent(id, () => []).add(ch);
    }

    final rows = <TvChannelRow>[];
    for (final cat in sortedCats) {
      final catId = cat.categoryId;
      if (catId == null) continue;
      try {
        final chs = byCat[catId] ?? const <ChannelLive>[];
        if (chs.isEmpty) continue;
        final sortedChs = nearestFirst(
          cat.categoryName,
          ContentIntelligenceService.sortLives(chs, profile, liveCats),
        );
        final subtitle = cat.categoryName ?? 'Live';
        final records = <TvStreamRecord>[
          for (final ch in sortedChs) _record(ch, subtitle),
        ];
        if (records.isNotEmpty) {
          rows.add(
            TvChannelRow(
              title: cat.categoryName ?? 'Live TV',
              streams: records,
            ),
          );
        }
      } catch (_) {}
      if (yieldSlice != null && !await yieldSlice()) return const [];
    }

    final usedIds = sortedCats
        .map((c) => c.categoryId)
        .whereType<String>()
        .toSet();
    for (final entry in byCat.entries) {
      if (usedIds.contains(entry.key)) continue;
      final name = idToName[entry.key] ?? 'More Live';
      if (ProviderCurationRules.isAdultCategory(name)) continue;
      final records = <TvStreamRecord>[
        for (final ch in nearestFirst(name, entry.value)) _record(ch, name),
      ];
      if (records.isNotEmpty) {
        rows.add(TvChannelRow(title: name, streams: records));
      }
      if (yieldSlice != null && !await yieldSlice()) return const [];
    }
    return rows;
  }

  static TvStreamRecord _record(ChannelLive ch, String subtitle) {
    final logo =
        ArtworkUrlResolver.resolveLiveLogo(
          primaryUrl: ch.streamIcon,
          epgOrTvgId: ch.epgChannelId?.toString(),
        ) ??
        '';
    final name = ch.name ?? 'Live Stream';
    return TvStreamRecord(
      title: name,
      subtitle: subtitle,
      streamUrl: (ch.directSource?.isNotEmpty == true)
          ? ch.directSource!
          : (ch.streamId ?? ''),
      imageUrl: logo.isEmpty ? null : logo,
      isHd: looksHd(name),
      tvgId: ch.epgChannelId?.toString(),
      streamId: ch.streamId,
    );
  }

  static bool looksHd(String name) {
    final n = name.toUpperCase();
    return n.contains(' HD') ||
        n.endsWith('HD') ||
        n.contains('1080') ||
        n.contains('720') ||
        n.contains('4K') ||
        n.contains('UHD');
  }
}

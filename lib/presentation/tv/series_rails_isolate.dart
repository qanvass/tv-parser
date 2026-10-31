import '../../repository/api/artwork_url_resolver.dart';
import '../../repository/api/content_intelligence_service.dart';
import '../../repository/api/provider_curation_rules.dart';
import '../../repository/models/category.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/user_preference_profile.dart';
import '../../repository/provider/provider_enums.dart';
import '../../repository/provider/title_normalizer.dart';
import '../../repository/provider/tmdb_enrichment_worker.dart';
import 'series_rail_grouper.dart';
import 'series_shelf_planner.dart';
import 'widgets/tv_channel_grid.dart';

/// Input for [buildSeriesRailsInBackground]. Plain data only so it can cross
/// an isolate boundary via `compute()`.
class SeriesRailsJob {
  final List<ChannelSerie> series;

  /// Categories used for shelf order and the "no rails" fallback names.
  final List<CategoryModel> categories;
  final List<CategoryModel> fallbackCategories;
  final UserPreferenceProfile profile;
  final Map<String, double> watchById;
  final int headCount;
  final int headLimit;

  const SeriesRailsJob({
    required this.series,
    required this.categories,
    required this.fallbackCategories,
    required this.profile,
    required this.watchById,
    required this.headCount,
    required this.headLimit,
  });
}

class SeriesRailsResult {
  /// First shelves only, for an instant first paint.
  final List<TvChannelRow> heads;

  /// Every shelf.
  final List<TvChannelRow> rows;
  final bool perShow;
  final int showCount;
  final int unassigned;

  const SeriesRailsResult({
    required this.heads,
    required this.rows,
    required this.perShow,
    required this.showCount,
    required this.unassigned,
  });
}

double? _parseSeriesRating(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final v = double.tryParse(raw.trim());
  if (v == null || v <= 0) return null;
  return v;
}

/// Poster/year/TMDB optional — never drop a playable series row.
TvStreamRecord seriesStreamRecordFor(
  ChannelSerie ch,
  String subtitle, {
  String? providerCategoryId,
  String? providerCategoryName,
  double? watchProgress,
}) {
  String streamUrl = '';
  if (ch.directSource != null && ch.directSource!.isNotEmpty) {
    streamUrl = ch.directSource!;
  } else if (ch.seriesId != null) {
    streamUrl = ch.seriesId!;
  }
  final poster = ArtworkUrlResolver.resolveVodPoster(cover: ch.cover);
  final parsed = TitleNormalizer.parse(ch.name ?? '');
  final rating = _parseSeriesRating(ch.rating ?? ch.rating5based);
  final seriesTitle = parsed.displayTitle.isEmpty
      ? (ch.name ?? 'Series')
      : parsed.displayTitle;
  final key = TmdbEnrichmentWorker.cacheKeyFor(
    seriesTitle,
    ch.seriesId,
    type: ContentType.series,
    year: parsed.year,
    matchTitle: parsed.matchTitle,
  );
  return TvStreamRecord(
    title: seriesTitle,
    subtitle: providerCategoryName ?? subtitle,
    streamUrl: streamUrl,
    imageUrl: poster,
    backdropUrl: ArtworkUrlResolver.resolveHeroBackdrop(posterFallback: poster),
    streamId: ch.seriesId,
    posterStyle: TvPosterStyle.vodPortrait,
    year: parsed.year,
    rating: rating,
    qualityLabel: parsed.qualityLabel,
    season: parsed.season,
    episode: parsed.episode,
    badge: parsed.episodeBadge,
    overview: ch.plot,
    watchProgress: watchProgress,
    enrichmentKey: key,
    providerCategoryId: providerCategoryId ?? ch.categoryId,
    providerCategoryName: providerCategoryName ?? subtitle,
  );
}

/// Entry point for `compute()`. Groups, sorts and builds every Series shelf
/// off the UI isolate (100k+ series took >60s on the main isolate and caused
/// an ANR on Android TV).
SeriesRailsResult buildSeriesRailsInBackground(SeriesRailsJob job) {
  final allSeries = job.series;
  final categories = job.categories;
  final watchById = job.watchById;

  final normalCats = categories
      .where(
        (c) =>
            c.categoryName != null &&
            !ProviderCurationRules.isAdultCategory(c.categoryName!),
      )
      .toList();

  final byCat = <String, List<ChannelSerie>>{};
  var unassigned = 0;
  for (final ch in allSeries) {
    final id = ch.categoryId;
    if (id == null || id.isEmpty) {
      unassigned++;
      continue;
    }
    byCat.putIfAbsent(id, () => []).add(ch);
  }

  if (SeriesShelfPlanner.looksPerShow(normalCats)) {
    return _buildPerShow(job, normalCats, byCat, unassigned);
  }

  final sortedCats = ProviderCurationRules.sortCategoriesForNormalDashboard(
    normalCats,
  );
  final shelves = <(CategoryModel, List<ChannelSerie>)>[];
  for (final cat in sortedCats) {
    final catId = cat.categoryId;
    if (catId == null) continue;
    final chs = byCat[catId];
    if (chs == null || chs.isEmpty) continue;
    try {
      shelves.add((
        cat,
        ContentIntelligenceService.sortSeries(chs, job.profile, categories),
      ));
    } catch (_) {}
  }

  TvStreamRecord buildSerie(CategoryModel cat, ChannelSerie ch) =>
      seriesStreamRecordFor(
        ch,
        cat.categoryName ?? 'Series',
        providerCategoryId: cat.categoryId,
        providerCategoryName: cat.categoryName,
        watchProgress: watchById[ch.seriesId ?? ''],
      );

  final heads = <TvChannelRow>[];
  for (final (cat, chs) in shelves.take(job.headLimit)) {
    try {
      final head = [
        for (final ch in chs.take(job.headCount)) buildSerie(cat, ch),
      ];
      if (head.isNotEmpty) {
        heads.add(
          TvChannelRow(
            title: cat.categoryName ?? 'Series Shows',
            streams: SeriesRailGrouper.groupForRail(head),
          ),
        );
      }
    } catch (_) {}
  }

  final rows = <TvChannelRow>[];
  for (final (cat, chs) in shelves) {
    final records = <TvStreamRecord>[];
    for (final ch in chs) {
      try {
        records.add(buildSerie(cat, ch));
      } catch (_) {}
    }
    if (records.isNotEmpty) {
      rows.add(
        TvChannelRow(
          title: cat.categoryName ?? 'Series Shows',
          streams: SeriesRailGrouper.groupForRail(records),
        ),
      );
    }
  }

  // Category metadata missing or produced zero rails: never publish an empty
  // Series tab when valid series records exist.
  if (rows.isEmpty && allSeries.isNotEmpty) {
    final nameById = <String, String>{
      for (final c in [...categories, ...job.fallbackCategories])
        if (c.categoryId != null && c.categoryId!.isNotEmpty)
          c.categoryId!:
              (c.categoryName != null && c.categoryName!.trim().isNotEmpty)
              ? c.categoryName!
              : 'All Series',
    };
    final byOwn = <String, List<ChannelSerie>>{};
    unassigned = 0;
    for (final ch in allSeries) {
      final id = ch.categoryId;
      if (id == null || id.isEmpty) {
        unassigned++;
        byOwn.putIfAbsent('_none', () => []).add(ch);
      } else {
        byOwn.putIfAbsent(id, () => []).add(ch);
      }
    }
    for (final entry in byOwn.entries) {
      final label = nameById[entry.key] ?? 'All Series';
      final records = <TvStreamRecord>[
        for (final ch in entry.value)
          seriesStreamRecordFor(
            ch,
            label,
            providerCategoryId: entry.key == '_none'
                ? ch.categoryId
                : entry.key,
            providerCategoryName: label,
            watchProgress: watchById[ch.seriesId ?? ''],
          ),
      ];
      if (records.isNotEmpty) {
        rows.add(
          TvChannelRow(
            title: label,
            streams: SeriesRailGrouper.groupForRail(records),
          ),
        );
      }
    }
  }

  return SeriesRailsResult(
    heads: heads,
    rows: rows,
    perShow: false,
    showCount: 0,
    unassigned: unassigned,
  );
}

/// Playlists with one group per show: one card per show, shelved by year.
SeriesRailsResult _buildPerShow(
  SeriesRailsJob job,
  List<CategoryModel> shows,
  Map<String, List<ChannelSerie>> byCat,
  int unassigned,
) {
  final plan = SeriesShelfPlanner.plan(shows);

  TvStreamRecord? showCard(CategoryModel cat) {
    final eps = byCat[cat.categoryId];
    if (eps == null || eps.isEmpty) return null;
    final name = cat.categoryName ?? 'Series';
    final title = SeriesShelfPlanner.showTitle(cat);
    final year = SeriesShelfPlanner.yearOf(cat);
    final card = SeriesRailGrouper.showCard(
      [
        for (final ch in eps)
          seriesStreamRecordFor(
            ch,
            name,
            providerCategoryId: cat.categoryId,
            providerCategoryName: name,
            watchProgress: job.watchById[ch.seriesId ?? ''],
          ),
      ],
      title: title,
      year: year,
    );
    return card.copyWith(
      enrichmentKey: TmdbEnrichmentWorker.cacheKeyFor(
        title,
        cat.categoryId,
        type: ContentType.series,
        year: year,
      ),
    );
  }

  List<TvChannelRow> build(int perShelf) {
    final rows = <TvChannelRow>[];
    for (final shelf in plan) {
      final cards = <TvStreamRecord>[];
      for (final cat in shelf.shows.take(perShelf)) {
        try {
          final card = showCard(cat);
          if (card != null) cards.add(card);
        } catch (_) {}
      }
      if (cards.isNotEmpty) {
        rows.add(TvChannelRow(title: shelf.title, streams: cards));
      }
    }
    return rows;
  }

  return SeriesRailsResult(
    heads: build(job.headCount),
    rows: build(1 << 30),
    perShow: true,
    showCount: shows.length,
    unassigned: unassigned,
  );
}

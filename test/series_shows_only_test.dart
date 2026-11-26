import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/series_rail_grouper.dart';
import 'package:mbark_iptv/presentation/tv/series_rails_isolate.dart';
import 'package:mbark_iptv/presentation/tv/widgets/tv_channel_grid.dart';
import 'package:mbark_iptv/repository/catalog/catalog_ingest.dart';
import 'package:mbark_iptv/repository/catalog/catalog_kind.dart';
import 'package:mbark_iptv/repository/catalog/catalog_store.dart';
import 'package:mbark_iptv/repository/models/category.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';
import 'package:mbark_iptv/repository/models/user_preference_profile.dart';

import 'catalog_memory_executor.dart';

/// Shows-only series: memory holds one row per show, the episodes are read
/// from the catalog store when a show is opened.
void main() {
  const showCount = 40;
  const episodesPerShow = 6;

  final cats = [
    for (var c = 0; c < showCount; c++)
      CategoryModel(categoryId: 'p$c', categoryName: 'Show $c (2026)'),
  ];
  // Catalog order: all of show 0, then all of show 1, and so on.
  final episodes = [
    for (var c = 0; c < showCount; c++)
      for (var e = 1; e <= episodesPerShow; e++)
        ChannelSerie(
          name: 'Show $c S01E0$e',
          seriesId: 'p$c-e$e',
          categoryId: 'p$c',
          cover: 'https://example.test/posters/p$c.png',
          directSource: 'https://example.test/stream/p$c/e$e.m3u8',
        ),
  ];

  Future<CatalogStore> ingested() async {
    final store = CatalogStore(CatalogMemoryExecutor());
    final dir = await Directory.systemTemp.createTemp('tvparser_shows_only');
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });
    final path = '${dir.path}/series.json';
    await File(path).writeAsString(
      jsonEncode([for (final row in episodes) row.toJson()]),
    );
    final count = await CatalogIngest.ingestFile(
      store: store,
      kind: CatalogKind.series,
      path: path,
      batchSize: 50,
    );
    expect(count, episodes.length);
    return store;
  }

  test('store answers nothing before the series kind is committed', () async {
    final store = CatalogStore(CatalogMemoryExecutor());
    expect(await store.seriesCategoryHeads(), isEmpty);
    expect(await store.seriesCountsByCategory(), isEmpty);
    expect(await store.seriesForCategory('p0'), isEmpty);
    expect(await store.seriesByItemId('p0-e1'), isNull);
    expect(
      await store.seriesByDirectSource(
        'https://example.test/stream/p0/e1.m3u8',
      ),
      isNull,
    );
  });

  test('one head per show, in catalog order, with episode counts', () async {
    final store = await ingested();

    final heads = await store.seriesCategoryHeads();
    expect(heads, hasLength(showCount));
    for (var c = 0; c < showCount; c++) {
      expect(heads[c].categoryId, 'p$c');
      expect(heads[c].seriesId, 'p$c-e1');
    }

    final counts = await store.seriesCountsByCategory();
    expect(counts, hasLength(showCount));
    expect(counts.values.every((n) => n == episodesPerShow), isTrue);
  });

  test('a show\'s episodes and single rows are read on demand', () async {
    final store = await ingested();

    final show7 = await store.seriesForCategory('p7');
    expect(
      [for (final e in show7) e.seriesId],
      [for (var e = 1; e <= episodesPerShow; e++) 'p7-e$e'],
    );
    expect(await store.seriesForCategory('missing'), isEmpty);
    expect(await store.seriesForCategory(''), isEmpty);

    final byId = await store.seriesByItemId('p12-e4');
    expect(byId?.name, 'Show 12 S01E04');
    expect(await store.seriesByItemId('nope'), isNull);

    final byUrl = await store.seriesByDirectSource(
      'https://example.test/stream/p3/e5.m3u8',
    );
    expect(byUrl?.seriesId, 'p3-e5');
    // A prefix of a stored address must not match a different row.
    expect(
      await store.seriesByDirectSource('https://example.test/stream/p3/e'),
      isNull,
    );
  });

  test('shelves built from heads match shelves built from every episode',
      () async {
    final store = await ingested();
    final heads = await store.seriesCategoryHeads();
    final counts = await store.seriesCountsByCategory();

    SeriesRailsResult build(
      List<ChannelSerie> series,
      Map<String, int> episodeCounts,
    ) {
      return buildSeriesRailsInBackground(
        SeriesRailsJob(
          series: series,
          categories: cats,
          fallbackCategories: const [],
          profile: UserPreferenceProfile(),
          watchById: const {},
          headCount: 40,
          headLimit: 40,
          episodeCounts: episodeCounts,
        ),
      );
    }

    final full = build(episodes, const {});
    final lazy = build(heads, counts);

    expect(lazy.perShow, isTrue);
    expect(lazy.showCount, full.showCount);
    expect(lazy.rows.length, full.rows.length);

    final fullCards = [for (final r in full.rows) ...r.streams];
    final lazyCards = [for (final r in lazy.rows) ...r.streams];
    expect(lazyCards.length, fullCards.length);
    expect(lazyCards.length, showCount);

    for (var i = 0; i < lazyCards.length; i++) {
      final a = fullCards[i];
      final b = lazyCards[i];
      // Same show card, minus the episode list it used to carry.
      expect(b.title, a.title);
      expect(b.year, a.year);
      expect(b.streamId, a.streamId);
      expect(b.streamUrl, a.streamUrl);
      expect(b.imageUrl, a.imageUrl);
      expect(b.enrichmentKey, a.enrichmentKey);
      expect(b.providerCategoryId, a.providerCategoryId);
      expect(b.season, isNull);
      expect(b.episode, isNull);
      expect(b.badge, isNull);
      expect(a.groupedEpisodes, hasLength(episodesPerShow));
      expect(b.groupedEpisodes, isEmpty);
      expect(b.lazyEpisodeCount, episodesPerShow);
      expect(b.hasEpisodeList, isTrue);
      expect(b.needsEpisodeFetch, isTrue);
      expect(a.needsEpisodeFetch, isFalse);
    }
  });

  test('a fetched show rebuilds the same episode list the card carried',
      () async {
    final store = await ingested();
    final fetched = await store.seriesForCategory('p5');

    TvStreamRecord cardFrom(List<ChannelSerie> list) {
      return SeriesRailGrouper.showCard(
        [
          for (final ch in list)
            seriesStreamRecordFor(
              ch,
              'Show 5 (2026)',
              providerCategoryId: 'p5',
              providerCategoryName: 'Show 5 (2026)',
            ),
        ],
        title: 'Show 5',
        year: 2026,
      );
    }

    final before = cardFrom([
      for (final e in episodes)
        if (e.categoryId == 'p5') e,
    ]);
    final after = cardFrom(fetched);
    expect(after.groupedEpisodes, hasLength(episodesPerShow));
    expect(
      [for (final e in after.groupedEpisodes) e.streamUrl],
      [for (final e in before.groupedEpisodes) e.streamUrl],
    );
    expect(after.needsEpisodeFetch, isFalse);
  });

  test('a single-episode show stays an ordinary card', () {
    final card = SeriesRailGrouper.showCard(
      [
        seriesStreamRecordFor(
          ChannelSerie(name: 'Solo S01E01', seriesId: 'solo-1'),
          'Solo (2026)',
        ),
      ],
      title: 'Solo',
      year: 2026,
      lazyEpisodeCount: 1,
    );
    expect(card.lazyEpisodeCount, 0);
    expect(card.needsEpisodeFetch, isFalse);
    expect(card.hasEpisodeList, isFalse);
  });
}

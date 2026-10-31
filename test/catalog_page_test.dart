import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/catalog/catalog_flags.dart';
import 'package:mbark_iptv/repository/catalog/catalog_ingest.dart';
import 'package:mbark_iptv/repository/catalog/catalog_kind.dart';
import 'package:mbark_iptv/repository/catalog/catalog_store.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';

import 'catalog_memory_executor.dart';

void main() {
  test('paged query matches the first row of the old list', () async {
    expect(CatalogDbFlags.readsEnabled, isFalse);

    final oldSeries = [
      ChannelSerie(
        name: 'North Documentary',
        seriesId: 's1',
        categoryId: 'cat-a',
        cover: 'https://example.test/posters/north.png',
        plot: 'See {note} and "quotes"',
        directSource: 'https://example.test/north/1',
      ),
      ChannelSerie(
        name: 'North Documentary Notes',
        seriesId: 's2',
        categoryId: 'cat-a',
        cover: 'https://example.test/posters/north.png',
        directSource: 'https://example.test/north/2',
      ),
      ChannelSerie(
        name: 'Harbor Stories',
        seriesId: 's3',
        categoryId: 'cat-b',
        cover: 'https://example.test/posters/harbor.png',
      ),
    ];
    final oldMovies = [
      ChannelMovie(
        name: 'Café Reel',
        streamId: 'm1',
        categoryId: 'movies',
        streamIcon: 'https://example.test/posters/cafe.png',
      ),
      ChannelMovie(
        name: 'Harbor Departure',
        streamId: 'm2',
        categoryId: 'movies',
      ),
    ];
    final oldLive = [
      const ChannelLive(
        name: 'Desk Camera',
        streamId: 'l1',
        categoryId: 'rooms',
        directSource: 'https://example.test/live/desk',
      ),
      const ChannelLive(
        name: 'Hall Camera',
        streamId: 'l2',
        categoryId: 'rooms',
      ),
    ];

    final executor = CatalogMemoryExecutor();
    final store = CatalogStore(executor);
    final dir = await Directory.systemTemp.createTemp('tvparser_catalog_test');
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    Future<void> writeJson(String name, List<Map<String, dynamic>> rows) {
      return File('${dir.path}/$name').writeAsString(jsonEncode(rows));
    }

    await writeJson('series.json', [for (final row in oldSeries) row.toJson()]);
    await CatalogIngest.ingestFile(
      store: store,
      kind: CatalogKind.series,
      path: '${dir.path}/series.json',
      batchSize: 2,
    );
    expect(executor.batchSizes, [2, 1]);

    final first = await store.pageSeries(limit: 1, offset: 0);
    expect(first, hasLength(1));
    expect(first.single.name, oldSeries.first.name);
    expect(first.single.seriesId, oldSeries.first.seriesId);
    expect(first.single.categoryId, oldSeries.first.categoryId);
    expect(first.single.cover, oldSeries.first.cover);
    expect(first.single.plot, oldSeries.first.plot);
    expect(first.single.directSource, oldSeries.first.directSource);

    final second = await store.pageSeries(limit: 1, offset: 1);
    expect(second.single.name, oldSeries[1].name);
    expect(second.single.seriesId, oldSeries[1].seriesId);

    final inCategory = oldSeries.where((row) => row.categoryId == 'cat-b');
    final categoryPage = await store.pageSeries(
      limit: 1,
      offset: 0,
      categoryId: 'cat-b',
    );
    expect(categoryPage.single.name, inCategory.first.name);
    expect(categoryPage.single.seriesId, inCategory.first.seriesId);

    executor.batchSizes.clear();
    await writeJson('movies.json', [for (final row in oldMovies) row.toJson()]);
    await CatalogIngest.ingestFile(
      store: store,
      kind: CatalogKind.movie,
      path: '${dir.path}/movies.json',
      batchSize: 2,
    );
    final moviePage = await store.pageMovies(limit: 1, offset: 0);
    expect(moviePage.single.name, oldMovies.first.name);
    expect(moviePage.single.streamId, oldMovies.first.streamId);

    executor.batchSizes.clear();
    await writeJson('live.json', [for (final row in oldLive) row.toJson()]);
    await CatalogIngest.ingestFile(
      store: store,
      kind: CatalogKind.live,
      path: '${dir.path}/live.json',
      batchSize: 2,
    );
    final livePage = await store.pageLive(limit: 1, offset: 0);
    expect(livePage.single.name, oldLive.first.name);
    expect(livePage.single.streamId, oldLive.first.streamId);
    expect(livePage.single.directSource, oldLive.first.directSource);

    final seriesStillFirst = await store.pageSeries(limit: 1, offset: 0);
    expect(seriesStillFirst.single.seriesId, oldSeries.first.seriesId);
  });
}

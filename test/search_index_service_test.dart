import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/repository/api/search_index_service.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'tv_parser_search_index_tests_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => storageDirectory.path,
    );
    await GetStorage.init('preferences');
  });

  tearDownAll(() {
    try {
      if (storageDirectory.existsSync()) {
        storageDirectory.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // Windows may still hold GetStorage's file handle.
    }
  });

  setUp(SearchIndexService.clearIndex);

  tearDown(SearchIndexService.clearIndex);

  ChannelLive live(String name, {String id = '1'}) => ChannelLive(
        name: name,
        streamId: id,
        directSource: 'http://example.test/$id',
      );

  ChannelMovie movie(String name, {String id = 'm1'}) => ChannelMovie(
        name: name,
        streamId: id,
      );

  ChannelSerie series(String name, {String id = 's1'}) => ChannelSerie(
        name: name,
        seriesId: id,
      );

  List<SearchIndexEntry> hits(String query) => SearchIndexService.search(query);

  test('1. indexLive adds Live entries', () async {
    await SearchIndexService.indexLive(
      liveChannels: [live('Atlanta News', id: 'atl')],
    );
    expect(SearchIndexService.liveIndexReady, isTrue);
    expect(SearchIndexService.isReady, isTrue);
    final found = hits('Atlanta');
    expect(found, isNotEmpty);
    expect(found.every((e) => e.type == 'live'), isTrue);
    expect((found.first.item as ChannelLive).streamId, 'atl');
  });

  test('2. indexLive does not delete Movie entries', () async {
    await SearchIndexService.indexMovies(
      movies: [movie('Inception', id: 'mov')],
    );
    await SearchIndexService.indexLive(
      liveChannels: [live('Atlanta News')],
    );
    expect(SearchIndexService.moviesIndexReady, isTrue);
    final movies = hits('Inception');
    expect(movies, isNotEmpty);
    expect(movies.first.type, 'movie');
    expect((movies.first.item as ChannelMovie).streamId, 'mov');
  });

  test('3. indexLive does not delete Series entries', () async {
    await SearchIndexService.indexSeries(
      series: [series('Atlanta FX', id: 'ser')],
    );
    await SearchIndexService.indexLive(
      liveChannels: [live('WSB Atlanta')],
    );
    expect(SearchIndexService.seriesIndexReady, isTrue);
    final seriesHits = hits('FX');
    expect(seriesHits.any((e) => e.type == 'series'), isTrue);
    expect(
      seriesHits
          .where((e) => e.type == 'series')
          .map((e) => (e.item as ChannelSerie).seriesId),
      contains('ser'),
    );
  });

  test('4. indexMovies does not delete Live', () async {
    await SearchIndexService.indexLive(
      liveChannels: [live('Atlanta News', id: 'atl')],
    );
    await SearchIndexService.indexMovies(
      movies: [movie('Inception')],
    );
    final found = hits('Atlanta');
    expect(found.any((e) => e.type == 'live'), isTrue);
    expect(SearchIndexService.liveIndexReady, isTrue);
  });

  test('5. indexSeries does not delete Live', () async {
    await SearchIndexService.indexLive(
      liveChannels: [live('Atlanta News', id: 'atl')],
    );
    await SearchIndexService.indexSeries(
      series: [series('The Bear')],
    );
    final found = hits('Atlanta');
    expect(found.any((e) => e.type == 'live'), isTrue);
    expect(SearchIndexService.liveIndexReady, isTrue);
  });

  test('6. Live-only index can search Atlanta', () async {
    await SearchIndexService.indexLive(
      liveChannels: [
        live('Atlanta News First', id: 'anf'),
        live('CBS Sports'),
      ],
    );
    expect(SearchIndexService.seriesIndexReady, isFalse);
    expect(SearchIndexService.moviesIndexReady, isFalse);
    final found = hits('Atlanta');
    expect(found, isNotEmpty);
    expect(found.first.type, 'live');
    expect(
      (found.first.item as ChannelLive).name,
      contains('Atlanta'),
    );
  });

  test('7. partial index search works while seriesIndexReady is false', () async {
    await SearchIndexService.indexLive(
      liveChannels: [live('Atlanta News', id: 'atl')],
    );
    await SearchIndexService.indexMovies(
      movies: [movie('Atlanta Dream', id: 'dream')],
    );
    expect(SearchIndexService.seriesIndexReady, isFalse);
    final found = hits('Atlanta');
    expect(found.length, greaterThanOrEqualTo(2));
    expect(found.any((e) => e.type == 'live'), isTrue);
    expect(found.any((e) => e.type == 'movie'), isTrue);
    expect(found.any((e) => e.type == 'series'), isFalse);
  });

  test('8. duplicate domain indexing replaces that domain', () async {
    await SearchIndexService.indexLive(
      liveChannels: [
        live('Atlanta News', id: 'a1'),
        live('CBS Atlanta', id: 'a2'),
      ],
    );
    await SearchIndexService.indexMovies(
      movies: [movie('Inception', id: 'keep')],
    );

    await SearchIndexService.indexLive(
      liveChannels: [live('Atlanta News', id: 'a1')],
    );

    final atlanta = hits('Atlanta');
    final liveHits = atlanta.where((e) => e.type == 'live').toList();
    expect(liveHits.length, 1);
    expect((liveHits.first.item as ChannelLive).streamId, 'a1');
    expect(hits('CBS').where((e) => e.type == 'live'), isEmpty);
    expect(hits('Inception').any((e) => e.type == 'movie'), isTrue);
  });
}

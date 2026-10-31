import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/presentation/tv/series_rails_isolate.dart';
import 'package:mbark_iptv/repository/api/search_index_service.dart';
import 'package:mbark_iptv/repository/models/category.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';
import 'package:mbark_iptv/repository/models/user_preference_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'tv_parser_series_rails_tests_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => storageDirectory.path,
    );
    await GetStorage.init('preferences');
  });

  const catCount = 50;
  final cats = [
    for (var c = 0; c < catCount; c++)
      CategoryModel(categoryId: 'c$c', categoryName: 'Category $c'),
  ];
  final series = [
    for (var i = 0; i < 100000; i++)
      ChannelSerie(
        name: 'Show ${i ~/ 10} S01E0${i % 10}',
        seriesId: 's$i',
        categoryId: 'c${i % catCount}',
      ),
  ];

  test('series rails build in a worker isolate for 100k items', () async {
    final sw = Stopwatch()..start();
    final result = await compute(
      buildSeriesRailsInBackground,
      SeriesRailsJob(
        series: series,
        categories: cats,
        fallbackCategories: const [],
        profile: UserPreferenceProfile(),
        watchById: const {},
        headCount: 40,
        headLimit: 40,
      ),
    );
    debugPrint('series rails 100k built in ${sw.elapsedMilliseconds} ms');
    expect(result.perShow, isFalse);
    expect(result.rows.length, catCount);
    expect(result.heads.length, 40);
    expect(result.unassigned, 0);
    expect(result.rows.first.streams, isNotEmpty);
  });

  test('searchAsync matches sync search on a large index', () async {
    await SearchIndexService.indexSeries(series: series);
    final sync = SearchIndexService.search('Show 123');
    final async = await SearchIndexService.searchAsync('Show 123');
    expect(async, isNotNull);
    expect(async!.length, sync.length);
    expect(async.first.item, same(sync.first.item));
    expect(
      await SearchIndexService.searchAsync('Show 1', isStale: () => true),
      isNull,
    );
  });
}

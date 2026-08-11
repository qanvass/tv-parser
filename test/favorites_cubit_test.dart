import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/logic/cubits/favorites/favorites_cubit.dart';
import 'package:mbark_iptv/repository/api/api.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';

class _MemoryFavoriteLocale extends FavoriteLocale {
  List<ChannelLive> lives = [];
  List<ChannelMovie> movies = [];
  List<ChannelSerie> series = [];

  @override
  Future<bool> saveFavoriteLives(List<ChannelLive> items) async {
    lives = List.of(items);
    return true;
  }

  @override
  Future<bool> saveFavoriteMovie(List<ChannelMovie> items) async {
    movies = List.of(items);
    return true;
  }

  @override
  Future<bool> saveFavoriteSerie(List<ChannelSerie> items) async {
    series = List.of(items);
    return true;
  }

  @override
  Future<List<ChannelLive>> getFavLives() async => List.of(lives);

  @override
  Future<List<ChannelMovie>> getFavMovies() async => List.of(movies);

  @override
  Future<List<ChannelSerie>> getFavSeries() async => List.of(series);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'tv_parser_favorites_cubit_tests_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => storageDirectory.path,
    );
    await GetStorage.init();
    await GetStorage.init('favorites');
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

  ChannelLive live(String id, {String name = 'Live'}) => ChannelLive(
        name: name,
        streamId: id,
        directSource: 'http://example.test/live/$id',
      );

  ChannelMovie movie(String id, {String name = 'Movie'}) => ChannelMovie(
        name: name,
        streamId: id,
      );

  ChannelSerie serie(String id, {String name = 'Series'}) => ChannelSerie(
        name: name,
        seriesId: id,
      );

  test('addLive persists and skips duplicate streamId', () async {
    final locale = _MemoryFavoriteLocale();
    final cubit = FavoritesCubit(locale);

    await cubit.addLive(live('101', name: 'One'), isAdd: true);
    await cubit.addLive(live('101', name: 'One again'), isAdd: true);
    await cubit.addLive(live('102', name: 'Two'), isAdd: true);

    expect(cubit.state.lives.map((e) => e.streamId), ['102', '101']);
    expect(locale.lives.map((e) => e.streamId), ['102', '101']);
    expect(cubit.state.lives.where((e) => e.streamId == '101').length, 1);
  });

  test('addMovie and addSerie persist and skip duplicate ids', () async {
    final locale = _MemoryFavoriteLocale();
    final cubit = FavoritesCubit(locale);

    await cubit.addMovie(movie('m1'), isAdd: true);
    await cubit.addMovie(movie('m1'), isAdd: true);
    await cubit.addSerie(serie('s1'), isAdd: true);
    await cubit.addSerie(serie('s1'), isAdd: true);

    expect(cubit.state.movies.map((e) => e.streamId), ['m1']);
    expect(cubit.state.series.map((e) => e.seriesId), ['s1']);
    expect(locale.movies.map((e) => e.streamId), ['m1']);
    expect(locale.series.map((e) => e.seriesId), ['s1']);
  });

  test('remove persists and initialData reloads saved lists', () async {
    final locale = _MemoryFavoriteLocale();
    final cubit = FavoritesCubit(locale);

    await cubit.addLive(live('101'), isAdd: true);
    await cubit.addMovie(movie('m1'), isAdd: true);
    await cubit.addSerie(serie('s1'), isAdd: true);
    await cubit.addLive(live('101'), isAdd: false);
    await cubit.addMovie(movie('m1'), isAdd: false);
    await cubit.addSerie(serie('s1'), isAdd: false);

    expect(cubit.state.lives, isEmpty);
    expect(cubit.state.movies, isEmpty);
    expect(cubit.state.series, isEmpty);
    expect(locale.lives, isEmpty);
    expect(locale.movies, isEmpty);
    expect(locale.series, isEmpty);

    locale.lives = [live('202')];
    locale.movies = [movie('m2')];
    locale.series = [serie('s2')];
    await cubit.initialData();

    expect(cubit.state.lives.single.streamId, '202');
    expect(cubit.state.movies.single.streamId, 'm2');
    expect(cubit.state.series.single.seriesId, 's2');
  });
}

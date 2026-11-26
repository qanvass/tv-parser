import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/logic/blocs/auth/auth_bloc.dart';
import 'package:mbark_iptv/logic/cubits/favorites/favorites_cubit.dart';
import 'package:mbark_iptv/logic/cubits/watch/watching_cubit.dart';
import 'package:mbark_iptv/presentation/screens/screens.dart';
import 'package:mbark_iptv/repository/api/api.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';
import 'package:mbark_iptv/repository/models/user.dart';
import 'package:mbark_iptv/repository/models/watching.dart';

class _MemoryFavoriteLocale extends FavoriteLocale {
  List<ChannelLive> lives = [];
  List<ChannelMovie> movies = [];
  List<ChannelSerie> series = [];

  @override
  Future<bool> saveFavoriteLives(List<ChannelLive> items) async => true;

  @override
  Future<bool> saveFavoriteMovie(List<ChannelMovie> items) async => true;

  @override
  Future<bool> saveFavoriteSerie(List<ChannelSerie> items) async => true;

  @override
  Future<List<ChannelLive>> getFavLives() async => List.of(lives);

  @override
  Future<List<ChannelMovie>> getFavMovies() async => List.of(movies);

  @override
  Future<List<ChannelSerie>> getFavSeries() async => List.of(series);
}

class _MemoryWatchingLocale extends WatchingLocale {
  List<WatchingModel> movies = [];

  @override
  Future<List<WatchingModel>> getWatchingMovies() async => List.of(movies);

  @override
  Future<List<WatchingModel>> getWatchingSeries() async => const [];

  @override
  Future<List<WatchingModel>> getWatchingLives() async => const [];
}

class _SignedInAuthBloc extends AuthBloc {
  _SignedInAuthBloc() : super(AuthApi()) {
    emit(AuthSuccess(UserModel.fromJson(const {}, 'https://example.test')));
  }
}

/// The Favourites screen at TV, tablet and phone sizes. A RenderFlex overflow
/// or any build error fails these tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'tv_parser_favourites_screen_tests_',
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Size logicalSize,
    int lives = 19,
    int movies = 0,
    int series = 2,
    int watching = 0,
  }) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = logicalSize * 2;
    addTearDown(tester.view.reset);

    final favLocale = _MemoryFavoriteLocale()
      ..lives = [
        for (var i = 0; i < lives; i++)
          ChannelLive(
            name: i.isEven
                ? 'Example Sports Network Regional Feed $i'
                : 'News $i',
            streamId: 'l$i',
            directSource: 'https://example.test/live/$i.m3u8',
          ),
      ]
      ..movies = [
        for (var i = 0; i < movies; i++)
          ChannelMovie(name: 'Sample Movie $i (2024)', streamId: 'm$i'),
      ]
      ..series = [
        for (var i = 0; i < series; i++)
          ChannelSerie(name: 'Sample Show $i S01E01', seriesId: 's$i'),
      ];
    final watchLocale = _MemoryWatchingLocale()
      ..movies = [
        for (var i = 0; i < watching; i++)
          WatchingModel(
            streamId: 'w$i',
            image: '',
            title: 'Unfinished Movie $i',
            stream: 'https://example.test/vod/$i.mp4',
            sliderValue: 600,
            durationStrm: 3600,
          ),
      ];

    final favorites = FavoritesCubit(favLocale);
    final watchingCubit = WatchingCubit(watchLocale);
    final auth = _SignedInAuthBloc();
    addTearDown(favorites.close);
    addTearDown(watchingCubit.close);
    addTearDown(auth.close);

    await tester.runAsync(() async {
      await favorites.initialData();
      watchingCubit.initialData();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<FavoritesCubit>.value(value: favorites),
          BlocProvider<WatchingCubit>.value(value: watchingCubit),
        ],
        child: const GetMaterialApp(home: FavouriteScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('TV layout shows every section with wired counts', (
    tester,
  ) async {
    await pumpScreen(tester, logicalSize: const Size(960, 540));

    expect(find.text('My Favourites'), findsOneWidget);
    expect(find.text('Your saved channels in one place'), findsOneWidget);
    expect(find.text('SECTIONS'), findsOneWidget);
    expect(find.text('Live TV (19)'), findsOneWidget);
    expect(find.text('Movies (0)'), findsOneWidget);
    expect(find.text('Series (2)'), findsOneWidget);
    expect(find.text('All Channels'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('19 Channels'), findsOneWidget);
    // Top bar.
    for (final label in ['Search', 'Movies', 'Series', 'Favourites', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('TV Parser'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    // First rows of the 4-column grid are built, each with a LIVE chip.
    expect(find.text('LIVE'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D-pad moves through sidebar, grid, view toggle and top bar', (
    tester,
  ) async {
    await pumpScreen(tester, logicalSize: const Size(960, 540), watching: 3);

    // Sidebar: down to Movies (empty), Series, All.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('0 Movies'), findsOneWidget);
    expect(find.text('No favourite movies yet'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('2 Series'), findsOneWidget);
    expect(find.text('SERIES'), findsWidgets);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('21 Items'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('3 Titles'), findsOneWidget);
    expect(find.text('RESUME'), findsWidgets);
    expect(find.text('Pick up where you left off'), findsOneWidget);

    // Back up to Live, into the grid, around it, and up to the view toggle.
    for (var i = 0; i < 5; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(find.text('19 Channels'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 6; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    // Now on the grid/list toggle: choose list.
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('LIVE'), findsWidgets);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    // Back to grid, then up to the top bar and along it.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 6; i++) {
      await press(tester, LogicalKeyboardKey.arrowLeft);
    }
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('My Favourites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty favourites show the empty state, not a blank grid', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      logicalSize: const Size(960, 540),
      lives: 0,
      series: 0,
    );
    expect(find.text('Live TV (0)'), findsOneWidget);
    expect(find.text('0 Channels'), findsOneWidget);
    expect(find.text('No favourite channels yet'), findsOneWidget);
    // Right from the sidebar must not move focus into an empty grid.
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet width does not overflow the top bar', (tester) async {
    await pumpScreen(tester, logicalSize: const Size(720, 480));
    expect(find.text('My Favourites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone keeps the tabbed layout', (tester) async {
    await pumpScreen(tester, logicalSize: const Size(390, 800), movies: 4);
    expect(find.text('Live TV (19)'), findsOneWidget);
    expect(find.text('Movies (4)'), findsOneWidget);
    expect(find.text('Series (2)'), findsOneWidget);
    expect(find.text('SECTIONS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

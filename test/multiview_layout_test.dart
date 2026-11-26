import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/presentation/tv/multiview/multiview_screen.dart';
import 'package:mbark_iptv/presentation/tv/multiview/multiview_store.dart';
import 'package:mbark_iptv/repository/api/api.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'tv_parser_multiview_tests_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => storageDirectory.path,
        );
    await GetStorage.init();
    await GetStorage.init('preferences');
    GetStorage();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  setUp(() {
    GetStorage('preferences').write(MultiviewStore.storageKey, ['', '', '', '']);
    GetStorage('preferences').remove(MultiviewStore.layoutKey);
  });

  test('missing or unknown layout stays on two panes', () {
    expect(MultiviewStore.layoutFromRaw(null), 2);
    expect(MultiviewStore.layoutFromRaw(''), 2);
    expect(MultiviewStore.layoutFromRaw(3), 2);
    expect(MultiviewStore.layoutFromRaw('2'), 2);
  });

  test('only an explicit 4 selects the four-pane grid', () {
    expect(MultiviewStore.layoutFromRaw(4), 4);
    expect(MultiviewStore.layoutFromRaw('4'), 4);
  });

  testWidgets('two-pane screen shows two empty panes and the category strip', (
    tester,
  ) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 2);
    await tester.pumpWidget(const MaterialApp(home: MultiviewScreen()));
    await tester.pump();

    expect(find.text('2 screens'), findsOneWidget);
    expect(find.text('4 screens'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Favs'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    // Each empty pane shows one prompt. The info bar stays off until a channel is chosen.
    expect(find.text('Add a channel'), findsNWidgets(2));
  });

  testWidgets('four-pane screen builds four empty panes and no players', (
    tester,
  ) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 4);
    await tester.pumpWidget(const MaterialApp(home: MultiviewScreen()));
    await tester.pump();

    expect(find.text('Add a channel'), findsNWidgets(4));
  });

  testWidgets('down from the panes reaches 2 screens and then Movies', (
    tester,
  ) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 2);
    await tester.pumpWidget(const MaterialApp(home: MultiviewScreen()));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile1');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewLayout2');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewLayout4');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewCategory0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewLayout4');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewCategory0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewCategory1');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile1');
  });

  testWidgets('choosing 4 screens builds four empty panes and remembers it', (
    tester,
  ) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 2);
    await tester.pumpWidget(const MaterialApp(home: MultiviewScreen()));
    await tester.pump();
    expect(find.text('Add a channel'), findsNWidgets(2));

    await tester.tap(find.text('4 screens'));
    await tester.pump();
    expect(find.text('Add a channel'), findsNWidgets(4));
    expect(MultiviewStore.readLayout(), 4);

    await tester.tap(find.text('2 screens'));
    await tester.pump();
    expect(find.text('Add a channel'), findsNWidgets(2));
    expect(MultiviewStore.readLayout(), 2);
  });

  testWidgets('choosing Movies returns movies', (tester) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 2);
    String? result;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await Get.to<String>(
                  () => const MultiviewScreen(),
                  transition: Transition.noTransition,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Movies'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('2 screens'), findsNothing);
    expect(result, 'movies');
  });

  testWidgets('Back closes multiview without choosing a category', (
    tester,
  ) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 2);
    Object? result = 'pending';
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await Get.to<String>(
                  () => const MultiviewScreen(),
                  transition: Transition.noTransition,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile0');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('2 screens'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('down from the four-pane grid reaches 4 screens', (tester) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 4);
    await tester.pumpWidget(const MaterialApp(home: MultiviewScreen()));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile2');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewLayout4');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewCategory0');
  });

  testWidgets('the other strip buttons return their category ids', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cases = {
      'Series': 'series',
      'Search': 'search',
      'Favs': 'favorites',
      'History': 'history',
    };
    for (final entry in cases.entries) {
      String? result;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await Get.to<String>(
                    () => const MultiviewScreen(),
                    transition: Transition.noTransition,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(entry.key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result, entry.value, reason: entry.key);
      expect(find.text('2 screens'), findsNothing);
    }
  });

  testWidgets('OK on an empty pane opens the channel list on Favorites', (
    tester,
  ) async {
    GetStorage('preferences').write(MultiviewStore.layoutKey, 2);
    await tester.pumpWidget(const MaterialApp(home: MultiviewScreen()));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile0');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();

    expect(find.text('Choose a channel'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Filter favorites'), findsOneWidget);
  });

  testWidgets(
    'OK on the other pane moves audio, and the next OK opens the list',
    (tester) async {
      await locale.write('m3u_channels', [
        const ChannelLive(streamId: 'left', name: 'Left Channel').toJson(),
        const ChannelLive(streamId: 'right', name: 'Right Channel').toJson(),
      ]);
      addTearDown(() async {
        await locale.remove('m3u_channels');
      });
      expect(
        LocaleApi.getM3uChannels().map((channel) => channel.name).toList(),
        ['Left Channel', 'Right Channel'],
      );
      GetStorage('preferences').write(MultiviewStore.layoutKey, 2);
      GetStorage('preferences').write(
        MultiviewStore.storageKey,
        ['left', 'right', '', ''],
      );

      await tester.pumpWidget(const MaterialApp(home: MultiviewScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.textContaining('Left Channel'), findsOneWidget);
      expect(find.text('Choose a channel'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'MultiviewTile1');
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(find.text('Choose a channel'), findsNothing);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.textContaining('Right Channel'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump();
      expect(find.text('Choose a channel'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
    },
  );
}

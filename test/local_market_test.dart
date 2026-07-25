import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';
import 'package:mbark_iptv/repository/models/local_market_profile.dart';
import 'package:mbark_iptv/repository/api/local_market_service.dart';
import 'package:mbark_iptv/repository/api/location_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'tv_parser_market_tests_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return storageDirectory.path;
          },
        );
    await GetStorage.init("preferences");
  });

  tearDownAll(() async {
    if (storageDirectory.existsSync()) {
      storageDirectory.deleteSync(recursive: true);
    }
  });

  tearDown(() async {
    final box = GetStorage("preferences");
    await box.erase();
    await LocalMarketService.resetActiveMarket();
  });

  group('LocalMarketService & Registry Tests', () {
    test('Verify total registry includes at least 30 markets', () {
      expect(
        LocalMarketService.supportedMarkets.length,
        greaterThanOrEqualTo(30),
      );
    });

    test('Verify findClosestMarket returns correct DMA', () {
      // Atlanta GA: lat 33.7490, lon -84.3880
      final marketAtlanta = LocalMarketService.findClosestMarket(33.7, -84.4);
      expect(marketAtlanta, isNotNull);
      expect(marketAtlanta!.id, equals("atlanta_ga"));

      // Los Angeles CA: lat 34.0522, lon -118.2437
      final marketLA = LocalMarketService.findClosestMarket(34.1, -118.3);
      expect(marketLA, isNotNull);
      expect(marketLA!.id, equals("los_angeles_ca"));

      // Seattle WA: lat 47.6062, lon -122.3321
      final marketSeattle = LocalMarketService.findClosestMarket(47.6, -122.3);
      expect(marketSeattle, isNotNull);
      expect(marketSeattle!.id, equals("seattle_wa"));

      // Denver CO: lat 39.7392, lon -104.9903
      final marketDenver = LocalMarketService.findClosestMarket(39.7, -105.0);
      expect(marketDenver, isNotNull);
      expect(marketDenver!.id, equals("denver_co"));
    });

    test('Verify findClosestMarket returns null when too far', () {
      // Somewhere in Atlantic ocean
      final ocean = LocalMarketService.findClosestMarket(20.0, -40.0);
      expect(ocean, isNull);
    });

    test('Verify getNearbyMarkets returns adjacent DMAs', () {
      final nearby = LocalMarketService.getNearbyMarkets("atlanta_ga");
      expect(nearby, isNotEmpty);
      expect(nearby.any((m) => m.id == "birmingham_al"), isTrue);
    });

    test('Verify searchMarkets returns matching query entries', () {
      final results = LocalMarketService.searchMarkets("Dallas");
      expect(results, isNotEmpty);
      expect(results.first.id, equals("dallas_fort_worth_tx"));
    });

    test('Verify cache and override methods', () async {
      await LocalMarketService.setActiveMarket("houston_tx");
      final active = LocalMarketService.getActiveMarket();
      expect(active, isNotNull);
      expect(active!.id, equals("houston_tx"));
    });
  });

  group('Local Channel Matching Tests', () {
    final mockPlaylist = [
      ChannelLive(num: "1", name: "WSB-TV ABC Atlanta", categoryId: "US Local"),
      ChannelLive(num: "2", name: "WAGA FOX 5", categoryId: "US Local"),
      ChannelLive(
        num: "3",
        name: "11Alive NBC Atlanta",
        categoryId: "US Local",
      ),
      ChannelLive(num: "4", name: "GPB PBS Atlanta", categoryId: "US Local"),
      ChannelLive(num: "5", name: "WFAA ABC Dallas", categoryId: "US Local"),
      ChannelLive(num: "6", name: "ESPN HD", categoryId: "Sports"),
      ChannelLive(
        num: "7",
        name: "Univision Atlanta WUVG",
        categoryId: "Spanish",
      ),
    ];

    test('Curation matches correct channels for Atlanta', () {
      final atlantaMarket = LocalMarketService.findMarketById("atlanta_ga");
      expect(atlantaMarket, isNotNull);

      // Category "broadcast"
      final broadcasts = LocalMarketService.getLocalChannelsForCategory(
        categoryKey: 'broadcast',
        market: atlantaMarket!,
        playlist: mockPlaylist,
      );
      expect(broadcasts.length, equals(5)); // WSB-TV, WAGA, 11Alive, GPB, WUVG
      expect(broadcasts.any((c) => c.name!.contains("WSB")), isTrue);
      expect(broadcasts.any((c) => c.name!.contains("WFAA")), isFalse);

      // Category "news"
      final news = LocalMarketService.getLocalChannelsForCategory(
        categoryKey: 'news',
        market: atlantaMarket,
        playlist: mockPlaylist,
      );
      expect(news.any((c) => c.name!.contains("11Alive")), isTrue);

      // Category "spanish"
      final spanish = LocalMarketService.getLocalChannelsForCategory(
        categoryKey: 'spanish',
        market: atlantaMarket,
        playlist: mockPlaylist,
      );
      expect(spanish.length, equals(1));
      expect(spanish.first.name, contains("WUVG"));
    });

    test('Curation matches correct channels for Dallas', () {
      final dallasMarket = LocalMarketService.findMarketById(
        "dallas_fort_worth_tx",
      );
      expect(dallasMarket, isNotNull);

      final broadcasts = LocalMarketService.getLocalChannelsForCategory(
        categoryKey: 'broadcast',
        market: dallasMarket!,
        playlist: mockPlaylist,
      );
      expect(broadcasts.length, equals(1));
      expect(broadcasts.first.name, contains("WFAA"));
    });
  });
}

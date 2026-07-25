import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';
import 'package:mbark_iptv/repository/models/channel_movie.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';
import 'package:mbark_iptv/repository/models/spotlight_event.dart';
import 'package:mbark_iptv/repository/models/user_preference_profile.dart';
import 'package:mbark_iptv/repository/api/channel_match_service.dart';
import 'package:mbark_iptv/repository/api/ai_intent_mapper.dart';
import 'package:mbark_iptv/repository/api/search_index_service.dart';
import 'package:mbark_iptv/repository/api/location_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;

  // Setup mock storage for GetStorage
  setUpAll(() async {
    storageDirectory = Directory.systemTemp.createTempSync(
      'tv_parser_location_tests_',
    );
    // Mock the path provider method channel
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
  });

  group('ChannelMatchService Tests', () {
    final mockChannels = [
      ChannelLive(num: "1", name: "ABC HD", categoryId: "US Local"),
      ChannelLive(num: "2", name: "ESPN FHD", categoryId: "US Sports"),
      ChannelLive(num: "3", name: "CBS Sports", categoryId: "US Sports"),
      ChannelLive(num: "4", name: "Fox News", categoryId: "US News"),
      ChannelLive(num: "5", name: "HBO", categoryId: "Movies"),
    ];

    test('Match event to exact network and sports boost', () {
      final event = SpotlightEvent(
        id: "nba_finals",
        title: "NBA Finals Game 1",
        sport: "Basketball",
        league: "NBA",
        startTimeLocal: DateTime.now().toIso8601String(),
        networks: ["ABC", "ESPN"],
        keywords: ["NBA", "Finals", "Game"],
        priority: 10,
      );

      final result = ChannelMatchService.matchEvent(
        event: event,
        allLiveChannels: mockChannels,
      );

      expect(result.bestChannel, isNotNull);
      // "ESPN FHD" or "ABC HD" should win because they are sports channels matching networks and high definition
      expect(result.bestChannel!.name, contains("ESPN"));
      expect(result.confidenceScore, greaterThan(0.5));
    });

    test('Local Affiliate Match CBS (WABC/WCBS etc)', () {
      final localCBSChannels = [
        ChannelLive(num: "1", name: "WCBS TV NY", categoryId: "Local"),
        ChannelLive(num: "2", name: "Fox Local", categoryId: "Local"),
      ];
      final event = SpotlightEvent(
        id: "cbs_event",
        title: "PGA Tour",
        sport: "Golf",
        league: "PGA",
        startTimeLocal: DateTime.now().toIso8601String(),
        networks: ["CBS"],
        keywords: ["PGA", "Golf"],
        priority: 5,
      );

      final result = ChannelMatchService.matchEvent(
        event: event,
        allLiveChannels: localCBSChannels,
      );

      expect(result.bestChannel, isNotNull);
      expect(result.bestChannel!.name, contains("WCBS"));
    });
  });

  group('AiIntentMapper Tests', () {
    test('Expand sports queries to intent keywords', () {
      final intent = AiIntentMapper.parseQuery("nba finals tonight");
      expect(intent.eventType, equals("sports"));
      expect(intent.league, equals("NBA"));
      expect(intent.keywords, contains("nba finals"));
      expect(intent.keywords, contains("espn"));
    });

    test('Expand news queries to news intent', () {
      final intent = AiIntentMapper.parseQuery("breaking news");
      expect(intent.eventType, equals("news"));
      expect(intent.keywords, contains("cnn"));
      expect(intent.keywords, contains("msnbc"));
    });

    test('Fallback tokenization for generic queries', () {
      final intent = AiIntentMapper.parseQuery("discovery science hd");
      expect(intent.eventType, equals("general"));
      expect(intent.keywords, contains("discovery"));
      expect(intent.keywords, contains("science"));
    });
  });

  group('SearchIndexService Tests', () {
    test(
      'Asynchronously build search index and perform scored search lookups',
      () async {
        final liveChannels = [
          ChannelLive(num: "1", name: "ABC News Live", categoryId: "News"),
          ChannelLive(num: "2", name: "NBA TV HD", categoryId: "Sports"),
        ];
        final movies = [
          ChannelMovie(
            num: "10",
            name: "The NBA Story",
            categoryId: "Documentaries",
          ),
        ];
        final series = [
          ChannelSerie(num: "20", name: "Breaking Bad", categoryId: "Drama"),
        ];

        await SearchIndexService.buildIndex(
          liveChannels: liveChannels,
          movies: movies,
          series: series,
        );

        expect(SearchIndexService.isReady, isTrue);
        expect(SearchIndexService.totalIndexedEntries, equals(4));

        // Search for "NBA" across categories
        final results = SearchIndexService.search("NBA");
        expect(results.length, equals(2)); // NBA TV HD and The NBA Story
        expect(
          results[0].type,
          equals("live"),
        ); // NBA TV HD should rank higher due to start match
        expect(results[1].type, equals("movie"));
      },
    );

    test(
      'Ensure exact phrase match ranks higher than expanded AI intent keywords (e.g. Breaking Bad vs News)',
      () async {
        final liveChannels = [
          ChannelLive(num: "1", name: "CNN Live News", categoryId: "News"),
          ChannelLive(num: "2", name: "Fox News", categoryId: "News"),
        ];
        final series = [
          ChannelSerie(num: "20", name: "Breaking Bad", categoryId: "Drama"),
        ];

        await SearchIndexService.buildIndex(
          liveChannels: liveChannels,
          movies: [],
          series: series,
        );

        final intent = AiIntentMapper.parseQuery("Breaking Bad");
        // "Breaking Bad" has "breaking", which AiIntentMapper maps to news keywords
        expect(intent.keywords, contains("news"));
        expect(intent.keywords, contains("cnn"));

        final results = SearchIndexService.search(
          "Breaking Bad",
          expandedKeywords: intent.keywords,
        );

        expect(results.isNotEmpty, isTrue);
        // Breaking Bad series must be the first/top result due to exact phrase match on the query "Breaking Bad",
        // even though "cnn" and "news" are in the expandedKeywords
        expect(results.first.type, equals("series"));
        expect(
          (results.first.item as ChannelSerie).name,
          equals("Breaking Bad"),
        );
      },
    );
  });

  group('LocationPreferenceService & UserPreferenceProfile Tests', () {
    test('Should show onboarding explainer by default', () {
      expect(LocationPreferenceService.shouldShowExplainer(), isTrue);
    });

    test('Marking explainer seen updates profile preferences', () async {
      await LocationPreferenceService.markExplainerSeen(true);
      expect(LocationPreferenceService.shouldShowExplainer(), isFalse);

      final profile = UserPreferenceProfile.load();
      expect(profile.hasSeenLocationExplainer, isTrue);
      expect(profile.hasAcceptedLocationPersonalization, isTrue);
      expect(profile.locationFeatureEnabled, isTrue);
    });

    test('Coordinates to region translation matches accurately', () async {
      // Atlanta area coordinate test
      await LocationPreferenceService.updateRegionFromCoordinates(33.7, -84.3);
      final profile = UserPreferenceProfile.load();
      expect(profile.region, equals("Atlanta, GA"));
      expect(profile.country, equals("USA"));
    });

    test(
      'Reset location preference updates profile flags to default state',
      () async {
        await LocationPreferenceService.markExplainerSeen(true);
        await LocationPreferenceService.resetLocationPreferences();

        expect(LocationPreferenceService.shouldShowExplainer(), isTrue);
        final profile = UserPreferenceProfile.load();
        expect(profile.hasSeenLocationExplainer, isFalse);
        expect(profile.hasAcceptedLocationPersonalization, isFalse);
        expect(profile.region, isNull);
      },
    );
  });
}

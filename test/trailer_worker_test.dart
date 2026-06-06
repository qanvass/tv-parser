import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mbark_iptv/repository/api/trailer_lookup_service.dart';
import 'package:mbark_iptv/repository/cache/trailer_cache_service.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrailerLookupService YouTube ID Extraction Tests', () {
    test('Extracts plain 11-character YouTube ID', () {
      expect(TrailerLookupService.extractYoutubeId('dQw4w9WgXcQ'), equals('dQw4w9WgXcQ'));
      expect(TrailerLookupService.extractYoutubeId('  dQw4w9WgXcQ  '), equals('dQw4w9WgXcQ')); // handles whitespaces
    });

    test('Extracts ID from youtube.com/watch?v= URLs', () {
      expect(
        TrailerLookupService.extractYoutubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        TrailerLookupService.extractYoutubeId('http://youtube.com/watch?v=dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('Extracts ID from youtu.be/ URLs', () {
      expect(
        TrailerLookupService.extractYoutubeId('https://youtu.be/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        TrailerLookupService.extractYoutubeId('http://youtu.be/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('Extracts ID from youtube.com/embed/ URLs', () {
      expect(
        TrailerLookupService.extractYoutubeId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('Extracts ID from URLs with query strings (? and &)', () {
      expect(
        TrailerLookupService.extractYoutubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        TrailerLookupService.extractYoutubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ?si=abc'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        TrailerLookupService.extractYoutubeId('https://youtu.be/dQw4w9WgXcQ?t=10'),
        equals('dQw4w9WgXcQ'),
      );
      expect(
        TrailerLookupService.extractYoutubeId('https://www.youtube.com/embed/dQw4w9WgXcQ?rel=0&autoplay=1'),
        equals('dQw4w9WgXcQ'),
      );
    });

    test('Rejects malformed or suspicious values', () {
      expect(TrailerLookupService.extractYoutubeId(''), isNull);
      expect(TrailerLookupService.extractYoutubeId('shortID'), isNull);
      expect(TrailerLookupService.extractYoutubeId('tooLongYouTubeIDName'), isNull);
      expect(TrailerLookupService.extractYoutubeId('https://google.com'), isNull);
    });

    test('Finds YouTube ID in structured metadata maps', () {
      final detailMap = {
        'youtube_trailer': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      };
      expect(TrailerLookupService.getYoutubeIdFromMetadata(detailMap), equals('dQw4w9WgXcQ'));

      final nestedMap = {
        'info': {
          'youtubeTrailer': 'dQw4w9WgXcQ',
        }
      };
      expect(TrailerLookupService.getYoutubeIdFromMetadata(nestedMap), equals('dQw4w9WgXcQ'));

      final movieDataMap = {
        'movie_data': {
          'youtube_id': 'dQw4w9WgXcQ',
        }
      };
      expect(TrailerLookupService.getYoutubeIdFromMetadata(movieDataMap), equals('dQw4w9WgXcQ'));
    });
  });

  group('TrailerCacheService and Entry Expiry Tests', () {
    setUpAll(() async {
      // Mock the path provider method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return '.'; // Return root directory for storage temp path
        },
      );
      await GetStorage.init('youtube_trailer_cache');
    });

    test('Writes and Reads success entry correctly', () {
      TrailerCacheService.writeEntry(
        title: 'The Devil Wears Prada 2',
        year: '2026',
        youtubeId: 'abc123xyz99',
        source: 'youtubeApi',
        failedLookup: false,
      );

      final entry = TrailerCacheService.getEntry('The Devil Wears Prada 2', '2026');
      expect(entry, isNotNull);
      expect(entry!.youtubeId, equals('abc123xyz99'));
      expect(entry.failedLookup, isFalse);
      expect(entry.source, equals('youtubeApi'));
      expect(entry.isExpired(), isFalse);
    });

    test('Writes and Reads failed entry correctly', () {
      TrailerCacheService.writeEntry(
        title: 'Non Existent Movie',
        year: '2099',
        youtubeId: null,
        source: 'none',
        failedLookup: true,
      );

      final entry = TrailerCacheService.getEntry('Non Existent Movie', '2099');
      expect(entry, isNotNull);
      expect(entry!.youtubeId, isNull);
      expect(entry.failedLookup, isTrue);
      expect(entry.isExpired(), isFalse);
    });

    test('Checks Entry Expiry validation logic', () {
      // Success entry older than 60 days is expired
      final oldSuccessEntry = TrailerCacheEntry(
        normalizedTitle: 'old movie',
        year: '1999',
        youtubeId: 'old_id_12345',
        source: 'youtubeApi',
        failedLookup: false,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch - (61 * 24 * 60 * 60 * 1000),
      );
      expect(oldSuccessEntry.isExpired(), isTrue);

      // Success entry newer than 30 days is NOT expired
      final newSuccessEntry = TrailerCacheEntry(
        normalizedTitle: 'new movie',
        year: '2025',
        youtubeId: 'new_id_12345',
        source: 'youtubeApi',
        failedLookup: false,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch - (15 * 24 * 60 * 60 * 1000),
      );
      expect(newSuccessEntry.isExpired(), isFalse);

      // Failed entry older than 7 days is expired
      final oldFailedEntry = TrailerCacheEntry(
        normalizedTitle: 'failed movie',
        year: '2000',
        youtubeId: null,
        source: 'none',
        failedLookup: true,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch - (8 * 24 * 60 * 60 * 1000),
      );
      expect(oldFailedEntry.isExpired(), isTrue);

      // Failed entry newer than 7 days is NOT expired
      final newFailedEntry = TrailerCacheEntry(
        normalizedTitle: 'failed movie',
        year: '2000',
        youtubeId: null,
        source: 'none',
        failedLookup: true,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch - (3 * 24 * 60 * 60 * 1000),
      );
      expect(newFailedEntry.isExpired(), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';
import 'package:mbark_iptv/repository/api/premium_plus_service.dart';

void main() {
  group('PremiumPlusService Curation & Matching Tests', () {
    test('Tokenized contiguous sublist check avoids false positives (Max vs Cinemax)', () {
      final mockChannels = [
        ChannelLive(num: "1", name: "Cinemax Action HD", streamId: "100"),
        ChannelLive(num: "2", name: "Maximum Movie TV", streamId: "101"),
        ChannelLive(num: "3", name: "HBO Max East HD", streamId: "102"),
      ];

      final results = PremiumPlusService.matchChannels(mockChannels, forceRefresh: true);

      // Max is defined in brand list. Let's find its match.
      final maxItem = results.firstWhere((r) => r.id == "max");
      
      expect(maxItem.matchedChannel, isNotNull);
      // It should match "HBO Max East HD"
      expect(maxItem.matchedChannel!.streamId, equals("102"));
      expect(maxItem.matchedChannel!.name, equals("HBO Max East HD"));
    });

    test('BET and BET+ are matched correctly without cross-matching', () {
      final mockChannels = [
        ChannelLive(num: "1", name: "BET HD", streamId: "201"),
        ChannelLive(num: "2", name: "BET+ HD", streamId: "202"),
      ];

      final results = PremiumPlusService.matchChannels(mockChannels, forceRefresh: true);

      final betItem = results.firstWhere((r) => r.id == "bet");
      final betPlusItem = results.firstWhere((r) => r.id == "bet_plus");

      expect(betItem.matchedChannel, isNotNull);
      expect(betItem.matchedChannel!.streamId, equals("201"));

      expect(betPlusItem.matchedChannel, isNotNull);
      expect(betPlusItem.matchedChannel!.streamId, equals("202"));
    });

    test('ESPN matches its variations and selects the highest scoring', () {
      final mockChannels = [
        ChannelLive(num: "1", name: "ESPN News", streamId: "301"),
        ChannelLive(num: "2", name: "ESPN USA HD", streamId: "302"), // Should score higher due to USA and HD boosts
      ];

      final results = PremiumPlusService.matchChannels(mockChannels, forceRefresh: true);

      final espnItem = results.firstWhere((r) => r.id == "espn");

      expect(espnItem.matchedChannel, isNotNull);
      expect(espnItem.matchedChannel!.streamId, equals("302"));
    });

    test('Hides rows/channels if there are no playlist matches', () {
      final mockChannels = [
        ChannelLive(num: "1", name: "Some Random Channel", streamId: "999"),
      ];

      final results = PremiumPlusService.matchChannels(mockChannels, forceRefresh: true);
      expect(results.isEmpty, isTrue);
    });

    test('Session caching returns the same list and avoids recalculation unless forceRefresh is true', () {
      final mockChannels = [
        ChannelLive(num: "1", name: "CNN USA HD", streamId: "401"),
      ];

      final results1 = PremiumPlusService.matchChannels(mockChannels, forceRefresh: true);
      expect(results1.length, equals(1));
      expect(results1.first.id, equals("cnn"));

      // Modify the playlist but call without forceRefresh
      final mockChannels2 = [
        ChannelLive(num: "1", name: "Fox News HD", streamId: "402"),
      ];

      final results2 = PremiumPlusService.matchChannels(mockChannels2);
      // Should still return cached CNN
      expect(results2.length, equals(1));
      expect(results2.first.id, equals("cnn"));

      // Now force refresh
      final results3 = PremiumPlusService.matchChannels(mockChannels2, forceRefresh: true);
      expect(results3.length, equals(1));
      expect(results3.first.id, equals("fox_news"));
    });
  });
}

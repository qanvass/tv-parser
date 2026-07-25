import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/premium_plus_service.dart';
import 'package:mbark_iptv/repository/models/channel_live.dart';

void main() {
  group('Playlist-derived featured channel curation', () {
    test('uses only channels supplied by the connected playlist', () {
      final channels = [
        const ChannelLive(name: 'Community Stream One', streamId: '1'),
        const ChannelLive(name: 'Community Stream Two', streamId: '2'),
      ];

      final results = PremiumPlusService.matchChannels(
        channels,
        forceRefresh: true,
      );

      expect(results.map((item) => item.displayName), [
        'Community Stream One',
        'Community Stream Two',
      ]);
      expect(results.every((item) => item.matchedChannel != null), isTrue);
    });

    test('excludes adult, blank, and duplicate channels', () {
      final channels = [
        const ChannelLive(name: '', streamId: 'blank'),
        const ChannelLive(name: 'Restricted', streamId: 'adult', isAdult: '1'),
        const ChannelLive(name: 'Sample Stream', streamId: 'sample'),
        const ChannelLive(name: 'Duplicate Stream', streamId: 'sample'),
      ];

      final results = PremiumPlusService.matchChannels(
        channels,
        forceRefresh: true,
      );

      expect(results, hasLength(1));
      expect(results.single.displayName, 'Sample Stream');
    });

    test('caps the featured row and preserves its session cache', () {
      final channels = List.generate(
        20,
        (index) => ChannelLive(name: 'Stream $index', streamId: '$index'),
      );

      final first = PremiumPlusService.matchChannels(
        channels,
        forceRefresh: true,
      );
      final cached = PremiumPlusService.matchChannels(const []);

      expect(first, hasLength(12));
      expect(identical(first, cached), isTrue);
    });
  });
}

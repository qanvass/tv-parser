import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/api.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';

ChannelSerie _ep(String id, String name, {String cat = 'c1'}) => ChannelSerie(
  seriesId: id,
  name: name,
  categoryId: cat,
  directSource: 'https://example.test/vod/$id.mkv',
);

void main() {
  test('groups playlist episodes of one show into sorted seasons', () {
    final source = [
      _ep('3', 'Medusa S02 E01'),
      _ep('1', 'Medusa S01 E02'),
      _ep('2', 'Medusa S01 E01'),
      _ep('9', 'Medusa Deluxe (2022)'),
      _ep('5', 'Other Show S01 E01'),
    ];

    final details = IpTvApi.m3uSerieDetails(
      '1',
      source: source,
      categories: const [],
    );

    expect(details, isNotNull);
    expect(details!.episodes!.keys.toList(), ['1', '2']);
    final s1 = details.episodes!['1']!;
    expect(s1.map((e) => e!.id), ['2', '1']);
    expect(s1.first!.directSource, 'https://example.test/vod/2.mkv');
    expect(s1.first!.containerExtension, 'mkv');
    expect(details.episodes!['2']!.single!.id, '3');
  });

  test('unknown series id returns null', () {
    expect(
      IpTvApi.m3uSerieDetails(
        'x',
        source: [_ep('1', 'A S01 E01')],
        categories: const [],
      ),
      isNull,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/models/channel_serie.dart';
import 'package:mbark_iptv/repository/provider/series_collapse.dart';

ChannelSerie _s(String id, String name, {String? cover}) =>
    ChannelSerie(seriesId: id, name: name, cover: cover);

void main() {
  test('collapses per-episode rows into one card per show', () {
    final out = SeriesCollapse.collapseByShow([
      _s('1', 'Show A (2026) S01 E01'),
      _s('2', 'Show A (2026) S01 E02'),
      _s('3', 'Other Show S01 E01'),
      _s('4', 'Show A (2026) S01 E03'),
    ]);
    expect(out.length, 2);
    // Order follows first appearance; representative is the latest episode.
    expect(out.first.seriesId, '4');
    expect(out.last.seriesId, '3');
  });

  test('prefers 4K over HD over untagged', () {
    final out = SeriesCollapse.collapseByShow([
      _s('1', 'Show A S01 E01'),
      _s('2', 'Show A HD S01 E01'),
      _s('3', 'Show A 4K S01 E01'),
    ]);
    expect(out.single.seriesId, '3');
  });

  test('same title with different year stays separate', () {
    final out = SeriesCollapse.collapseByShow([
      _s('1', 'Show A (1999) S01 E01'),
      _s('2', 'Show A (2026) S01 E01'),
    ]);
    expect(out.length, 2);
  });
}

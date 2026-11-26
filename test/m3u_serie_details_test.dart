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
  staleIdTests();
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

// Playlist ids are list positions: a saved id can name another show later.
void staleIdTests() {
  final saved = ChannelSerie(
    seriesId: 'm3u_stream_40',
    name: 'Reasonable Doubt (2022) S01 E01',
    directSource: 'https://example.test/tvshow/tt1/1/1',
  );

  test('row at a saved id that is now another show is rejected', () {
    final other = _ep('m3u_stream_40', 'The Kids in the Hall S01 E01');
    expect(IpTvApi.m3uSeriesIsSavedShow(other, saved), isFalse);
  });

  test('row with the saved title or address is accepted', () {
    expect(
      IpTvApi.m3uSeriesIsSavedShow(
        _ep('m3u_stream_77', 'Reasonable Doubt (2022) S02 E03'),
        saved,
      ),
      isTrue,
    );
    expect(
      IpTvApi.m3uSeriesIsSavedShow(
        ChannelSerie(name: 'Renamed', directSource: saved.directSource),
        saved,
      ),
      isTrue,
    );
    expect(
      IpTvApi.m3uSeriesIsSavedShow(_ep('1', 'Anything'), ChannelSerie()),
      isTrue,
    );
  });

  test('saved show is found again by title, same year first', () {
    final rows = [
      _ep('1', 'The Legend of Vox Machina (2022) S01 E01'),
      _ep('2', 'Reasonable Doubt (1991) S01 E01'),
      _ep('3', 'Reasonable Doubt (2022) S01 E01'),
    ];
    expect(IpTvApi.m3uSeriesByShowTitle(rows, saved)!.seriesId, '3');
    expect(IpTvApi.m3uSeriesByShowTitle(rows.take(2), saved)!.seriesId, '2');
    expect(IpTvApi.m3uSeriesByShowTitle(rows.take(1), saved), isNull);
  });
}

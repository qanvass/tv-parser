import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/presentation/tv/series_rail_grouper.dart';
import 'package:mbark_iptv/presentation/tv/widgets/tv_channel_grid.dart';
import 'package:mbark_iptv/repository/provider/title_normalizer.dart';

TvStreamRecord _raw(String title) {
  return TvStreamRecord(
    title: title,
    subtitle: 'Series',
    streamUrl: title,
  );
}

TvStreamRecord _preParsed(String title) {
  final parsed = TitleNormalizer.parse(title);
  return TvStreamRecord(
    title: parsed.displayTitle.isEmpty ? title : parsed.displayTitle,
    subtitle: 'Series',
    streamUrl: title,
    year: parsed.year,
    season: parsed.season,
    episode: parsed.episode,
    badge: parsed.episodeBadge,
    qualityLabel: parsed.qualityLabel,
  );
}

void main() {
  test('episodes of one show collapse to a single card', () {
    final grouped = SeriesRailGrouper.groupForRail([
      _preParsed('Batman Caped Crusader S01E01'),
      _preParsed('Batman Caped Crusader S01E02'),
      _preParsed('Batman Caped Crusader S01E05'),
    ]);
    expect(grouped, hasLength(1));
    expect(grouped.first.title, 'Batman Caped Crusader');
    expect(grouped.first.groupedEpisodes, hasLength(3));
  });

  test('pre-parsed records keep the same grouping as raw titles', () {
    const titles = [
      'Love Island [S01 E01]',
      'Love Island [S01 E02]',
      'Some Obscure Show',
      'The Golem (1920) 1080p',
    ];
    final fromRaw = SeriesRailGrouper.groupForRail(titles.map(_raw).toList());
    final fromParsed =
        SeriesRailGrouper.groupForRail(titles.map(_preParsed).toList());
    expect(fromParsed.map((e) => e.title), fromRaw.map((e) => e.title));
    expect(
      fromParsed.map((e) => e.groupedEpisodes.length),
      fromRaw.map((e) => e.groupedEpisodes.length),
    );
  });
}

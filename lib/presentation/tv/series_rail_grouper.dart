import '../../repository/provider/title_normalizer.dart';
import 'widgets/tv_channel_grid.dart';

/// Collapse per-episode VOD rows into one show card when titles share a
/// sanitized series name. Episodes stay attached and playable. No invented seasons.
class SeriesRailGrouper {
  static List<TvStreamRecord> groupForRail(List<TvStreamRecord> items) {
    if (items.length < 2) {
      return items.map(_withParsedBadge).toList(growable: false);
    }

    final buckets = <String, List<TvStreamRecord>>{};
    for (final item in items) {
      final key = TitleNormalizer.seriesGroupKey(item.title);
      if (key.isEmpty) {
        buckets.putIfAbsent('\u0000${item.streamUrl}', () => []).add(item);
        continue;
      }
      buckets.putIfAbsent(key, () => []).add(item);
    }

    if (buckets.length >= items.length) {
      return items.map(_withParsedBadge).toList(growable: false);
    }

    final out = <TvStreamRecord>[];
    final seen = <String>{};
    for (final item in items) {
      final key = TitleNormalizer.seriesGroupKey(item.title);
      final bucketKey = key.isEmpty ? '\u0000${item.streamUrl}' : key;
      if (!seen.add(bucketKey)) continue;
      final group = buckets[bucketKey] ?? [item];
      out.add(_collapse(group));
    }
    return out;
  }

  static TvStreamRecord _collapse(List<TvStreamRecord> group) {
    final first = group.first;
    final parsed = TitleNormalizer.parse(first.title);
    var best = first;
    for (final item in group) {
      if ((item.imageUrl ?? '').isNotEmpty) {
        best = item;
        break;
      }
    }
    final single = group.length == 1;
    final ep = TitleNormalizer.parse(best.title);
    return best.copyWith(
      title: parsed.displayTitle.isEmpty ? best.title : parsed.displayTitle,
      year: best.year ?? parsed.year,
      season: single ? ep.season : null,
      episode: single ? ep.episode : null,
      badge: single ? ep.episodeBadge : null,
      groupedEpisodes: group.length > 1 ? group : const [],
    );
  }

  static TvStreamRecord _withParsedBadge(TvStreamRecord item) {
    final parsed = TitleNormalizer.parse(item.title);
    return item.copyWith(
      title: parsed.displayTitle.isEmpty ? item.title : parsed.displayTitle,
      year: item.year ?? parsed.year,
      season: item.season ?? parsed.season,
      episode: item.episode ?? parsed.episode,
      badge: item.badge ?? parsed.episodeBadge,
      qualityLabel: item.qualityLabel ?? parsed.qualityLabel,
    );
  }
}

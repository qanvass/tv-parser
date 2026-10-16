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

  /// One card for a whole show (playlist group = show). Episodes are kept in
  /// season/episode order; a single-episode show stays directly playable.
  static TvStreamRecord showCard(
    List<TvStreamRecord> episodes, {
    required String title,
    int? year,
  }) {
    final eps = [for (final e in episodes) _withParsedBadge(e)];
    final indexed = [for (var i = 0; i < eps.length; i++) (i, eps[i])];
    indexed.sort((a, b) {
      final s = (a.$2.season ?? 1 << 20).compareTo(b.$2.season ?? 1 << 20);
      if (s != 0) return s;
      final e = (a.$2.episode ?? 1 << 20).compareTo(b.$2.episode ?? 1 << 20);
      return e != 0 ? e : a.$1.compareTo(b.$1);
    });
    final ordered = [for (final x in indexed) x.$2];
    var best = ordered.first;
    for (final item in ordered) {
      if ((item.imageUrl ?? '').isNotEmpty) {
        best = item;
        break;
      }
    }
    if (ordered.length == 1) {
      return best.copyWith(title: title, year: year ?? best.year);
    }
    return best.copyWith(
      title: title,
      year: year ?? best.year,
      season: null,
      episode: null,
      badge: null,
      groupedEpisodes: ordered,
    );
  }

  static bool _alreadyParsed(TvStreamRecord item) =>
      item.year != null ||
      item.season != null ||
      item.episode != null ||
      item.badge != null ||
      item.qualityLabel != null;

  static TvStreamRecord _collapse(List<TvStreamRecord> group) {
    final first = group.first;
    var best = first;
    for (final item in group) {
      if ((item.imageUrl ?? '').isNotEmpty) {
        best = item;
        break;
      }
    }
    final single = group.length == 1;
    final parsed = _alreadyParsed(first) ? null : TitleNormalizer.parse(first.title);
    final ep = single && !_alreadyParsed(best)
        ? TitleNormalizer.parse(best.title)
        : null;
    return best.copyWith(
      title: parsed == null
          ? first.title
          : (parsed.displayTitle.isEmpty ? best.title : parsed.displayTitle),
      year: best.year ?? first.year ?? parsed?.year,
      season: single ? (best.season ?? ep?.season) : null,
      episode: single ? (best.episode ?? ep?.episode) : null,
      badge: single ? (best.badge ?? ep?.episodeBadge) : null,
      groupedEpisodes: group.length > 1 ? group : const [],
    );
  }

  static TvStreamRecord _withParsedBadge(TvStreamRecord item) {
    if (_alreadyParsed(item)) return item;
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

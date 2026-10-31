import '../models/channel_serie.dart';
import 'title_normalizer.dart';

/// Playlist (M3U) catalogs list every episode — and often every quality copy —
/// as its own series entry. These helpers collapse those rows so the UI shows
/// one card per show and one tile per episode, keeping the best copy.
class SeriesCollapse {
  /// Rank for the quality label parsed from the provider title (never inferred).
  static int qualityRank(String? label) {
    switch (label) {
      case '4K':
        return 2;
      case 'HD':
        return 1;
      default:
        return 0;
    }
  }

  /// Show key: normalized title + year (a remake with another year stays apart).
  static String showKey(ChannelSerie s) {
    final t = TitleNormalizer.parse(s.name ?? '');
    final title = t.matchTitle.toLowerCase();
    if (title.isEmpty) return 'id:${s.seriesId ?? ''}';
    return '$title|${t.year ?? ''}';
  }

  /// True when [a] is a better representative than [b]:
  /// higher quality, then has artwork, then the most recent episode.
  static bool isBetter(ChannelSerie a, ChannelSerie b) {
    final ta = TitleNormalizer.parse(a.name ?? '');
    final tb = TitleNormalizer.parse(b.name ?? '');
    final qa = qualityRank(ta.qualityLabel);
    final qb = qualityRank(tb.qualityLabel);
    if (qa != qb) return qa > qb;
    final ca = (a.cover ?? '').isNotEmpty;
    final cb = (b.cover ?? '').isNotEmpty;
    if (ca != cb) return ca;
    final ea = (ta.season ?? 0) * 1000 + (ta.episode ?? 0);
    final eb = (tb.season ?? 0) * 1000 + (tb.episode ?? 0);
    return ea > eb;
  }

  /// One entry per show, in the order each show first appeared (keeps
  /// search relevance ranking). The kept entry is the best copy of that show.
  static List<ChannelSerie> collapseByShow(List<ChannelSerie> items) {
    final order = <String>[];
    final best = <String, ChannelSerie>{};
    for (final s in items) {
      final key = showKey(s);
      final current = best[key];
      if (current == null) {
        order.add(key);
        best[key] = s;
      } else if (isBetter(s, current)) {
        best[key] = s;
      }
    }
    return [for (final k in order) best[k]!];
  }
}

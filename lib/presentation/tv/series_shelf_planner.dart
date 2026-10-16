import '../../repository/models/category.dart';

/// One shelf of shows (each category = one show).
class SeriesShelfPlan {
  final String title;
  final List<CategoryModel> shows;
  const SeriesShelfPlan(this.title, this.shows);
}

/// Some playlists put every show in its own group ("The Last of Us (2023)").
/// Turning each group into a shelf gives thousands of one-card rows; instead
/// each group becomes one show card and shows are shelved by release year.
/// Only the group name is used — no invented genres.
class SeriesShelfPlanner {
  SeriesShelfPlanner._();

  static final RegExp _yearSuffix = RegExp(r'\((19|20)\d{2}\)\s*$');
  static final RegExp _year = RegExp(r'\(((?:19|20)\d{2})\)\s*$');

  /// True when most series groups are individual shows (name ends in a year).
  static bool looksPerShow(List<CategoryModel> cats) {
    if (cats.length < 30) return false;
    var titled = 0;
    for (final c in cats) {
      if (_yearSuffix.hasMatch(c.categoryName ?? '')) titled++;
    }
    return titled * 2 >= cats.length;
  }

  static int? yearOf(CategoryModel cat) {
    final m = _year.firstMatch(cat.categoryName ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Show name without the trailing "(YYYY)".
  static String showTitle(CategoryModel cat) {
    final name = (cat.categoryName ?? '').trim();
    final stripped = name.replaceFirst(_yearSuffix, '').trim();
    return stripped.isEmpty ? (name.isEmpty ? 'Series' : name) : stripped;
  }

  /// New & Recent, then decades (newest first), then shows with no year.
  /// Within a shelf: newest first, provider order for ties.
  static List<SeriesShelfPlan> plan(List<CategoryModel> shows, {int? nowYear}) {
    final now = nowYear ?? DateTime.now().year;
    final buckets = <String, List<(int, int, CategoryModel)>>{};
    const order = [
      'New & Recent',
      '2020s Series',
      '2010s Series',
      '2000s Series',
      '1990s Series',
      'Classic Series',
      'More Series',
    ];
    for (var i = 0; i < shows.length; i++) {
      final cat = shows[i];
      final y = yearOf(cat);
      final String shelf;
      if (y == null) {
        shelf = 'More Series';
      } else if (y >= now - 1) {
        shelf = 'New & Recent';
      } else if (y >= 2020) {
        shelf = '2020s Series';
      } else if (y >= 2010) {
        shelf = '2010s Series';
      } else if (y >= 2000) {
        shelf = '2000s Series';
      } else if (y >= 1990) {
        shelf = '1990s Series';
      } else {
        shelf = 'Classic Series';
      }
      buckets.putIfAbsent(shelf, () => []).add((y ?? 0, i, cat));
    }
    final out = <SeriesShelfPlan>[];
    for (final title in order) {
      final list = buckets[title];
      if (list == null || list.isEmpty) continue;
      list.sort((a, b) {
        final c = b.$1.compareTo(a.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
      out.add(SeriesShelfPlan(title, [for (final e in list) e.$3]));
    }
    return out;
  }
}

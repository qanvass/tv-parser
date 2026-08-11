/// Presentation taxonomy for Movies rails.
///
/// Provider `group-title` / category names stay on the catalog.
/// This mapper only decides **headings** the TV UI may show.
class PresentationSourceGroup<T> {
  final String? providerCategoryId;
  final String providerCategoryName;
  final List<T> items;

  const PresentationSourceGroup({
    this.providerCategoryId,
    required this.providerCategoryName,
    required this.items,
  });
}

class PresentationShelf<T> {
  final String title;
  final List<T> items;

  const PresentationShelf({
    required this.title,
    required this.items,
  });
}

/// Collapses provider year-bucket categories into a few user-facing shelves.
///
/// Does not rewrite playlists or delete [CategoryModel] metadata.
/// Does not invent Netflix/Prime/genre rows.
class CategoryPresentationMapper {
  static const int classicsBeforeYear = 1980;
  static const int recentFromYear = 2020;

  static const String shelfMovies = 'Movies';
  static const String shelfClassics = 'Classics';
  static const String shelfRecentlyAdded = 'Recently Added';

  static final RegExp _moviesThenYear = RegExp(
    r'^(?:movies?|films?|vod)\s+((?:19|20)\d{2})\b',
    caseSensitive: false,
  );
  static final RegExp _yearThenMovies = RegExp(
    r'^((?:19|20)\d{2})\s+(?:movies?|films?|vod)\b',
    caseSensitive: false,
  );
  static final RegExp _moviesTrailingYear = RegExp(
    r'\b(?:movies?|films?|vod)\b.*?\b((?:19|20)\d{2})\s*$',
    caseSensitive: false,
  );
  static final RegExp _bareYear = RegExp(r'^((?:19|20)\d{2})$');

  /// Year encoded in a provider category / group-title, or null.
  static int? yearFromCategoryName(String? name) {
    final raw = name?.trim();
    if (raw == null || raw.isEmpty) return null;

    final moviesFirst = _moviesThenYear.firstMatch(raw);
    if (moviesFirst != null) return int.tryParse(moviesFirst.group(1)!);

    final yearFirst = _yearThenMovies.firstMatch(raw);
    if (yearFirst != null) return int.tryParse(yearFirst.group(1)!);

    final trailing = _moviesTrailingYear.firstMatch(raw);
    if (trailing != null) return int.tryParse(trailing.group(1)!);

    final bare = _bareYear.firstMatch(raw);
    if (bare != null) return int.tryParse(bare.group(1)!);

    return null;
  }

  static bool isYearBucketName(String? name) =>
      yearFromCategoryName(name) != null;

  static String decadeLabel(int year) => '${(year ~/ 10) * 10}s';

  /// Build presentation shelves from provider-grouped rows.
  ///
  /// Year-bucket headings are never returned. Named (non-year) categories
  /// keep their provider labels. Empty shelves are omitted.
  ///
  /// If [groups] contain items but nothing would display, emits a single
  /// [shelfMovies] fallback (Phase 0: content exists → not an empty Movies tab).
  static List<PresentationShelf<T>> presentMovies<T>({
    required List<PresentationSourceGroup<T>> groups,
    int? Function(T item)? itemYear,
  }) {
    final named = <PresentationSourceGroup<T>>[];
    final recent = <T>[];
    final mid = <T>[];
    final classics = <T>[];

    for (final group in groups) {
      if (group.items.isEmpty) continue;
      final categoryYear = yearFromCategoryName(group.providerCategoryName);
      if (categoryYear == null) {
        named.add(group);
        continue;
      }
      for (final item in group.items) {
        final year = itemYear?.call(item) ?? categoryYear;
        if (year >= recentFromYear) {
          recent.add(item);
        } else if (year < classicsBeforeYear) {
          classics.add(item);
        } else {
          mid.add(item);
        }
      }
    }

    _sortByYearDesc(recent, itemYear);
    _sortByYearDesc(mid, itemYear);
    _sortByYearDesc(classics, itemYear);

    final out = <PresentationShelf<T>>[];
    if (recent.isNotEmpty) {
      out.add(PresentationShelf(title: shelfRecentlyAdded, items: recent));
    }
    if (mid.isNotEmpty) {
      out.add(PresentationShelf(title: shelfMovies, items: mid));
    }
    for (final group in named) {
      final label = group.providerCategoryName.trim().isEmpty
          ? shelfMovies
          : group.providerCategoryName.trim();
      if (isYearBucketName(label)) continue;
      out.add(PresentationShelf(title: label, items: group.items));
    }
    if (classics.isNotEmpty) {
      out.add(PresentationShelf(title: shelfClassics, items: classics));
    }

    if (out.isEmpty) {
      final leftover = <T>[
        for (final group in groups) ...group.items,
      ];
      if (leftover.isNotEmpty) {
        out.add(PresentationShelf(title: shelfMovies, items: leftover));
      }
    }

    return out;
  }

  static void _sortByYearDesc<T>(List<T> items, int? Function(T item)? itemYear) {
    if (itemYear == null || items.length < 2) return;
    items.sort((a, b) {
      final ay = itemYear(a) ?? 0;
      final by = itemYear(b) ?? 0;
      return by.compareTo(ay);
    });
  }
}

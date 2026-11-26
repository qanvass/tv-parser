import 'running_series_data.dart';
import 'title_normalizer.dart';

/// What Quasar asked for on 2026-11-26, in his words:
///
///  * "we can remove all series before the year 2020 and all movies before the
///    year 2020"
///  * "there's a series that's still playing in 2026, but it goes back to 2018
///    ... It's okay to keep those. ... We don't need to see the part of that
///    series before 2020 either."
///
/// So: a movie from before 2020 is not loaded. A series from before 2020 is
/// not loaded unless it is still running, and then only its seasons from 2020
/// on are loaded. Nothing that is dropped takes memory, storage or search time.
///
/// How old something is comes only from what the provider wrote: a year in
/// brackets ("Cheers (1982)", "Heat [1995]", "Friends (1994-2004)") or a
/// decade shelf ("1990s Series"). A bare number is left alone because it is
/// often the title itself ("1923", "Blade Runner 2049"). A title with neither
/// is kept: its age is not known.
///
/// "Still running" comes from [runningSeriesBefore2020], a list generated from
/// TMDB by tool/gen_running_series.py and compiled in, so this works in any
/// isolate and costs the TV nothing at load time.
abstract final class CatalogAgePolicy {
  static const int seriesFromYear = 2020;
  static const int moviesFromYear = 2020;

  /// Used when the still-running list is missing: without it only shows that
  /// cannot possibly be current are dropped.
  static const int seriesFloorYear = 2000;

  static final RegExp _bracketYear = RegExp(r'[\(\[]\s*((?:19|20)\d{2})\b');
  static final RegExp _decade = RegExp(r'(?<![0-9])((?:19|20)[0-9]0)s(?![a-z])');
  static final RegExp _notKey = RegExp(r'[^a-z0-9]+');
  static final RegExp _firstNumber = RegExp(r'\d{1,3}');

  /// The first bracketed year in [text], or null.
  static int? bracketYear(String? text) {
    if (text == null || text.isEmpty) return null;
    final m = _bracketYear.firstMatch(text);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// The decade a group is named after ("1990s Series" -> 1990), or null.
  static int? groupDecade(String? group) {
    if (group == null || group.isEmpty) return null;
    final m = _decade.firstMatch(group);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// A title reduced to a-z0-9. Must match squash() in the generator.
  static String titleKey(String title) =>
      title.toLowerCase().replaceAll('&', ' and ').replaceAll(_notKey, '');

  static bool movieTooOld(String? name, [String? group]) {
    final year = bracketYear(name);
    if (year != null) return year < moviesFromYear;
    final decade = groupDecade(group);
    return decade != null && decade + 9 < moviesFromYear;
  }

  /// The verdict for a show: [dropShow], [keepAll], or the number of the
  /// first season to keep.
  static const int dropShow = -1;
  static const int keepAll = 0;

  static String _memoKey = '';
  static int _memoVerdict = keepAll;

  /// [name] is the row's title (it may carry an episode tag), [group] the
  /// playlist group, [startYear] a first-air year the provider gave directly.
  /// [running] is only for tests.
  static int seriesVerdict(
    String? name, {
    String? group,
    int? startYear,
    Map<String, List<int>>? running,
    SanitizedTitle? parsed,
  }) {
    final list = running ?? runningSeriesBefore2020;
    final year = startYear ?? bracketYear(name) ?? bracketYear(group);
    final decade = year == null ? groupDecade(group) : null;
    if (year == null && decade == null) return keepAll;
    if (year != null && year >= seriesFromYear) return keepAll;
    if (decade != null && decade >= seriesFromYear) return keepAll;
    if (list.isEmpty) {
      final latest = year ?? decade! + 9;
      return latest < seriesFloorYear ? dropShow : keepAll;
    }

    // Episodes of one show arrive together: remember the last answer.
    final title = (parsed ?? TitleNormalizer.parse(name ?? '')).matchTitle;
    final memoKey = '$title|${group ?? ''}|${year ?? ''}';
    final sameShow = running == null && memoKey == _memoKey;
    if (sameShow) return _memoVerdict;

    var verdict = dropShow;
    final titles = <String>{
      titleKey(title),
      // Playlists with one group per show: the group is the title.
      if (decade == null) titleKey(TitleNormalizer.parse(group ?? '').matchTitle),
    }..remove('');
    for (final key in titles) {
      final pairs = list[key];
      if (pairs == null) continue;
      for (var i = 0; i + 1 < pairs.length; i += 2) {
        final first = pairs[i];
        final sameStart = year != null
            ? (first - year).abs() <= 1
            : first >= decade! - 1 && first <= decade + 10;
        if (sameStart) {
          verdict = pairs[i + 1] < 1 ? 1 : pairs[i + 1];
          break;
        }
      }
      if (verdict != dropShow) break;
    }
    if (running == null) {
      _memoKey = memoKey;
      _memoVerdict = verdict;
    }
    return verdict;
  }

  /// True when this series row (a show, or one episode of it) is not loaded.
  static bool seriesRowTooOld(
    String? name, {
    String? group,
    int? startYear,
    Map<String, List<int>>? running,
  }) {
    // Cheap exit first: most rows are new enough or carry no age at all.
    final year = startYear ?? bracketYear(name) ?? bracketYear(group);
    if (year != null && year >= seriesFromYear) return false;
    if (year == null) {
      final decade = groupDecade(group);
      if (decade == null || decade >= seriesFromYear) return false;
    }
    final parsed = TitleNormalizer.parse(name ?? '');
    final verdict = seriesVerdict(
      name,
      group: group,
      startYear: startYear,
      running: running,
      parsed: parsed,
    );
    if (verdict == dropShow) return true;
    if (verdict == keepAll) return false;
    final season = parsed.season;
    return season != null && season < verdict;
  }

  /// Season labels ("3", "Season 03") that stay for a show whose first kept
  /// season is [fromSeason]. A label with no number stays.
  static bool seasonKept(String label, int fromSeason) {
    if (fromSeason <= keepAll) return true;
    final m = _firstNumber.firstMatch(label);
    final n = m == null ? null : int.tryParse(m.group(0)!);
    return n == null || n >= fromSeason;
  }
}

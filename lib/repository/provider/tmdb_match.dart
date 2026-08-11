import 'title_normalizer.dart';

/// High-confidence TMDB match only. Never apply artwork on a loose fuzzy hit.
class TmdbMatch {
  static final RegExp _imdbId = RegExp(r'^tt[0-9]+$');

  /// Keep only a well-formed IMDb title id (`tt` + digits). Malformed → null.
  static String? normalizeImdbId(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || !_imdbId.hasMatch(s)) return null;
    return s;
  }

  /// Accept when titles match exactly after sanitize, and years agree when both exist.
  static bool isHighConfidence({
    required String queryTitle,
    required String resultTitle,
    int? queryYear,
    int? resultYear,
  }) {
    final q = TitleNormalizer.parse(queryTitle).matchTitle.toLowerCase();
    final r = TitleNormalizer.parse(resultTitle).matchTitle.toLowerCase();
    if (q.isEmpty || r.isEmpty) return false;
    if (q != r) return false;
    if (queryYear != null && resultYear != null) {
      return queryYear == resultYear;
    }
    // Exact name with no conflicting year is enough.
    return true;
  }

  static int? yearFromDate(String? isoDate) {
    if (isoDate == null || isoDate.length < 4) return null;
    return int.tryParse(isoDate.substring(0, 4));
  }
}

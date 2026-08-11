/// Strips quality tags, years, and episode tokens for matching — does not invent titles.
class SanitizedTitle {
  final String raw;
  /// Provider title with known tags removed. Never a different invented name.
  final String displayTitle;
  /// Lower-noise form used for TMDB / grouping.
  final String matchTitle;
  final int? year;
  final int? season;
  final int? episode;
  /// HD / 4K only when those tokens appear in the raw title.
  final String? qualityLabel;

  const SanitizedTitle({
    required this.raw,
    required this.displayTitle,
    required this.matchTitle,
    this.year,
    this.season,
    this.episode,
    this.qualityLabel,
  });

  String? get episodeBadge {
    if (season == null || episode == null) return null;
    return 'S$season:E$episode';
  }
}

/// Strips quality tags and extracts years for matching — does not invent titles.
class TitleNormalizer {
  static final RegExp _yearInParens = RegExp(r'\(\s*((?:19|20)\d{2})\s*\)');
  static final RegExp _yearBare = RegExp(
    r'(?:^|[\s._-])((?:19|20)\d{2})(?:$|[\s._-])',
  );
  static final RegExp _qualityTags = RegExp(
    r'\b(?:4K|UHD|FHD|HD|SD|HDR|HDR10|DV|H265|H\.?265|HEVC|X264|X265|'
    r'1080P?|720P?|2160P?|BluRay|WEB-?DL|WEBRip|HDTV|AAC|DDP?5\.?1)\b',
    caseSensitive: false,
  );
  static final RegExp _episodeToken = RegExp(
    r'\[?\s*S(\d{1,2})\s*[.\- ]?\s*E(\d{1,3})\s*\]?',
    caseSensitive: false,
  );
  static final RegExp _episodeVerbose = RegExp(
    r'\bSeason\s*(\d{1,2})\s*(?:Episode|Ep\.?)\s*(\d{1,3})\b',
    caseSensitive: false,
  );
  static final RegExp _episodeX = RegExp(r'\b(\d{1,2})x(\d{1,3})\b');
  static final RegExp _multiSpace = RegExp(r'\s+');
  static final RegExp _sepNoise = RegExp(r'[\._]+');

  /// Clean display/match title: remove quality tokens, years, episode tags.
  static String normalize(String raw) => parse(raw).matchTitle;

  static SanitizedTitle parse(String raw) {
    final original = raw.trim();
    if (original.isEmpty) {
      return const SanitizedTitle(raw: '', displayTitle: '', matchTitle: '');
    }

    final year = extractYear(original);
    final ep = _extractEpisode(original);
    final quality = qualityFromTitle(original);

    var s = original;
    s = s.replaceAll(_sepNoise, ' ');
    s = s.replaceAll(_yearInParens, ' ');
    s = s.replaceAll(_episodeToken, ' ');
    s = s.replaceAll(_episodeVerbose, ' ');
    s = s.replaceAll(_episodeX, ' ');
    s = s.replaceAll(_qualityTags, ' ');
    s = s.replaceAll(RegExp(r'[\[\]\{\}]'), ' ');
    s = s.replaceAll(_multiSpace, ' ').trim();
    s = s.replaceAll(RegExp(r'[\s\-|:]+$'), '').trim();
    s = s.replaceAll(RegExp(r'^[\s\-|:]+'), '').trim();

    final display = s.isEmpty ? original : s;
    return SanitizedTitle(
      raw: original,
      displayTitle: display,
      matchTitle: display,
      year: year,
      season: ep?.$1,
      episode: ep?.$2,
      qualityLabel: quality,
    );
  }

  static (int, int)? _extractEpisode(String raw) {
    final a = _episodeToken.firstMatch(raw);
    if (a != null) {
      final s = int.tryParse(a.group(1) ?? '');
      final e = int.tryParse(a.group(2) ?? '');
      if (s != null && e != null) return (s, e);
    }
    final b = _episodeVerbose.firstMatch(raw);
    if (b != null) {
      final s = int.tryParse(b.group(1) ?? '');
      final e = int.tryParse(b.group(2) ?? '');
      if (s != null && e != null) return (s, e);
    }
    final c = _episodeX.firstMatch(raw);
    if (c != null) {
      final s = int.tryParse(c.group(1) ?? '');
      final e = int.tryParse(c.group(2) ?? '');
      if (s != null && e != null) return (s, e);
    }
    return null;
  }

  /// HD / 4K only when present in the raw string — never inferred.
  static String? qualityFromTitle(String raw) {
    if (RegExp(r'\b(?:4K|UHD|2160P?)\b', caseSensitive: false).hasMatch(raw)) {
      return '4K';
    }
    if (RegExp(
      r'\b(?:1080P?|720P?|FHD|HD)\b',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'HD';
    }
    return null;
  }

  /// Grouping key for series rails. Same show → same key. Does not invent seasons.
  static String seriesGroupKey(String raw) {
    final parsed = parse(raw);
    return parsed.matchTitle.toLowerCase();
  }

  /// First plausible release year in the string, or null.
  static int? extractYear(String raw) {
    final paren = _yearInParens.firstMatch(raw);
    if (paren != null) {
      return int.tryParse(paren.group(1)!);
    }
    final bare = _yearBare.firstMatch(raw);
    if (bare != null) {
      return int.tryParse(bare.group(1)!);
    }
    return null;
  }

  /// Channel-id style: lowercase, alnum only.
  static String normalizeChannelId(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

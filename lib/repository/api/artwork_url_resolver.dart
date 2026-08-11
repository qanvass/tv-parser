/// Central artwork URL rules for playlist logos + optional TMDB image paths.
///
/// Live cards use square channel logos; Movies/Series cards use portrait
/// posters; heroes prefer landscape backdrops. Never invent copyrighted
/// brand assets — only playlist/CDN URLs and TMDB paths from a confident hit.
class ArtworkUrlResolver {
  static const String starliteMediaHost = 'https://media.starlite.best';
  static const String tmdbImageHost = 'https://image.tmdb.org/t/p';

  /// Live logo: prefer `tvg-logo` / `stream_icon`, else Starlite CDN by tvg-id.
  static String? resolveLiveLogo({
    String? primaryUrl,
    String? epgOrTvgId,
    String mediaHost = starliteMediaHost,
  }) {
    final primary = _clean(primaryUrl);
    if (primary != null) return primary;

    final id = _clean(epgOrTvgId);
    if (id == null) return null;
    final host = mediaHost.replaceAll(RegExp(r'/+$'), '');
    return '$host/$id.png';
  }

  /// Portrait poster for Movies / Series rails and cards.
  /// Preference: explicit poster → list icon/cover → detail movie_image → first backdrop.
  static String? resolveVodPoster({
    String? streamIcon,
    String? cover,
    String? movieImage,
    String? backdrop,
    List<String>? backdropPath,
  }) {
    return _firstValid([
      streamIcon,
      cover,
      movieImage,
      backdrop,
      if (backdropPath != null && backdropPath.isNotEmpty) backdropPath.first,
    ]);
  }

  /// Landscape hero / spotlight art (backdrops first, then poster).
  static String? resolveHeroBackdrop({
    String? backdrop,
    List<String>? backdropPath,
    String? posterFallback,
  }) {
    return _firstValid([
      backdrop,
      if (backdropPath != null && backdropPath.isNotEmpty) backdropPath.first,
      posterFallback,
    ]);
  }

  /// TMDB poster path → HTTPS image. [path] must come from a TMDB payload.
  static String? tmdbPoster(String? path) {
    final p = _tmdbPath(path);
    if (p == null) return null;
    return '$tmdbImageHost/w500$p';
  }

  /// TMDB backdrop path → HTTPS image.
  static String? tmdbBackdrop(String? path) {
    final p = _tmdbPath(path);
    if (p == null) return null;
    return '$tmdbImageHost/w1280$p';
  }

  static String? _tmdbPath(String? path) {
    if (path == null) return null;
    final s = path.trim();
    if (s.isEmpty || s == 'null') return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return s.startsWith('/') ? s : '/$s';
  }

  /// Headers for [CachedNetworkImage] — same family as the Dio catalog client.
  static const Map<String, String> imageHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12; Android TV) AppleWebKit/537.36',
    'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
  };

  /// True when [url] looks like a usable http(s) image reference.
  static bool isUsableImageUrl(String? url) {
    final cleaned = _clean(url);
    if (cleaned == null) return false;
    final lower = cleaned.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Host only — safe for debug logs. Never returns the full URL.
  static String? hostOnly(String? url) {
    final cleaned = _clean(url);
    if (cleaned == null || !isUsableImageUrl(cleaned)) return null;
    return Uri.tryParse(cleaned)?.host;
  }

  static String? _firstValid(List<String?> candidates) {
    for (final c in candidates) {
      if (isUsableImageUrl(c)) return _clean(c);
    }
    return null;
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    var s = value.trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    if ((s.startsWith('"') && s.endsWith('"') && s.length > 1) ||
        (s.startsWith("'") && s.endsWith("'") && s.length > 1)) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('//')) s = 'https:$s';
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }
}

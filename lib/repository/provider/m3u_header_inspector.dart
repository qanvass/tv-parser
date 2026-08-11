/// Extract XMLTV hints from M3U playlist headers without inventing URLs.
class M3uHeaderInspector {
  static final RegExp _urlTvg = RegExp(
    r'(?:url-tvg|x-tvg-url)\s*=\s*"([^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _urlTvgUnquoted = RegExp(
    r'(?:url-tvg|x-tvg-url)\s*=\s*([^\s",]+)',
    caseSensitive: false,
  );

  /// Returns the first `url-tvg` / `x-tvg-url` value from header lines, or null.
  static String? extractXmlTvUrl(String content) {
    if (content.isEmpty) return null;
    // Only scan the header / early lines — avoid huge playlist cost.
    final head = content.length > 8000 ? content.substring(0, 8000) : content;
    final lines = head.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      // First non-comment line ends the header scan.
      if (!t.startsWith('#')) break;
      if (!t.toUpperCase().contains('TVG')) continue;
      final quoted = _urlTvg.firstMatch(t);
      if (quoted != null) {
        final v = quoted.group(1)?.trim();
        if (v != null && v.isNotEmpty) return _firstUrl(v);
      }
      final unquoted = _urlTvgUnquoted.firstMatch(t);
      if (unquoted != null) {
        final v = unquoted.group(1)?.trim();
        if (v != null && v.isNotEmpty) return _firstUrl(v);
      }
    }
    // Also allow #EXTM3U url-tvg=... on the first line even without newline scan miss.
    final m = _urlTvg.firstMatch(head) ?? _urlTvgUnquoted.firstMatch(head);
    final v = m?.group(1)?.trim();
    if (v == null || v.isEmpty) return null;
    return _firstUrl(v);
  }

  static String _firstUrl(String raw) {
    // Some playlists comma-separate multiple EPG URLs.
    final first = raw.split(',').first.trim();
    return first;
  }

  static bool looksLikeM3u(String content) => content.contains('#EXTM3U');
}

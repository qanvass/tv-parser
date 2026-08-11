/// Pure helpers for Xtream-compatible host / probe URL construction.
class XtreamProbeUrlBuilder {
  /// Normalize a user-supplied host or full URL into scheme+authority[+path prefix].
  ///
  /// Examples:
  /// - `example.com` → `http://example.com`
  /// - `https://example.com:8080/` → `https://example.com:8080`
  /// - `http://host/c/` → `http://host/c` (keeps path prefix before player_api)
  static String normalizeHostBase(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (!s.contains('://')) {
      s = 'http://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return '';

    final path = uri.path;
    // Strip trailing player_api.php if user pasted a full API URL.
    var cleanPath = path;
    if (cleanPath.toLowerCase().endsWith('/player_api.php')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - '/player_api.php'.length);
    }
    cleanPath = cleanPath.replaceAll(RegExp(r'/+$'), '');

    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port$cleanPath';
  }

  /// Build `…/player_api.php?username=…&password=…&action=…` (optional action).
  /// Callers must not log the returned URL (contains credentials).
  static String playerApiUrl({
    required String hostBase,
    required String username,
    required String password,
    String? action,
    Map<String, String> extra = const {},
  }) {
    final base = normalizeHostBase(hostBase);
    final q = <String, String>{
      'username': username,
      'password': password,
      if (action != null && action.isNotEmpty) 'action': action,
      ...extra,
    };
    final uri = Uri.parse('$base/player_api.php').replace(queryParameters: q);
    return uri.toString();
  }

  /// Extract username/password from `/api/list/{user}/{pass}` style paths (generic).
  static (String, String)? credentialsFromListPath(String url) {
    try {
      final uri = Uri.parse(url);
      final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final listIdx = parts.indexOf('list');
      if (listIdx >= 0 && parts.length > listIdx + 2) {
        return (parts[listIdx + 1], parts[listIdx + 2]);
      }
    } catch (_) {}
    return null;
  }

  /// Guess an Xtream host base from an M3U playlist URL (scheme+host+port only).
  static String? hostBaseFromPlaylistUrl(String playlistUrl) {
    final uri = Uri.tryParse(playlistUrl);
    if (uri == null || uri.host.isEmpty) return null;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme.isEmpty ? 'http' : uri.scheme}://${uri.host}$port';
  }
}

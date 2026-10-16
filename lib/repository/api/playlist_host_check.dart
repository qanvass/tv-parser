import 'dart:async';
import 'dart:io';

/// Explains a failed M3U login when the cause is the network, not the
/// credentials: the playlist's server name does not exist, or the device is
/// offline. Shows only the host name — never the path (it may hold a password).
class PlaylistHostCheck {
  PlaylistHostCheck._();

  /// A clear message when [playlistUrl]'s server can't be found, else null
  /// (keep the generic message — e.g. server reachable but playlist invalid).
  static Future<String?> unreachableServerMessage(String playlistUrl) async {
    final raw = playlistUrl.trim();
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
    final host = uri?.host ?? '';
    if (host.isEmpty || InternetAddress.tryParse(host) != null) return null;

    if (await _resolves(host)) return null;
    if (!await _resolves('google.com')) {
      return 'No internet connection. Check your Wi-Fi or mobile data and '
          'try again.';
    }
    return 'Can\'t find the playlist server "$host". That address no longer '
        'exists — your username and password were not checked. Ask your '
        'provider for the current M3U link.';
  }

  static Future<bool> _resolves(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      // Slow DNS is not proof the server is gone.
      return true;
    } catch (_) {
      return true;
    }
  }
}

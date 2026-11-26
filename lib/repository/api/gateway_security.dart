import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Cryptographic handshake generator for securing TV Parser network requests
/// against reverse engineering, unauthorized web crawlers, and scrapers.
class GatewaySecurity {
  static const String _defaultSecret =
      'tvparser_sec_f98c7e3c12f047b79e058f82f644bf4f';
  static final Random _random = Random.secure();

  /// Generates the cryptographic security headers required by the TV Parser Gateway.
  static Map<String, String> generateHeaders(String path, {String? secret}) {
    final s = secret ?? _defaultSecret;
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _generateNonce();

    final payload = '$path:$timestamp:$nonce';
    final hmac = Hmac(sha256, utf8.encode(s));
    final signature = hmac.convert(utf8.encode(payload)).toString();

    return {
      'x-tvparser-timestamp': timestamp,
      'x-tvparser-nonce': nonce,
      'x-tvparser-signature': signature,
    };
  }

  /// Appends the cryptographic tokens as query parameters for media players (e.g. VLC)
  /// so that direct stream fetches pass gateway authentication.
  static String signUrl(String rawUrl, {String? secret}) {
    try {
      final uri = Uri.parse(rawUrl);
      final s = secret ?? _defaultSecret;
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateNonce();

      final payload = '${uri.path}:$timestamp:$nonce';
      final hmac = Hmac(sha256, utf8.encode(s));
      final signature = hmac.convert(utf8.encode(payload)).toString();

      final newQuery = Map<String, dynamic>.from(uri.queryParameters);
      newQuery['_ts'] = timestamp;
      newQuery['_nonce'] = nonce;
      newQuery['_sig'] = signature;

      return uri.replace(queryParameters: newQuery).toString();
    } catch (_) {
      return rawUrl;
    }
  }

  static String _generateNonce([int length = 16]) {
    final values = List<int>.generate(length, (_) => _random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

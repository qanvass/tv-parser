import 'dart:convert';

import 'package:get_storage/get_storage.dart';

import 'channel_intelligence_config.dart';

/// Persistent TTL cache for logo URLs and Gemini enrichment payloads.
class ChannelIntelligenceCache {
  static final GetStorage _box = GetStorage('channel_intelligence');
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await GetStorage.init('channel_intelligence');
    _initialized = true;
  }

  static String _key(String namespace, String id) => '$namespace:$id';

  static Future<Map<String, dynamic>?> read(String namespace, String id) async {
    await ensureInitialized();
    final raw = _box.read(_key(namespace, id));
    if (raw == null) return null;
    try {
      final decoded = raw is String ? jsonDecode(raw) : Map<String, dynamic>.from(raw);
      final expiresAt = decoded['expiresAt'];
      if (expiresAt != null) {
        final expiry = DateTime.tryParse(expiresAt.toString());
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          await _box.remove(_key(namespace, id));
          return null;
        }
      }
      final payload = decoded['payload'];
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> write(
    String namespace,
    String id,
    Map<String, dynamic> payload,
  ) async {
    await ensureInitialized();
    final envelope = {
      'payload': payload,
      'expiresAt': DateTime.now().add(ChannelIntelligenceConfig.cacheTtl).toIso8601String(),
    };
    await _box.write(_key(namespace, id), jsonEncode(envelope));
  }

  static Future<String?> readLogo(String normalizedName) async {
    final hit = await read('logo', normalizedName);
    return hit?['url']?.toString();
  }

  static Future<void> writeLogo(String normalizedName, String url) async {
    await write('logo', normalizedName, {'url': url});
  }
}

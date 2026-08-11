import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'provider_capabilities.dart';

/// Persists [ProviderCapabilities] next to M3U session cache (not SharedPreferences).
class ProviderCapabilityStore {
  ProviderCapabilityStore._();
  static final ProviderCapabilityStore instance = ProviderCapabilityStore._();

  static const fileName = 'provider_capabilities.json';

  ProviderCapabilities? _mem;
  Directory? _dir;

  ProviderCapabilities? get cached => _mem;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/m3u_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  Future<bool> save(ProviderCapabilities caps) async {
    _mem = caps;
    try {
      final dir = await _ensureDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonEncode(caps.toJson()), flush: true);
      return true;
    } catch (e) {
      debugPrint('[CAPABILITIES] save error: $e');
      return _mem != null;
    }
  }

  Future<ProviderCapabilities?> load() async {
    if (_mem != null) return _mem;
    try {
      final dir = await _ensureDir();
      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      _mem = ProviderCapabilities.fromJson(Map<String, dynamic>.from(raw));
      return _mem;
    } catch (e) {
      debugPrint('[CAPABILITIES] load error: $e');
      return null;
    }
  }

  Future<void> clear() async {
    _mem = null;
    try {
      final dir = await _ensureDir();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

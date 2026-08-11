import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'unified_media_metadata.dart';

/// Disk cache under `m3u_cache/` — never SharedPreferences.
class TmdbMetadataCache {
  TmdbMetadataCache({Directory? overrideDir}) : _overrideDir = overrideDir;

  final Directory? _overrideDir;
  final Map<String, Map<String, dynamic>> _mem = {};
  bool _loaded = false;
  bool _dirty = false;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          raw.forEach((k, v) {
            if (v is Map) {
              _mem['$k'] = Map<String, dynamic>.from(v);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[TMDB] cache load skipped: ${e.runtimeType}');
    }
    _loaded = true;
  }

  static const Duration missTtl = Duration(minutes: 20);

  bool has(String key) {
    final row = _mem[key];
    if (row == null) return false;
    if (row['miss'] == true && _missExpired(row)) {
      _mem.remove(key);
      return false;
    }
    return true;
  }

  bool isMiss(String key) {
    final row = _mem[key];
    if (row == null || row['miss'] != true) return false;
    if (_missExpired(row)) {
      _mem.remove(key);
      return false;
    }
    return true;
  }

  bool _missExpired(Map<String, dynamic> row) {
    final at = row['missAt'];
    if (at is! String) return true;
    final ts = DateTime.tryParse(at);
    if (ts == null) return true;
    return DateTime.now().difference(ts) > missTtl;
  }

  UnifiedMediaMetadata? get(String key) {
    final row = _mem[key];
    if (row == null || row['miss'] == true) return null;
    try {
      return UnifiedMediaMetadata.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> putHit(String key, UnifiedMediaMetadata meta) async {
    _mem[key] = meta.toJson();
    _dirty = true;
    await _maybeFlush();
  }

  Future<void> putMiss(String key) async {
    _mem[key] = {
      'miss': true,
      'missAt': DateTime.now().toIso8601String(),
    };
    _dirty = true;
    await _maybeFlush();
  }

  Future<void> flush() async {
    if (!_dirty) return;
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(_mem), flush: true);
      _dirty = false;
      _lastFlush = DateTime.now();
    } catch (e) {
      debugPrint('[TMDB] cache flush skipped: ${e.runtimeType}');
    }
  }

  Future<void> _maybeFlush() async {
    final elapsed = DateTime.now().difference(_lastFlush);
    if (elapsed.inSeconds >= 8) {
      await flush();
    }
  }

  Future<File> _file() async {
    final dir = _overrideDir ?? await _defaultDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/tmdb_enrichment.json');
  }

  static Future<Directory> _defaultDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/m3u_cache');
  }
}

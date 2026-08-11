import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Phase 1 local catalog timings. Never logs passwords or full URLs.
///
/// Disable with `--dart-define=ENABLE_CATALOG_PERF=false`.
class CatalogPerf {
  CatalogPerf._();

  static const bool enabled = bool.fromEnvironment(
    'ENABLE_CATALOG_PERF',
    defaultValue: true,
  );

  static DateTime? _origin;
  static String _reason = 'none';
  static final Map<String, int> _ms = <String, int>{};
  static final Map<String, int> _counts = <String, int>{};
  static final Map<String, DateTime> _anchors = <String, DateTime>{};

  static bool get hasSession => _origin != null;

  static String get isolateName => Isolate.current.debugName ?? 'unknown';

  static void beginSession({String reason = 'unknown'}) {
    if (!enabled) return;
    _origin = DateTime.now();
    _reason = reason;
    _ms.clear();
    _counts.clear();
    _anchors.clear();
    debugPrint(
      '[CATALOG_PERF] begin reason=$reason isolate=$isolateName',
    );
  }

  /// Named lap (e.g. movie_rail). First call wins.
  static void anchor(String key) {
    if (!enabled) return;
    _anchors.putIfAbsent(key, DateTime.now);
  }

  static void spanFromAnchor(String msKey, String anchorKey) {
    if (!enabled) return;
    final start = _anchors[anchorKey];
    if (start == null) return;
    _ms[msKey] = DateTime.now().difference(start).inMilliseconds;
  }

  /// Milliseconds since [beginSession].
  static void mark(String key) {
    if (!enabled) return;
    final origin = _origin;
    if (origin == null) return;
    _ms[key] = DateTime.now().difference(origin).inMilliseconds;
  }

  /// Explicit span (download, parse, isolate build, …).
  static void span(String key, int elapsedMs) {
    if (!enabled) return;
    _ms[key] = elapsedMs;
  }

  static void count(String key, int value) {
    if (!enabled) return;
    _counts[key] = value;
  }

  /// Immediate timeline event (MOVIES_START, MOVIES_FIRST_ROW, …).
  static void timeline(String event) {
    if (!enabled) return;
    final origin = _origin;
    final elapsed = origin == null
        ? -1
        : DateTime.now().difference(origin).inMilliseconds;
    debugPrint(
      '[CATALOG_PERF] event=$event elapsedMs=$elapsed isolate=$isolateName',
    );
  }

  static void flush(String stage) {
    if (!enabled) return;
    final buf = StringBuffer(
      '[CATALOG_PERF] stage=$stage reason=$_reason isolate=$isolateName',
    );
    void emitMs(String key) {
      final v = _ms[key];
      if (v != null) buf.write(' $key=$v');
    }

    void emitCount(String key) {
      final v = _counts[key];
      if (v != null) buf.write(' $key=$v');
    }

    emitMs('app_shell_ms');
    emitMs('login_validation_ms');
    emitMs('live_parse_ms');
    emitMs('downloadMs');
    emitMs('authMs');
    emitMs('parseMs');
    emitMs('warmLiveMs');
    emitMs('warmVodMs');
    emitMs('movie_cache_read_ms');
    emitMs('movie_json_decode_ms');
    emitMs('movie_group_ms');
    emitMs('movie_first_row_ms');
    emitMs('movie_first_row_from_tab_ms');
    emitMs('series_cache_read_ms');
    emitMs('series_json_decode_ms');
    emitMs('series_group_ms');
    emitMs('series_first_row_ms');
    emitMs('search_index_ms');
    emitMs('firstLiveMs');
    emitMs('firstMovieMs');
    emitMs('firstSeriesMs');
    emitMs('firstMoviePersistMs');
    emitMs('firstSeriesPersistMs');
    emitMs('vodCatalogReadyMs');
    emitMs('searchIndexReadyMs');
    emitCount('liveCount');
    emitCount('movieCount');
    emitCount('seriesCount');
    emitCount('movieCategoryCount');
    emitCount('seriesCategoryCount');
    emitCount('movieRowCount');
    emitCount('seriesRowCount');
    emitCount('liveCatCount');
    emitCount('movieCatCount');
    emitCount('seriesCatCount');
    emitCount('liveRowsPublished');
    emitCount('movieRowsPublished');
    emitCount('seriesRowsPublished');
    emitCount('movieJsonBytes');
    emitCount('seriesJsonBytes');
    emitCount('searchIndexEntries');
    debugPrint(buf.toString());
  }
}

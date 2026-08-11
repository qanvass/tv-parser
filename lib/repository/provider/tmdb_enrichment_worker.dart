import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'external_ids.dart';
import 'media_metadata_enrichment_service.dart';
import 'provider_enums.dart';
import 'title_normalizer.dart';
import 'tmdb_client.dart';
import 'tmdb_match.dart';
import 'tmdb_metadata_cache.dart';
import 'unified_media_metadata.dart';

class TmdbEnqueueRequest {
  final String rawTitle;
  final String? providerId;
  final ContentType type;
  final String? posterUrl;
  final String? backdropUrl;
  final String? trailerUrl;
  final String? overview;
  final int? year;
  final double? rating;
  final int? runtimeMinutes;
  final String? imdbId;

  const TmdbEnqueueRequest({
    required this.rawTitle,
    required this.type,
    this.providerId,
    this.posterUrl,
    this.backdropUrl,
    this.trailerUrl,
    this.overview,
    this.year,
    this.rating,
    this.runtimeMinutes,
    this.imdbId,
  });

  String get key => TmdbEnrichmentWorker.cacheKeyFor(
        rawTitle,
        providerId,
        type: type,
        year: year,
      );
}

/// Queued, rate-limited TMDB hydration. Never blocks splash / Live first frame.
class TmdbEnrichmentWorker extends ChangeNotifier {
  TmdbEnrichmentWorker({
    TmdbClient? client,
    TmdbMetadataCache? cache,
    MediaMetadataEnrichmentService? enricher,
    @visibleForTesting Duration pumpDelay = const Duration(milliseconds: 280),
  })  : _client = client ?? TmdbClient(),
        _cache = cache ?? TmdbMetadataCache(),
        _enricher = enricher ?? MediaMetadataEnrichmentService(tmdb: client),
        _pumpDelay = pumpDelay;

  static final TmdbEnrichmentWorker instance = TmdbEnrichmentWorker();

  final TmdbClient _client;
  final TmdbMetadataCache _cache;
  final MediaMetadataEnrichmentService _enricher;
  final Duration _pumpDelay;
  final Queue<TmdbEnqueueRequest> _queue = Queue<TmdbEnqueueRequest>();
  final Set<String> _queued = {};

  bool _pumping = false;

  bool get isEnabled => _client.isEnabled;

  UnifiedMediaMetadata? lookup(String key) => _cache.get(key);

  /// Debug-only counters for the v3008 rebuild audit. Release stays silent.
  @visibleForTesting
  int debugNotifyCount = 0;
  @visibleForTesting
  int debugCacheHitSkipCount = 0;

  /// [year] must be the same value stored on the rail record. Passing a
  /// stripped display title without [year] used to produce a different key
  /// than `cacheKeyFor(rawNameWithYear)` — UI lookup then missed every hit.
  ///
  /// When the caller already ran [TitleNormalizer.parse], pass that
  /// [matchTitle] (and the same [year]) to skip a second parse. The
  /// emitted string format is unchanged.
  static String cacheKeyFor(
    String rawTitle,
    String? providerId, {
    ContentType type = ContentType.unknown,
    int? year,
    String? matchTitle,
  }) {
    if (matchTitle != null) {
      return '${type.name}|${providerId ?? ''}|${matchTitle.toLowerCase()}|${year ?? ''}';
    }
    final parsed = TitleNormalizer.parse(rawTitle);
    return '${type.name}|${providerId ?? ''}|${parsed.matchTitle.toLowerCase()}|${year ?? parsed.year ?? ''}';
  }

  Future<void> ensureStarted() async {
    if (!_client.isEnabled) return;
    await _cache.load();
  }

  void prioritize(TmdbEnqueueRequest request) {
    if (!_client.isEnabled) return;
    if (_cache.has(request.key)) {
      // Cache already has art — posters/hero look up on build. A notify
      // here rebuilt the whole dashboard on every D-pad focus.
      if (kDebugMode) debugCacheHitSkipCount++;
      return;
    }
    _queue.removeWhere((j) => j.key == request.key);
    _queued.remove(request.key);
    _queue.addFirst(request);
    _queued.add(request.key);
    _pump();
  }

  void enqueue(TmdbEnqueueRequest request) {
    if (!_client.isEnabled) return;
    if (_cache.has(request.key) || _queued.contains(request.key)) return;
    _queued.add(request.key);
    _queue.add(request);
    _pump();
  }

  void enqueueMany(Iterable<TmdbEnqueueRequest> requests) {
    if (!_client.isEnabled) return;
    for (final request in requests) {
      if (_cache.has(request.key) || _queued.contains(request.key)) continue;
      _queued.add(request.key);
      _queue.add(request);
    }
    _pump();
  }

  @override
  void notifyListeners() {
    if (kDebugMode) debugNotifyCount++;
    super.notifyListeners();
  }

  Future<void> _pump() async {
    if (_pumping) return;
    if (!_client.isEnabled) return;
    _pumping = true;
    await _cache.load();
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeFirst();
        _queued.remove(job.key);
        if (_cache.has(job.key)) continue;
        try {
          final meta = await _enricher.enrich(
            rawTitle: job.rawTitle,
            contentType: job.type,
            provider: UnifiedMediaMetadata(
              title: job.rawTitle,
              year: job.year,
              posterUrl: job.posterUrl,
              backdropUrl: job.backdropUrl,
              trailerUrl: job.trailerUrl,
              overview: job.overview,
              rating: job.rating,
              runtimeMinutes: job.runtimeMinutes,
              contentType: job.type,
              externalIds: ExternalIds(
                imdb: TmdbMatch.normalizeImdbId(job.imdbId),
                providerStreamId: job.providerId,
              ),
            ),
          );
          final gotArt = (meta.posterUrl != null && meta.posterUrl!.isNotEmpty) ||
              (meta.backdropUrl != null && meta.backdropUrl!.isNotEmpty);
          if (gotArt || meta.source == MetadataSource.tmdb) {
            await _cache.putHit(job.key, meta);
            notifyListeners();
          } else {
            // Transient empty result — TTL miss, not a permanent skip.
            await _cache.putMiss(job.key);
          }
        } catch (e) {
          debugPrint('[TMDB] job skipped: ${e.runtimeType}');
          // Network/parse errors must not permanently poison the key.
        }
        await Future<void>.delayed(_pumpDelay);
      }
    } finally {
      await _cache.flush();
      _pumping = false;
    }
  }
}

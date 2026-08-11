import 'package:flutter/foundation.dart';

import '../api/artwork_url_resolver.dart';
import '../api/metadata_enrichment_service.dart';
import 'provider_enums.dart';
import 'title_normalizer.dart';
import 'tmdb_client.dart';
import 'tmdb_match.dart';
import 'tvmaze_client.dart';
import 'unified_media_metadata.dart';
import 'external_ids.dart';

/// Enrichment priority: provider title → TMDB art (high-confidence) → title-only.
///
/// Does not invent artwork, trailers, or plot. TMDB stays off until a key exists.
class MediaMetadataEnrichmentService {
  MediaMetadataEnrichmentService({
    TmdbClient? tmdb,
    TvmazeClient? tvmaze,
  })  : _tmdb = tmdb ?? TmdbClient(),
        _tvmaze = tvmaze ?? TvmazeClient();

  final TmdbClient _tmdb;
  final TvmazeClient _tvmaze;

  bool get tmdbEnabled => _tmdb.isEnabled;

  /// Merge known provider fields first; optionally probe external sources.
  Future<UnifiedMediaMetadata> enrich({
    required String rawTitle,
    ContentType contentType = ContentType.unknown,
    UnifiedMediaMetadata? provider,
  }) async {
    final parsed = TitleNormalizer.parse(rawTitle);
    final year = provider?.year ?? parsed.year;
    final normalized = parsed.matchTitle;

    final providerPoster = ArtworkUrlResolver.isUsableImageUrl(provider?.posterUrl)
        ? provider!.posterUrl
        : null;
    final providerBackdrop =
        ArtworkUrlResolver.isUsableImageUrl(provider?.backdropUrl)
            ? provider!.backdropUrl
            : null;

    UnifiedMediaMetadata? tmdbHit;
    String matchMethod = 'none';
    final isSeries = contentType == ContentType.series ||
        contentType == ContentType.episode;
    if (_tmdb.isEnabled && (normalized.isNotEmpty || !isSeries)) {
      if (!isSeries) {
        final imdb = TmdbMatch.normalizeImdbId(provider?.externalIds.imdb);
        if (imdb != null) {
          final hit = await _tmdb.findMovieByImdbId(imdb);
          if (hit != null) {
            matchMethod = 'imdb';
            tmdbHit = _fromTmdbHit(
              hit: hit,
              parsed: parsed,
              normalized: normalized,
              year: year,
              contentType: contentType,
              provider: provider,
              providerPoster: providerPoster,
              providerBackdrop: providerBackdrop,
              matchMethod: matchMethod,
            );
          }
        }
        if (tmdbHit == null && normalized.isNotEmpty) {
          final hit = await _tmdb.searchMovie(normalized, year: year);
          if (hit != null) {
            matchMethod = 'title_year';
            tmdbHit = _fromTmdbHit(
              hit: hit,
              parsed: parsed,
              normalized: normalized,
              year: year,
              contentType: contentType,
              provider: provider,
              providerPoster: providerPoster,
              providerBackdrop: providerBackdrop,
              matchMethod: matchMethod,
            );
          }
        }
      } else if (normalized.isNotEmpty) {
        final hit = await _tmdb.searchTv(normalized, year: year);
        if (hit != null) {
          matchMethod = 'title_year';
          tmdbHit = _fromTmdbHit(
            hit: hit,
            parsed: parsed,
            normalized: normalized,
            year: year,
            contentType: contentType,
            provider: provider,
            providerPoster: providerPoster,
            providerBackdrop: providerBackdrop,
            matchMethod: matchMethod,
          );
        }
      }
      _logMatch(
        matchMethod: matchMethod,
        hit: tmdbHit,
        providerPoster: providerPoster,
        providerBackdrop: providerBackdrop,
        providerTrailer: provider?.trailerUrl,
      );
    }

    if (tmdbHit != null) return tmdbHit;

    if (provider != null && _hasUsefulProvider(provider)) {
      return UnifiedMediaMetadata(
        title: parsed.displayTitle.isEmpty ? provider.title : parsed.displayTitle,
        originalTitle: provider.originalTitle,
        normalizedTitle:
            normalized.isEmpty ? provider.normalizedTitle : normalized,
        year: year,
        overview: _safeOverview(provider.overview),
        posterUrl: providerPoster,
        backdropUrl: providerBackdrop,
        trailerUrl: provider.trailerUrl,
        genres: provider.genres,
        rating: provider.rating,
        runtimeMinutes: provider.runtimeMinutes,
        contentType: provider.contentType != ContentType.unknown
            ? provider.contentType
            : contentType,
        externalIds: provider.externalIds,
        source: MetadataSource.provider,
      );
    }

    if (_tvmaze.isEnabled &&
        (contentType == ContentType.series ||
            contentType == ContentType.episode ||
            contentType == ContentType.unknown)) {
      final hit =
          await _tvmaze.searchShow(normalized.isEmpty ? rawTitle : normalized);
      if (hit != null) {
        // HTTP not wired — ignore until a real payload exists.
      }
    }

    return UnifiedMediaMetadata(
      title: parsed.displayTitle.isEmpty ? rawTitle.trim() : parsed.displayTitle,
      normalizedTitle: normalized.isEmpty ? null : normalized,
      year: year,
      posterUrl: providerPoster,
      backdropUrl: providerBackdrop,
      trailerUrl: provider?.trailerUrl,
      rating: provider?.rating,
      runtimeMinutes: provider?.runtimeMinutes,
      contentType: contentType,
      source: MetadataSource.none,
    );
  }

  bool _hasUsefulProvider(UnifiedMediaMetadata m) {
    return (m.overview != null && m.overview!.trim().isNotEmpty) ||
        (m.posterUrl != null && m.posterUrl!.isNotEmpty) ||
        (m.backdropUrl != null && m.backdropUrl!.isNotEmpty) ||
        (m.trailerUrl != null && m.trailerUrl!.isNotEmpty) ||
        m.genres.isNotEmpty ||
        m.externalIds.tmdb != null ||
        m.externalIds.imdb != null;
  }

  UnifiedMediaMetadata _fromTmdbHit({
    required Map<String, dynamic> hit,
    required SanitizedTitle parsed,
    required String normalized,
    required int? year,
    required ContentType contentType,
    required UnifiedMediaMetadata? provider,
    required String? providerPoster,
    required String? providerBackdrop,
    required String matchMethod,
  }) {
    return UnifiedMediaMetadata(
      title: parsed.displayTitle,
      originalTitle: provider?.originalTitle,
      normalizedTitle: normalized,
      year: year ?? hit['year'] as int?,
      overview: _safeOverview(provider?.overview) ??
          _safeOverview(hit['overview'] as String?),
      posterUrl: hit['poster_url'] as String? ?? providerPoster,
      backdropUrl: hit['backdrop_url'] as String? ?? providerBackdrop,
      trailerUrl: provider?.trailerUrl,
      genres: provider?.genres ?? const [],
      rating: provider?.rating ?? (hit['rating'] as num?)?.toDouble(),
      runtimeMinutes: provider?.runtimeMinutes,
      contentType: contentType,
      externalIds: ExternalIds(
        tmdb: hit['tmdb_id'] as String?,
        imdb: provider?.externalIds.imdb,
        tvgId: provider?.externalIds.tvgId,
        providerStreamId: provider?.externalIds.providerStreamId,
      ),
      source: MetadataSource.tmdb,
      matchMethod: matchMethod,
    );
  }

  void _logMatch({
    required String matchMethod,
    required UnifiedMediaMetadata? hit,
    required String? providerPoster,
    required String? providerBackdrop,
    required String? providerTrailer,
  }) {
    final poster = hit?.posterUrl ?? providerPoster;
    final backdrop = hit?.backdropUrl ?? providerBackdrop;
    final trailer = hit?.trailerUrl ?? providerTrailer;
    // print survives release; never include keys/URLs.
    // ignore: avoid_print
    print(
      '[TMDB_MATCH] matchMethod=$matchMethod '
      'hasPoster=${poster != null && poster.isNotEmpty} '
      'hasBackdrop=${backdrop != null && backdrop.isNotEmpty} '
      'hasTrailer=${trailer != null && trailer.isNotEmpty}',
    );
  }

  String? _safeOverview(String? overview) {
    if (overview == null) return null;
    final cleaned = MetadataEnrichmentService.cleanPlot(overview);
    if (cleaned == 'No description available for this title.') return null;
    return cleaned;
  }
}

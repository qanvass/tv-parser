import 'package:flutter/foundation.dart';

import '../../../repository/api/artwork_url_resolver.dart';
import '../../../repository/provider/tmdb_enrichment_worker.dart';
import '../widgets/tv_channel_grid.dart';
import 'cinematic_artwork.dart';

/// Safe [MOVIE_ART] logs — title + booleans + host only. Never URLs.
class MovieArtDebug {
  static const int sampleSize = 10;
  static final Set<String> _cardTitles = {};
  static bool _sampleLogged = false;
  static String? _lastHeroKey;

  static void logRailSample(List<TvChannelRow> rows) {
    if (_sampleLogged) return;
    _sampleLogged = true;
    var n = 0;
    var provider = 0;
    var resolved = 0;
    var backdrop = 0;
    for (final row in rows) {
      for (final stream in row.streams) {
        if (n >= sampleSize) break;
        n++;
        final extra = stream.enrichmentKey == null
            ? null
            : TmdbEnrichmentWorker.instance.lookup(stream.enrichmentKey!);
        final art = CinematicArtwork.fromRecord(stream, extra: extra);
        final hasProvider = ArtworkUrlResolver.isUsableImageUrl(stream.imageUrl);
        final hasPoster = art.poster != null;
        final hasBackdrop = art.backdrop != null;
        if (hasProvider) provider++;
        if (hasPoster) resolved++;
        if (hasBackdrop) backdrop++;
        debugPrint(
          '[MOVIE_ART] sample title="${stream.title}" '
          'hasProviderArtwork=$hasProvider '
          'hasResolvedPoster=$hasPoster '
          'hasBackdrop=$hasBackdrop '
          'posterHost=${ArtworkUrlResolver.hostOnly(art.poster) ?? "none"}',
        );
      }
      if (n >= sampleSize) break;
    }
    final denom = n == 0 ? 1 : n;
    debugPrint(
      '[MOVIE_ART] sample n=$n '
      'providerArtworkPct=${((provider / denom) * 100).round()} '
      'resolvedArtworkPct=${((resolved / denom) * 100).round()} '
      'backdropPct=${((backdrop / denom) * 100).round()} '
      'tmdbWorker=${TmdbEnrichmentWorker.instance.isEnabled}',
    );
  }

  static void logCard({
    required String title,
    required bool hasProviderArtwork,
    required bool hasResolvedPoster,
    required bool hasBackdrop,
    String? posterHost,
    String? load,
  }) {
    if (_cardTitles.length >= sampleSize && !_cardTitles.contains(title)) {
      return;
    }
    _cardTitles.add(title);
    debugPrint(
      '[MOVIE_ART] card title="$title" '
      'hasProviderArtwork=$hasProviderArtwork '
      'hasResolvedPoster=$hasResolvedPoster '
      'hasBackdrop=$hasBackdrop '
      'posterHost=${posterHost ?? "none"} '
      'imageLoad=${load ?? "pending"}',
    );
  }

  static void logHero({
    required String title,
    required String mode,
    required bool hasBackdrop,
    required bool hasPoster,
    required bool hasTrailerMeta,
    required bool playableTrailer,
  }) {
    final key =
        '$title|$mode|$hasBackdrop|$hasPoster|$hasTrailerMeta|$playableTrailer';
    if (_lastHeroKey == key) return;
    _lastHeroKey = key;
    debugPrint(
      '[MOVIE_ART] hero title="$title" mode=$mode '
      'hasBackdrop=$hasBackdrop hasPoster=$hasPoster '
      'hasTrailerMeta=$hasTrailerMeta playableTrailer=$playableTrailer',
    );
  }
}

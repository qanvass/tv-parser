import '../../../repository/api/artwork_url_resolver.dart';
import '../../../repository/provider/unified_media_metadata.dart';
import '../widgets/tv_channel_grid.dart';
import 'playable_trailer_url.dart';

enum CinematicArtKind {
  poster,
  backdrop,
  clearLogo,
  channelLogo,
  episodeStill,
  trailer,
}

enum CinematicHeroVisual {
  video,
  motionBackdrop,
  posterCinematicFallback,
}

/// First-class art slots. Null means missing — never invent, never block render.
class CinematicArtwork {
  final String? poster;
  final String? backdrop;
  final String? clearLogo;
  final String? channelLogo;
  final String? episodeStill;
  final String? trailer;

  const CinematicArtwork({
    this.poster,
    this.backdrop,
    this.clearLogo,
    this.channelLogo,
    this.episodeStill,
    this.trailer,
  });

  bool get hasPoster => poster != null;
  bool get hasBackdrop => backdrop != null && backdrop != poster;
  bool get hasAnyStill => poster != null || backdrop != null;

  /// Landscape stage URL. Portrait-only titles keep [poster] and use
  /// the portrait cinematic treatment instead of stretching 16:9.
  String? get displayBackdrop => backdrop ?? poster;

  bool get isPortraitOnly =>
      poster != null && (backdrop == null || backdrop == poster);

  String? urlFor(CinematicArtKind kind) {
    switch (kind) {
      case CinematicArtKind.poster:
        return poster;
      case CinematicArtKind.backdrop:
        return backdrop;
      case CinematicArtKind.clearLogo:
        return clearLogo;
      case CinematicArtKind.channelLogo:
        return channelLogo;
      case CinematicArtKind.episodeStill:
        return episodeStill;
      case CinematicArtKind.trailer:
        return trailer;
    }
  }

  static CinematicArtwork fromRecord(
    TvStreamRecord stream, {
    UnifiedMediaMetadata? extra,
  }) {
    // 1 cached/TMDB poster, 2 provider imageUrl. Do not stuff a backdrop
    // into the 2:3 card slot — hero handles portrait-as-bg separately.
    final poster = ArtworkUrlResolver.resolveVodPoster(
      streamIcon: extra?.posterUrl,
      cover: stream.imageUrl,
    );
    final backdrop = ArtworkUrlResolver.resolveHeroBackdrop(
      backdrop: extra?.backdropUrl,
      posterFallback: null,
    ) ??
        ArtworkUrlResolver.resolveHeroBackdrop(
          backdrop: stream.backdropUrl,
          posterFallback: null,
        );
    return CinematicArtwork(
      poster: poster,
      backdrop: backdrop ?? poster,
      clearLogo: null,
      channelLogo: stream.isVod ? null : _img(stream.imageUrl),
      episodeStill: null,
      trailer: PlayableTrailerUrl.resolve(extra?.trailerUrl) ??
          PlayableTrailerUrl.resolve(stream.trailerUrl),
    );
  }

  static String? _img(String? url) =>
      ArtworkUrlResolver.isUsableImageUrl(url) ? url : null;
}

/// One selected-movie snapshot. Hero and actions read only this.
class CinematicSelectedMovie {
  final TvStreamRecord stream;
  final CinematicArtwork art;
  final UnifiedMediaMetadata? extra;

  const CinematicSelectedMovie({
    required this.stream,
    required this.art,
    this.extra,
  });

  String get title => stream.title;
  int? get year => extra?.year ?? stream.year;
  double? get rating => extra?.rating ?? stream.rating;
  int? get runtimeMinutes => extra?.runtimeMinutes ?? stream.runtimeMinutes;
  String? get overview => extra?.overview ?? stream.overview;
  String? get qualityLabel => stream.qualityLabel;
  String? get genre {
    final genres = extra?.genres;
    if (genres == null || genres.isEmpty) return null;
    final first = genres.first.trim();
    return first.isEmpty ? null : first;
  }

  bool get hasTrailerMeta {
    final raw = extra?.trailerUrl ?? stream.trailerUrl;
    return raw != null && raw.trim().isNotEmpty && raw != 'null';
  }

  bool get hasPlayableTrailer => art.trailer != null;

  CinematicHeroVisual visual({required bool trailerVisible}) {
    if (trailerVisible && hasPlayableTrailer) {
      return CinematicHeroVisual.video;
    }
    if (art.hasAnyStill) return CinematicHeroVisual.motionBackdrop;
    return CinematicHeroVisual.posterCinematicFallback;
  }

  String visualLabel({required bool trailerVisible}) {
    switch (visual(trailerVisible: trailerVisible)) {
      case CinematicHeroVisual.video:
        return 'VIDEO';
      case CinematicHeroVisual.motionBackdrop:
        return 'MOTION BACKDROP';
      case CinematicHeroVisual.posterCinematicFallback:
        return 'POSTER CINEMATIC FALLBACK';
    }
  }
}

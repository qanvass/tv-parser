import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../repository/api/artwork_url_resolver.dart';
import '../../../repository/provider/tmdb_enrichment_worker.dart';
import '../widgets/tv_artwork_shimmer.dart';
import '../widgets/tv_channel_grid.dart';
import 'cinematic_artwork.dart';
import 'cinematic_title_placeholder.dart';
import 'cinematic_tokens.dart';
import 'movie_art_debug.dart';

class CinematicPosterCard extends StatefulWidget {
  static const double width = 140;
  static const double height = 210;

  final TvStreamRecord stream;
  final VoidCallback onSelected;
  final ValueChanged<TvStreamRecord>? onFocused;

  const CinematicPosterCard({
    super.key,
    required this.stream,
    required this.onSelected,
    this.onFocused,
  });

  @override
  State<CinematicPosterCard> createState() => _CinematicPosterCardState();
}

class _CinematicPosterCardState extends State<CinematicPosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) {
        setState(() => _focused = value);
        if (value) widget.onFocused?.call(widget.stream);
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.gameButtonA ||
            k == LogicalKeyboardKey.space) {
          widget.onSelected();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? CinematicTokens.focusScale : 1.0,
        duration: CinematicMotion.focus,
        curve: CinematicMotion.standard,
        child: AnimatedSlide(
          offset: _focused ? const Offset(0, -0.018) : Offset.zero,
          duration: CinematicMotion.focus,
          curve: CinematicMotion.standard,
          child: SizedBox(
            width: CinematicPosterCard.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    canRequestFocus: false,
                    onTap: widget.onSelected,
                    borderRadius:
                        BorderRadius.circular(CinematicTokens.radiusPoster),
                    child: AnimatedContainer(
                      duration: CinematicMotion.focus,
                      curve: CinematicMotion.standard,
                      width: CinematicPosterCard.width,
                      height: CinematicPosterCard.height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          CinematicTokens.radiusPoster,
                        ),
                        border: Border.all(
                          width: _focused ? 1.4 : 0,
                          color: _focused
                              ? CinematicTokens.focus.withValues(alpha: 0.9)
                              : Colors.transparent,
                        ),
                        boxShadow: _focused
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  blurRadius: 16,
                                  spreadRadius: 0.4,
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListenableBuilder(
                        listenable: TmdbEnrichmentWorker.instance,
                        builder: (context, _) {
                          final extra = widget.stream.enrichmentKey == null
                              ? null
                              : TmdbEnrichmentWorker.instance
                                  .lookup(widget.stream.enrichmentKey!);
                          final art = CinematicArtwork.fromRecord(
                            widget.stream,
                            extra: extra,
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CinematicTitlePlaceholder(
                                title: widget.stream.title,
                              ),
                              _PosterArt(
                                url: art.poster,
                                title: widget.stream.title,
                                hasProvider: ArtworkUrlResolver
                                    .isUsableImageUrl(widget.stream.imageUrl),
                                hasResolved: art.hasPoster,
                                hasBackdrop: art.hasBackdrop,
                              ),
                              if (_focused)
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0x18FFFFFF),
                                  ),
                                ),
                              if ((widget.stream.watchProgress ?? 0) > 0.02)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: LinearProgressIndicator(
                                    value: widget.stream.watchProgress!
                                        .clamp(0.0, 1.0),
                                    minHeight: 3,
                                    backgroundColor: Colors.black45,
                                    color: CinematicTokens.accent,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.stream.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _focused
                        ? CinematicTokens.textPrimary
                        : CinematicTokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterArt extends StatelessWidget {
  final String? url;
  final String title;
  final bool hasProvider;
  final bool hasResolved;
  final bool hasBackdrop;

  const _PosterArt({
    this.url,
    required this.title,
    required this.hasProvider,
    required this.hasResolved,
    required this.hasBackdrop,
  });

  @override
  Widget build(BuildContext context) {
    if (!ArtworkUrlResolver.isUsableImageUrl(url)) {
      MovieArtDebug.logCard(
        title: title,
        hasProviderArtwork: hasProvider,
        hasResolvedPoster: hasResolved,
        hasBackdrop: hasBackdrop,
        posterHost: null,
        load: 'fallback_generated',
      );
      return const SizedBox.expand();
    }
    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        width: CinematicPosterCard.width,
        height: CinematicPosterCard.height,
        memCacheWidth: 320,
        fadeInDuration: CinematicMotion.backdrop,
        httpHeaders: ArtworkUrlResolver.imageHeaders,
        placeholder: (_, _) => const TvArtworkShimmer(),
        imageBuilder: (context, provider) {
          MovieArtDebug.logCard(
            title: title,
            hasProviderArtwork: hasProvider,
            hasResolvedPoster: true,
            hasBackdrop: hasBackdrop,
            posterHost: ArtworkUrlResolver.hostOnly(url),
            load: 'success',
          );
          return Image(image: provider, fit: BoxFit.cover);
        },
        errorWidget: (_, _, error) {
          MovieArtDebug.logCard(
            title: title,
            hasProviderArtwork: hasProvider,
            hasResolvedPoster: hasResolved,
            hasBackdrop: hasBackdrop,
            posterHost: ArtworkUrlResolver.hostOnly(url),
            load: 'failure_${error.runtimeType}',
          );
          return CinematicTitlePlaceholder(title: title);
        },
      ),
    );
  }
}

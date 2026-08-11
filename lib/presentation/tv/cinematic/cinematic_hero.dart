import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../repository/api/artwork_url_resolver.dart';
import '../widgets/tv_status_clock.dart';
import 'cinematic_artwork.dart';
import 'cinematic_stadium_button.dart';
import 'cinematic_title_placeholder.dart';
import 'cinematic_tokens.dart';
import 'hero_preview_controller.dart';
import 'movie_art_debug.dart';

class CinematicHero extends StatelessWidget {
  final CinematicSelectedMovie? selected;
  final HeroPreviewController preview;
  final bool kenBurns;
  final VoidCallback? onWatch;
  final VoidCallback? onMyList;
  final bool inMyList;
  final String eyebrow;

  const CinematicHero({
    super.key,
    required this.selected,
    required this.preview,
    required this.kenBurns,
    this.onWatch,
    this.onMyList,
    this.inMyList = false,
    this.eyebrow = 'MOVIES',
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preview,
      builder: (context, _) {
        final movie = selected;
        final art = movie?.art ?? const CinematicArtwork();
        final title = movie?.title ?? 'Movies';
        final year = movie?.year;
        final rating = movie?.rating;
        final runtime = movie?.runtimeMinutes;
        final overview = movie?.overview;
        final genre = movie?.genre;
        final meta = <String>[
          if (year != null) '$year',
          if (runtime != null && runtime > 0) '${runtime}m',
          if (rating != null && rating > 0) rating.toStringAsFixed(1),
          if (genre != null) genre,
          if (movie?.qualityLabel != null) movie!.qualityLabel!,
        ].join('  ·  ');

        if (movie != null) {
          MovieArtDebug.logHero(
            title: movie.title,
            mode: movie.visualLabel(trailerVisible: preview.trailerVisible),
            hasBackdrop: art.hasBackdrop,
            hasPoster: art.hasPoster,
            hasTrailerMeta: movie.hasTrailerMeta,
            playableTrailer: movie.hasPlayableTrailer,
          );
        }

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CinematicTitlePlaceholder(title: title, hero: true),
              _HeroStage(
                art: art,
                title: title,
                kenBurns: kenBurns && preview.player == null,
              ),
              if (preview.player != null && preview.trailerVisible)
                _TrailerLayer(controller: preview.player!),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      CinematicTokens.scrimLeft,
                      CinematicTokens.scrimMid,
                      CinematicTokens.scrimClear,
                      Color(0x660B0B0E),
                    ],
                    stops: [0.0, 0.34, 0.72, 1.0],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x660B0B0E),
                      CinematicTokens.scrimClear,
                      CinematicTokens.scrimBottom,
                    ],
                    stops: [0.0, 0.42, 1.0],
                  ),
                ),
              ),
              const Positioned(
                top: 4,
                right: 0,
                child: TvStatusClock(),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18, 28, 18),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: AnimatedSwitcher(
                        duration: CinematicMotion.heroText,
                        switchInCurve: CinematicMotion.standard,
                        child: Column(
                          key: ValueKey(
                            movie?.stream.streamId ?? movie?.title ?? 'empty',
                          ),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow,
                              style: TextStyle(
                                color: CinematicTokens.textSecondary
                                    .withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _HeroTitle(title: title, logoUrl: art.clearLogo),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CinematicTokens.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (overview != null &&
                                overview.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                overview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: CinematicTokens.textSecondary
                                      .withValues(alpha: 0.85),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                CinematicStadiumButton(
                                  label: 'Watch',
                                  icon: Icons.play_arrow_rounded,
                                  onPressed: movie == null ||
                                          movie.stream.streamUrl.isEmpty
                                      ? null
                                      : onWatch,
                                ),
                                CinematicStadiumButton(
                                  label: inMyList ? 'In My List' : 'My List',
                                  icon: inMyList
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  onPressed: movie == null ? null : onMyList,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroTitle extends StatelessWidget {
  final String title;
  final String? logoUrl;

  const _HeroTitle({required this.title, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    if (ArtworkUrlResolver.isUsableImageUrl(logoUrl)) {
      return SizedBox(
        height: 72,
        child: Align(
          alignment: Alignment.centerLeft,
          child: CachedNetworkImage(
            imageUrl: logoUrl!,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            memCacheWidth: 640,
            fadeInDuration: CinematicMotion.heroText,
            httpHeaders: ArtworkUrlResolver.imageHeaders,
            errorWidget: (_, _, _) => _TitleText(title),
          ),
        ),
      );
    }
    return _TitleText(title);
  }
}

class _TitleText extends StatelessWidget {
  final String title;

  const _TitleText(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: CinematicTokens.textPrimary,
        fontSize: 40,
        fontWeight: FontWeight.w900,
        height: 1.05,
        letterSpacing: -0.8,
      ),
    );
  }
}

class _HeroStage extends StatefulWidget {
  final CinematicArtwork art;
  final String title;
  final bool kenBurns;

  const _HeroStage({
    required this.art,
    required this.title,
    required this.kenBurns,
  });

  @override
  State<_HeroStage> createState() => _HeroStageState();
}

class _HeroStageState extends State<_HeroStage> {
  late Widget _first;
  late Widget _second;
  late String _slotKey;
  CrossFadeState _fade = CrossFadeState.showFirst;

  @override
  void initState() {
    super.initState();
    _first = _buildStage(widget);
    _second = _first;
    _slotKey = _stageKey(widget);
  }

  @override
  void didUpdateWidget(covariant _HeroStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _stageKey(widget);
    if (nextKey == _slotKey) return;
    final next = _buildStage(widget);
    setState(() {
      if (_fade == CrossFadeState.showFirst) {
        _second = next;
        _fade = CrossFadeState.showSecond;
      } else {
        _first = next;
        _fade = CrossFadeState.showFirst;
      }
      _slotKey = nextKey;
    });
  }

  static String _stageKey(_HeroStage w) {
    final landscape = w.art.hasBackdrop ? w.art.backdrop : null;
    if (ArtworkUrlResolver.isUsableImageUrl(landscape)) {
      return 'bd-$landscape';
    }
    if (ArtworkUrlResolver.isUsableImageUrl(w.art.poster)) {
      return 'pt-${w.art.poster}';
    }
    return 'ph-${w.title}';
  }

  static Widget _buildStage(_HeroStage w) {
    final landscape = w.art.hasBackdrop ? w.art.backdrop : null;
    final poster = w.art.poster;
    if (ArtworkUrlResolver.isUsableImageUrl(landscape)) {
      return w.kenBurns
          ? _KenBurnsStill(url: landscape!)
          : _StillImage(url: landscape!);
    }
    if (ArtworkUrlResolver.isUsableImageUrl(poster)) {
      return _PortraitCinematicBg(url: poster!, kenBurns: w.kenBurns);
    }
    return _KenBurnsChild(
      enabled: w.kenBurns,
      child: CinematicTitlePlaceholder(title: w.title, hero: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: SizedBox.expand(child: _first),
      secondChild: SizedBox.expand(child: _second),
      crossFadeState: _fade,
      duration: CinematicMotion.backdrop,
      firstCurve: CinematicMotion.standard,
      secondCurve: CinematicMotion.standard,
      sizeCurve: CinematicMotion.standard,
      layoutBuilder: (top, topKey, bottom, bottomKey) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(key: bottomKey, child: bottom),
            Positioned.fill(key: topKey, child: top),
          ],
        );
      },
    );
  }
}

class _StillImage extends StatelessWidget {
  final String url;

  const _StillImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: 1280,
      fadeInDuration: CinematicMotion.backdrop,
      httpHeaders: ArtworkUrlResolver.imageHeaders,
      placeholder: (_, _) => const SizedBox.expand(),
      errorWidget: (_, _, _) => const SizedBox.expand(),
    );
  }
}

class _KenBurnsStill extends StatelessWidget {
  final String url;

  const _KenBurnsStill({required this.url});

  @override
  Widget build(BuildContext context) {
    return _KenBurnsChild(
      enabled: true,
      child: _StillImage(url: url),
    );
  }
}

/// 22s, 1.00→1.04 zoom + subtle horizontal drift. Previous animation dies
/// with the widget key when the selected title changes.
class _KenBurnsChild extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _KenBurnsChild({
    required this.child,
    required this.enabled,
  });

  @override
  State<_KenBurnsChild> createState() => _KenBurnsChildState();
}

class _KenBurnsChildState extends State<_KenBurnsChild>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<Offset> _drift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: CinematicMotion.kenBurns,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _drift = Tween<Offset>(
      begin: const Offset(-0.012, 0),
      end: const Offset(0.012, 0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.enabled) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _KenBurnsChild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return FractionalTranslation(
          translation: _drift.value,
          child: Transform.scale(
            scale: _scale.value,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Portrait poster as cinematic 16:9: blurred enlarged fill + sharp poster right.
class _PortraitCinematicBg extends StatelessWidget {
  final String url;
  final bool kenBurns;

  const _PortraitCinematicBg({
    required this.url,
    required this.kenBurns,
  });

  @override
  Widget build(BuildContext context) {
    final blurred = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
      child: Transform.scale(
        scale: 1.22,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.38),
            BlendMode.darken,
          ),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: 720,
            fadeInDuration: CinematicMotion.backdrop,
            httpHeaders: ArtworkUrlResolver.imageHeaders,
            placeholder: (_, _) => const SizedBox.expand(),
            errorWidget: (_, _, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        kenBurns ? _KenBurnsChild(enabled: true, child: blurred) : blurred,
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 36, 18),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(CinematicTokens.radiusPoster),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  fadeInDuration: CinematicMotion.heroText,
                  httpHeaders: ArtworkUrlResolver.imageHeaders,
                  placeholder: (_, _) => const SizedBox.expand(),
                  errorWidget: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrailerLayer extends StatelessWidget {
  final VideoPlayerController controller;

  const _TrailerLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return AnimatedOpacity(
      opacity: 1,
      duration: CinematicMotion.previewFade,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

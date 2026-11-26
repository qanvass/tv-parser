import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';
import '../../tv/cinematic/cinematic_title_placeholder.dart';

/// Presentation pieces of the series details page. They draw what they are
/// given and hold no catalog, metadata or playback logic.

/// Colors used only by the series details page and the paused player overlay.
abstract final class SeriesDetailTokens {
  static const Color background = Color(0xFF050A18);
  static const Color surface = Color(0xFF0C1626);
  static const Color surfaceRaised = Color(0xFF12203A);
  static const Color hairline = Color(0x24FFFFFF);
  static const Color textSecondary = Color(0xFFB4C0D4);
  static const Color textMuted = Color(0xFF7E8CA6);
}

/// Full-page backdrop with the scrims that keep text readable. Falls back to
/// a title-tinted gradient when the show has no landscape artwork.
class SeriesBackdrop extends StatelessWidget {
  const SeriesBackdrop({super.key, required this.title, this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Opacity(
      opacity: 0.55,
      child: CinematicTitlePlaceholder(
        title: title,
        hero: true,
        showLabels: false,
      ),
    );
    final url = imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: SeriesDetailTokens.background),
        if (url == null)
          fallback
        else
          CachedNetworkImage(
            imageUrl: url,
            memCacheWidth: 1280,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            fadeInDuration: const Duration(milliseconds: 350),
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xF2050A18), Color(0xB3050A18), Color(0x26050A18)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x8C050A18),
                Color(0x33050A18),
                Color(0xE6050A18),
                SeriesDetailTokens.background,
              ],
              stops: [0.0, 0.28, 0.58, 0.72],
            ),
          ),
        ),
      ],
    );
  }
}

/// 2:3 series poster. Shows a titled placeholder when there is no artwork.
class SeriesPoster extends StatelessWidget {
  const SeriesPoster({
    super.key,
    required this.title,
    required this.width,
    this.imageUrl,
  });

  final String title;
  final double width;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = CinematicTitlePlaceholder(title: title, badge: 'SERIES');
    final url = imageUrl;
    return Container(
      width: width,
      height: width * 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorPrimary.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: kColorPrimary.withValues(alpha: 0.18),
            blurRadius: 18,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              memCacheWidth: 400,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

/// Pill button of the header action row.
class SeriesActionButton extends StatelessWidget {
  const SeriesActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.focused,
    required this.onTap,
    this.primary = false,
    this.iconColor,
    this.scale = 1,
  });

  final IconData icon;
  final String label;
  final bool focused;
  final bool primary;
  final Color? iconColor;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final fill = primary
        ? kColorPrimary
        : focused
        ? SeriesDetailTokens.surfaceRaised
        : const Color(0xB30A1220);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40 * scale,
        padding: EdgeInsets.symmetric(horizontal: (primary ? 22 : 16) * scale),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: focused
                ? Colors.white
                : primary
                ? kColorPrimary
                : Colors.white.withValues(alpha: 0.28),
            width: 2,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: kColorPrimary.withValues(alpha: 0.55),
                    blurRadius: 14,
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: (primary ? 20 : 17) * scale,
              color: iconColor ?? Colors.white,
            ),
            SizedBox(width: 8 * scale),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: (primary ? 15 : 13) * scale,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Season selector pill. [selected] is the season whose episodes are listed;
/// [focused] adds the remote-focus outline.
class SeriesSeasonPill extends StatelessWidget {
  const SeriesSeasonPill({
    super.key,
    required this.label,
    required this.selected,
    required this.focused,
    required this.onTap,
    this.scale = 1,
  });

  final String label;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34 * scale,
          alignment: Alignment.center,
          margin: EdgeInsets.only(right: 10 * scale),
          decoration: BoxDecoration(
            color: selected ? kColorPrimary : SeriesDetailTokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: focused
                  ? Colors.white
                  : selected
                  ? kColorPrimary
                  : Colors.white.withValues(alpha: 0.22),
              width: 2,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: kColorPrimary.withValues(alpha: 0.55),
                      blurRadius: 12,
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : SeriesDetailTokens.textSecondary,
              fontSize: 13 * scale,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 16:9 placeholder for an episode without a still. Never a stretched poster.
class SeriesEpisodeStillPlaceholder extends StatelessWidget {
  const SeriesEpisodeStillPlaceholder({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14284A), Color(0xFF0A1424), Color(0xFF07101E)],
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.16),
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Landscape episode card: still, play mark, runtime, watch progress, and the
/// episode number and title underneath.
class SeriesEpisodeCard extends StatelessWidget {
  const SeriesEpisodeCard({
    super.key,
    required this.episodeLabel,
    required this.seasonLabel,
    required this.title,
    required this.focused,
    required this.selected,
    required this.onTap,
    this.stillUrl,
    this.runtime,
    this.progress,
    this.scale = 1,
  });

  /// e.g. `E2`.
  final String episodeLabel;

  /// e.g. `Season 2`. Empty hides it.
  final String seasonLabel;
  final String title;
  final String? stillUrl;
  final String? runtime;

  /// Watched fraction 0..1, or null when the episode has no saved progress.
  final double? progress;
  final bool focused;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final placeholder = SeriesEpisodeStillPlaceholder(label: episodeLabel);
    final url = stillUrl;
    final p = progress;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: focused ? 1.04 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: SeriesDetailTokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused
                  ? kColorFocus
                  : selected
                  ? kColorPrimary.withValues(alpha: 0.55)
                  : SeriesDetailTokens.hairline,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: focused ? 0.6 : 0.35),
                blurRadius: focused ? 18 : 8,
                offset: Offset(0, focused ? 8 : 3),
              ),
              if (focused)
                BoxShadow(
                  color: kColorPrimary.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url == null)
                      placeholder
                    else
                      CachedNetworkImage(
                        imageUrl: url,
                        memCacheWidth: 360,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, _) => placeholder,
                        errorWidget: (_, _, _) => placeholder,
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)],
                          stops: [0.55, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7 * scale,
                      bottom: 7 * scale,
                      child: Container(
                        width: 22 * scale,
                        height: 22 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 15 * scale,
                        ),
                      ),
                    ),
                    if (runtime != null)
                      Positioned(
                        right: 6 * scale,
                        bottom: 7 * scale,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5 * scale,
                            vertical: 2 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            runtime!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5 * scale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (p != null && p > 0)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: FractionallySizedBox(
                          widthFactor: p.clamp(0.02, 1.0),
                          child: Container(height: 3, color: kColorPrimary),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  9 * scale,
                  7 * scale,
                  9 * scale,
                  8 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: episodeLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5 * scale,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (seasonLabel.isNotEmpty)
                            TextSpan(
                              text: '   $seasonLabel',
                              style: TextStyle(
                                color: SeriesDetailTokens.textMuted,
                                fontSize: 10.5 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3 * scale),
                    SizedBox(
                      height: 29 * scale,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SeriesDetailTokens.textSecondary,
                          fontSize: 11 * scale,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

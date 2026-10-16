import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../repository/provider/provider_enums.dart';
import '../../../repository/provider/tmdb_enrichment_worker.dart';
import '../../../repository/provider/unified_media_metadata.dart';

enum PosterAspect { vertical, landscape }

class HorizontalPosterRows extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final Color? titleIconColor;
  final int itemCount;
  final PosterAspect aspect;
  final Widget? Function(BuildContext, int) itemBuilder;
  final VoidCallback? onSeeAllTap;

  const HorizontalPosterRows({
    super.key,
    required this.title,
    this.titleIcon,
    this.titleIconColor,
    required this.itemCount,
    this.aspect = PosterAspect.vertical,
    required this.itemBuilder,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    final isVertical = aspect == PosterAspect.vertical;
    final rowHeight = isVertical ? 190.0 : 138.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(
                      titleIcon,
                      color: titleIconColor ?? Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              if (onSeeAllTap != null)
                GestureDetector(
                  onTap: onSeeAllTap,
                  child: Text(
                    "See All",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Lazy-loaded Horizontal ListView
        SizedBox(
          height: rowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            cacheExtent: 150.0, // Conservative recycling cache
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: itemBuilder(context, index),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class PosterCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final PosterAspect aspect;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? ratingBadge;
  final bool isLive;
  final bool isFavorite;

  /// Movie / series cards without playlist art look up a poster (TMDB via
  /// TV Parser's relay). Null = never look up (live channels etc.).
  final ContentType? artType;

  const PosterCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.aspect = PosterAspect.vertical,
    required this.onTap,
    this.onLongPress,
    this.ratingBadge,
    this.isLive = false,
    this.isFavorite = false,
    this.artType,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = aspect == PosterAspect.vertical;
    final cardWidth = isVertical ? 110.0 : 170.0;
    final cardHeight = isVertical ? 150.0 : 96.0;

    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphic Card
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Widescreen/Vertical Poster Cover Image (Async)
                  _buildArtwork(isVertical),

                  // Shadow Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Badges
                  if (ratingBadge != null && ratingBadge!.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white12, width: 0.5),
                        ),
                        child: Text(
                          ratingBadge!,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  if (isLive)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "LIVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Premium Heart Indicator
                  if (isFavorite)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.red,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Label Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(bool isVertical) {
    final own = imageUrl?.trim();
    if (own != null && own.isNotEmpty) return _networkArt(own, isVertical);
    final type = artType;
    final worker = TmdbEnrichmentWorker.instance;
    if (type == null || isLive || !worker.isEnabled) {
      return _buildFallbackArtwork(isVertical);
    }
    final request = TmdbEnqueueRequest(rawTitle: title, type: type);
    worker.enqueue(request);
    return ValueListenableBuilder<UnifiedMediaMetadata?>(
      valueListenable: worker.notifierFor(request.key),
      builder: (context, meta, _) {
        final url = isVertical
            ? (meta?.posterUrl ?? meta?.backdropUrl)
            : (meta?.backdropUrl ?? meta?.posterUrl);
        return url != null && url.isNotEmpty
            ? _networkArt(url, isVertical)
            : _buildFallbackArtwork(isVertical);
      },
    );
  }

  Widget _networkArt(String url, bool isVertical) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: isVertical ? 220 : 340,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (context, url) => const PosterSkeletonCard(),
        errorWidget: (context, url, error) => _buildFallbackArtwork(isVertical),
      );

  static const List<List<Color>> _fallbackPalettes = [
    [Color(0xFF3A1C71), Color(0xFF16102A)],
    [Color(0xFF0F3D5E), Color(0xFF0A1622)],
    [Color(0xFF5A1E2E), Color(0xFF1A0C12)],
    [Color(0xFF1E4D3A), Color(0xFF0B1A14)],
    [Color(0xFF5B3A12), Color(0xFF1C130A)],
    [Color(0xFF2B2F6B), Color(0xFF101226)],
  ];

  /// No artwork: a title card (stable colour per title) instead of an empty
  /// box, so rows still read as content.
  Widget _buildFallbackArtwork(bool isVertical) {
    final palette =
        _fallbackPalettes[title.hashCode.abs() % _fallbackPalettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(10, isLive ? 22 : 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            isLive ? Icons.live_tv_rounded : Icons.movie_filter_rounded,
            color: Colors.white.withOpacity(0.35),
            size: isVertical ? 18 : 16,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: isVertical ? 4 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: isVertical ? 13 : 12,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class PosterSkeletonCard extends StatelessWidget {
  const PosterSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF141416), Color(0xFF1C1C1E), Color(0xFF141416)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(color: Colors.white10, strokeWidth: 1.5),
        ),
      ),
    );
  }
}

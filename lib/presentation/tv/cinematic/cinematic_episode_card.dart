import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../repository/api/artwork_url_resolver.dart';
import '../widgets/tv_artwork_shimmer.dart';
import '../widgets/tv_channel_grid.dart';
import 'cinematic_tokens.dart';

/// 16:9 episode still. Uses already-grouped episode records only.
class CinematicEpisodeCard extends StatefulWidget {
  static const double width = 240;
  static const double height = 135;

  final TvStreamRecord stream;
  final VoidCallback onSelected;
  final ValueChanged<TvStreamRecord>? onFocused;

  const CinematicEpisodeCard({
    super.key,
    required this.stream,
    required this.onSelected,
    this.onFocused,
  });

  @override
  State<CinematicEpisodeCard> createState() => _CinematicEpisodeCardState();
}

class _CinematicEpisodeCardState extends State<CinematicEpisodeCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final still = widget.stream.backdropUrl ?? widget.stream.imageUrl;
    final progress = widget.stream.watchProgress ?? 0;
    final badge = widget.stream.badge;
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
        scale: _focused ? 1.06 : 1.0,
        duration: CinematicMotion.focus,
        curve: CinematicMotion.standard,
        child: SizedBox(
          width: CinematicEpisodeCard.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: CinematicMotion.focus,
                width: CinematicEpisodeCard.width,
                height: CinematicEpisodeCard.height,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(CinematicTokens.radiusPoster),
                  border: Border.all(
                    width: _focused ? 1.4 : 0,
                    color: _focused
                        ? CinematicTokens.focus.withValues(alpha: 0.9)
                        : Colors.transparent,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: CinematicTokens.surface),
                    if (ArtworkUrlResolver.isUsableImageUrl(still))
                      CachedNetworkImage(
                        imageUrl: still!,
                        fit: BoxFit.cover,
                        memCacheWidth: 480,
                        placeholder: (_, _) => const TvArtworkShimmer(),
                        errorWidget: (_, _, _) => const ColoredBox(
                          color: CinematicTokens.surface,
                        ),
                      ),
                    if (badge != null && badge.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: CinematicTokens.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (progress > 0.02)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.black45,
                          color: CinematicTokens.focus,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.stream.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CinematicTokens.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CinematicEpisodeRow extends StatelessWidget {
  final String title;
  final List<TvStreamRecord> streams;
  final ValueChanged<String> onChannelSelected;
  final ValueChanged<TvStreamRecord>? onStreamFocused;

  const CinematicEpisodeRow({
    super.key,
    required this.title,
    required this.streams,
    required this.onChannelSelected,
    this.onStreamFocused,
  });

  @override
  Widget build(BuildContext context) {
    if (streams.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 188,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                color: CinematicTokens.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4, right: 24),
              itemCount: streams.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final stream = streams[index];
                return CinematicEpisodeCard(
                  stream: stream,
                  onSelected: () => onChannelSelected(stream.streamUrl),
                  onFocused: onStreamFocused,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

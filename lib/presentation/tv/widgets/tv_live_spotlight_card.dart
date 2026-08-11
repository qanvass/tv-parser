import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../helpers/helpers.dart';
import '../../../../repository/models/channel_live.dart';
import '../../../../repository/models/spotlight_event.dart';
import '../../../../repository/api/channel_match_service.dart';

class TvLiveSpotlightCard extends StatefulWidget {
  final SpotlightEvent event;
  final List<ChannelLive> allLiveChannels;
  final ValueChanged<String> onChannelSelected;

  const TvLiveSpotlightCard({
    super.key,
    required this.event,
    required this.allLiveChannels,
    required this.onChannelSelected,
  });

  @override
  State<TvLiveSpotlightCard> createState() => _TvLiveSpotlightCardState();
}

class _TvLiveSpotlightCardState extends State<TvLiveSpotlightCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final matchResult = ChannelMatchService.matchEvent(
      event: widget.event,
      allLiveChannels: widget.allLiveChannels,
    );

    final bestCh = matchResult.bestChannel;
    final confidencePct = (matchResult.confidenceScore * 100).toInt();

    String formattedTime = 'Live Now';
    try {
      final startTime = DateTime.parse(widget.event.startTimeLocal);
      formattedTime = DateFormat('h:mm a').format(startTime);
    } catch (_) {}

    void playBest() {
      if (bestCh == null) return;
      if (bestCh.directSource != null && bestCh.directSource!.isNotEmpty) {
        widget.onChannelSelected(bestCh.directSource!);
      } else if (bestCh.streamId != null) {
        widget.onChannelSelected(bestCh.streamId!);
      }
    }

    return Focus(
      onFocusChange: (value) {
        setState(() {
          _focused = value;
        });
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.gameButtonA) {
          playBest();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 268,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF12353A),
                Color(0xFF0C1A28),
                Color(0xFF070D16),
              ],
            ),
            border: Border.all(
              width: _focused ? 2.8 : 1.0,
              color: _focused
                  ? kColorFocus
                  : kColorPrimary.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
              if (_focused)
                BoxShadow(
                  color: kColorPrimary.withValues(alpha: 0.38),
                  blurRadius: 22,
                  spreadRadius: 0.5,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              canRequestFocus: false,
              onTap: playBest,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kColorPrimary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: kColorPrimary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            widget.event.sport.toUpperCase(),
                            style: const TextStyle(
                              color: kColorPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            widget.event.networks.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (bestCh != null) ...[
                      Row(
                        children: [
                          if (bestCh.streamIcon != null &&
                              bestCh.streamIcon!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: bestCh.streamIcon!,
                                width: 26,
                                height: 26,
                                fit: BoxFit.contain,
                                placeholder: (_, _) => Icon(
                                  Icons.live_tv_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                errorWidget: (_, _, _) => Icon(
                                  Icons.live_tv_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.live_tv_rounded,
                              size: 20,
                              color: kColorPrimary.withValues(alpha: 0.7),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bestCh.name ?? 'Live Channel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Matched · $confidencePct%',
                                  style: TextStyle(
                                    color: kColorPrimary.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_focused)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [kColorPrimaryDark, kColorPrimary],
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Not in playlist',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

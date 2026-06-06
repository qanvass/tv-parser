import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    // Perform fuzzy match logic
    final matchResult = ChannelMatchService.matchEvent(
      event: widget.event,
      allLiveChannels: widget.allLiveChannels,
    );

    final bestCh = matchResult.bestChannel;
    final confidencePct = (matchResult.confidenceScore * 100).toInt();

    // Format Start Time
    String formattedTime = "Live Now";
    try {
      final startTime = DateTime.parse(widget.event.startTimeLocal);
      formattedTime = DateFormat('h:mm a').format(startTime);
    } catch (_) {}

    return Focus(
      onFocusChange: (value) {
        setState(() {
          _focused = value;
        });
      },
      child: AnimatedScale(
        scale: _focused ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: 280,
          margin: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF281E46),
                Color(0xFF140F22),
                Color(0xFF0A0811),
              ],
            ),
            border: Border.all(
              width: _focused ? 2.5 : 1.0,
              color: _focused ? Colors.white : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              if (_focused)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (bestCh != null) {
                  // Resolve stream URL using bestChannel source
                  if (bestCh.directSource != null && bestCh.directSource!.isNotEmpty) {
                    widget.onChannelSelected(bestCh.directSource!);
                  } else if (bestCh.streamId != null) {
                    // Try to generate standard playback link locally or let parent handle it
                    // We call onChannelSelected with streamUrl as required
                    widget.onChannelSelected(bestCh.streamId!);
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header tag and networks
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.event.sport.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          widget.event.networks.join(" | "),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      widget.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Time
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Colors.white30),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Playlist Matching info
                    if (bestCh != null) ...[
                      Row(
                        children: [
                          if (bestCh.streamIcon != null && bestCh.streamIcon!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: bestCh.streamIcon!,
                                width: 22,
                                height: 22,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Icon(Icons.live_tv_rounded, size: 12, color: Colors.white24),
                                errorWidget: (_, __, ___) => const Icon(Icons.live_tv_rounded, size: 12, color: Colors.white24),
                              ),
                            )
                          else
                            const Icon(Icons.live_tv_rounded, size: 18, color: Colors.white60),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bestCh.name ?? 'Live Channel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Match • $confidencePct% Confidence",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        "Not in playlist",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11, fontWeight: FontWeight.bold),
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

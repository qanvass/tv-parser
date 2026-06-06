import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../repository/models/channel_live.dart';
import '../../../../repository/models/spotlight_event.dart';
import '../../../../repository/api/channel_match_service.dart';

class LiveSpotlightCard extends StatelessWidget {
  final SpotlightEvent event;
  final List<ChannelLive> allLiveChannels;
  final void Function(ChannelLive) onPlayChannel;

  const LiveSpotlightCard({
    super.key,
    required this.event,
    required this.allLiveChannels,
    required this.onPlayChannel,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve matches using the matching service
    final matchResult = ChannelMatchService.matchEvent(
      event: event,
      allLiveChannels: allLiveChannels,
    );

    final bestCh = matchResult.bestChannel;
    final altChs = matchResult.alternativeChannels;
    final confidencePct = (matchResult.confidenceScore * 100).toInt();

    // Format Start Time
    String formattedTime = "Live Now";
    try {
      final startTime = DateTime.parse(event.startTimeLocal);
      formattedTime = DateFormat('h:mm a').format(startTime);
    } catch (_) {}

    return GestureDetector(
      onTap: bestCh != null ? () => onPlayChannel(bestCh) : null,
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF231A3A),
              Color(0xFF13101E),
              Color(0xFF0C0A12),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Decorative Logo or Glassmorphic Glow
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.stars_rounded,
                size: 140,
                color: Colors.amber.withValues(alpha: 0.03),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Tag Bar: Event category & local broadcast networks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.sport.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Row(
                        children: event.networks.map((net) {
                          return Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              net,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
  
                  // Event Title
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
  
                  // Start Time indicator
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(
                        formattedTime,
                        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 12),
  
                  // Matching playlist result indicator
                  if (bestCh != null) ...[
                    Row(
                      children: [
                        // Approximate channel logo
                        if (bestCh.streamIcon != null && bestCh.streamIcon!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: bestCh.streamIcon!,
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Icon(Icons.live_tv_rounded, size: 14, color: Colors.white24),
                              errorWidget: (_, __, ___) => const Icon(Icons.live_tv_rounded, size: 14, color: Colors.white24),
                            ),
                          )
                        else
                          const Icon(Icons.live_tv_rounded, size: 20, color: Colors.white70),
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
                                "Playlist Match • $confidencePct% Confidence",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
  
                    // Actions row
                    Row(
                      children: [
                        // Watch Button
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => onPlayChannel(bestCh),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text(
                              "Watch Now",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
  
                        // Alternatives dropdown selector if available
                        if (altChs.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
                              ),
                            ),
                            icon: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white70, size: 18),
                            onPressed: () => _showAlternativeChannelsSheet(context),
                          ),
                        ],
                      ],
                    ),
                  ] else ...[
                    // Not matching message
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white38),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Channel currently not in playlist",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a custom bottom sheet showing other matching channel options
  void _showAlternativeChannelsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13101E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Alternative Broadcasters",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: event.networks.length,
                    itemBuilder: (context, index) {
                      final netName = event.networks[index];
                      final matchedList = allLiveChannels
                          .where((ch) => (ch.name ?? '').toLowerCase().contains(netName.toLowerCase()))
                          .toList();

                      if (matchedList.isEmpty) return const SizedBox();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              "Matches for $netName",
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...matchedList.take(3).map((ch) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: ch.streamIcon != null && ch.streamIcon!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: ch.streamIcon!,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => const Icon(Icons.live_tv_rounded, color: Colors.white24),
                                        errorWidget: (_, __, ___) => const Icon(Icons.live_tv_rounded, color: Colors.white24),
                                      )
                                    : const Icon(Icons.live_tv_rounded, color: Colors.white30),
                              ),
                              title: Text(
                                ch.name ?? 'Broadcaster Feed',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              trailing: const Icon(Icons.play_circle_outline_rounded, color: Colors.white30),
                              onTap: () {
                                Navigator.pop(context);
                                onPlayChannel(ch);
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

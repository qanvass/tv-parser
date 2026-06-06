import 'package:flutter/material.dart';
import '../../../../repository/models/channel_live.dart';
import '../../../../repository/models/spotlight_event.dart';
import 'live_spotlight_card.dart';

class LiveSpotlightRow extends StatelessWidget {
  final List<SpotlightEvent> events;
  final List<ChannelLive> allLiveChannels;
  final void Function(ChannelLive) onPlayChannel;
  final String title;
  final IconData titleIcon;
  final Color titleIconColor;

  const LiveSpotlightRow({
    super.key,
    required this.events,
    required this.allLiveChannels,
    required this.onPlayChannel,
    this.title = "Live Tonight",
    this.titleIcon = Icons.bolt_rounded,
    this.titleIconColor = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(titleIcon, color: titleIconColor, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 225, // height matching card size constraints
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return LiveSpotlightCard(
                event: event,
                allLiveChannels: allLiveChannels,
                onPlayChannel: onPlayChannel,
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

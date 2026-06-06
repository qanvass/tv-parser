import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../repository/models/channel_live.dart';
import '../../../../repository/models/spotlight_event.dart';
import 'tv_live_spotlight_card.dart';

class TvLiveSpotlightRow extends StatelessWidget {
  final List<SpotlightEvent> events;
  final List<ChannelLive> allLiveChannels;
  final ValueChanged<String> onChannelSelected;

  const TvLiveSpotlightRow({
    super.key,
    required this.events,
    required this.allLiveChannels,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox();

    return SizedBox(
      height: 200, // height constraint for TV cards
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Live Tonight",
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
              scrollDirection: Axis.horizontal,
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return TvLiveSpotlightCard(
                  event: event,
                  allLiveChannels: allLiveChannels,
                  onChannelSelected: onChannelSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

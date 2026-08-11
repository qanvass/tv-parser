import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../repository/models/channel_live.dart';
import '../../../../repository/models/spotlight_event.dart';
import 'tv_channel_grid.dart';
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
    if (events.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TvRailSectionHeader(
            title: 'Live Tonight',
          ),
          const SizedBox(height: 10),
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

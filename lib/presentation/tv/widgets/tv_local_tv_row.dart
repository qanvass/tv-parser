import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../repository/models/channel_live.dart';
import '../../../../repository/api/local_market_service.dart';
import '../../../../repository/models/user_preference_profile.dart';
import '../../../../logic/blocs/auth/auth_bloc.dart';
import 'tv_channel_grid.dart';

class TvLocalTvRow extends StatelessWidget {
  final List<ChannelLive> allLiveChannels;
  final ValueChanged<String> onChannelSelected;

  const TvLocalTvRow({
    super.key,
    required this.allLiveChannels,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final activeMarket = LocalMarketService.getActiveMarket();
    final profile = UserPreferenceProfile.load();

    // Only render if location personalization is enabled and active market exists
    if (!profile.locationFeatureEnabled || activeMarket == null) {
      return const SizedBox();
    }

    final localChannels = LocalMarketService.getLocalChannelsForCategory(
      categoryKey: 'all',
      market: activeMarket,
      playlist: allLiveChannels,
    );

    if (localChannels.isEmpty) return const SizedBox();

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return const SizedBox();
    final user = authState.user;

    final List<TvStreamRecord> streamRecords = localChannels.map((ch) {
      final defaultStreamUrl =
          "${user.serverInfo?.serverUrl}/live/${user.userInfo?.username}/${user.userInfo?.password}/${ch.streamId}.ts";
      final streamUrl = (ch.directSource != null && ch.directSource!.isNotEmpty)
          ? ch.directSource!
          : defaultStreamUrl;

      return TvStreamRecord(
        title: ch.name ?? 'Local Channel',
        subtitle: "Local • HD",
        streamUrl: streamUrl,
        imageUrl: ch.streamIcon,
      );
    }).toList();

    return SizedBox(
      height: 218,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                "Local TV Near You (${activeMarket.displayName})",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
              scrollDirection: Axis.horizontal,
              itemCount: streamRecords.length,
              itemBuilder: (context, index) {
                final stream = streamRecords[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: TvChannelCard(
                    stream: stream,
                    onSelected: () => onChannelSelected(stream.streamUrl),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

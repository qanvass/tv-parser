import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../repository/models/channel_live.dart';
import '../../../../repository/api/local_market_service.dart';
import '../../../../repository/models/user_preference_profile.dart';
import '../../../../logic/blocs/auth/auth_bloc.dart';
import '../../../../helpers/helpers.dart';
import 'tv_channel_grid.dart';

class TvLocalTvRow extends StatelessWidget {
  final List<ChannelLive> allLiveChannels;
  final ValueChanged<String> onChannelSelected;
  final ValueChanged<TvStreamRecord>? onStreamFocused;

  const TvLocalTvRow({
    super.key,
    required this.allLiveChannels,
    required this.onChannelSelected,
    this.onStreamFocused,
  });

  @override
  Widget build(BuildContext context) {
    final activeMarket = LocalMarketService.getActiveMarket();
    final profile = UserPreferenceProfile.load();

    if (!profile.locationFeatureEnabled || activeMarket == null) {
      return const SizedBox.shrink();
    }

    final localChannels = LocalMarketService.getLocalChannelsForCategory(
      categoryKey: 'all',
      market: activeMarket,
      playlist: allLiveChannels,
    );

    if (localChannels.isEmpty) return const SizedBox.shrink();

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return const SizedBox.shrink();
    final user = authState.user;

    final List<TvStreamRecord> streamRecords = [];
    for (var i = 0; i < localChannels.length; i++) {
      final ch = localChannels[i];
      final defaultStreamUrl =
          "${user.serverInfo?.serverUrl}/live/${user.userInfo?.username}/${user.userInfo?.password}/${ch.streamId}.ts";
      final streamUrl = (ch.directSource != null && ch.directSource!.isNotEmpty)
          ? ch.directSource!
          : defaultStreamUrl;
      final name = ch.name ?? 'Local Channel';

      streamRecords.add(
        TvStreamRecord(
          title: name,
          subtitle: 'Local · HD',
          streamUrl: streamUrl,
          imageUrl: ch.streamIcon,
          badge: '${i + 1}'.padLeft(3, '0'),
          isHd: true,
        ),
      );
    }

    return SizedBox(
      height: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvRailSectionHeader(
            title: 'Local TV · ${activeMarket.displayName}',
            trailing: 'View All · ${streamRecords.length}',
            icon: Icons.location_on_rounded,
            accent: kColorAccentWarm,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              scrollCacheExtent: const ScrollCacheExtent.pixels(300.0),
              scrollDirection: Axis.horizontal,
              itemCount: streamRecords.length,
              itemBuilder: (context, index) {
                final stream = streamRecords[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
                  child: TvChannelCard(
                    stream: stream,
                    onSelected: () => onChannelSelected(stream.streamUrl),
                    onFocused: onStreamFocused,
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

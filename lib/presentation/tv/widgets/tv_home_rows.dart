import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/cubits/favorites/favorites_cubit.dart';
import '../../../logic/cubits/watch/watching_cubit.dart';
import '../../../repository/api/playback_url_builder.dart';
import '../../../repository/models/channel_live.dart';
import '../../../repository/models/watching.dart';
import 'tv_channel_grid.dart';

/// Home resume rails shown above category rows on Live TV.
class TvHomeRows extends StatelessWidget {
  final ValueChanged<String> onChannelSelected;
  final List<ChannelLive> allLiveChannels;

  const TvHomeRows({
    super.key,
    required this.onChannelSelected,
    required this.allLiveChannels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocBuilder<WatchingCubit, WatchingState>(
          builder: (context, watchState) {
            final continueItems = <TvStreamRecord>[
              ...watchState.movies.take(12).map(_watchingToRecord),
              ...watchState.series.take(12).map(_watchingToRecord),
            ];
            if (continueItems.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _HomeRail(
                title: 'Continue Watching',
                streams: continueItems,
                onChannelSelected: onChannelSelected,
              ),
            );
          },
        ),
        BlocBuilder<FavoritesCubit, FavoritesState>(
          builder: (context, favState) {
            final favs = <TvStreamRecord>[
              ...favState.lives.take(10).map(
                (ch) => TvStreamRecord(
                  title: ch.name ?? 'Live',
                  subtitle: 'Favorite · Live',
                  streamUrl: ch.directSource?.isNotEmpty == true
                      ? ch.directSource!
                      : (ch.streamId ?? ''),
                  imageUrl: ch.streamIcon,
                ),
              ),
              ...favState.movies.take(8).map(
                (m) => TvStreamRecord(
                  title: m.name ?? 'Movie',
                  subtitle: 'Favorite · Movie',
                  streamUrl: m.directSource?.isNotEmpty == true
                      ? m.directSource!
                      : (m.streamId ?? ''),
                  imageUrl: m.streamIcon,
                ),
              ),
              ...favState.series.take(8).map(
                (s) => TvStreamRecord(
                  title: s.name ?? 'Series',
                  subtitle: 'Favorite · Series',
                  streamUrl: s.seriesId ?? '',
                  imageUrl: s.cover,
                ),
              ),
            ];
            if (favs.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _HomeRail(
                title: 'Favorites',
                streams: favs,
                onChannelSelected: onChannelSelected,
              ),
            );
          },
        ),
        BlocBuilder<WatchingCubit, WatchingState>(
          builder: (context, watchState) {
            final recentLive = watchState.live.take(12).map(_watchingToRecord).toList();
            if (recentLive.isEmpty && allLiveChannels.isEmpty) {
              return const SizedBox.shrink();
            }
            // Prefer explicit recent live from WatchingCubit; otherwise stay quiet.
            if (recentLive.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: _HomeRail(
                title: 'Recent Live',
                streams: recentLive,
                onChannelSelected: onChannelSelected,
              ),
            );
          },
        ),
      ],
    );
  }

  static TvStreamRecord _watchingToRecord(WatchingModel w) {
    return TvStreamRecord(
      title: w.title,
      subtitle: 'Resume',
      streamUrl: w.stream.isNotEmpty ? w.stream : w.streamId,
      imageUrl: w.image.isNotEmpty ? w.image : null,
    );
  }
}

class _HomeRail extends StatelessWidget {
  final String title;
  final List<TvStreamRecord> streams;
  final ValueChanged<String> onChannelSelected;

  const _HomeRail({
    required this.title,
    required this.streams,
    required this.onChannelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: streams.length,
              itemBuilder: (context, index) {
                final stream = streams[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: TvChannelCard(
                    stream: stream,
                    onSelected: () => _play(stream),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _play(TvStreamRecord stream) async {
    var url = stream.streamUrl;
    if (url.isEmpty) return;
    // If we only have a stream id (not a full URL), try to resolve live URL.
    if (!url.contains('://') && !url.startsWith('m3u:')) {
      try {
        url = await PlaybackUrlBuilder.buildLiveUrl(url);
      } catch (_) {}
    }
    onChannelSelected(url);
  }
}

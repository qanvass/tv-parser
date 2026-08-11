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
  final ValueChanged<TvStreamRecord>? onStreamFocused;

  const TvHomeRows({
    super.key,
    required this.onChannelSelected,
    required this.allLiveChannels,
    this.onStreamFocused,
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
              padding: const EdgeInsets.only(bottom: 22),
              child: _HomeRail(
                title: 'Continue Watching',
                icon: Icons.play_circle_outline_rounded,
                streams: continueItems,
                onChannelSelected: onChannelSelected,
                onStreamFocused: onStreamFocused,
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
                  isHd: (ch.name ?? '').toUpperCase().contains('HD'),
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
                  streamId: m.streamId,
                  imdbId: m.imdbId,
                  tvgId: m.imdbId,
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
              padding: const EdgeInsets.only(bottom: 22),
              child: _HomeRail(
                title: 'Favorites',
                icon: Icons.favorite_rounded,
                streams: favs,
                onChannelSelected: onChannelSelected,
                onStreamFocused: onStreamFocused,
              ),
            );
          },
        ),
        BlocBuilder<WatchingCubit, WatchingState>(
          builder: (context, watchState) {
            final recentLive =
                watchState.live.take(12).map(_watchingToRecord).toList();
            if (recentLive.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: _HomeRail(
                title: 'Recent Live',
                icon: Icons.history_rounded,
                streams: recentLive,
                onChannelSelected: onChannelSelected,
                onStreamFocused: onStreamFocused,
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
  final IconData? icon;
  final List<TvStreamRecord> streams;
  final ValueChanged<String> onChannelSelected;
  final ValueChanged<TvStreamRecord>? onStreamFocused;

  const _HomeRail({
    required this.title,
    required this.streams,
    required this.onChannelSelected,
    this.icon,
    this.onStreamFocused,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvRailSectionHeader(
            title: title,
            trailing: 'View All · ${streams.length}',
            icon: icon,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: streams.length,
              itemBuilder: (context, index) {
                final stream = streams[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
                  child: TvChannelCard(
                    stream: stream,
                    onSelected: () => _play(stream),
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

  Future<void> _play(TvStreamRecord stream) async {
    var url = stream.streamUrl;
    if (url.isEmpty) return;
    if (!url.contains('://') && !url.startsWith('m3u:')) {
      try {
        url = await PlaybackUrlBuilder.buildLiveUrl(url);
      } catch (_) {}
    }
    onChannelSelected(url);
  }
}

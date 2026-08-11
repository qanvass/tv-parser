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
                  subtitle: 'Live',
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
                  subtitle: 'Movie',
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
                  subtitle: 'Series',
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
  final List<TvStreamRecord> streams;
  final ValueChanged<String> onChannelSelected;
  final ValueChanged<TvStreamRecord>? onStreamFocused;

  const _HomeRail({
    required this.title,
    required this.streams,
    required this.onChannelSelected,
    this.onStreamFocused,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvRailSectionHeader(
            title: title,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: streams.length,
              itemBuilder: (context, index) {
                final stream = streams[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
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

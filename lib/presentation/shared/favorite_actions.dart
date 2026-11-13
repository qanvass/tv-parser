import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/cubits/favorites/favorites_cubit.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';

abstract final class FavoriteActions {
  static Future<void> add(BuildContext context, Object item) async {
    final cubit = context.read<FavoritesCubit>();
    bool exists;
    try {
      if (item is ChannelLive) {
        exists = cubit.state.lives.any((v) =>
            v.streamId == item.streamId && v.directSource == item.directSource);
        await cubit.addLive(item, isAdd: true);
      } else if (item is ChannelMovie) {
        exists = cubit.state.movies.any((v) =>
            v.streamId == item.streamId && v.directSource == item.directSource);
        await cubit.addMovie(item, isAdd: true);
      } else if (item is ChannelSerie) {
        // Clean up any stale movie duplicate with matching id or title
        final staleMovies = cubit.state.movies
            .where((m) =>
                m.streamId == item.seriesId ||
                (m.name != null &&
                    item.name != null &&
                    m.name!.trim().toLowerCase() ==
                        item.name!.trim().toLowerCase()))
            .toList();
        for (final m in staleMovies) {
          await cubit.addMovie(m, isAdd: false);
        }
        exists = cubit.state.series.any((v) =>
            v.seriesId == item.seriesId && v.name == item.name);
        await cubit.addSerie(item, isAdd: true);
      } else {
        return;
      }
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
        content: Text(exists ? 'Already in Favorites' : 'Added to Favorites'),
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not save Favorite. Try again.')),
      );
    }
  }
}

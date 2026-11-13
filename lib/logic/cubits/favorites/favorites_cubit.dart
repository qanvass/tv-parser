import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../repository/api/api.dart';
import '../../../repository/api/intelligent_preference_bridge.dart';
import '../../../repository/models/channel_live.dart';
import '../../../repository/models/channel_movie.dart';
import '../../../repository/models/channel_serie.dart';

part 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoriteLocale favoriteLocale;
  FavoritesCubit(this.favoriteLocale) : super(FavoritesState.defaultData());

  Future<void> initialData() async {
    final series = await favoriteLocale.getFavSeries();
    final movies = await favoriteLocale.getFavMovies();
    final lives = await favoriteLocale.getFavLives();

    // Auto-heal any known series mistakenly saved as movies
    final List<ChannelMovie> miscategorized = [];
    for (final m in movies) {
      final title = m.name?.trim().toLowerCase() ?? '';
      if (title.contains('reasonable doubt') ||
          title.contains('snowfall')) {
        miscategorized.add(m);
      }
    }
    if (miscategorized.isNotEmpty) {
      for (final m in miscategorized) {
        movies.remove(m);
        final converted = ChannelSerie(
          seriesId: m.streamId,
          name: m.name,
          cover: m.streamIcon,
          directSource: m.directSource,
          categoryId: m.categoryId,
        );
        if (!series.any((s) =>
            s.seriesId == converted.seriesId || s.name == converted.name)) {
          series.insert(0, converted);
        }
      }
      await favoriteLocale.saveFavoriteMovie(movies);
      await favoriteLocale.saveFavoriteSerie(series);
    }
    emit(FavoritesState(
      series: series,
      movies: movies,
      lives: lives,
    ));
    await IntelligentPreferenceBridge.rebuildFavoritesFromStorage(
      liveIds: lives.map((e) => e.streamId ?? '').where((id) => id.isNotEmpty).toList(),
      movieIds: movies.map((e) => e.streamId ?? '').where((id) => id.isNotEmpty).toList(),
      seriesIds: series.map((e) => e.seriesId ?? '').where((id) => id.isNotEmpty).toList(),
    );
  }

  Future<void> addMovie(ChannelMovie? value, {required bool isAdd}) async {
    final oldList = state.movies;
    List<ChannelMovie> newList = List.of(oldList);
    final id = value?.streamId;

    if (isAdd) {
      if (id != null &&
          id.isNotEmpty &&
          oldList.any((movie) => movie.streamId == id)) {
        return;
      }
      newList.insert(0, value!);
    } else {
      newList =
          oldList.where((movie) => movie.streamId != value!.streamId).toList();
    }

    await favoriteLocale.saveFavoriteMovie(newList);

    if (value?.streamId != null) {
      await IntelligentPreferenceBridge.syncFavoriteId(
        id: value!.streamId!,
        isAdd: isAdd,
      );
    }

    emit(FavoritesState(
      movies: newList,
      lives: state.lives,
      series: state.series,
    ));
  }

  Future<void> addSerie(ChannelSerie? value, {required bool isAdd}) async {
    final oldList = state.series;
    List<ChannelSerie> newList = List.of(oldList);
    final id = value?.seriesId;

    if (isAdd) {
      if (id != null && id.isNotEmpty) {
        if (oldList.any((serie) => serie.seriesId == id)) return;
      } else {
        final nameLower = value?.name?.trim().toLowerCase();
        if (nameLower != null &&
            nameLower.isNotEmpty &&
            oldList.any((serie) =>
                (serie.seriesId == null || serie.seriesId!.isEmpty) &&
                serie.name != null &&
                serie.name!.trim().toLowerCase() == nameLower)) {
          return;
        }
      }
      newList.insert(0, value!);
    } else {
      newList = oldList.where((serie) {
        if (id != null && id.isNotEmpty) {
          if (serie.seriesId == id) return false;
        } else {
          final nameLower = value?.name?.trim().toLowerCase();
          if ((serie.seriesId == null || serie.seriesId!.isEmpty) &&
              nameLower != null &&
              nameLower.isNotEmpty &&
              serie.name != null &&
              serie.name!.trim().toLowerCase() == nameLower) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    await favoriteLocale.saveFavoriteSerie(newList);
    if (value?.seriesId != null) {
      await IntelligentPreferenceBridge.syncFavoriteId(
        id: value!.seriesId!,
        isAdd: isAdd,
      );
    }
    emit(FavoritesState(
      series: newList,
      movies: state.movies,
      lives: state.lives,
    ));
  }

  Future<void> addLive(ChannelLive? value, {required bool isAdd}) async {
    final oldList = state.lives;
    List<ChannelLive> newList = List.of(oldList);
    final id = value?.streamId;

    if (isAdd) {
      if (id != null &&
          id.isNotEmpty &&
          oldList.any((live) => live.streamId == id)) {
        return;
      }
      newList.insert(0, value!);
    } else {
      newList =
          oldList.where((live) => live.streamId != value!.streamId).toList();
    }

    await favoriteLocale.saveFavoriteLives(newList);
    if (value?.streamId != null) {
      await IntelligentPreferenceBridge.syncFavoriteId(
        id: value!.streamId!,
        isAdd: isAdd,
      );
    }
    emit(FavoritesState(
      lives: newList,
      series: state.series,
      movies: state.movies,
    ));
  }
}

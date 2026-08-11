import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../repository/api/api.dart';
import '../../../../repository/models/category.dart';

part 'movie_caty_event.dart';
part 'movie_caty_state.dart';

class MovieCatyBloc extends Bloc<MovieCatyEvent, MovieCatyState> {
  final IpTvApi api;

  MovieCatyBloc(this.api) : super(MovieCatyInitial()) {
    on<GetMovieCategories>((event, emit) async {
      emit(MovieCatyLoading());
      var result = await api.getCategories("get_vod_categories");
      if (result.isEmpty) {
        result = LocaleApi.getM3uMovieCategories();
      }
      emit(MovieCatySuccess(result));
      debugPrint('[MovieCaty] GetMovieCategories count=${result.length}');
    });
    on<HydrateMovieCategories>((event, emit) {
      final cats = event.categories.isNotEmpty
          ? event.categories
          : LocaleApi.getM3uMovieCategories();
      emit(MovieCatySuccess(List<CategoryModel>.from(cats)));
      debugPrint('[MovieCaty] hydrated count=${cats.length}');
    });
  }
}

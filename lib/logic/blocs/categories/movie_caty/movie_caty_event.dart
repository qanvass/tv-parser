part of 'movie_caty_bloc.dart';

@immutable
abstract class MovieCatyEvent {}

class GetMovieCategories extends MovieCatyEvent {}

/// Inject already-persisted VOD categories (post Starlite sync).
class HydrateMovieCategories extends MovieCatyEvent {
  final List<CategoryModel> categories;
  HydrateMovieCategories(this.categories);
}

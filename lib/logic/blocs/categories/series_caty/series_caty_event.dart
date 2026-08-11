part of 'series_caty_bloc.dart';

@immutable
abstract class SeriesCatyEvent {}

class GetSeriesCategories extends SeriesCatyEvent {}

/// Inject already-persisted series categories (post Starlite sync).
class HydrateSeriesCategories extends SeriesCatyEvent {
  final List<CategoryModel> categories;
  HydrateSeriesCategories(this.categories);
}

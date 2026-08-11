class ChannelSerie {
  final String? num;
  final String? name;
  final String? seriesId;
  final String? cover;
  final String? plot;

  final String? rating;
  final String? rating5based;

  final String? categoryId;
  /// M3U direct stream URL when the playlist embeds episode/media links.
  final String? directSource;

  ChannelSerie({
    this.num,
    this.name,
    this.seriesId,
    this.cover,
    this.plot,
    this.rating,
    this.rating5based,
    this.categoryId,
    this.directSource,
  });

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }

  ChannelSerie.fromJson(Map<String, dynamic> json)
      : num = _str(json['num']),
        name = _str(json['name']),
        seriesId = _str(json['series_id']),
        cover = _str(json['cover']),
        plot = _str(json['plot']),
        rating = _str(json['rating']),
        rating5based = _str(json['rating_5based']),
        categoryId = _str(json['category_id']),
        directSource = _str(json['direct_source']);

  Map<String, dynamic> toJson() => {
        'num': num,
        'name': name,
        'series_id': seriesId,
        'cover': cover,
        'plot': plot,
        'rating': rating,
        'rating_5based': rating5based,
        'category_id': categoryId,
        'direct_source': directSource,
      };
}

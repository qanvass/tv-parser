import '../provider/tmdb_match.dart';

class ChannelMovie {
  final String? num;
  final String? name;
  final String? streamType;
  final String? streamId;
  final String? streamIcon;
  final String? rating;
  final String? rating5based;
  final String? added;
  final String? isAdult;
  final String? categoryId;
  final String? containerExtension;
  final String? customSid;
  final String? directSource;
  /// Optional trailer id/url when present on XC list rows.
  final String? youtubeTrailer;
  /// Validated IMDb title id (`tt` + digits). Never overloads [name].
  final String? imdbId;

  ChannelMovie({
    this.num,
    this.name,
    this.streamType,
    this.streamId,
    this.streamIcon,
    this.rating,
    this.rating5based,
    this.added,
    this.isAdult,
    this.categoryId,
    this.containerExtension,
    this.customSid,
    this.directSource,
    this.youtubeTrailer,
    String? imdbId,
  }) : imdbId = TmdbMatch.normalizeImdbId(imdbId);

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }

  ChannelMovie.fromJson(Map<String, dynamic> json)
    : num = _str(json['num']),
      name = _str(json['name']),
      streamType = _str(json['stream_type']),
      streamId = _str(json['stream_id']),
      streamIcon = _str(json['stream_icon']),
      rating = _str(json['rating']),
      rating5based = _str(json['rating_5based']),
      added = _str(json['added']),
      isAdult = _str(json['is_adult']),
      categoryId = _str(json['category_id']),
      containerExtension = _str(json['container_extension']),
      customSid = _str(json['custom_sid']),
      directSource = _str(json['direct_source']),
      youtubeTrailer = _str(json['youtube_trailer']) ??
          _str(json['youtubeTrailer']) ??
          _str(json['trailer']) ??
          _str(json['youtube_id']),
      imdbId = TmdbMatch.normalizeImdbId(
        _str(json['imdb_id']) ??
            _str(json['imdbId']) ??
            _str(json['tvg_id']),
      );

  Map<String, dynamic> toJson() => {
    'num': num,
    'name': name,
    'stream_type': streamType,
    'stream_id': streamId,
    'stream_icon': streamIcon,
    'rating': rating,
    'rating_5based': rating5based,
    'added': added,
    'is_adult': isAdult,
    'category_id': categoryId,
    'container_extension': containerExtension,
    'custom_sid': customSid,
    'direct_source': directSource,
    'youtube_trailer': youtubeTrailer,
    if (imdbId != null) 'imdb_id': imdbId,
  };
}

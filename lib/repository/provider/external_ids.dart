/// Cross-system identifiers for a channel or title. All optional; never invent.
class ExternalIds {
  final String? tmdb;
  final String? tvmaze;
  final String? imdb;
  final String? tvgId;
  final String? providerStreamId;

  const ExternalIds({
    this.tmdb,
    this.tvmaze,
    this.imdb,
    this.tvgId,
    this.providerStreamId,
  });

  factory ExternalIds.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ExternalIds();
    return ExternalIds(
      tmdb: json['tmdb'] as String?,
      tvmaze: json['tvmaze'] as String?,
      imdb: json['imdb'] as String?,
      tvgId: json['tvg_id'] as String?,
      providerStreamId: json['provider_stream_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (tmdb != null) 'tmdb': tmdb,
        if (tvmaze != null) 'tvmaze': tvmaze,
        if (imdb != null) 'imdb': imdb,
        if (tvgId != null) 'tvg_id': tvgId,
        if (providerStreamId != null) 'provider_stream_id': providerStreamId,
      };

  ExternalIds copyWith({
    String? tmdb,
    String? tvmaze,
    String? imdb,
    String? tvgId,
    String? providerStreamId,
  }) {
    return ExternalIds(
      tmdb: tmdb ?? this.tmdb,
      tvmaze: tvmaze ?? this.tvmaze,
      imdb: imdb ?? this.imdb,
      tvgId: tvgId ?? this.tvgId,
      providerStreamId: providerStreamId ?? this.providerStreamId,
    );
  }
}

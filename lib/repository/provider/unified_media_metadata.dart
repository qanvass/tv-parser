import 'external_ids.dart';
import 'provider_enums.dart';

/// Normalized media metadata. Fields stay null when unknown — never fabricated.
class UnifiedMediaMetadata {
  final String? title;
  final String? originalTitle;
  final String? normalizedTitle;
  final int? year;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final String? trailerUrl;
  final List<String> genres;
  final double? rating;
  final int? runtimeMinutes;
  final ContentType contentType;
  final ExternalIds externalIds;
  final MetadataSource source;
  /// `imdb` | `title_year` | `none` when a TMDB attempt ran. Null if never tried.
  final String? matchMethod;

  const UnifiedMediaMetadata({
    this.title,
    this.originalTitle,
    this.normalizedTitle,
    this.year,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.trailerUrl,
    this.genres = const [],
    this.rating,
    this.runtimeMinutes,
    this.contentType = ContentType.unknown,
    this.externalIds = const ExternalIds(),
    this.source = MetadataSource.none,
    this.matchMethod,
  });

  factory UnifiedMediaMetadata.fromJson(Map<String, dynamic> json) {
    return UnifiedMediaMetadata(
      title: json['title'] as String?,
      originalTitle: json['original_title'] as String?,
      normalizedTitle: json['normalized_title'] as String?,
      year: json['year'] as int?,
      overview: json['overview'] as String?,
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      trailerUrl: json['trailer_url'] as String?,
      genres: (json['genres'] as List?)?.map((e) => '$e').toList() ?? const [],
      rating: (json['rating'] as num?)?.toDouble(),
      runtimeMinutes: json['runtime_minutes'] as int?,
      contentType: ContentType.values.firstWhere(
        (e) => e.name == json['content_type'],
        orElse: () => ContentType.unknown,
      ),
      externalIds: ExternalIds.fromJson(
        json['external_ids'] is Map
            ? Map<String, dynamic>.from(json['external_ids'] as Map)
            : null,
      ),
      source: MetadataSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => MetadataSource.none,
      ),
      matchMethod: json['match_method'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (originalTitle != null) 'original_title': originalTitle,
        if (normalizedTitle != null) 'normalized_title': normalizedTitle,
        if (year != null) 'year': year,
        if (overview != null) 'overview': overview,
        if (posterUrl != null) 'poster_url': posterUrl,
        if (backdropUrl != null) 'backdrop_url': backdropUrl,
        if (trailerUrl != null) 'trailer_url': trailerUrl,
        if (genres.isNotEmpty) 'genres': genres,
        if (rating != null) 'rating': rating,
        if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
        'content_type': contentType.name,
        'external_ids': externalIds.toJson(),
        'source': source.name,
        if (matchMethod != null) 'match_method': matchMethod,
      };

  /// Title-only fallback when no enrichment source has data.
  factory UnifiedMediaMetadata.titleOnly(String rawTitle) {
    return UnifiedMediaMetadata(
      title: rawTitle.trim().isEmpty ? null : rawTitle.trim(),
      source: MetadataSource.none,
    );
  }
}

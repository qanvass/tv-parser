import 'provider_enums.dart';

/// Detected provider feature set. Plain M3U is the minimum tier until probes finish.
class ProviderCapabilities {
  final ProviderType providerType;
  final bool supportsLive;
  final bool supportsXmlTv;
  final bool supportsShortEpg;
  final bool supportsFullEpg;
  final bool supportsVod;
  final bool supportsSeries;
  final bool supportsCatchup;
  final bool supportsPosters;
  final bool supportsTrailers;

  /// Normalized Xtream-compatible `player_api.php` base (scheme+host[+port][/path]).
  final String? playerApiBase;

  /// First `url-tvg` / `x-tvg-url` found in M3U header, if any.
  final String? xmlTvUrl;

  final List<String> notes;
  final DateTime? probedAt;

  /// Sample counts from probes (0 when unsupported / not probed).
  final int liveCategorySample;
  final int liveStreamSample;
  final int vodCategorySample;
  final int vodStreamSample;
  final int seriesCategorySample;
  final int seriesSample;

  const ProviderCapabilities({
    this.providerType = ProviderType.unknown,
    this.supportsLive = false,
    this.supportsXmlTv = false,
    this.supportsShortEpg = false,
    this.supportsFullEpg = false,
    this.supportsVod = false,
    this.supportsSeries = false,
    this.supportsCatchup = false,
    this.supportsPosters = false,
    this.supportsTrailers = false,
    this.playerApiBase,
    this.xmlTvUrl,
    this.notes = const [],
    this.probedAt,
    this.liveCategorySample = 0,
    this.liveStreamSample = 0,
    this.vodCategorySample = 0,
    this.vodStreamSample = 0,
    this.seriesCategorySample = 0,
    this.seriesSample = 0,
  });

  /// Minimum tier: live playlist only, nothing else assumed.
  factory ProviderCapabilities.m3uMinimum({
    bool hasLive = true,
    String? xmlTvUrl,
    List<String> notes = const [],
  }) {
    return ProviderCapabilities(
      providerType: ProviderType.m3u,
      supportsLive: hasLive,
      supportsXmlTv: xmlTvUrl != null && xmlTvUrl.isNotEmpty,
      xmlTvUrl: xmlTvUrl,
      notes: notes,
      probedAt: DateTime.now().toUtc(),
    );
  }

  factory ProviderCapabilities.fromJson(Map<String, dynamic> json) {
    return ProviderCapabilities(
      providerType: ProviderType.values.firstWhere(
        (e) => e.name == json['provider_type'],
        orElse: () => ProviderType.unknown,
      ),
      supportsLive: json['supports_live'] as bool? ?? false,
      supportsXmlTv: json['supports_xmltv'] as bool? ?? false,
      supportsShortEpg: json['supports_short_epg'] as bool? ?? false,
      supportsFullEpg: json['supports_full_epg'] as bool? ?? false,
      supportsVod: json['supports_vod'] as bool? ?? false,
      supportsSeries: json['supports_series'] as bool? ?? false,
      supportsCatchup: json['supports_catchup'] as bool? ?? false,
      supportsPosters: json['supports_posters'] as bool? ?? false,
      supportsTrailers: json['supports_trailers'] as bool? ?? false,
      playerApiBase: json['player_api_base'] as String?,
      xmlTvUrl: json['xmltv_url'] as String?,
      notes: (json['notes'] as List?)?.map((e) => '$e').toList() ?? const [],
      probedAt: json['probed_at'] != null
          ? DateTime.tryParse(json['probed_at'] as String)
          : null,
      liveCategorySample: json['live_category_sample'] as int? ?? 0,
      liveStreamSample: json['live_stream_sample'] as int? ?? 0,
      vodCategorySample: json['vod_category_sample'] as int? ?? 0,
      vodStreamSample: json['vod_stream_sample'] as int? ?? 0,
      seriesCategorySample: json['series_category_sample'] as int? ?? 0,
      seriesSample: json['series_sample'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider_type': providerType.name,
        'supports_live': supportsLive,
        'supports_xmltv': supportsXmlTv,
        'supports_short_epg': supportsShortEpg,
        'supports_full_epg': supportsFullEpg,
        'supports_vod': supportsVod,
        'supports_series': supportsSeries,
        'supports_catchup': supportsCatchup,
        'supports_posters': supportsPosters,
        'supports_trailers': supportsTrailers,
        if (playerApiBase != null) 'player_api_base': playerApiBase,
        if (xmlTvUrl != null) 'xmltv_url': xmlTvUrl,
        if (notes.isNotEmpty) 'notes': notes,
        if (probedAt != null) 'probed_at': probedAt!.toIso8601String(),
        'live_category_sample': liveCategorySample,
        'live_stream_sample': liveStreamSample,
        'vod_category_sample': vodCategorySample,
        'vod_stream_sample': vodStreamSample,
        'series_category_sample': seriesCategorySample,
        'series_sample': seriesSample,
      };

  ProviderCapabilities copyWith({
    ProviderType? providerType,
    bool? supportsLive,
    bool? supportsXmlTv,
    bool? supportsShortEpg,
    bool? supportsFullEpg,
    bool? supportsVod,
    bool? supportsSeries,
    bool? supportsCatchup,
    bool? supportsPosters,
    bool? supportsTrailers,
    String? playerApiBase,
    String? xmlTvUrl,
    List<String>? notes,
    DateTime? probedAt,
    int? liveCategorySample,
    int? liveStreamSample,
    int? vodCategorySample,
    int? vodStreamSample,
    int? seriesCategorySample,
    int? seriesSample,
  }) {
    return ProviderCapabilities(
      providerType: providerType ?? this.providerType,
      supportsLive: supportsLive ?? this.supportsLive,
      supportsXmlTv: supportsXmlTv ?? this.supportsXmlTv,
      supportsShortEpg: supportsShortEpg ?? this.supportsShortEpg,
      supportsFullEpg: supportsFullEpg ?? this.supportsFullEpg,
      supportsVod: supportsVod ?? this.supportsVod,
      supportsSeries: supportsSeries ?? this.supportsSeries,
      supportsCatchup: supportsCatchup ?? this.supportsCatchup,
      supportsPosters: supportsPosters ?? this.supportsPosters,
      supportsTrailers: supportsTrailers ?? this.supportsTrailers,
      playerApiBase: playerApiBase ?? this.playerApiBase,
      xmlTvUrl: xmlTvUrl ?? this.xmlTvUrl,
      notes: notes ?? this.notes,
      probedAt: probedAt ?? this.probedAt,
      liveCategorySample: liveCategorySample ?? this.liveCategorySample,
      liveStreamSample: liveStreamSample ?? this.liveStreamSample,
      vodCategorySample: vodCategorySample ?? this.vodCategorySample,
      vodStreamSample: vodStreamSample ?? this.vodStreamSample,
      seriesCategorySample: seriesCategorySample ?? this.seriesCategorySample,
      seriesSample: seriesSample ?? this.seriesSample,
    );
  }

  /// Safe log line — never includes credentials.
  String get capabilityLogLine =>
      '[CAPABILITIES] live=$supportsLive xmltv=$supportsXmlTv '
      'shortEpg=$supportsShortEpg fullEpg=$supportsFullEpg '
      'vod=$supportsVod series=$supportsSeries catchup=$supportsCatchup '
      'posters=$supportsPosters trailers=$supportsTrailers '
      'type=${providerType.name}';
}

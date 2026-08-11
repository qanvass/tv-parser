/// Detected provider protocol family (generic — not vendor-specific).
enum ProviderType { xtream, m3u, stalker, unknown }

/// Unified catalog content kind.
enum ContentType { live, movie, series, episode, unknown }

/// Where a metadata field was obtained. Never invent values.
enum MetadataSource { provider, xmltv, tmdb, tvmaze, cache, none }

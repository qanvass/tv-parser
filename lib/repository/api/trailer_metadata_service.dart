class TrailerMetadataService {
  /// Cleans a movie title by removing common IPTV noise, qualities, and bracket/parentheses tags.
  static String cleanMovieTitle(String title) {
    String name = title;

    // 1. Remove contents inside square brackets e.g. [US] [4K] [HD]
    name = name.replaceAll(RegExp(r'\[[^\]]*\]'), '');

    // 2. Remove contents inside parentheses e.g. (2025) (4K)
    name = name.replaceAll(RegExp(r'\([^\)]*\)'), '');

    // 3. Remove noise keywords (case-insensitive)
    final noiseKeywords = [
      r'\b(top\s*10|top\s*5|top\s*100)\b',
      r'\b(4k|uhd|fhd|hd|sd|3d|1080p|720p|576p|480p|hevc|x265|x264|h264|h265|aac)\b',
      r'\b(2025|2026|2024|2023)\b',
      r'\b(en|es|fr|it|de|us|usa|uk|ca|latin|multi|sub|dub|dubbed|subbed|censored|uncensored)\b',
    ];

    for (final pattern in noiseKeywords) {
      name = name.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    // 4. Remove leading/trailing non-alphanumeric noise (like hyphens, dots, vertical bars)
    name = name.replaceAll(RegExp(r'^[^\w\s]+|[^\w\s]+$'), '');

    // 5. Collapse multiple spaces into one
    name = name.replaceAll(RegExp(r'\s+'), ' ');

    return name.trim();
  }
}

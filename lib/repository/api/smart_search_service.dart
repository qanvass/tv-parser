class SearchIntent {
  final String? type; // 'live', 'movie', 'series'
  final String? country;
  final String? language;
  final List<String> genres;
  final List<String> keywords;
  final List<String> boostedTerms;

  SearchIntent({
    this.type,
    this.country,
    this.language,
    this.genres = const [],
    this.keywords = const [],
    this.boostedTerms = const [],
  });

  @override
  String toString() {
    return 'SearchIntent(type: $type, country: $country, language: $language, genres: $genres, keywords: $keywords, boostedTerms: $boostedTerms)';
  }
}

class SmartSearchService {
  /// Parses a natural language phrase into a structured SearchIntent
  static SearchIntent parse(String query) {
    final clean = query.trim().toLowerCase();
    
    String? type;
    if (clean.contains('movie') || clean.contains('film') || clean.contains('vod')) {
      type = 'movie';
    } else if (clean.contains('series') || clean.contains('show') || clean.contains('tv show') || clean.contains('episode')) {
      type = 'series';
    } else if (clean.contains('live') || clean.contains('channel') || clean.contains('tv')) {
      type = 'live';
    }

    String? country;
    if (clean.contains('spanish') || clean.contains('spain') || clean.contains('espana')) {
      country = 'Spain';
    } else if (clean.contains('usa') || clean.contains('american') || clean.contains('us ')) {
      country = 'USA';
    } else if (clean.contains('uk') || clean.contains('british') || clean.contains('united kingdom')) {
      country = 'United Kingdom';
    } else if (clean.contains('latino') || clean.contains('mexic')) {
      country = 'Mexico';
    } else if (clean.contains('brazil') || clean.contains('brasil')) {
      country = 'Brazil';
    } else if (clean.contains('nigerian') || clean.contains('nollywood')) {
      country = 'Nigeria';
    } else if (clean.contains('caribbean') || clean.contains('jamaica')) {
      country = 'Caribbean';
    }

    String? language;
    if (clean.contains('spanish') || clean.contains('espanol') || clean.contains('esp ')) {
      language = 'Spanish';
    } else if (clean.contains('english') || clean.contains(' eng')) {
      language = 'English';
    } else if (clean.contains('french') || clean.contains('francais')) {
      language = 'French';
    } else if (clean.contains('portuguese') || clean.contains('brazilian')) {
      language = 'Portuguese';
    } else if (clean.contains('arabic') || clean.contains(' ar ')) {
      language = 'Arabic';
    }

    final List<String> genres = [];
    if (clean.contains('action') || clean.contains('thrill') || clean.contains('fight')) {
      genres.add('action');
    }
    if (clean.contains('comedy') || clean.contains('funny') || clean.contains('laugh')) {
      genres.add('comedy');
    }
    if (clean.contains('kids') || clean.contains('cartoon') || clean.contains('animation') || clean.contains('family')) {
      genres.add('kids');
    }
    if (clean.contains('sport') || clean.contains('racing') || clean.contains('football') || clean.contains('soccer') || clean.contains('f1') || clean.contains('ufc')) {
      genres.add('sports');
    }
    if (clean.contains('news') || clean.contains('weather') || clean.contains('breaking')) {
      genres.add('news');
    }

    final List<String> boostedTerms = [];
    if (clean.contains('cnn')) boostedTerms.add('cnn');
    if (clean.contains('espn')) boostedTerms.add('espn');
    if (clean.contains('hbo')) boostedTerms.add('hbo');
    if (clean.contains('formula one') || clean.contains('formula 1') || clean.contains('f1')) boostedTerms.add('formula 1');
    if (clean.contains('world cup')) boostedTerms.add('world cup');
    if (clean.contains('atlanta')) boostedTerms.add('atlanta');
    if (clean.contains('globo')) boostedTerms.add('globo');

    // Split words as general keywords
    final keywords = clean.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (!keywords.contains(clean)) {
      keywords.add(clean);
    }

    return SearchIntent(
      type: type,
      country: country,
      language: language,
      genres: genres,
      keywords: keywords,
      boostedTerms: boostedTerms,
    );
  }

  /// Calculates a relevance score for search curation ranking
  static double scoreSearchResult(
    dynamic item,
    SearchIntent intent,
    String? categoryName,
  ) {
    double score = 0;
    final nameLower = (item.name ?? '').toLowerCase();
    final catLower = (categoryName ?? '').toLowerCase();

    // 1. Match type intent
    if (intent.type != null) {
      if (intent.type == 'movie' && item.runtime != null) {
        score += 100; // Strong match for Movie
      } else if (intent.type == 'series' && item.seriesId != null) {
        score += 100; // Strong match for Series
      } else if (intent.type == 'live' && item.directSource != null) {
        score += 100; // Strong match for Live
      }
    }

    // 2. Match exact query keywords
    for (final kw in intent.keywords) {
      if (nameLower.contains(kw)) {
        score += 80;
      }
      if (catLower.contains(kw)) {
        score += 40;
      }
    }

    // 3. Match country profile
    if (intent.country != null) {
      final country = intent.country!.toLowerCase();
      if (nameLower.contains(country) || catLower.contains(country)) {
        score += 90;
      }
    }

    // 4. Match language profile
    if (intent.language != null) {
      final lang = intent.language!.toLowerCase();
      if (nameLower.contains(lang) || catLower.contains(lang)) {
        score += 80;
      }
    }

    // 5. Match genres
    for (final g in intent.genres) {
      if (g == 'sports' && (nameLower.contains('sport') || nameLower.contains('f1') || nameLower.contains('espn') || catLower.contains('sport'))) {
        score += 60;
      }
      if (g == 'news' && (nameLower.contains('news') || nameLower.contains('cnn') || catLower.contains('news'))) {
        score += 60;
      }
      if (g == 'kids' && (nameLower.contains('kids') || nameLower.contains('disney') || nameLower.contains('cartoon') || catLower.contains('kids'))) {
        score += 60;
      }
    }

    // 6. Match boosted terms
    for (final bt in intent.boostedTerms) {
      if (nameLower.contains(bt)) {
        score += 150; // Extreme boost for direct brand queries
      }
    }

    return score;
  }
}

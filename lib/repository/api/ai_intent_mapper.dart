class ParsedIntent {
  final String intent; // e.g. 'live_event_search'
  final String eventType; // e.g. 'sports', 'news', 'general'
  final String? league; // e.g. 'NBA', 'NFL', 'UFC'
  final List<String> keywords;
  final String dateScope; // e.g. 'today', 'upcoming'
  final String preferredContentType; // e.g. 'live_tv'

  const ParsedIntent({
    required this.intent,
    required this.eventType,
    this.league,
    required this.keywords,
    this.dateScope = 'today',
    this.preferredContentType = 'live_tv',
  });

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'eventType': eventType,
        'league': league,
        'keywords': keywords,
        'dateScope': dateScope,
        'preferredContentType': preferredContentType,
      };
}

class AiIntentMapper {
  /// Local, offline-safe intent parser expanding search queries to helper keywords
  static ParsedIntent parseQuery(String query) {
    final clean = query.trim().toLowerCase();

    // 1. NBA / Basketball
    if (clean.contains('nba') || clean.contains('knicks') || clean.contains('spurs') || clean.contains('basketball')) {
      return const ParsedIntent(
        intent: "live_event_search",
        eventType: "sports",
        league: "NBA",
        keywords: ["nba finals", "knicks", "spurs", "abc", "espn", "basketball", "wabc", "finals"],
        dateScope: "today",
        preferredContentType: "live_tv",
      );
    }

    // 2. NFL / Football
    if (clean.contains('nfl') || clean.contains('falcons') || clean.contains('patriots') || clean.contains('football')) {
      return const ParsedIntent(
        intent: "live_event_search",
        eventType: "sports",
        league: "NFL",
        keywords: ["nfl", "falcons", "patriots", "football", "nbc", "peacock", "fox", "cbs", "kickoff"],
        dateScope: "today",
        preferredContentType: "live_tv",
      );
    }

    // 3. UFC / MMA
    if (clean.contains('ufc') || clean.contains('mma') || clean.contains('fight') || clean.contains('jones') || clean.contains('aspinall')) {
      return const ParsedIntent(
        intent: "live_event_search",
        eventType: "sports",
        league: "UFC",
        keywords: ["ufc", "jones", "aspinall", "mma", "espn", "espn ppv", "championship", "fight"],
        dateScope: "today",
        preferredContentType: "live_tv",
      );
    }

    // 4. Soccer / Champions League
    if (clean.contains('soccer') || clean.contains('champions league') || clean.contains('uefa')) {
      return const ParsedIntent(
        intent: "live_event_search",
        eventType: "sports",
        league: "Champions League",
        keywords: ["soccer", "champions league", "football", "cbs", "paramount+", "final"],
        dateScope: "today",
        preferredContentType: "live_tv",
      );
    }

    // 5. News / Breaking News
    if (clean.contains('news') || clean.contains('cnn') || clean.contains('msnbc') || clean.contains('breaking')) {
      return const ParsedIntent(
        intent: "live_event_search",
        eventType: "news",
        league: "Global",
        keywords: ["news", "breaking news", "cnn", "msnbc", "fox news", "weather", "live news"],
        dateScope: "today",
        preferredContentType: "live_tv",
      );
    }

    // Standard fallback: Tokenize the query to form keyword lists
    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    if (tokens.isEmpty && clean.isNotEmpty) {
      tokens.add(clean);
    }

    final isSports = clean.contains('sport') || clean.contains('game') || clean.contains('match');
    final isNews = clean.contains('news') || clean.contains('breaking') || clean.contains('live');

    return ParsedIntent(
      intent: "live_event_search",
      eventType: isSports ? "sports" : (isNews ? "news" : "general"),
      keywords: tokens,
      dateScope: "today",
      preferredContentType: "live_tv",
    );
  }
}

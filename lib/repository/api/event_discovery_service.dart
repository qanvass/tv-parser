import '../models/spotlight_event.dart';

class EventDiscoveryService {
  /// Local Mock list of major upcoming live events.
  static const List<SpotlightEvent> _mockEvents = [
    SpotlightEvent(
      id: "nba_finals_2026_game_1",
      title: "NBA Finals: Knicks vs Spurs",
      sport: "Basketball",
      league: "NBA",
      startTimeLocal: "2026-06-03T20:30:00-04:00",
      networks: ["ABC", "ESPN App"],
      keywords: ["nba finals", "knicks", "spurs", "basketball", "abc", "wabc", "espn", "finals"],
      priority: 100,
    ),
    SpotlightEvent(
      id: "nfl_game_kickoff_2026",
      title: "NFL Kickoff: Falcons vs Patriots",
      sport: "Football",
      league: "NFL",
      startTimeLocal: "2026-06-03T19:00:00-04:00",
      networks: ["NBC", "Peacock"],
      keywords: ["nfl", "falcons", "patriots", "football", "nbc", "peacock", "kickoff"],
      priority: 95,
    ),
    SpotlightEvent(
      id: "ufc_championship_fight",
      title: "UFC 320: Jones vs Aspinall",
      sport: "MMA",
      league: "UFC",
      startTimeLocal: "2026-06-03T22:00:00-04:00",
      networks: ["ESPN", "ESPN PPV"],
      keywords: ["ufc", "jones", "aspinall", "mma", "espn", "championship", "fight"],
      priority: 90,
    ),
    SpotlightEvent(
      id: "champions_league_final_2026",
      title: "UEFA Champions League Final",
      sport: "Soccer",
      league: "Champions League",
      startTimeLocal: "2026-06-03T15:00:00-04:00",
      networks: ["CBS", "Paramount+"],
      keywords: ["soccer", "champions league", "real madrid", "cbs", "paramount", "final", "football"],
      priority: 85,
    ),
    SpotlightEvent(
      id: "live_breaking_news_coverage",
      title: "Breaking News: Live Coverage",
      sport: "News",
      league: "Global",
      startTimeLocal: "2026-06-03T08:00:00-04:00",
      networks: ["CNN", "MSNBC", "Fox News"],
      keywords: ["breaking news", "live news", "cnn", "msnbc", "fox news", "election", "weather"],
      priority: 80,
    ),
  ];

  /// Fetches spotlight events relevant to the current user time and location preference.
  static Future<List<SpotlightEvent>> getSpotlightEvents({
    DateTime? mockTime,
    String? region,
  }) async {
    // Resolve current comparison time
    final targetTime = mockTime ?? DateTime.now();

    final List<SpotlightEvent> activeEvents = [];
    for (final event in _mockEvents) {
      if (event.isLiveToday(targetTime)) {
        activeEvents.add(event);
      }
    }

    // Sort by priority desc
    activeEvents.sort((a, b) => b.priority.compareTo(a.priority));

    // Fallback: If no event matches the dynamic 12h window (due to testing on a different date),
    // return all mock events so the UI is always testable and renders immediately.
    if (activeEvents.isEmpty) {
      return List.from(_mockEvents);
    }

    return activeEvents;
  }
}

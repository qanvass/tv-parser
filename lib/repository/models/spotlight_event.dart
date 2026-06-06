class SpotlightEvent {
  final String id;
  final String title;
  final String sport;
  final String league;
  final String startTimeLocal; // ISO-8601 offset format e.g. "2026-06-03T20:30:00-04:00"
  final List<String> networks;
  final List<String> keywords;
  final int priority;

  const SpotlightEvent({
    required this.id,
    required this.title,
    required this.sport,
    required this.league,
    required this.startTimeLocal,
    required this.networks,
    required this.keywords,
    required this.priority,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sport': sport,
        'league': league,
        'startTimeLocal': startTimeLocal,
        'networks': networks,
        'keywords': keywords,
        'priority': priority,
      };

  factory SpotlightEvent.fromJson(Map<String, dynamic> json) {
    return SpotlightEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      sport: json['sport']?.toString() ?? '',
      league: json['league']?.toString() ?? '',
      startTimeLocal: json['startTimeLocal']?.toString() ?? '',
      networks: List<String>.from(json['networks'] ?? []),
      keywords: List<String>.from(json['keywords'] ?? []),
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
    );
  }

  /// Helper to check if event is active or starts in the near future (e.g. today)
  bool isLiveToday(DateTime userLocalTime) {
    try {
      final startTime = DateTime.parse(startTimeLocal);
      final difference = startTime.difference(userLocalTime);

      // Event is "Live Today" if it is scheduled for today (e.g. within 12 hours before or after)
      return difference.inHours.abs() <= 12;
    } catch (_) {
      return false;
    }
  }
}

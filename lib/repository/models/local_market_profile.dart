class LocalMarketProfile {
  final String id;
  final String displayName;
  final String city;
  final String state;
  final String timezone;
  final double latitude;
  final double longitude;
  final Map<String, List<String>> stationAliases;
  final List<String> sportsAliases;
  final List<String> newsAliases;
  final List<String> spanishAliases;
  final List<String> nearbyMarkets; // List of nearby market IDs

  const LocalMarketProfile({
    required this.id,
    required this.displayName,
    required this.city,
    required this.state,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    required this.stationAliases,
    required this.sportsAliases,
    required this.newsAliases,
    required this.spanishAliases,
    required this.nearbyMarkets,
  });

  factory LocalMarketProfile.fromJson(Map<String, dynamic> json) {
    return LocalMarketProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      timezone: json['timezone']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
      stationAliases: (json['stationAliases'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, List<String>.from(v as Iterable)),
          ) ??
          {},
      sportsAliases: List<String>.from(json['sportsAliases'] as Iterable? ?? []),
      newsAliases: List<String>.from(json['newsAliases'] as Iterable? ?? []),
      spanishAliases: List<String>.from(json['spanishAliases'] as Iterable? ?? []),
      nearbyMarkets: List<String>.from(json['nearbyMarkets'] as Iterable? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'city': city,
        'state': state,
        'timezone': timezone,
        'latitude': latitude,
        'longitude': longitude,
        'stationAliases': stationAliases,
        'sportsAliases': sportsAliases,
        'newsAliases': newsAliases,
        'spanishAliases': spanishAliases,
        'nearbyMarkets': nearbyMarkets,
      };
}

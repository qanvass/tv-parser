import 'dart:math' as math;

import '../models/local_market_profile.dart';
import 'local_market_service.dart';
import 'provider_curation_rules.dart';
import '../models/user_preference_profile.dart';

/// Orders "local" channels (e.g. a playlist's "US Local" group) nearest-first
/// relative to the user's Local TV Market. Uses only the channel name:
/// the market's own city/callsigns first, then other known market cities,
/// then the trailing US state code ("ABC (KAKE) Wichita KS"). Channels with
/// no recognisable place keep their order at the end. Never invents data.
class LocalProximity {
  LocalProximity._();

  /// True for playlist groups that hold local affiliates.
  static bool isLocalCategory(String? name) {
    if (name == null) return false;
    final n = name.toLowerCase();
    return n.contains('local');
  }

  /// The user's Local TV Market when location personalization is on.
  static LocalMarketProfile? activeMarket() {
    if (!UserPreferenceProfile.load().locationFeatureEnabled) return null;
    return LocalMarketService.getActiveMarket();
  }

  /// Nearest-first when [categoryName] is a local group and a market is set;
  /// otherwise [items] unchanged.
  static List<T> orderIfLocal<T>(
    String? categoryName,
    List<T> items,
    String Function(T) nameOf,
  ) {
    if (!isLocalCategory(categoryName)) return items;
    final market = activeMarket();
    return market == null ? items : sortNearest(items, market, nameOf);
  }

  /// Stable nearest-first ordering of [items] by [nameOf].
  static List<T> sortNearest<T>(
    List<T> items,
    LocalMarketProfile market,
    String Function(T) nameOf,
  ) {
    final ctx = _MarketContext(market);
    final keyed = <(double, int, T)>[];
    for (var i = 0; i < items.length; i++) {
      keyed.add((ctx.rank(nameOf(items[i])), i, items[i]));
    }
    keyed.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final k in keyed) k.$3];
  }

  /// Keeps own-market channels, channels with no recognisable place, and
  /// those within [maxKm]; drops ones that name a far-away city/state
  /// (e.g. "FOX 5 New York" matching an Atlanta "FOX 5" alias). Order kept.
  static List<T> nearbyOnly<T>(
    List<T> items,
    LocalMarketProfile market,
    String Function(T) nameOf, {
    double maxKm = 400,
  }) {
    final ctx = _MarketContext(market);
    return [
      for (final item in items)
        if (() {
          final r = ctx.rank(nameOf(item));
          return r <= maxKm || r >= 1e9;
        }())
          item,
    ];
  }

  /// Approximate geographic centres (lat, lng) of US states + DC.
  static const Map<String, (double, double)> _stateCentres = {
    'AL': (32.8, -86.8),
    'AK': (61.4, -152.3),
    'AZ': (34.2, -111.7),
    'AR': (34.9, -92.4),
    'CA': (36.8, -119.4),
    'CO': (39.0, -105.5),
    'CT': (41.6, -72.7),
    'DE': (39.0, -75.5),
    'DC': (38.9, -77.0),
    'FL': (28.6, -82.4),
    'GA': (32.7, -83.4),
    'HI': (20.8, -156.3),
    'ID': (44.4, -114.6),
    'IL': (40.0, -89.2),
    'IN': (39.9, -86.3),
    'IA': (42.1, -93.5),
    'KS': (38.5, -98.4),
    'KY': (37.5, -85.3),
    'LA': (31.1, -92.0),
    'ME': (45.4, -69.2),
    'MD': (39.0, -76.8),
    'MA': (42.3, -71.8),
    'MI': (44.3, -85.4),
    'MN': (46.3, -94.3),
    'MS': (32.7, -89.7),
    'MO': (38.4, -92.5),
    'MT': (47.0, -109.6),
    'NE': (41.5, -99.8),
    'NV': (39.3, -116.6),
    'NH': (43.7, -71.6),
    'NJ': (40.2, -74.7),
    'NM': (34.4, -106.1),
    'NY': (42.9, -75.5),
    'NC': (35.6, -79.4),
    'ND': (47.5, -100.5),
    'OH': (40.3, -82.8),
    'OK': (35.6, -97.5),
    'OR': (43.9, -120.6),
    'PA': (40.9, -77.8),
    'RI': (41.7, -71.5),
    'SC': (33.9, -80.9),
    'SD': (44.4, -100.2),
    'TN': (35.9, -86.4),
    'TX': (31.5, -99.3),
    'UT': (39.3, -111.7),
    'VT': (44.1, -72.7),
    'VA': (37.5, -78.9),
    'WA': (47.4, -120.5),
    'WV': (38.6, -80.6),
    'WI': (44.6, -89.9),
    'WY': (43.0, -107.6),
    'PR': (18.2, -66.5),
  };

  /// Full state names → code. Bare "Washington" is left out (city vs state).
  static const Map<String, String> _stateNames = {
    'district of columbia': 'DC',
    'alabama': 'AL',
    'alaska': 'AK',
    'arizona': 'AZ',
    'arkansas': 'AR',
    'california': 'CA',
    'colorado': 'CO',
    'connecticut': 'CT',
    'delaware': 'DE',
    'florida': 'FL',
    'georgia': 'GA',
    'hawaii': 'HI',
    'idaho': 'ID',
    'illinois': 'IL',
    'indiana': 'IN',
    'iowa': 'IA',
    'kansas': 'KS',
    'kentucky': 'KY',
    'louisiana': 'LA',
    'maine': 'ME',
    'maryland': 'MD',
    'massachusetts': 'MA',
    'michigan': 'MI',
    'minnesota': 'MN',
    'mississippi': 'MS',
    'missouri': 'MO',
    'montana': 'MT',
    'nebraska': 'NE',
    'nevada': 'NV',
    'new hampshire': 'NH',
    'new jersey': 'NJ',
    'new mexico': 'NM',
    'north carolina': 'NC',
    'north dakota': 'ND',
    'ohio': 'OH',
    'oklahoma': 'OK',
    'oregon': 'OR',
    'pennsylvania': 'PA',
    'rhode island': 'RI',
    'south carolina': 'SC',
    'south dakota': 'SD',
    'tennessee': 'TN',
    'texas': 'TX',
    'utah': 'UT',
    'vermont': 'VT',
    'virginia': 'VA',
    'west virginia': 'WV',
    'wisconsin': 'WI',
    'wyoming': 'WY',
    'puerto rico': 'PR',
  };

  /// Longest spelled-out state in [lower] ("west virginia" over "virginia").
  static String? _stateFromName(String lower) {
    String? hit;
    var hitLen = 0;
    for (final e in _stateNames.entries) {
      if (e.key.length > hitLen && RegExp('\\b${e.key}\\b').hasMatch(lower)) {
        hit = e.value;
        hitLen = e.key.length;
      }
    }
    return hit;
  }

  static final RegExp _stateToken = RegExp(r'\b([A-Z]{2})\b');
  static final RegExp _callsign = RegExp(r'^[KW][A-Z]{2,3}(-TV)?$');

  static double _km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}

class _MarketContext {
  final LocalMarketProfile market;
  late final String _city = market.city.toLowerCase();
  late final List<RegExp> _callsigns = [
    for (final list in market.stationAliases.values)
      for (final alias in list)
        if (LocalProximity._callsign.hasMatch(alias.toUpperCase()))
          RegExp('\\b${RegExp.escape(alias.toLowerCase())}\\b'),
  ];
  late final List<(String, double, double)> _otherCities = [
    for (final m in LocalMarketService.supportedMarkets)
      if (m.id != market.id) (m.city.toLowerCase(), m.latitude, m.longitude),
  ];

  _MarketContext(this.market);

  /// Lower = closer. Own-market channels sort below 0 by station priority.
  double rank(String name) {
    final lower = name.toLowerCase();
    final own =
        lower.contains(_city) || _callsigns.any((re) => re.hasMatch(lower));
    if (own) {
      final priority = market.id == 'atlanta_ga'
          ? ProviderCurationRules.getAtlantaLocalPriority(name)
          : 0;
      return -1.0 - priority;
    }
    for (final (city, lat, lng) in _otherCities) {
      if (lower.contains(city)) {
        return LocalProximity._km(market.latitude, market.longitude, lat, lng);
      }
    }
    // Last two-letter state code in the name ("... Wichita KS").
    String? state;
    for (final m in LocalProximity._stateToken.allMatches(name)) {
      final code = m.group(1)!;
      if (LocalProximity._stateCentres.containsKey(code)) state = code;
    }
    // Spelled-out place ("FOX 5 Plus (District of Columbia)").
    state ??= LocalProximity._stateFromName(lower);
    if (state != null) {
      if (state == market.state) return 1.0;
      final (lat, lng) = LocalProximity._stateCentres[state]!;
      return LocalProximity._km(market.latitude, market.longitude, lat, lng);
    }
    return 1e9;
  }
}

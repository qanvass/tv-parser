import '../models/spotlight_event.dart';

class EventDiscoveryService {
  /// Fetches spotlight events relevant to the current user time and location preference.
  static Future<List<SpotlightEvent>> getSpotlightEvents({
    DateTime? mockTime,
    String? region,
  }) async {
    return [];
  }
}

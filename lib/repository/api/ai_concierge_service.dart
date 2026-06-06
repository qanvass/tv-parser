import 'dart:async';
import 'package:get_storage/get_storage.dart';
import '../models/user_preference_profile.dart';

class AiConciergeService {
  static final _storage = GetStorage("ai_concierge_cache");
  static int _requestCount = 0;
  static DateTime? _lastRequestTime;

  /// Optional backend URL configuration (never expose raw API keys inside the app!)
  static const String backendAiEndpoint = "https://your-backend-proxy.com/api/ai/recommend";

  /// Evaluates and filters candidate recommendations using high-end AI recommendations logic
  static Future<List<Map<String, String>>> fetchAiRecommendations({
    required String query,
    required UserPreferenceProfile profile,
    required List<Map<String, String>> candidates,
  }) async {
    // 1. Capping limit (Max 50 items sent to the AI backend to keep token usage extremely low)
    final cappedCandidates = candidates.take(50).toList();

    // 2. Local Rate-limiting (Throttle requests to max 5 calls per minute)
    final now = DateTime.now();
    if (_lastRequestTime != null && now.difference(_lastRequestTime!) < const Duration(minutes: 1)) {
      if (_requestCount >= 5) {
        throw Exception("Concierge rate limit reached. Please wait a moment.");
      }
      _requestCount++;
    } else {
      _requestCount = 1;
      _lastRequestTime = now;
    }

    // 3. Response Caching Logic (avoid querying the backend for identical queries)
    final cacheKey = "${profile.country}_${profile.language}_${query.toLowerCase().trim()}";
    final cachedData = _storage.read(cacheKey);
    if (cachedData != null) {
      try {
        final List<dynamic> decoded = cachedData;
        return decoded.map((item) => Map<String, String>.from(item)).toList();
      } catch (_) {}
    }

    // 4. Emulate Backend AI Processing (Mocks low-cost pay-as-you-go Gemini Flash or GPT-4o mini proxy response)
    // If you hook up a real backend later, this is where your proxy POST lives!
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate roundtrip latency

    final List<Map<String, String>> recommendations = [];
    final q = query.toLowerCase();

    for (final c in cappedCandidates) {
      final name = (c['name'] ?? '').toLowerCase();
      final cat = (c['category'] ?? '').toLowerCase();

      String? reason;
      if (q.contains("sports") && (name.contains("sport") || cat.contains("sport"))) {
        reason = "Recommended sports channel matching your request";
      } else if (q.contains("news") && (name.contains("news") || cat.contains("news"))) {
        reason = "Local news streaming in your region";
      } else if (q.contains("movie") && (name.contains("movie") || cat.contains("movie"))) {
        reason = "Popular VOD recommendation based on interest";
      } else if (profile.language != null &&
          (name.contains(profile.language!.toLowerCase()) || cat.contains(profile.language!.toLowerCase()))) {
        reason = "Concierge picked language-matching highlight";
      } else if (profile.country != null &&
          (name.contains(profile.country!.toLowerCase()) || cat.contains(profile.country!.toLowerCase()))) {
        reason = "Trending stream from your location";
      }

      if (reason != null) {
        recommendations.add({
          'streamId': c['streamId'] ?? '',
          'name': c['name'] ?? '',
          'category': c['category'] ?? '',
          'streamIcon': c['streamIcon'] ?? '',
          'type': c['type'] ?? 'live',
          'reason': reason,
        });
      }
      if (recommendations.length >= 8) break; // return top 8
    }

    // Fallback if no matching reasons found
    if (recommendations.isEmpty && cappedCandidates.isNotEmpty) {
      for (var i = 0; i < cappedCandidates.length && i < 5; i++) {
        recommendations.add({
          'streamId': cappedCandidates[i]['streamId'] ?? '',
          'name': cappedCandidates[i]['name'] ?? '',
          'category': cappedCandidates[i]['category'] ?? '',
          'streamIcon': cappedCandidates[i]['streamIcon'] ?? '',
          'type': cappedCandidates[i]['type'] ?? 'live',
          'reason': "Concierge selected favorite highlight based on your profile",
        });
      }
    }

    // Save to Cache
    await _storage.write(cacheKey, recommendations);

    return recommendations;
  }
}

import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'channel_intelligence_cache.dart';
import 'channel_intelligence_config.dart';

/// Gemini Flash enrichment for descriptions, genres, trailer hints, and logo domains.
/// Disabled by default; enable with ENABLE_GEMINI + API key (never committed).
class GeminiChannelIntelligenceService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Enriches movie/series metadata. Returns cached or freshly generated payload.
  static Future<Map<String, dynamic>?> enrichTitle({
    required String title,
    String? year,
    String contentType = 'movie',
    String? existingPlot,
  }) async {
    final cacheId =
        '${contentType}:${_normalize(title)}${year != null ? ':$year' : ''}';
    final cached = await ChannelIntelligenceCache.read('enrich', cacheId);
    if (cached != null) return cached;

    if (!ChannelIntelligenceConfig.enableGemini) return null;
    final apiKey = await ChannelIntelligenceConfig.resolveApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final prompt = '''
You are a neutral media metadata assistant for a legal IPTV player app.
Given a title from a user playlist, return ONLY valid JSON (no markdown):
{"description":"2-3 sentence neutral synopsis","genres":["Genre1","Genre2"],"youtubeSearchQuery":"Title Year official trailer"}

Title: "$title"${year != null ? '\nYear: $year' : ''}
Content type: $contentType
${existingPlot != null && existingPlot.isNotEmpty ? 'Existing plot (may be spam, ignore if low quality): "$existingPlot"' : ''}
Do not mention IPTV, subscriptions, or piracy. Keep description factual and family-safe.
''';

    final result = await _generateJson(
      apiKey: apiKey,
      model: ChannelIntelligenceConfig.geminiModel,
      prompt: prompt,
    );
    if (result != null) {
      await ChannelIntelligenceCache.write('enrich', cacheId, result);
    }
    return result;
  }

  /// Suggests a brand domain for logo lookup (e.g. "espn.com").
  static Future<String?> suggestLogoDomain(String channelName) async {
    final cacheId = _normalize(channelName);
    final cached = await ChannelIntelligenceCache.read('logo_domain', cacheId);
    if (cached?['domain'] != null) return cached!['domain'].toString();

    if (!ChannelIntelligenceConfig.enableGemini) return null;
    final apiKey = await ChannelIntelligenceConfig.resolveApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final prompt = '''
Return ONLY valid JSON for a TV channel name from a user playlist:
{"brandDomain":"example.com"}
Channel: "$channelName"
Pick the most likely official broadcaster website domain. No explanation.
''';

    final result = await _generateJson(
      apiKey: apiKey,
      model: ChannelIntelligenceConfig.geminiLiteModel,
      prompt: prompt,
    );
    final domain = result?['brandDomain']?.toString().trim();
    if (domain != null && domain.isNotEmpty) {
      await ChannelIntelligenceCache.write('logo_domain', cacheId, {
        'domain': domain,
      });
    }
    return domain;
  }

  /// Returns a YouTube search query optimized for trailer discovery.
  static Future<String?> suggestTrailerSearchQuery({
    required String title,
    String? year,
  }) async {
    final cacheId = _normalize('$title${year ?? ''}');
    final cached = await ChannelIntelligenceCache.read('trailer', cacheId);
    if (cached?['youtubeSearchQuery'] != null) {
      return cached!['youtubeSearchQuery'].toString();
    }

    if (!ChannelIntelligenceConfig.enableGemini) return null;
    final apiKey = await ChannelIntelligenceConfig.resolveApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final prompt = '''
Return ONLY valid JSON:
{"youtubeSearchQuery":"Title Year official trailer"}
Title: "$title"${year != null ? '\nYear: $year' : ''}
''';

    final result = await _generateJson(
      apiKey: apiKey,
      model: ChannelIntelligenceConfig.geminiModel,
      prompt: prompt,
    );
    final query = result?['youtubeSearchQuery']?.toString();
    if (query != null && query.isNotEmpty) {
      await ChannelIntelligenceCache.write('trailer', cacheId, {
        'youtubeSearchQuery': query,
      });
    }
    return query;
  }

  static Future<Map<String, dynamic>?> _generateJson({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    try {
      final url = '$_baseUrl/$model:generateContent?key=$apiKey';
      final response = await _dio.post(
        url,
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 512,
            'responseMimeType': 'application/json',
          },
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final text = _extractText(response.data);
      if (text == null || text.isEmpty) return null;

      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[GeminiIntelligence] generate failed: $e');
      log('[GeminiIntelligence] error: $e');
    }
    return null;
  }

  static String? _extractText(dynamic data) {
    try {
      final candidates = data?['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final parts = candidates[0]?['content']?['parts'];
      if (parts is! List || parts.isEmpty) return null;
      return parts[0]?['text']?.toString();
    } catch (_) {}
    return null;
  }

  static String _normalize(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

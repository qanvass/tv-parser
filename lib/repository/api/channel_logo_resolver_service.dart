import 'dart:developer';

import 'package:dio/dio.dart';

import 'channel_intelligence_cache.dart';
import 'gemini_channel_intelligence_service.dart';

/// Resolves channel logos when playlist URLs 404 or are missing.
/// Uses cached heuristics first; optional Gemini domain hint when flagged.
class ChannelLogoResolverService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 4),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (compatible; TVParser/2.0; +https://tvparser.app)',
      },
    ),
  );

  static final Map<String, Future<String?>> _inFlight = {};

  /// Returns a working logo URL or null (caller shows initials).
  static Future<String?> resolveLogo({
    required String channelName,
    String? primaryUrl,
  }) async {
    final normalized = _normalize(channelName);
    if (normalized.isEmpty) return null;

    final cacheKey = normalized;
    final cached = await ChannelIntelligenceCache.readLogo(cacheKey);
    if (cached != null && await _urlExists(cached)) {
      return cached;
    }

    return _inFlight.putIfAbsent(cacheKey, () async {
      try {
        if (primaryUrl != null &&
            primaryUrl.trim().isNotEmpty &&
            await _urlExists(primaryUrl.trim())) {
          await ChannelIntelligenceCache.writeLogo(cacheKey, primaryUrl.trim());
          return primaryUrl.trim();
        }

        final cleaned = _cleanDisplayName(channelName);

        // Wikipedia thumbnail (brand-neutral lookup by playlist name).
        final wiki = await _wikipediaThumbnail(cleaned);
        if (wiki != null) {
          await ChannelIntelligenceCache.writeLogo(cacheKey, wiki);
          return wiki;
        }

        // Clearbit + Google favicon from guessed domain.
        for (final domain in _guessDomains(cleaned)) {
          final clearbit = 'https://logo.clearbit.com/$domain';
          if (await _urlExists(clearbit)) {
            await ChannelIntelligenceCache.writeLogo(cacheKey, clearbit);
            return clearbit;
          }
          final favicon =
              'https://www.google.com/s2/favicons?domain=$domain&sz=128';
          if (await _urlExists(favicon)) {
            await ChannelIntelligenceCache.writeLogo(cacheKey, favicon);
            return favicon;
          }
        }

        // Optional Gemini domain hint (feature-flagged).
        final geminiDomain =
            await GeminiChannelIntelligenceService.suggestLogoDomain(cleaned);
        if (geminiDomain != null && geminiDomain.isNotEmpty) {
          final clearbit = 'https://logo.clearbit.com/$geminiDomain';
          if (await _urlExists(clearbit)) {
            await ChannelIntelligenceCache.writeLogo(cacheKey, clearbit);
            return clearbit;
          }
        }
      } catch (e) {
        log('[LogoResolver] failed for "$channelName": $e');
      } finally {
        _inFlight.remove(cacheKey);
      }
      return null;
    });
  }

  static String _normalize(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _cleanDisplayName(String name) {
    var text = name.trim();
    text = text.replaceAll(RegExp(r'\([^)]*\)'), '');
    text = text.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    final noise = [
      r'\bhd\b', r'\bfhd\b', r'\b4k\b', r'\buhd\b', r'\bsd\b',
      r'\busa\b', r'\bus\b', r'\buk\b', r'\ben\b', r'\blive\b',
      r'\bchannel\b', r'\btv\b', r'\+\d+',
    ];
    for (final n in noise) {
      text = text.replaceAll(RegExp(n, caseSensitive: false), ' ');
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> _guessDomains(String cleaned) {
    final tokens = cleaned
        .toLowerCase()
        .split(RegExp(r'[\s\-_\.]+'))
        .where((t) => t.length >= 3 && !RegExp(r'^\d+$').hasMatch(t))
        .toList();
    if (tokens.isEmpty) return [];
    final primary = tokens.first;
    final joined = tokens.take(2).join('');
    return {
      '$primary.com',
      '$primary.tv',
      '$joined.com',
      if (tokens.length > 1) '${tokens[0]}${tokens[1]}.com',
    }.toList();
  }

  static Future<bool> _urlExists(String url) async {
    try {
      final head = await _dio.head(url);
      if (head.statusCode != null &&
          head.statusCode! >= 200 &&
          head.statusCode! < 400) {
        return true;
      }
    } catch (_) {}
    try {
      final get = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final code = get.statusCode ?? 0;
      final bytes = get.data?.length ?? 0;
      return code >= 200 && code < 400 && bytes > 64;
    } catch (_) {}
    return false;
  }

  static Future<String?> _wikipediaThumbnail(String query) async {
    if (query.length < 2) return null;
    try {
      final searchUrl =
          'https://en.wikipedia.org/w/api.php?action=opensearch&search=${Uri.encodeComponent(query)}&limit=1&namespace=0&format=json';
      final searchResp = await _dio.get(searchUrl);
      if (searchResp.data is! List || (searchResp.data as List).length < 2) {
        return null;
      }
      final titles = (searchResp.data as List)[1];
      if (titles is! List || titles.isEmpty) return null;
      final title = titles.first.toString();
      if (title.isEmpty) return null;

      final imageUrl =
          'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(title)}&prop=pageimages&format=json&pithumbsize=256';
      final imgResp = await _dio.get(imageUrl);
      final pages = imgResp.data?['query']?['pages'];
      if (pages is! Map) return null;
      for (final page in pages.values) {
        if (page is Map && page['thumbnail']?['source'] != null) {
          return page['thumbnail']['source'].toString();
        }
      }
    } catch (_) {}
    return null;
  }
}

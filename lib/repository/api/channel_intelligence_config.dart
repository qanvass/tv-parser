import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Feature flags and API key resolution for Gemini-powered channel intelligence.
/// Keys are never committed — use dart-define or local `.secrets/gemini.json`.
class ChannelIntelligenceConfig {
  static const bool enableGemini = bool.fromEnvironment(
    'ENABLE_GEMINI',
    defaultValue: false,
  );

  static const String geminiApiKeyDefine = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Primary model for descriptions / trailer hints.
  static const String geminiModel = 'gemini-2.0-flash';

  /// Lighter model for logo-domain hints only.
  static const String geminiLiteModel = 'gemini-2.0-flash-lite';

  static const Duration cacheTtl = Duration(days: 30);

  static String? _cachedKey;

  static bool get isGeminiAvailable =>
      enableGemini && (_cachedKey ?? geminiApiKeyDefine).isNotEmpty;

  /// Resolves API key once per session: dart-define → `.secrets/gemini.json`.
  static Future<String?> resolveApiKey() async {
    if (_cachedKey != null) return _cachedKey;
    if (geminiApiKeyDefine.isNotEmpty) {
      _cachedKey = geminiApiKeyDefine;
      return _cachedKey;
    }
    try {
      final key = await _readSecretsFile();
      if (key != null && key.isNotEmpty) {
        _cachedKey = key;
      }
    } catch (e) {
      debugPrint('[ChannelIntelligence] secrets read failed: $e');
    }
    return _cachedKey;
  }

  static Future<String?> _readSecretsFile() async {
    final candidates = <File>[];

    // Dev: project-root `.secrets` when running from workspace on desktop.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final cwd = Directory.current;
      candidates.add(File('${cwd.path}/.secrets/gemini.json'));
      candidates.add(File('${cwd.path}/../.secrets/gemini.json'));
    }

    // Mobile: optional file in app support dir (side-loaded for QA).
    try {
      final dir = await getApplicationSupportDirectory();
      candidates.add(File('${dir.path}/.secrets/gemini.json'));
    } catch (_) {}

    for (final file in candidates) {
      if (!await file.exists()) continue;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final key = decoded['api_key']?.toString() ??
            decoded['GEMINI_API_KEY']?.toString();
        if (key != null && key.isNotEmpty) return key;
      }
    }
    return null;
  }
}

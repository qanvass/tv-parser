import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Startup Show / APTV native catalog host (not M3U).
///
/// Movies/Series/trailers/popular rails come from `dev.testbyte.top`, while
/// Live stays on starlite `/api/list` M3U. Auth is `POST /api/login` with
/// `{username,password}` — M3U list creds are often a different account.
class ApolloStartupShowApi {
  static const String defaultBaseUrl = 'https://dev.testbyte.top/api/';
  static const String proxyBaseUrl = 'https://proxy.testbyte.top/api/';

  final String baseUrl;

  ApolloStartupShowApi({
    Dio? dio,
    this.baseUrl = defaultBaseUrl,
    ApolloNativeAuthSession? session,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 45),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 12; Android TV) AppleWebKit/537.36',
                },
              ),
            ),
        _session = session ?? ApolloNativeAuthSession.empty() {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) {
        _attachAuthHeaders(options);
        handler.next(options);
      }),
    );
  }

  final Dio _dio;
  ApolloNativeAuthSession _session;

  ApolloNativeAuthSession get session => _session;

  void applySession(ApolloNativeAuthSession session) {
    _session = session;
  }

  void _attachAuthHeaders(RequestOptions options) {
    final version = _session.apiVersion ?? 'V4';
    final profile = _session.apiProfile ?? 'androidtv';
    options.headers['X-API-Version'] = version;
    options.headers['X-API-PROFILE'] = profile;
    if (_session.appVersion != null && _session.appVersion!.isNotEmpty) {
      options.headers['X-APP-VERSION'] = _session.appVersion;
    }

    final bearer = _session.authorizationHeader;
    if (bearer != null) {
      options.headers['Authorization'] = bearer;
    }

    // HMAC headers when a capture provides secret + signer inputs.
    // Do not invent a signing secret — only attach if session already has them.
    if (_session.xSignature != null &&
        _session.xSignature!.isNotEmpty &&
        _session.xSignatureTimestamp != null &&
        _session.xSignatureTimestamp!.isNotEmpty) {
      options.headers['x-signature'] = _session.xSignature;
      options.headers['x-signature-timestamp'] = _session.xSignatureTimestamp;
    }
  }

  /// `POST /login` — real Startup Show gate.
  /// Returns updated session on success; throws [ApolloNativeApiException] on failure.
  Future<ApolloNativeAuthSession> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        'login',
        data: {'username': username, 'password': password},
      );
      final map = _asMap(response.data);
      if (map == null) {
        throw ApolloNativeApiException(
          statusCode: response.statusCode ?? 0,
          message: 'Login response was not a JSON object',
          kind: ApolloNativeAuthFailure.unknown,
        );
      }
      final success = map['success'];
      if (success == false) {
        throw ApolloNativeApiException(
          statusCode: response.statusCode ?? 400,
          message: (map['message'] ?? 'Login failed').toString(),
          kind: ApolloNativeAuthFailure.badCredentials,
        );
      }
      final next = ApolloNativeAuthSession.fromLoginResponse(
        map,
        username: username,
      );
      if (!next.hasAuthMaterial) {
        throw ApolloNativeApiException(
          statusCode: response.statusCode ?? 200,
          message:
              'Login succeeded but no token/session fields were recognized',
          kind: ApolloNativeAuthFailure.unknown,
          bodyKeys: map.keys.map((e) => e.toString()).toList(),
        );
      }
      _session = next;
      return next;
    } on ApolloNativeApiException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e, fallback: ApolloNativeAuthFailure.badCredentials);
    }
  }

  Future<List<Map<String, dynamic>>> movieCategories() =>
      _getList('info/movie/categories');

  Future<List<Map<String, dynamic>>> movieItems({
    required String categoryId,
    int offset = 0,
    int limit = 40,
  }) =>
      _getList('info/movie/items/$categoryId/$offset/$limit');

  Future<List<Map<String, dynamic>>> popularMovieCategories({
    int offset = 0,
    int limit = 99,
  }) =>
      _getList('popular/movie/categories/$offset/$limit');

  Future<List<Map<String, dynamic>>> movieRecommendations() =>
      _getList('info/movies/recommendations');

  Future<Map<String, dynamic>?> movieByIds(String ids) =>
      _getMap('info/movie/$ids');

  Future<List<Map<String, dynamic>>> movieSearch(String keyword) =>
      _getList('info/movie/search/${Uri.encodeComponent(keyword)}');

  Future<Map<String, dynamic>?> playMovie(String imdbId) =>
      _getMap('play/movie/$imdbId');

  Future<List<Map<String, dynamic>>> tvShowCategories() =>
      _getList('info/tvshow/categories');

  Future<List<Map<String, dynamic>>> tvShowItems({
    required String categoryId,
    int offset = 0,
    int limit = 40,
  }) =>
      _getList('info/tvshow/items/$categoryId/$offset/$limit');

  Future<List<Map<String, dynamic>>> liveTvCategories() =>
      _getList('info/livetv/categories');

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final data = await _getRaw(path);
    return _coerceList(data);
  }

  Future<Map<String, dynamic>?> _getMap(String path) async {
    final data = await _getRaw(path);
    return _asMap(data);
  }

  Future<dynamic> _getRaw(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data;
    } on DioException catch (e) {
      throw _mapDio(e, fallback: ApolloNativeAuthFailure.unauthorized);
    }
  }

  ApolloNativeApiException _mapDio(
    DioException e, {
    required ApolloNativeAuthFailure fallback,
  }) {
    final code = e.response?.statusCode ?? 0;
    final map = _asMap(e.response?.data);
    final message = (map?['message'] ?? e.message ?? 'request failed').toString();
    final kind = code == 401
        ? ApolloNativeAuthFailure.unauthorized
        : code == 400
            ? ApolloNativeAuthFailure.badCredentials
            : code == 422
                ? ApolloNativeAuthFailure.validation
                : fallback;
    return ApolloNativeApiException(
      statusCode: code,
      message: message,
      kind: kind,
      bodyKeys: map?.keys.map((k) => k.toString()).toList(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static List<Map<String, dynamic>> _coerceList(dynamic data) {
    if (data == null) return const [];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final map = _asMap(data);
    if (map == null) return const [];
    for (final key in const [
      'data',
      'items',
      'categories',
      'movies',
      'results',
      'list',
      'content',
    ]) {
      final v = map[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    // Single category/object payload — treat as one-element list when id-like.
    if (map.containsKey('id') ||
        map.containsKey('category_id') ||
        map.containsKey('categoryId')) {
      return [map];
    }
    return const [];
  }
}

enum ApolloNativeAuthFailure {
  none,
  unauthorized,
  badCredentials,
  validation,
  network,
  unknown,
  capturePending,
}

class ApolloNativeApiException implements Exception {
  final int statusCode;
  final String message;
  final ApolloNativeAuthFailure kind;
  final List<String>? bodyKeys;

  const ApolloNativeApiException({
    required this.statusCode,
    required this.message,
    required this.kind,
    this.bodyKeys,
  });

  @override
  String toString() =>
      'ApolloNativeApiException($statusCode, $kind, $message'
      '${bodyKeys == null ? '' : ', keys=${bodyKeys!.join(",")}'})';
}

/// Auth material for Startup Show native API — never hardcode HMAC secrets.
class ApolloNativeAuthSession {
  final String? username;
  final String? token;
  final String? refreshToken;
  final String? apiVersion;
  final String? apiProfile;
  final String? appVersion;
  final String? xSignature;
  final String? xSignatureTimestamp;
  final String? hmacSecretHintPresent; // "yes" only — never store inventing
  final DateTime? savedAt;
  final Map<String, dynamic>? rawLogin;

  const ApolloNativeAuthSession({
    this.username,
    this.token,
    this.refreshToken,
    this.apiVersion,
    this.apiProfile,
    this.appVersion,
    this.xSignature,
    this.xSignatureTimestamp,
    this.hmacSecretHintPresent,
    this.savedAt,
    this.rawLogin,
  });

  factory ApolloNativeAuthSession.empty() => const ApolloNativeAuthSession();

  bool get hasAuthMaterial =>
      (token != null && token!.trim().isNotEmpty) ||
      (xSignature != null && xSignature!.trim().isNotEmpty);

  String? get authorizationHeader {
    final t = token?.trim();
    if (t == null || t.isEmpty) return null;
    if (t.toLowerCase().startsWith('bearer ')) return t;
    return 'Bearer $t';
  }

  factory ApolloNativeAuthSession.fromLoginResponse(
    Map<String, dynamic> map, {
    String? username,
  }) {
    final nested = _firstMap(map, const ['data', 'user', 'session', 'result']);
    final source = nested ?? map;
    final token = _pickString(source, const [
          'token',
          'accessToken',
          'access_token',
          'authToken',
          'auth_token',
          'jwt',
          'sessionToken',
          'session_token',
          'apiToken',
          'api_token',
        ]) ??
        _pickString(map, const [
          'token',
          'accessToken',
          'access_token',
          'authToken',
          'jwt',
        ]);

    return ApolloNativeAuthSession(
      username: username ?? _pickString(source, const ['username', 'user', 'email']),
      token: token,
      refreshToken: _pickString(source, const [
        'refreshToken',
        'refresh_token',
      ]),
      apiVersion: _pickString(source, const ['apiVersion', 'api_version']) ?? 'V4',
      apiProfile:
          _pickString(source, const ['apiProfile', 'api_profile', 'profile']) ??
              'androidtv',
      appVersion: _pickString(source, const ['appVersion', 'app_version']),
      xSignature: _pickString(source, const ['x-signature', 'xSignature', 'signature']),
      xSignatureTimestamp: _pickString(source, const [
        'x-signature-timestamp',
        'xSignatureTimestamp',
        'signature_timestamp',
        'timestamp',
      ]),
      savedAt: DateTime.now().toUtc(),
      rawLogin: map,
    );
  }

  factory ApolloNativeAuthSession.fromJson(Map<String, dynamic> json) {
    return ApolloNativeAuthSession(
      username: _pickString(json, const ['username']),
      token: _pickString(json, const [
        'token',
        'accessToken',
        'access_token',
      ]),
      refreshToken: _pickString(json, const ['refreshToken', 'refresh_token']),
      apiVersion: _pickString(json, const ['apiVersion', 'api_version']) ?? 'V4',
      apiProfile:
          _pickString(json, const ['apiProfile', 'api_profile']) ?? 'androidtv',
      appVersion: _pickString(json, const ['appVersion', 'app_version']),
      xSignature: _pickString(json, const ['xSignature', 'x-signature']),
      xSignatureTimestamp: _pickString(json, const [
        'xSignatureTimestamp',
        'x-signature-timestamp',
      ]),
      hmacSecretHintPresent: _pickString(json, const ['hmacSecretPresent']),
      savedAt: DateTime.tryParse(_pickString(json, const ['savedAt', 'saved_at']) ?? ''),
      rawLogin: json['rawLogin'] is Map
          ? Map<String, dynamic>.from(json['rawLogin'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'token': token,
        'refreshToken': refreshToken,
        'apiVersion': apiVersion,
        'apiProfile': apiProfile,
        'appVersion': appVersion,
        'xSignature': xSignature,
        'xSignatureTimestamp': xSignatureTimestamp,
        'hmacSecretPresent': hmacSecretHintPresent,
        'savedAt': (savedAt ?? DateTime.now().toUtc()).toIso8601String(),
        // Omit rawLogin by default to keep file smaller; callers may merge.
      };

  static Map<String, dynamic>? _firstMap(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = map[k];
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return null;
  }

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') continue;
      return s;
    }
    return null;
  }
}

/// Loads/saves `.secrets/apollo_native_session.json` (gitignored) when present.
class ApolloNativeSessionStore {
  static const sessionFileName = 'apollo_native_session.json';

  /// Candidate paths (desktop workspace + app-local). Never logs contents.
  static List<File> candidateFiles({Directory? appSupport}) {
    final out = <File>[];
    // Workspace parent `.secrets` (dev / overnight agents).
    try {
      final cwd = Directory.current.path;
      out.add(File('$cwd/.secrets/$sessionFileName'));
      out.add(File('$cwd/../.secrets/$sessionFileName'));
      // Common layout: azul_iptv cwd → parent TV Parcer/.secrets
      out.add(File('$cwd/../../.secrets/$sessionFileName'));
    } catch (_) {}
    if (appSupport != null) {
      out.add(File('${appSupport.path}/$sessionFileName'));
    }
    return out;
  }

  static Future<ApolloNativeAuthSession?> load({Directory? appSupport}) async {
    for (final file in candidateFiles(appSupport: appSupport)) {
      try {
        if (!await file.exists()) continue;
        final raw = jsonDecode(await file.readAsString());
        if (raw is! Map) continue;
        final session =
            ApolloNativeAuthSession.fromJson(Map<String, dynamic>.from(raw));
        if (session.hasAuthMaterial) {
          debugPrint(
            '[APOLLO_NATIVE] loaded session file present '
            'hasToken=${session.token != null} '
            'hasSig=${session.xSignature != null}',
          );
          return session;
        }
      } catch (e) {
        debugPrint('[APOLLO_NATIVE] session load skip: $e');
      }
    }
    return null;
  }

  static Future<bool> save(
    ApolloNativeAuthSession session, {
    Directory? preferredDir,
  }) async {
    try {
      Directory dir;
      if (preferredDir != null) {
        dir = preferredDir;
      } else {
        // Prefer workspace parent `.secrets` on desktop if writable.
        final parentSecrets = Directory('${Directory.current.path}/../.secrets');
        if (await parentSecrets.exists()) {
          dir = parentSecrets;
        } else {
          final local = Directory('${Directory.current.path}/.secrets');
          if (!await local.exists()) {
            await local.create(recursive: true);
          }
          dir = local;
        }
      }
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$sessionFileName');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(session.toJson()),
        flush: true,
      );
      debugPrint('[APOLLO_NATIVE] session saved (no secrets logged)');
      return true;
    } catch (e) {
      debugPrint('[APOLLO_NATIVE] session save failed: $e');
      return false;
    }
  }
}

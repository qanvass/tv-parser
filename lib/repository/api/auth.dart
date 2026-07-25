part of 'api.dart';

Map<String, dynamic>? _normalizeAuthResponse(dynamic data) {
  if (data == null) {
    return null;
  }

  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }

  if (data is String) {
    if (data.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(data);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
  }

  return null;
}

class AuthApi {
  Future<UserModel?> registerUser(
    String username,
    String password,
    String link,
    String name,
  ) async {
    try {
      debugPrint("[Auth] login request started");
      final Response response = await _dio.get(
        "$link/player_api.php?username=$username&password=$password",
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic>? json = _normalizeAuthResponse(
          response.data,
        );

        if (json == null) {
          debugPrint(
            '[Auth] login failed: response was not a valid JSON object',
          );
          return null;
        }

        debugPrint("[Auth] login success");
        final user = UserModel.fromJson(json, link);
        //save to locale
        await LocaleApi.saveUser(user);
        return user;
      } else {
        debugPrint("[Auth] login failed status=${response.statusCode}");
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint("[Auth] login error: $e");
      debugPrint("[Auth] stackTrace: $stackTrace");
      return null;
    }
  }

  Future<UserModel?> registerM3u(String playlistUrl) async {
    try {
      final uri = Uri.tryParse(playlistUrl);
      final safeUrl = (uri == null || !uri.hasScheme)
          ? '<invalid>'
          : '${uri.scheme}://${uri.host}${uri.path}';
      debugPrint("[Auth] M3U login request started for: $safeUrl");
      final Response<String> response = await _dio.get(
        playlistUrl,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final content = response.data!;
        if (!content.contains("#EXTM3U")) {
          debugPrint("[Auth] M3U download failed: missing #EXTM3U header (received non-M3U content)");
          return null;
        }

        final Map<String, dynamic> parsedData = await compute(M3uParser.parse, content);
        final List<CategoryModel> categories =
            parsedData['categories'] as List<CategoryModel>;
        final List<ChannelLive> channels =
            parsedData['channels'] as List<ChannelLive>;

        if (channels.isEmpty) {
          debugPrint("[Auth] M3U download failed: no channels parsed");
          return null;
        }

        // Cache M3U lists locally
        await LocaleApi.saveM3uCategories(categories);
        await LocaleApi.saveM3uChannels(channels);

        // Build mock UserModel
        final mockUser = UserModel(
          userInfo: UserInfo(
            username: "Playlist User",
            password: "",
            status: "Active",
            expDate: (DateTime(2099, 12, 31).millisecondsSinceEpoch ~/ 1000)
                .toString(),
          ),
          serverInfo: ServerInfo(
            serverUrl: "m3u://$playlistUrl",
            timezone: "UTC",
          ),
        );

        // Save mock user to locale
        await LocaleApi.saveUser(mockUser);
        debugPrint(
          "[Auth] M3U login success. Channels parsed: ${channels.length}",
        );
        return mockUser;
      } else {
        debugPrint("[Auth] M3U download failed status=${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("[Auth] M3U login error: $e");
      return null;
    }
  }
}

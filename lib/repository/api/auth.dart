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
      final Response response = await _dio
          .get("$link/player_api.php?username=$username&password=$password");

      if (response.statusCode == 200) {
        final Map<String, dynamic>? json = _normalizeAuthResponse(response.data);

        if (json == null) {
          debugPrint('[Auth] login failed: response was not a valid JSON object');
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
}


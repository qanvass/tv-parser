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

        IptvProviderSession.instance.markXtreamSession();

        await LocaleApi.saveUser(user);

        // Capability probe after Xtream auth — non-blocking.
        // ignore: unawaited_futures
        ProviderCapabilityInspector.instance
            .inspectAfterXtream(
          host: link,
          username: username,
          password: password,
        )
            .catchError((Object e) {
          debugPrint('[CAPABILITIES] async xtream probe error: $e');
          return const ProviderCapabilities();
        });

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

      debugPrint("[Auth] M3U login request started");

      CatalogPerf.beginSession(reason: 'm3u_login');

      final downloadWatch = Stopwatch()..start();

      final Response<String> response = await _dio.get(

        playlistUrl,

        options: Options(responseType: ResponseType.plain),

      );

      CatalogPerf.span('downloadMs', downloadWatch.elapsedMilliseconds);



      if (response.statusCode == 200 && response.data != null) {

        final content = response.data!;

        // Provider session owns parse → classify → file cache → readable index.

        final user = await IptvProviderSession.instance.commitM3u(

          playlistUrl: playlistUrl,

          content: content,

        );

        CatalogPerf.mark('authMs');

        CatalogPerf.mark('login_validation_ms');

        CatalogPerf.flush('after_auth');

        if (user == null) {

          debugPrint("[Auth] M3U login failed: wiring produced empty catalog");

          return null;

        }

        debugPrint(

          "[Auth] M3U login success via IptvProviderSession "

          "${IptvProviderSession.instance.lastStats}",

        );

        return user;

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


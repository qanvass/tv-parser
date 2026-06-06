part of 'api.dart';

class IpTvApi {
  /// Categories
  Future<List<CategoryModel>> getCategories(String type) async {
    if (gatewayService.isReviewMode) {
      return [
        CategoryModel(
          categoryId: "demo_cat",
          categoryName: "Reviewer Demo Playlists",
          parentId: "0",
        )
      ];
    }
    try {
      final user = await LocaleApi.getUser();

      if (user == null) {
        debugPrint("User is Null");
        return [];
      }

      debugPrint("[IPTV] playlist fetch started");

      var url = "${user.serverInfo!.serverUrl}/player_api.php";

      Response<String> response = await _dio.get(
        url,
        queryParameters: {
          "password": user.userInfo!.password,
          "username": user.userInfo!.username,
          "action": type,
        },
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200) {
        final rawData = response.data ?? "[]";
        final list = await compute(_parseCategories, rawData);
        //TODO: save list to locale
        debugPrint("[IPTV] playlist fetch completed count=${list.length}");

        return list;
      }

      return [];
    } catch (e) {
      debugPrint("[IPTV] fetch error");
      return [];
    }
  }

  /// Channels Live
  Future<List<ChannelLive>> getLiveChannels(String catyId) async {
    if (gatewayService.isReviewMode) {
      return [
        ChannelLive(
          num: "1",
          name: "Big Buck Bunny (Live)",
          streamId: "1",
          categoryId: "demo_cat",
          streamIcon: "",
          directSource: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        ),
        ChannelLive(
          num: "2",
          name: "Sintel (Live)",
          streamId: "2",
          categoryId: "demo_cat",
          streamIcon: "",
          directSource: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
        ),
      ];
    }
    try {
      final user = await LocaleApi.getUser();

      if (user == null) {
        debugPrint("User is Null");
        return [];
      }

      var url = "${user.serverInfo!.serverUrl}/player_api.php";

      Response<String> response = await _dio.get(
        url,
        queryParameters: {
          "password": user.userInfo!.password,
          "username": user.userInfo!.username,
          "action": "get_live_streams",
          "category_id": catyId,
        },
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200) {
        final rawData = response.data ?? "[]";
        final list = await compute(_parseLiveChannels, rawData);
        //TODO: save list to locale

        return list;
      }

      return [];
    } catch (e) {
      log("Error Channel $catyId");
      return [];
    }
  }

  /// Channels Movie
  Future<List<ChannelMovie>> getMovieChannels(String catyId) async {
    if (gatewayService.isReviewMode) {
      return [
        ChannelMovie(
          num: "1",
          name: "Big Buck Bunny (VOD)",
          streamId: "1",
          categoryId: "demo_cat",
          directSource: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        ),
        ChannelMovie(
          num: "2",
          name: "Sintel (VOD)",
          streamId: "2",
          categoryId: "demo_cat",
          directSource: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
        ),
      ];
    }
    try {
      final user = await LocaleApi.getUser();

      if (user == null) {
        debugPrint("User is Null");
        return [];
      }

      var url = "${user.serverInfo!.serverUrl}/player_api.php";

      Response<String> response = await _dio.get(
        url,
        queryParameters: {
          "password": user.userInfo!.password,
          "username": user.userInfo!.username,
          "action": "get_vod_streams",
          "category_id": catyId,
        },
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200) {
        final rawData = response.data ?? "[]";
        final list = await compute(_parseMovieChannels, rawData);
        //TODO: save list to locale

        return list;
      }

      return [];
    } catch (e) {
      debugPrint("Error Channel $catyId: $e");
      return [];
    }
  }

  /// Channels Series
  Future<List<ChannelSerie>> getSeriesChannels(String catyId) async {
    if (gatewayService.isReviewMode) {
      return [
        ChannelSerie(
          num: "1",
          name: "Big Buck Bunny (Series)",
          seriesId: "1",
          categoryId: "demo_cat",
        ),
      ];
    }
    try {
      final user = await LocaleApi.getUser();

      if (user == null) {
        debugPrint("User is Null");
        return [];
      }

      var url = "${user.serverInfo!.serverUrl}/player_api.php";

      Response<String> response = await _dio.get(
        url,
        queryParameters: {
          "password": user.userInfo!.password,
          "username": user.userInfo!.username,
          "action": "get_series",
          "category_id": catyId,
        },
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200) {
        final rawData = response.data ?? "[]";
        final list = await compute(_parseSeriesChannels, rawData);
        //TODO: save list to locale

        return list;
      }

      return [];
    } catch (e) {
      debugPrint("Error Channel Series $catyId: $e");
      return [];
    }
  }

  /// Movie Detail
  static Future<MovieDetail?> getMovieDetails(String movieId) async {
    try {
      final user = await LocaleApi.getUser();

      if (user == null) {
        debugPrint("User is Null");
        return null;
      }

      var url = "${user.serverInfo!.serverUrl}/player_api.php";

      Response<String> response = await _dio.get(
        url,
        queryParameters: {
          "password": user.userInfo!.password,
          "username": user.userInfo!.username,
          "action": "get_vod_info",
          "vod_id": movieId,
        },
      );

      if (response.statusCode == 200) {
        // log(response.data.toString());
        final json = jsonDecode(response.data ?? "[]");

        final movie = MovieDetail.fromJson(json);
        return movie;
      }

      return null;
    } catch (e) {
      debugPrint("Error Movie $movieId");
      return null;
    }
  }

  /// Serie Detail
  static Future<SerieDetails?> getSerieDetails(String serieId) async {
    try {
      final user = await LocaleApi.getUser();

      if (user == null) {
        debugPrint("User is Null");
        return null;
      }

      var url = "${user.serverInfo!.serverUrl}/player_api.php";

      Response<String> response = await _dio.get(
        url,
        queryParameters: {
          "password": user.userInfo!.password,
          "username": user.userInfo!.username,
          "action": "get_series_info",
          "series_id": serieId,
        },
      );

      if (response.statusCode == 200) {
        //log(response.data.toString());
        final json = jsonDecode(response.data ?? "");
        final serie = SerieDetails.fromJson(json);
        return serie;
      }

      return null;
    } catch (e) {
      debugPrint("Error MovSerie $serieId");
      return null;
    }
  }

  /// EPG LIVE
  static Future<List<EpgModel>> getEPGbyStreamId(String streamId) async {
    try {
      final user = await LocaleApi.getUser();

      if (user == null) {
        debugPrint("User is Null");
        return [];
      }

      var url = "${user.serverInfo!.serverUrl}/player_api.php";

      Response<String> response = await _dio.get(
        url,
        queryParameters: {
          "password": user.userInfo!.password,
          "username": user.userInfo!.username,
          "action": "get_short_epg",
          "stream_id": streamId,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(
          response.data ?? "",
        )['epg_listings'];
        debugPrint("EPG length: ${json.length}");

        final list = json.map((e) => EpgModel.fromJson(e)).toList();
        return list;
      }

      return [];
    } catch (e) {
      debugPrint("Error EPG Series $streamId: $e");
      return [];
    }
  }
}

List<CategoryModel> _parseCategories(String data) {
  final List<dynamic> json = jsonDecode(data);
  return json.map((e) => CategoryModel.fromJson(e)).toList();
}

List<ChannelLive> _parseLiveChannels(String data) {
  final List<dynamic> json = jsonDecode(data);
  return json.map((e) => ChannelLive.fromJson(e)).toList();
}

List<ChannelMovie> _parseMovieChannels(String data) {
  final List<dynamic> json = jsonDecode(data);
  return json.map((e) => ChannelMovie.fromJson(e)).toList();
}

List<ChannelSerie> _parseSeriesChannels(String data) {
  final List<dynamic> json = jsonDecode(data);
  return json.map((e) => ChannelSerie.fromJson(e)).toList();
}

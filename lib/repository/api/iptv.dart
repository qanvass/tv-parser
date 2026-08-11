part of 'api.dart';

class IpTvApi {
  /// Categories
  Future<List<CategoryModel>> getCategories(String type) async {
    final user = await LocaleApi.getUser();
    if (user != null &&
        IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
      final cats = IptvProviderSession.instance.categoriesForAction(type);
      debugPrint(
        "[IPTV_WIRING] getCategories action=$type count=${cats.length} "
        "kind=${IptvProviderSession.instance.kind}",
      );
      return cats;
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
    final user = await LocaleApi.getUser();
    if (user != null &&
        IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
      final list =
          IptvProviderSession.instance.liveChannels(categoryId: catyId);
      debugPrint(
        "[IPTV_WIRING] getLiveChannels caty=${catyId.isEmpty ? 'all' : catyId} "
        "count=${list.length}",
      );
      return list;
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
    final user = await LocaleApi.getUser();
    if (user != null &&
        IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
      final list =
          IptvProviderSession.instance.movieChannels(categoryId: catyId);
      debugPrint(
        "[IPTV_WIRING] getMovieChannels caty=${catyId.isEmpty ? 'all' : catyId} "
        "count=${list.length}",
      );
      return list;
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
    final user = await LocaleApi.getUser();
    if (user != null &&
        IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
      final list =
          IptvProviderSession.instance.seriesChannels(categoryId: catyId);
      debugPrint(
        "[IPTV_WIRING] getSeriesChannels caty=${catyId.isEmpty ? 'all' : catyId} "
        "count=${list.length}",
      );
      return list;
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
      if (user != null &&
          IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
        return null;
      }

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
      if (user != null &&
          IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
        return null;
      }

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
      if (user != null &&
          IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
        return _xmlTvNowNextForM3u(streamId);
      }

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

  /// M3U path: match playlist tvg-id / name against cached XMLTV. Never invent.
  static List<EpgModel> _xmlTvNowNextForM3u(String streamId) {
    if (!XmlTvRepository.isFeatureEnabled) return const [];
    final repo = XmlTvRepository.instance;
    if (!repo.isReady) {
      // Kick a background load; caller can retry after notifyListeners.
      final url = IptvProviderSession.instance.playlistUrl;
      // ignore: unawaited_futures
      repo.ensureLoaded(playlistUrl: url);
      return const [];
    }
    final ch = _liveChannelForEpgKey(streamId);
    return repo.nowNextAsEpgModels(
      tvgId: ch?.epgChannelId?.toString(),
      channelId: ch?.streamId,
      channelName: ch?.name,
      streamId: ch?.streamId ?? streamId,
    );
  }

  static ChannelLive? _liveChannelForEpgKey(String key) {
    final needle = key.trim();
    if (needle.isEmpty) return null;
    final channels = LocaleApi.getM3uChannels();
    for (final ch in channels) {
      if (ch.streamId == needle) return ch;
      if (ch.directSource == needle) return ch;
      final tvg = ch.epgChannelId?.toString();
      if (tvg != null && tvg == needle) return ch;
    }
    return null;
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

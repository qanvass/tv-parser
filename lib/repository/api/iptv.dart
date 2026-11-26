part of 'api.dart';

class IpTvApi {
  /// Categories
  Future<List<CategoryModel>> getCategories(String type) async {
    final user = await LocaleApi.getUser();
    if (user != null &&
        IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
      // Splash can ask before the on-disk cache is warm; reading early
      // returned [] and left the phone browse screens empty for the session.
      switch (type) {
        case 'get_live_categories':
          await LocaleApi.ensureM3uLiveCache();
          break;
        case 'get_vod_categories':
          await LocaleApi.ensureM3uMovieCategories();
          break;
        case 'get_series_categories':
          await LocaleApi.ensureM3uSeriesCategories();
          break;
      }
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
      await LocaleApi.ensureM3uLiveCache();
      final list = IptvProviderSession.instance.liveChannels(
        categoryId: catyId,
      );
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
      await LocaleApi.warmM3uMovieCache();
      final list = IptvProviderSession.instance.movieChannels(
        categoryId: catyId,
      );
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
      await LocaleApi.warmM3uSeriesCache();
      // Shows-only memory has one row per show, so one show's episodes come
      // from SQLite. The unfiltered list stays the show rows.
      final oneCategory = catyId.isNotEmpty && catyId != 'all';
      final list = oneCategory && LocaleApi.m3uSeriesShowsOnly
          ? await LocaleApi.m3uSeriesEpisodesForCategory(catyId)
          : IptvProviderSession.instance.seriesChannels(categoryId: catyId);
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

  /// Serie Detail. [saved] is the row the caller opened (favourite, search
  /// hit, list card); playlist accounts use it to catch a stale [serieId].
  static Future<SerieDetails?> getSerieDetails(
    String serieId, {
    ChannelSerie? saved,
  }) async {
    final details = await _getSerieDetailsAllSeasons(serieId, saved: saved);
    return details == null ? null : _withoutOldSeasons(details, saved);
  }

  /// A show that is kept only because it is still running loses its seasons
  /// from before the cutoff (see [CatalogAgePolicy]).
  static SerieDetails _withoutOldSeasons(
    SerieDetails details,
    ChannelSerie? saved,
  ) {
    final date = details.info?.releaseDate ?? '';
    final year = date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;
    final from = CatalogAgePolicy.seriesVerdict(
      saved?.name ?? details.info?.name,
      startYear: (year != null && year > 1900 && year < 2100) ? year : null,
    );
    final episodes = details.episodes;
    if (from <= CatalogAgePolicy.keepAll || episodes == null) return details;
    final kept = <String, List<Episode?>?>{
      for (final entry in episodes.entries)
        if (CatalogAgePolicy.seasonKept(entry.key, from)) entry.key: entry.value,
    };
    // Never leave a show page empty: if the labels did not line up, show all.
    if (kept.isEmpty || kept.length == episodes.length) return details;
    return SerieDetails(
      info: details.info,
      episodes: kept,
      seasons: details.seasons
          ?.where(
            (s) => CatalogAgePolicy.seasonKept(s.seasonNumber ?? '', from),
          )
          .toList(),
    );
  }

  static Future<SerieDetails?> _getSerieDetailsAllSeasons(
    String serieId, {
    ChannelSerie? saved,
  }) async {
    try {
      final user = await LocaleApi.getUser();
      if (user != null &&
          IptvProviderSession.isM3uServerUrl(user.serverInfo?.serverUrl)) {
        await LocaleApi.warmM3uSeriesCache();
        final anchor = await _resolveM3uSeriesAnchor(serieId, saved);
        // Saved show is gone from the catalog: show nothing, never the
        // show that now sits at its old id.
        if (anchor == null && saved != null) return null;
        if (LocaleApi.m3uSeriesShowsOnly) {
          if (anchor == null) return null;
          final episodes = await LocaleApi.m3uSeriesEpisodesForCategory(
            anchor.categoryId ?? '',
          );
          return m3uSerieDetails(
            anchor.seriesId ?? serieId,
            source: episodes.isEmpty ? [anchor] : episodes,
          );
        }
        return m3uSerieDetails(anchor?.seriesId ?? serieId);
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

  /// The playlist row a saved series points at, or null when the saved show
  /// is no longer in the catalog.
  ///
  /// Playlist ids are positions in the provider list (`m3u_stream_N`), so an
  /// id saved earlier (favourite, history) names a different show once the
  /// provider adds or removes entries. The row found by id is used only when
  /// it still is the saved show; otherwise the show is found by its stream
  /// address, then by title. A page must never list another show's episodes
  /// under the saved name, so no match means null, not the row at that id.
  /// With nothing saved to compare, the id decides.
  static Future<ChannelSerie?> _resolveM3uSeriesAnchor(
    String serieId,
    ChannelSerie? saved,
  ) async {
    final byId = await LocaleApi.m3uSeriesByItemId(serieId);
    if (saved == null) return byId;
    if (byId != null) {
      if (m3uSeriesIsSavedShow(byId, saved)) return byId;
      // Per-show playlists title the card after the category, not the episode.
      final catId = byId.categoryId;
      if (catId != null) {
        for (final c in LocaleApi.getM3uSeriesCategories()) {
          if (c.categoryId != catId) continue;
          final asShow = ChannelSerie(name: c.categoryName);
          if (m3uSeriesIsSavedShow(asShow, ChannelSerie(name: saved.name))) {
            return byId;
          }
          break;
        }
      }
    }

    final savedUrl = saved.directSource?.trim() ?? '';
    if (savedUrl.isNotEmpty) {
      final byUrl = await LocaleApi.m3uSeriesByDirectSource(savedUrl);
      if (byUrl != null) return byUrl;
    }
    final byTitle = m3uSeriesByShowTitle(LocaleApi.getM3uSeries(), saved);
    debugPrint(
      '[M3U] saved series id was stale; '
      '${byTitle != null ? 'matched by title' : 'show not found'}',
    );
    return byTitle;
  }

  static String _showKey(String? name) =>
      TitleNormalizer.parse(name ?? '').matchTitle.toLowerCase();

  /// True when [row] is the show [saved] names: same stream address or same
  /// show title. True too when [saved] has neither to compare.
  @visibleForTesting
  static bool m3uSeriesIsSavedShow(ChannelSerie row, ChannelSerie saved) {
    final savedUrl = saved.directSource?.trim() ?? '';
    final savedKey = _showKey(saved.name);
    if (savedUrl.isEmpty && savedKey.isEmpty) return true;
    if (savedUrl.isNotEmpty && row.directSource?.trim() == savedUrl) {
      return true;
    }
    return savedKey.isNotEmpty && _showKey(row.name) == savedKey;
  }

  /// First row of [rows] with the show title of [saved], preferring the same
  /// year when the saved name carries one.
  @visibleForTesting
  static ChannelSerie? m3uSeriesByShowTitle(
    Iterable<ChannelSerie> rows,
    ChannelSerie saved,
  ) {
    final key = _showKey(saved.name);
    if (key.isEmpty) return null;
    final year = TitleNormalizer.extractYear(saved.name ?? '');
    ChannelSerie? anyYear;
    for (final s in rows) {
      final name = s.name ?? '';
      // Cheap substring gate before the regex parse (catalogs can be 100k).
      if (!name.toLowerCase().contains(key)) continue;
      if (_showKey(name) != key) continue;
      if (year == null || TitleNormalizer.extractYear(name) == year) return s;
      anyYear ??= s;
    }
    return anyYear;
  }

  /// Playlist (M3U) accounts have no `get_series_info`: every playlist series
  /// entry is one playable episode. Group the anchor's show into seasons.
  @visibleForTesting
  static SerieDetails? m3uSerieDetails(
    String seriesId, {
    List<ChannelSerie>? source,
    List<CategoryModel>? categories,
  }) {
    final all = source ?? LocaleApi.getM3uSeries();
    final anchor = all.firstWhere(
      (s) => s.seriesId == seriesId,
      orElse: () => ChannelSerie(),
    );
    final anchorName = anchor.name ?? '';
    if (anchorName.isEmpty) return null;

    final cats = categories ?? LocaleApi.getM3uSeriesCategories();
    final perShow =
        anchor.categoryId != null && SeriesShelfPlanner.looksPerShow(cats);
    final anchorTitle = TitleNormalizer.parse(anchorName);
    final key = anchorTitle.matchTitle.toLowerCase();
    final probe = anchorTitle.displayTitle.toLowerCase();

    final members = <ChannelSerie>[];
    for (final s in all) {
      if ((s.directSource ?? '').isEmpty) continue;
      if (perShow) {
        if (s.categoryId == anchor.categoryId) members.add(s);
        continue;
      }
      final name = s.name ?? '';
      // Cheap substring gate before the regex parse (catalogs can be 100k).
      if (!name.toLowerCase().contains(probe)) continue;
      if (TitleNormalizer.parse(name).matchTitle.toLowerCase() == key) {
        members.add(s);
      }
    }
    if (members.isEmpty) return null;

    // Keep one copy per season/episode: providers often list the same episode
    // in several qualities. The best copy (4K > HD > untagged) wins.
    final bestCopy = <String, ChannelSerie>{};
    final keptMembers = <ChannelSerie>[];
    for (final s in members) {
      final t = TitleNormalizer.parse(s.name ?? '');
      if (t.episode == null) {
        keptMembers.add(s);
        continue;
      }
      final k = '${t.season ?? 1}:${t.episode}';
      final current = bestCopy[k];
      if (current == null) {
        bestCopy[k] = s;
        keptMembers.add(s);
      } else if (SeriesCollapse.isBetter(s, current)) {
        keptMembers[keptMembers.indexOf(current)] = s;
        bestCopy[k] = s;
      }
    }

    final bySeason = <int, List<(int, Episode)>>{};
    for (final s in keptMembers) {
      final t = TitleNormalizer.parse(s.name ?? '');
      final season = t.season ?? 1;
      final list = bySeason.putIfAbsent(season, () => []);
      final epNum = t.episode ?? list.length + 1;
      final src = s.directSource!;
      final dot = Uri.tryParse(src)?.path.lastIndexOf('.') ?? -1;
      final ext = dot > 0 ? Uri.parse(src).path.substring(dot + 1) : 'mp4';
      list.add((
        epNum,
        Episode(
          id: s.seriesId,
          episodeNum: '$epNum',
          title: s.name,
          containerExtension: ext,
          season: '$season',
          directSource: src,
        ),
      ));
    }

    final seasons = bySeason.keys.toList()..sort();
    final category = cats.firstWhere(
      (c) => c.categoryId == anchor.categoryId,
      orElse: () => CategoryModel(),
    );
    return SerieDetails(
      seasons: const [],
      info: InfoSerie(
        name: perShow && category.categoryName != null
            ? SeriesShelfPlanner.showTitle(category)
            : anchorTitle.displayTitle,
        cover: anchor.cover,
        plot: anchor.plot,
        rating: anchor.rating,
        categoryId: anchor.categoryId,
      ),
      episodes: {
        for (final n in seasons)
          '$n': [
            for (final e
                in (bySeason[n]!..sort((a, b) => a.$1.compareTo(b.$1))))
              e.$2,
          ],
      },
    );
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
  return json
      .map((e) => ChannelMovie.fromJson(e))
      .where((m) => !CatalogAgePolicy.movieTooOld(m.name))
      .toList();
}

List<ChannelSerie> _parseSeriesChannels(String data) {
  final List<dynamic> json = jsonDecode(data);
  final out = <ChannelSerie>[];
  for (final e in json) {
    final serie = ChannelSerie.fromJson(e);
    // Providers give the first-air date as "releaseDate" or "year".
    final raw = e is Map ? (e['releaseDate'] ?? e['release_date'] ?? e['year']) : null;
    final text = raw?.toString() ?? '';
    final year = text.length >= 4 ? int.tryParse(text.substring(0, 4)) : null;
    final startYear = (year != null && year > 1900 && year < 2100) ? year : null;
    if (CatalogAgePolicy.seriesRowTooOld(serie.name, startYear: startYear)) {
      continue;
    }
    out.add(serie);
  }
  return out;
}

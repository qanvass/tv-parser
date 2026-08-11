part of 'api.dart';

/// Which provider adapter owns the active session.
enum IptvProviderKind {
  /// Classic Xtream `player_api.php` + `/live|/movie|/series/` URLs.
  xtream,

  /// Apollo / Starlite / tvnow style `/api/list/...` M3U with `/api/stream/...`.
  /// Live from M3U; Movies/Series from `/m3u8/movies` + `/m3u8/tvshows` (same
  /// Live creds) when available, else Startup Show native REST.
  m3uStarlite,

  /// Generic M3U playlist (may mix live + VOD by path/group).
  m3uGeneric,
}

/// Stage counts for logcat proof that nothing was silently dropped.
class IptvWiringStats {
  final int fetchedBytes;
  final int extinfSeen;
  final int parsedEntries;
  final int storedLive;
  final int storedMovie;
  final int storedSeries;
  final int storedLiveCats;
  final int storedMovieCats;
  final int storedSeriesCats;
  final int readableLive;
  final int readableMovie;
  final int readableSeries;
  final IptvProviderKind kind;

  const IptvWiringStats({
    required this.fetchedBytes,
    required this.extinfSeen,
    required this.parsedEntries,
    required this.storedLive,
    required this.storedMovie,
    required this.storedSeries,
    required this.storedLiveCats,
    required this.storedMovieCats,
    required this.storedSeriesCats,
    required this.readableLive,
    required this.readableMovie,
    required this.readableSeries,
    required this.kind,
  });

  String get byTypeLog =>
      'live=$storedLive movie=$storedMovie series=$storedSeries';

  @override
  String toString() =>
      'fetched=$fetchedBytes parsed=$parsedEntries/$extinfSeen '
      'stored=$byTypeLog '
      'cats=live:$storedLiveCats/movie:$storedMovieCats/series:$storedSeriesCats '
      'readable=live:$readableLive/movie:$readableMovie/series:$readableSeries '
      'kind=$kind';
}

/// Single owner for playlist ingest → classify → durable cache → UI index.
///
/// Keeps Apollo/Starlite M3U off classic Xtream `player_api` paths while
/// preserving file+memory cache (SharedPreferences size fix).
class IptvProviderSession {
  IptvProviderSession._();
  static final IptvProviderSession instance = IptvProviderSession._();

  IptvProviderKind kind = IptvProviderKind.xtream;
  IptvWiringStats? lastStats;
  String? playlistUrl;
  bool _nativePersistersBound = false;
  bool _vodM3uPersistersBound = false;

  /// UI hooks: independent domain ready (do not use login Success(0)).
  void Function()? onMoviesCatalogReady;
  void Function()? onSeriesCatalogReady;

  /// Legacy: fires after both domain jobs have been *started* and movies
  /// persist has completed. Movies UI must use [onMoviesCatalogReady].
  void Function()? onVodCatalogReady;

  static bool isM3uServerUrl(String? serverUrl) =>
      serverUrl != null && serverUrl.startsWith('m3u:');

  static bool isApolloStarliteFamily(String playlistUrl, {String? sampleUrl}) {
    return detectKind(playlistUrl, sampleUrl: sampleUrl) ==
        IptvProviderKind.m3uStarlite;
  }

  static IptvProviderKind detectKind(String playlistUrl, {String? sampleUrl}) {
    final host = Uri.tryParse(playlistUrl)?.host.toLowerCase() ?? '';
    final path = Uri.tryParse(playlistUrl)?.path.toLowerCase() ?? '';
    final sample = (sampleUrl ?? '').toLowerCase();

    final starliteFamily = host.contains('starlite.best') ||
        host.contains('tvnow.best') ||
        path.contains('/api/list/') ||
        sample.contains('/api/stream/') ||
        sample.contains('livetv.epg');

    if (starliteFamily) return IptvProviderKind.m3uStarlite;
    return IptvProviderKind.m3uGeneric;
  }

  void _ensureNativePersistersBound() {
    if (_nativePersistersBound) return;
    _nativePersistersBound = true;
    ApolloNativeCatalogSession.instance.bindPersisters(
      movies: (cats, movies) async {
        await LocaleApi.saveM3uMovieCategories(cats);
        await LocaleApi.saveM3uMovies(movies);
      },
      series: (cats, series) async {
        await LocaleApi.saveM3uSeriesCategories(cats);
        await LocaleApi.saveM3uSeries(series);
      },
    );
  }

  void _ensureVodM3uPersistersBound() {
    if (_vodM3uPersistersBound) return;
    _vodM3uPersistersBound = true;
    StarliteVodM3uSession.instance.bindPersisters(
      movies: (cats, movies) async {
        await LocaleApi.saveM3uMovieCategories(cats);
        await LocaleApi.saveM3uMovies(movies);
      },
      series: (cats, series) async {
        await LocaleApi.saveM3uSeriesCategories(cats);
        await LocaleApi.saveM3uSeries(series);
      },
    );
  }

  /// Live stays on M3U cache; Movies/Series from `/m3u8/movies` + `/tvshows`
  /// (same Live creds) when eligible, else Startup Show native REST.
  Future<void> syncApolloNativeVodIfNeeded({
    String? usernameHint,
    String? passwordHint,
  }) async {
    if (kind != IptvProviderKind.m3uStarlite) return;
    _ensureNativePersistersBound();
    final url = playlistUrl;
    final ok = await ApolloNativeCatalogSession.instance.syncAfterApolloLive(
      playlistUrl: url,
      usernameHint: usernameHint,
      passwordHint: passwordHint,
    );
    debugPrint(
      '[IPTV_WIRING] apollo_native_vod ok=$ok '
      'movies=${ApolloNativeCatalogSession.instance.lastMovieCategoryCount}/'
      '${ApolloNativeCatalogSession.instance.lastMovieItemCount} '
      'series=${ApolloNativeCatalogSession.instance.lastSeriesCategoryCount}/'
      '${ApolloNativeCatalogSession.instance.lastSeriesItemCount} '
      'failure=${ApolloNativeCatalogSession.instance.lastFailure}',
    );
  }

  bool _canSyncStarlite(String? url) {
    if (kind != IptvProviderKind.m3uStarlite) return false;
    if (!StarliteVodM3uUrls.isFeatureEnabled) return false;
    if (url == null || url.isEmpty) return false;
    return StarliteVodM3uUrls.isEligible(url);
  }

  /// Movies M3U only. Publishes [onMoviesCatalogReady] when persist finishes.
  Future<bool> syncStarliteMoviesIfNeeded() async {
    final url = playlistUrl;
    if (!_canSyncStarlite(url)) return false;
    _ensureVodM3uPersistersBound();
    final ok = await StarliteVodM3uSession.instance.syncMovies(url!);
    debugPrint(
      '[IPTV_WIRING] vod_m3u movies ok=$ok '
      'count=${StarliteVodM3uSession.instance.lastMovieCount} '
      'failure=${StarliteVodM3uSession.instance.lastMoviesFailure}',
    );
    if (ok) {
      CatalogPerf.mark('firstMoviePersistMs');
      CatalogPerf.count(
        'movieCount',
        StarliteVodM3uSession.instance.lastMovieCount,
      );
      CatalogPerf.flush('movies_catalog_ready');
    }
    onMoviesCatalogReady?.call();
    return ok;
  }

  /// Series shards only. Publishes [onSeriesCatalogReady] when persist finishes.
  Future<bool> syncStarliteSeriesIfNeeded() async {
    final url = playlistUrl;
    if (!_canSyncStarlite(url)) return false;
    _ensureVodM3uPersistersBound();
    final ok = await StarliteVodM3uSession.instance.syncSeries(url!);
    debugPrint(
      '[IPTV_WIRING] vod_m3u series ok=$ok '
      'count=${StarliteVodM3uSession.instance.lastSeriesCount} '
      'shards=${StarliteVodM3uSession.instance.lastTvShowShardsFetched} '
      'failure=${StarliteVodM3uSession.instance.lastSeriesFailure}',
    );
    if (ok) {
      CatalogPerf.mark('firstSeriesPersistMs');
      CatalogPerf.count(
        'seriesCount',
        StarliteVodM3uSession.instance.lastSeriesCount,
      );
      CatalogPerf.flush('series_catalog_ready');
    }
    onSeriesCatalogReady?.call();
    return ok;
  }

  /// Starts movies and series independently. Returns when **movies** persist.
  /// Series continues in the background.
  Future<bool> syncStarliteVodM3uIfNeeded() async {
    if (!_canSyncStarlite(playlistUrl)) {
      if (kind == IptvProviderKind.m3uStarlite &&
          !StarliteVodM3uUrls.isFeatureEnabled) {
        debugPrint('[IPTV_WIRING] vod_m3u skipped: feature flag off');
      }
      return false;
    }
    _ensureVodM3uPersistersBound();
    final movieFuture = syncStarliteMoviesIfNeeded();
    // ignore: unawaited_futures
    syncStarliteSeriesIfNeeded();
    return movieFuture;
  }

  Future<void> _syncVodAfterLive({
    String? usernameHint,
    String? passwordHint,
  }) async {
    final movieOk = await syncStarliteVodM3uIfNeeded();
    if (!movieOk && LocaleApi.getM3uMovies().isEmpty) {
      await syncApolloNativeVodIfNeeded(
        usernameHint: usernameHint,
        passwordHint: passwordHint,
      );
      onMoviesCatalogReady?.call();
      onSeriesCatalogReady?.call();
    }
    onVodCatalogReady?.call();
  }

  /// Commit a downloaded M3U body into durable cache + memory index.
  /// Returns a mock [UserModel] with `m3u://` server marker for session routing.
  Future<UserModel?> commitM3u({
    required String playlistUrl,
    required String content,
  }) async {
    final fetchedBytes = content.length;
    if (!content.contains('#EXTM3U')) {
      debugPrint(
        '[IPTV_WIRING] abort: missing #EXTM3U fetched=$fetchedBytes',
      );
      return null;
    }

    final parseWatch = Stopwatch()..start();
    final parsed = M3uParser.parseCatalog(content);
    CatalogPerf.span('parseMs', parseWatch.elapsedMilliseconds);
    CatalogPerf.span('live_parse_ms', parseWatch.elapsedMilliseconds);
    final sampleUrl = parsed.liveChannels.isNotEmpty
        ? (parsed.liveChannels.first.directSource ?? '')
        : (parsed.movieChannels.isNotEmpty
            ? (parsed.movieChannels.first.directSource ?? '')
            : '');
    kind = detectKind(playlistUrl, sampleUrl: sampleUrl);
    this.playlistUrl = playlistUrl;

    debugPrint(
      '[IPTV_WIRING] fetched=$fetchedBytes parsed=${parsed.parsedEntries} '
      'extinf=${parsed.extinfSeen} byType=${parsed.byType} kind=$kind',
    );

    if (parsed.parsedEntries == 0) {
      debugPrint('[IPTV_WIRING] abort: parsed=0');
      return null;
    }

    // Persist ALL types — never truncate. File cache avoids SP ~1MB binder cap.
    final liveCatsOk =
        await LocaleApi.saveM3uCategories(parsed.liveCategories);
    final liveOk = await LocaleApi.saveM3uChannels(parsed.liveChannels);
    final movieCatsOk =
        await LocaleApi.saveM3uMovieCategories(parsed.movieCategories);
    final moviesOk = await LocaleApi.saveM3uMovies(parsed.movieChannels);
    final seriesCatsOk =
        await LocaleApi.saveM3uSeriesCategories(parsed.seriesCategories);
    final seriesOk = await LocaleApi.saveM3uSeries(parsed.seriesChannels);

    final readableLive = LocaleApi.getM3uChannels().length;
    final readableMovie = LocaleApi.getM3uMovies().length;
    final readableSeries = LocaleApi.getM3uSeries().length;

    lastStats = IptvWiringStats(
      fetchedBytes: fetchedBytes,
      extinfSeen: parsed.extinfSeen,
      parsedEntries: parsed.parsedEntries,
      storedLive: parsed.liveChannels.length,
      storedMovie: parsed.movieChannels.length,
      storedSeries: parsed.seriesChannels.length,
      storedLiveCats: parsed.liveCategories.length,
      storedMovieCats: parsed.movieCategories.length,
      storedSeriesCats: parsed.seriesCategories.length,
      readableLive: readableLive,
      readableMovie: readableMovie,
      readableSeries: readableSeries,
      kind: kind,
    );

    debugPrint(
      '[IPTV_WIRING] stored live=$liveOk(${parsed.liveChannels.length}) '
      'movie=$moviesOk(${parsed.movieChannels.length}) '
      'series=$seriesOk(${parsed.seriesChannels.length}) '
      'cats live=$liveCatsOk(${parsed.liveCategories.length}) '
      'movie=$movieCatsOk(${parsed.movieCategories.length}) '
      'series=$seriesCatsOk(${parsed.seriesCategories.length})',
    );
    debugPrint('[IPTV_WIRING] $lastStats');
    CatalogPerf.count('liveCount', readableLive);
    CatalogPerf.count('movieCount', readableMovie);
    CatalogPerf.count('seriesCount', readableSeries);
    CatalogPerf.count('liveCatCount', parsed.liveCategories.length);
    CatalogPerf.count('movieCatCount', parsed.movieCategories.length);
    CatalogPerf.count('movieCategoryCount', parsed.movieCategories.length);
    CatalogPerf.count('seriesCatCount', parsed.seriesCategories.length);
    CatalogPerf.count('seriesCategoryCount', parsed.seriesCategories.length);
    CatalogPerf.flush('after_live_persist');

    if (readableLive + readableMovie + readableSeries == 0) {
      debugPrint('[IPTV_WIRING] abort: readable=0 after persist');
      return null;
    }

    final mockUser = UserModel(
      userInfo: UserInfo(
        username: 'Playlist User',
        password: '',
        status: 'Active',
        expDate: (DateTime(2099, 12, 31).millisecondsSinceEpoch ~/ 1000)
            .toString(),
      ),
      serverInfo: ServerInfo(
        serverUrl: 'm3u://$playlistUrl',
        timezone: 'UTC',
      ),
    );
    await LocaleApi.saveUser(mockUser);

    // List-API Live M3U is often live-only — pull VOD M3Us in background so
    // login/splash can reach the Live shell without waiting on 18k+/100k parse.
    if (kind == IptvProviderKind.m3uStarlite) {
      final extracted =
          ApolloNativeCatalogSession.extractListCredentials(playlistUrl);
      // ignore: unawaited_futures
      _syncVodAfterLive(
        usernameHint: extracted?.$1,
        passwordHint: extracted?.$2,
      ).then((_) {
        lastStats = IptvWiringStats(
          fetchedBytes: fetchedBytes,
          extinfSeen: parsed.extinfSeen,
          parsedEntries: parsed.parsedEntries,
          storedLive: parsed.liveChannels.length,
          storedMovie: LocaleApi.getM3uMovies().length,
          storedSeries: LocaleApi.getM3uSeries().length,
          storedLiveCats: parsed.liveCategories.length,
          storedMovieCats: LocaleApi.getM3uMovieCategories().length,
          storedSeriesCats: LocaleApi.getM3uSeriesCategories().length,
          readableLive: LocaleApi.getM3uChannels().length,
          readableMovie: LocaleApi.getM3uMovies().length,
          readableSeries: LocaleApi.getM3uSeries().length,
          kind: kind,
        );
        debugPrint('[IPTV_WIRING] after_vod $lastStats');
      });
    }

    // Capability probe after catalog commit — non-blocking so login stays fast.
    final extractedCreds =
        XtreamProbeUrlBuilder.credentialsFromListPath(playlistUrl) ??
            ApolloNativeCatalogSession.extractListCredentials(playlistUrl);
    // ignore: unawaited_futures
    ProviderCapabilityInspector.instance
        .inspectAfterM3u(
      playlistUrl: playlistUrl,
      m3uContent: content,
      username: extractedCreds?.$1,
      password: extractedCreds?.$2,
    )
        .catchError((Object e) {
      debugPrint('[CAPABILITIES] async probe error: $e');
      return ProviderCapabilities.m3uMinimum();
    });

    // ignore: unawaited_futures
    XmlTvRepository.instance.ensureLoaded(playlistUrl: playlistUrl);

    return mockUser;
  }

  void markXtreamSession() {
    kind = IptvProviderKind.xtream;
    playlistUrl = null;
    lastStats = null;
  }

  /// Restore kind after app restart when user is already M3U-logged-in.
  Future<void> hydrateFromLocale() async {
    final user = await LocaleApi.getUser();
    if (user == null || !isM3uServerUrl(user.serverInfo?.serverUrl)) {
      kind = IptvProviderKind.xtream;
      return;
    }
    final url = user.serverInfo!.serverUrl!.substring(
      user.serverInfo!.serverUrl!.startsWith('m3u://') ? 6 : 4,
    );
    playlistUrl = url;
    if (!CatalogPerf.hasSession) {
      CatalogPerf.beginSession(reason: 'warm_start');
    }
    final sample = LocaleApi.getM3uChannels().isNotEmpty
        ? (LocaleApi.getM3uChannels().first.directSource ?? '')
        : '';
    kind = detectKind(url, sampleUrl: sample);
    debugPrint(
      '[IPTV_WIRING] hydrate kind=$kind '
      'readable=live:${LocaleApi.getM3uChannels().length} '
      '(vod deferred)',
    );

    // Restore last capability snapshot for UI honesty (no network).
    final caps = await ProviderCapabilityStore.instance.load();
    if (caps != null) {
      ProviderCapabilityInspector.instance.lastCapabilities = caps;
      debugPrint(caps.capabilityLogLine);
    }

    // XMLTV after Live hydrate — never await on the splash path.
    // ignore: unawaited_futures
    XmlTvRepository.instance.ensureLoaded(playlistUrl: url);

    // Warm + optionally sync VOD off the critical path. Never call
    // getM3uMovies/getM3uSeries here — that sync-parses multi-MB JSON and
    // freezes Chromecast before/after splash.
    if (kind == IptvProviderKind.m3uStarlite) {
      final extracted =
          ApolloNativeCatalogSession.extractListCredentials(url);
      // ignore: unawaited_futures
      Future(() async {
        await LocaleApi.warmM3uMovieCache();
        if (LocaleApi.getM3uMovies().isEmpty) {
          await _syncVodAfterLive(
            usernameHint: extracted?.$1,
            passwordHint: extracted?.$2,
          );
        } else {
          onMoviesCatalogReady?.call();
        }
        // ignore: unawaited_futures
        LocaleApi.warmM3uSeriesCache().then((_) {
          if (LocaleApi.getM3uSeries().isEmpty) {
            // ignore: unawaited_futures
            syncStarliteSeriesIfNeeded();
          } else {
            onSeriesCatalogReady?.call();
          }
        });
      });
    }
  }

  List<CategoryModel> categoriesForAction(String action) {
    switch (action) {
      case 'get_live_categories':
        return LocaleApi.getM3uCategories();
      case 'get_vod_categories':
        return LocaleApi.getM3uMovieCategories();
      case 'get_series_categories':
        return LocaleApi.getM3uSeriesCategories();
      default:
        return const [];
    }
  }

  List<ChannelLive> liveChannels({String? categoryId}) {
    final all = LocaleApi.getM3uChannels();
    if (categoryId == null || categoryId.isEmpty || categoryId == 'all') {
      return all;
    }
    return all.where((ch) => ch.categoryId == categoryId).toList();
  }

  List<ChannelMovie> movieChannels({String? categoryId}) {
    final all = LocaleApi.getM3uMovies();
    if (categoryId == null || categoryId.isEmpty || categoryId == 'all') {
      return all;
    }
    return all.where((ch) => ch.categoryId == categoryId).toList();
  }

  List<ChannelSerie> seriesChannels({String? categoryId}) {
    final all = LocaleApi.getM3uSeries();
    if (categoryId == null || categoryId.isEmpty || categoryId == 'all') {
      return all;
    }
    return all.where((ch) => ch.categoryId == categoryId).toList();
  }

  /// Resolve playback URL without rewriting M3U onto `/live/<id>.ts`.
  String resolveLiveUrl(ChannelLive channel) {
    final direct = channel.directSource?.trim() ?? '';
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      return direct;
    }
    final streamId = channel.streamId?.trim() ?? '';
    if (streamId.isEmpty) return '';
    final match = LocaleApi.getM3uChannels().firstWhere(
      (ch) => ch.streamId == streamId,
      orElse: () => const ChannelLive(),
    );
    return match.directSource ?? '';
  }

  String resolveMovieUrl(ChannelMovie channel) {
    final direct = channel.directSource?.trim() ?? '';
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      return direct;
    }
    final streamId = channel.streamId?.trim() ?? '';
    if (streamId.isEmpty) return '';
    final match = LocaleApi.getM3uMovies().firstWhere(
      (ch) => ch.streamId == streamId,
      orElse: () => ChannelMovie(),
    );
    return match.directSource ?? '';
  }

  String resolveSeriesUrl(ChannelSerie channel) {
    final direct = channel.directSource?.trim() ?? '';
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      return direct;
    }
    final seriesId = channel.seriesId?.trim() ?? '';
    if (seriesId.isEmpty) return '';
    final match = LocaleApi.getM3uSeries().firstWhere(
      (ch) => ch.seriesId == seriesId,
      orElse: () => ChannelSerie(),
    );
    return match.directSource ?? '';
  }
}

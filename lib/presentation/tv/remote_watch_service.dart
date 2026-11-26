import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../helpers/helpers.dart';
import '../../repository/api/api.dart';
import '../../repository/api/search_index_service.dart';
import '../../repository/models/category.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/provider/series_collapse.dart';
import '../../repository/provider/title_normalizer.dart';
import 'live/live_browse_gate.dart';
import 'playback_report.dart';

/// "Play this by name" from outside the app (the home assistant sends an
/// Android intent; MainActivity forwards it here).
///
/// It does what a person does with the remote: go back to the dashboard,
/// search the catalog that is already loaded for the saved login, and open the
/// best match through the dashboard's own play handoff. It never reads, writes
/// or switches logins, and it never builds a playlist or provider URL itself
/// beyond what Search already does.
class RemoteWatchCommand {
  final String id;

  /// 'live', 'movie', 'series' or 'any'.
  final String kind;
  final String query;

  /// Only for a series, when the viewer named them.
  final int? season;
  final int? episode;

  const RemoteWatchCommand({
    required this.id,
    required this.kind,
    required this.query,
    this.season,
    this.episode,
  });

  static int? _smallNumber(Object? raw) {
    final n = int.tryParse((raw ?? '').toString().trim());
    return (n == null || n < 1 || n > 999) ? null : n;
  }

  static RemoteWatchCommand? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final query = (raw['query'] ?? '').toString().trim();
    if (query.isEmpty || query.length > 120) return null;
    final kindRaw = (raw['kind'] ?? 'any').toString().trim().toLowerCase();
    final kind = switch (kindRaw) {
      'live' || 'channel' || 'tv' => 'live',
      'movie' || 'film' || 'vod' => 'movie',
      'series' || 'show' || 'tv_show' || 'episode' => 'series',
      _ => 'any',
    };
    final season = _smallNumber(raw['season']);
    final episode = _smallNumber(raw['episode']);
    return RemoteWatchCommand(
      id: (raw['id'] ?? '').toString().trim(),
      // A season or episode number can only mean a series.
      kind: (kind == 'any' && (season != null || episode != null))
          ? 'series'
          : kind,
      query: query,
      season: season,
      episode: episode,
    );
  }

  /// Ids start with the sender's clock in epoch milliseconds. A command that
  /// Android redelivers long after it was sent must not start playback.
  bool isStale(DateTime now) {
    final head = id.split('-').first;
    final sentMs = int.tryParse(head);
    // No send time: it cannot be told apart from an old, redelivered one.
    if (sentMs == null || sentMs < 1000000000000) return true;
    final ageMs = now.millisecondsSinceEpoch - sentMs;
    return ageMs > const Duration(minutes: 3).inMilliseconds;
  }
}

/// The dashboard registers these so a remote play releases the Live preview's
/// provider connection exactly as a remote-control click does.
class RemoteWatchHost {
  final Future<void> Function(String url, {String? title, String? streamId})
  playLive;
  final Future<void> Function(String url) playMovie;

  /// Opens the show's own page, which starts the episode itself.
  final Future<void> Function(ChannelSerie show, {int? season, int? episode})
  openSeries;

  /// Ids of the adult movie and series groups the dashboard knows about.
  final Set<String> Function() adultCategoryIds;

  /// Lets the Live preview start again when a request ends without a player.
  final void Function() resyncPreview;

  const RemoteWatchHost({
    required this.playLive,
    required this.playMovie,
    required this.openSeries,
    required this.adultCategoryIds,
    required this.resyncPreview,
  });
}

class RemoteWatchService {
  RemoteWatchService._();
  static final RemoteWatchService instance = RemoteWatchService._();

  static const MethodChannel _channel = MethodChannel('tvparser/watch');

  RemoteWatchHost? _host;
  bool _started = false;

  /// True from the moment a request closes the open player until its own
  /// player has been asked to open. The dashboard holds its Live preview off.
  bool handoffPending = false;
  int _gen = 0;

  /// Called once after the first frame. Safe to call on any platform.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'watch') {
        final cmd = RemoteWatchCommand.fromMap(call.arguments);
        if (cmd != null) unawaited(_run(cmd));
      }
      return null;
    });
    try {
      final pending = await _channel.invokeMethod<Object?>('take');
      final cmd = RemoteWatchCommand.fromMap(pending);
      if (cmd != null) unawaited(_run(cmd));
    } catch (_) {
      // Older native side or no pending command.
    }
  }

  void attachHost(RemoteWatchHost host) => _host = host;

  void detachHost(RemoteWatchHost host) {
    if (identical(_host, host)) _host = null;
  }

  Future<void> _report(
    RemoteWatchCommand cmd,
    String status, {
    String kind = '',
    String title = '',
    List<String> alts = const [],
  }) async {
    try {
      await _channel.invokeMethod<void>('report', <String, String>{
        'id': cmd.id,
        'status': status,
        'kind': kind,
        'title': title,
        'alts': alts.join(' | '),
      });
    } catch (_) {}
  }

  Future<void> _run(RemoteWatchCommand cmd) async {
    // Latest command wins; an older one stops at its next checkpoint.
    final gen = ++_gen;
    bool superseded() => gen != _gen;
    // Held for the whole request, so the dashboard never starts its Live
    // preview only to have it torn down a moment later.
    handoffPending = true;
    var handedOff = false;
    try {
      if (cmd.isStale(DateTime.now())) {
        await _report(cmd, 'stale');
        return;
      }
      await _report(cmd, 'received');
      // The request arrives as an Android intent, which pauses and resumes the
      // app for an instant; the dashboard's Live preview shuts down on that
      // pause. Shutting it down again while that is still in progress left a
      // video decoder running with nowhere to draw (seen on a Chromecast as
      // endless "BufferQueue has been abandoned" errors and a skipping
      // picture). Nothing is handed off until that first shutdown has settled.
      final received = DateTime.now();

      // Cold start: splash, saved-login resume, then the dashboard.
      final host = await _waitForHost(superseded);
      if (superseded()) return;
      if (host == null) {
        // No dashboard means no active saved login on screen. Do nothing.
        await _report(cmd, 'not_ready');
        return;
      }
      await _waitForBrowseReady();
      if (superseded()) return;

      final adultIds = _adultCategoryIds();
      try {
        adultIds.addAll(host.adultCategoryIds());
      } catch (_) {}

      ChannelLive? live;
      var liveRank = 99;
      var liveAlts = const <String>[];
      var movieAlts = const <String>[];
      if (cmd.kind == 'live' || cmd.kind == 'any') {
        final lives = await _liveCatalog();
        if (superseded()) return;
        if (lives.isNotEmpty && !SearchIndexService.liveIndexReady) {
          await SearchIndexService.indexLive(
            liveChannels: lives,
            adultCategoryIds: adultIds,
          );
        }
        final found = await _search(cmd.query, 'live');
        if (superseded()) return;
        final candidates = found
            .whereType<ChannelLive>()
            .where((c) => !adultIds.contains(c.categoryId))
            .toList();
        final pick = pickBest<ChannelLive>(
          cmd.query,
          candidates,
          (c) => c.name ?? '',
        );
        live = pick?.item;
        liveRank = pick?.rank ?? 99;
        liveAlts = otherNames(
          candidates,
          live,
          (c) => c.name ?? '',
          query: cmd.query,
        );
      }

      // 'any' takes a clear channel-name match; otherwise it looks at movies.
      final wantMovie =
          cmd.kind == 'movie' || (cmd.kind == 'any' && liveRank > 0);
      ChannelMovie? movie;
      var movieRank = 99;
      if (wantMovie) {
        final movies = await _movieCatalog();
        if (superseded()) return;
        if (movies.isNotEmpty && !SearchIndexService.moviesIndexReady) {
          await SearchIndexService.indexMovies(
            movies: movies,
            adultCategoryIds: adultIds,
          );
        }
        final found = await _search(cmd.query, 'movie');
        if (superseded()) return;
        final candidates = found
            .whereType<ChannelMovie>()
            .where((m) => !adultIds.contains(m.categoryId))
            .toList();
        final pick = pickBest<ChannelMovie>(
          cmd.query,
          candidates,
          (m) => m.name ?? '',
          channel: false,
        );
        movie = pick?.item;
        movieRank = pick?.rank ?? 99;
        movieAlts = otherNames(
          candidates,
          movie,
          (m) => m.name ?? '',
          query: cmd.query,
          channel: false,
        );
      }

      // A series when it was asked for, or when no channel or movie has
      // exactly that name.
      final wantSeries =
          cmd.kind == 'series' ||
          (cmd.kind == 'any' && liveRank > 0 && movieRank > 0);
      ChannelSerie? show;
      var showRank = 99;
      var showAlts = const <String>[];
      if (wantSeries) {
        // The dashboard fills the series search list shortly after it opens.
        await _waitForSeriesIndex(cmd.kind == 'series' ? 160 : 60);
        if (superseded()) return;
        final found = await _search(cmd.query, 'series');
        if (superseded()) return;
        final candidates = SeriesCollapse.collapseByShow(
          found
              .whereType<ChannelSerie>()
              .where((s) => !adultIds.contains(s.categoryId))
              .toList(),
        );
        final pick = pickBest<ChannelSerie>(
          cmd.query,
          candidates,
          showName,
          channel: false,
        );
        showAlts = otherNames(
          candidates,
          pick?.item,
          showName,
          query: cmd.query,
          channel: false,
        );
        show = pick?.item;
        showRank = pick?.rank ?? 99;
      }

      // One of the three: an exact name first (channel, movie, series), then
      // a channel that starts with it, then the nearest movie, series, channel.
      final order = <(int, String)>[
        (liveRank * 10 + (liveRank == 2 ? 5 : 0), 'live'),
        (movieRank * 10 + 1, 'movie'),
        (showRank * 10 + 2, 'series'),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      final choice = order.first.$2;
      if (choice != 'live') live = null;
      if (choice != 'movie') movie = null;
      if (choice != 'series') show = null;

      // Nothing by that name: leave whatever is on the screen alone.
      if (movie == null && live == null && show == null) {
        await _report(cmd, 'not_found');
        return;
      }
      // Something to put on: close any open player first so only one
      // provider connection is used.
      handedOff = true;
      final settleMs =
          2500 - DateTime.now().difference(received).inMilliseconds;
      if (settleMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: settleMs));
        if (superseded()) return;
      }
      if (Get.currentRoute != screenWelcome) {
        Get.until((route) => route.settings.name == screenWelcome);
        // The closed player is still on screen, and still reporting, while
        // its route animates out.
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (superseded()) return;
      }

      if (show != null) {
        final picked = show;
        PlaybackReport.note = '';
        final outcome = await _playAndConfirm(
          () => host.openSeries(
            picked,
            season: cmd.season,
            episode: cmd.episode,
          ),
          wait: const Duration(seconds: 35),
        );
        if (superseded()) return;
        final note = PlaybackReport.note;
        PlaybackReport.note = '';
        await _report(
          cmd,
          outcome,
          kind: 'series',
          title: outcome == 'no_episode'
              ? '${showName(picked)}: $note'
              : (note.isEmpty ? showName(picked) : note),
          alts: showAlts,
        );
        return;
      }
      if (movie != null) {
        final url = await _movieUrl(movie);
        if (superseded()) return;
        if (url.isNotEmpty) {
          final outcome = await _playAndConfirm(() => host.playMovie(url));
          if (superseded()) return;
          await _report(
            cmd,
            outcome,
            kind: 'movie',
            title: movie.name ?? '',
            alts: movieAlts,
          );
          return;
        }
      }
      if (live != null) {
        final url = await PlaybackUrlBuilder.resolveLivePlaybackUrl(live);
        if (superseded()) return;
        if (url.isNotEmpty) {
          final picked = live;
          final outcome = await _playAndConfirm(
            () => host.playLive(
              url,
              title: picked.name,
              streamId: picked.streamId,
            ),
          );
          if (superseded()) return;
          await _report(
            cmd,
            outcome,
            kind: 'live',
            title: live.name ?? '',
            alts: liveAlts,
          );
          return;
        }
      }
      await _report(cmd, 'not_found');
    } catch (e) {
      debugPrint('[RemoteWatch] failed: ${e.runtimeType}');
      await _report(cmd, 'error');
    } finally {
      if (!superseded()) {
        handoffPending = false;
        // Nothing was opened: the preview that was held off may run again.
        if (!handedOff) {
          try {
            _host?.resyncPreview();
          } catch (_) {}
        }
      }
    }
  }

  /// Starts the stream and waits for the player's own verdict:
  /// 'playing' (it held for a moment with no error), 'failed' (the player put
  /// up its unavailable screen), or 'opened' when it said neither in time.
  Future<String> _playAndConfirm(
    Future<void> Function() start, {
    Duration wait = const Duration(seconds: 25),
  }) async {
    final done = Completer<String>();
    Timer? settle;
    void finish(String outcome) {
      if (!done.isCompleted) done.complete(outcome);
    }

    // Nothing a player says counts until the new one has been asked to open:
    // the one being closed can still report for a moment.
    var armed = false;
    PlaybackReport.listener = (outcome) {
      // Only "playing" can come from the player that is being closed.
      if (!armed && outcome == 'playing') return;
      if (outcome != 'playing') {
        finish(outcome);
        return;
      }
      // A stream can start and die in its first second; let it hold.
      settle ??= Timer(const Duration(milliseconds: 2500), () {
        finish('playing');
      });
    };
    final mine = PlaybackReport.listener;
    final timeout = Timer(wait, () => finish('opened'));
    try {
      // The handoff itself must not be able to hang the request.
      await start().timeout(const Duration(seconds: 20), onTimeout: () {});
      // The player has been asked to open: the dashboard may run its Live
      // preview again when the viewer comes back to it.
      handoffPending = false;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      armed = true;
      return await done.future;
    } finally {
      // A newer request may already be listening; leave its listener alone.
      if (identical(PlaybackReport.listener, mine)) {
        PlaybackReport.listener = null;
      }
      settle?.cancel();
      timeout.cancel();
    }
  }

  Future<RemoteWatchHost?> _waitForHost(bool Function() superseded) async {
    for (var i = 0; i < 360; i++) {
      final host = _host;
      if (host != null) return host;
      if (superseded()) return null;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return _host;
  }

  Future<void> _waitForSeriesIndex(int quarterSeconds) async {
    for (var i = 0; i < quarterSeconds; i++) {
      if (SearchIndexService.seriesIndexReady) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _waitForBrowseReady() async {
    for (var i = 0; i < 32; i++) {
      if (LiveBrowseGate.welcomeOverlayCleared) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Set<String> _adultCategoryIds() {
    final cats = <CategoryModel>[
      ...LocaleApi.getM3uCategories(),
      ...LocaleApi.getM3uMovieCategories(),
      ...LocaleApi.getM3uSeriesCategories(),
      ...IptvProviderSession.instance.categoriesForAction(
        'get_live_categories',
      ),
    ];
    final ids = <String>{};
    for (final cat in cats) {
      final name = cat.categoryName;
      final id = cat.categoryId;
      if (name != null && id != null && id.isNotEmpty) {
        if (ProviderCurationRules.isAdultCategory(name)) ids.add(id);
      }
    }
    return ids;
  }

  /// Same sources Search uses: what is already in memory, then the saved
  /// login's own list call.
  Future<List<ChannelLive>> _liveCatalog() async {
    final cached = IptvProviderSession.instance.liveChannels();
    if (cached.isNotEmpty) return cached;
    try {
      return await IpTvApi().getLiveChannels('');
    } catch (_) {
      return const [];
    }
  }

  Future<List<ChannelMovie>> _movieCatalog() async {
    final cached = IptvProviderSession.instance.movieChannels();
    if (cached.isNotEmpty) return cached;
    try {
      return await IpTvApi().getMovieChannels('');
    } catch (_) {
      return const [];
    }
  }

  Future<List<Object>> _search(String query, String type) async {
    final results = await SearchIndexService.searchAsync(query);
    if (results == null) return const [];
    return [
      for (final entry in results)
        if (entry.type == type) entry.item as Object,
    ];
  }

  Future<String> _movieUrl(ChannelMovie movie) async {
    final direct = movie.directSource?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final id = movie.streamId;
    if (id == null || id.isEmpty) return '';
    return PlaybackUrlBuilder.buildMovieUrl(
      id,
      containerExtension: movie.containerExtension,
    );
  }

  // ---- name matching (pure; unit tested) ----

  /// A show's name without the episode tag playlists put on every row.
  static String showName(ChannelSerie s) {
    final raw = (s.name ?? '').trim();
    final clean = TitleNormalizer.parse(raw).displayTitle.trim();
    return clean.isEmpty ? raw : clean;
  }

  static final RegExp _firstNumber = RegExp(r'\d{1,3}');

  /// The first number in a label: "2", "Season 02", "S2".
  static int? firstNumber(String label) {
    final m = _firstNumber.firstMatch(label);
    return m == null ? null : int.tryParse(m.group(0)!);
  }

  /// Where number [want] sits in [labels] ("1", "Season 2", ...), or -1.
  /// [byPosition] also accepts the Nth entry when no label carries the number.
  static int numberedIndex(
    List<String> labels,
    int want, {
    bool byPosition = false,
  }) {
    for (var i = 0; i < labels.length; i++) {
      if (firstNumber(labels[i]) == want) return i;
    }
    // Position only when the list carries no numbers at all: with episodes
    // 1, 2, 3, 5 a request for 4 must not land on 5.
    if (byPosition &&
        want >= 1 &&
        want <= labels.length &&
        labels.every((l) => firstNumber(l) == null)) {
      return want - 1;
    }
    return -1;
  }

  static final RegExp _leadingRegion = RegExp(
    r'^\s*[\[\(\|]?\s*(us|usa|uk|ca|en|eng|english)\s*[\]\)\|:\-]+\s*',
    caseSensitive: false,
  );
  static final RegExp _qualityTag = RegExp(
    r'\b(uhd|fhd|hd|sd|4k|8k|hevc|h265|h264|1080p|720p|50fps|60fps)\b',
    caseSensitive: false,
  );
  // Only a bracketed or dashed year: "Blade Runner 2049" keeps its number.
  static final RegExp _trailingYear = RegExp(
    r'(\s*[\(\[]\s*(19|20)\d{2}\s*[\)\]]|\s+-\s*(19|20)\d{2})\s*$',
  );
  static final RegExp _notWord = RegExp(r'[^a-z0-9]+');

  static final RegExp _regionWord = RegExp(r'^(us|usa|uk|ca)$');

  /// Words that mark another edition of a channel. "CNN" means CNN, not
  /// "CNN Espanol" or "CNN International", unless that word was asked for.
  static const Set<String> _editionWords = {
    'espanol', 'español', 'spanish', 'latino', 'latin', 'latam', 'mexico',
    'international', 'intl', 'world', 'europe', 'asia', 'africa', 'arabic',
    'brasil', 'brazil', 'portugal', 'turk', 'india', 'philippines', 'chile',
    'french', 'france', 'deutsch', 'germany', 'italia', 'canada', 'indonesia',
    'plus', 'kids', 'jr', 'junior', 'deportes', 'alt', 'alternate',
    'raw', 'backup',
  };

  /// A title reduced to the words a person would say.
  @visibleForTesting
  static String spokenName(String raw, {bool channel = true}) {
    var s = raw.toLowerCase();
    // Providers stack prefixes ("US: ", "USA | "); strip up to two.
    for (var i = 0; i < 2; i++) {
      s = s.replaceFirst(_leadingRegion, '');
    }
    s = s.replaceAll(_qualityTag, ' ');
    s = s.replaceFirst(_trailingYear, ' ');
    final words = s
        .replaceAll(_notWord, ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    // "CNN US", "US CNN": the country tag is not part of a channel's name.
    // A title keeps it: "The Last of Us", "This Is Us".
    if (!channel) return words.join(' ');
    while (words.length > 1 && _regionWord.hasMatch(words.last)) {
      words.removeLast();
    }
    while (words.length > 1 && _regionWord.hasMatch(words.first)) {
      words.removeAt(0);
    }
    return words.join(' ');
  }

  static final RegExp _feedNumber = RegExp(r'^\d{3,}$');

  /// Picks from [candidates] (already in search-score order):
  /// rank 0 = the name is exactly what was asked for, rank 1 = it starts with
  /// it (fewest extra words first; numbered event feeds and other editions
  /// last), rank 2 = the first hit whose name has every word that was asked
  /// for. Null when nothing has all the words: better to say "not found" than
  /// to put on something else. Ties keep search order.
  static ({T item, int rank})? pickBest<T>(
    String query,
    List<T> candidates,
    String Function(T) nameOf, {
    bool channel = true,
  }) {
    if (candidates.isEmpty) return null;
    final want = spokenName(query, channel: channel);
    if (want.isEmpty) return null;
    final wantList = want.split(' ');
    final wantWords = wantList.toSet();
    T? prefix;
    var prefixCost = 1 << 30;
    T? allWords;
    for (final candidate in candidates) {
      final name = spokenName(nameOf(candidate), channel: channel);
      if (name == want) return (item: candidate, rank: 0);
      if (name.startsWith('$want ')) {
        final extra = name.substring(want.length + 1).split(' ');
        var cost = extra.length;
        if (extra.any((w) => _feedNumber.hasMatch(w))) cost += 50;
        if (extra.any(
          (w) => _editionWords.contains(w) && !wantWords.contains(w),
        )) {
          cost += 100;
        }
        if (cost < prefixCost) {
          prefixCost = cost;
          prefix = candidate;
        }
        continue;
      }
      if (allWords == null) {
        final have = name.split(' ').toSet();
        if (wantList.every(have.contains)) allWords = candidate;
      }
    }
    if (prefix != null) return (item: prefix, rank: 1);
    if (allWords != null) return (item: allWords, rank: 2);
    return null;
  }

  /// A few other matches, by name, so the assistant can offer them.
  static List<String> otherNames<T>(
    List<T> candidates,
    T? picked,
    String Function(T) nameOf, {
    String query = '',
    bool channel = true,
  }) {
    // Only names that hold every word that was asked for: a search for
    // "Breaking Bad" also returns every other title with "Bad" in it.
    final want = spokenName(
      query,
      channel: channel,
    ).split(' ').where((w) => w.isNotEmpty);
    final out = <String>[];
    for (final c in candidates) {
      if (identical(c, picked)) continue;
      if (want.isNotEmpty) {
        final have = spokenName(
          nameOf(c),
          channel: channel,
        ).split(' ').toSet();
        if (!want.every(have.contains)) continue;
      }
      final name = nameOf(c).replaceAll('|', ' ').trim();
      if (name.isEmpty || out.contains(name)) continue;
      out.add(name.length > 32 ? name.substring(0, 32) : name);
      if (out.length >= 5) break;
    }
    return out;
  }
}

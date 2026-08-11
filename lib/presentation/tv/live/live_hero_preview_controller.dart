import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';

import '../widgets/tv_channel_grid.dart';
import 'live_preview_trace.dart';

enum LiveHeroPreviewPhase { idle, loading, playing, failed, disposed }

/// Pure reconnect rules — no VLC, no URLs logged.
abstract final class LiveHeroPreviewPolicy {
  static const Duration focusDebounce = Duration(milliseconds: 700);
  static const Duration firstFrameTimeout = Duration(seconds: 20);

  static bool isLivePreviewSource(TvStreamRecord stream) {
    return !stream.isVod && stream.streamUrl.trim().isNotEmpty;
  }

  static bool shouldSkipReconnect({
    required String? activeUrl,
    required String nextUrl,
    required LiveHeroPreviewPhase phase,
  }) {
    if (nextUrl.isEmpty) return true;
    if (activeUrl != nextUrl) return false;
    return phase == LiveHeroPreviewPhase.loading ||
        phase == LiveHeroPreviewPhase.playing;
  }
}

/// Test seam so debounce / same-URL / cancel can run without a native player.
class LiveHeroPreviewHooks {
  const LiveHeroPreviewHooks({
    this.open,
    this.replace,
    this.release,
  });

  final Future<void> Function(String url, String title)? open;
  final Future<void> Function(String url, String title)? replace;
  final Future<void> Function()? release;
}

/// Exactly one muted Live hero preview. Never used by Movies / TMDB.
class LiveHeroPreviewController extends ChangeNotifier {
  LiveHeroPreviewController({
    @visibleForTesting LiveHeroPreviewHooks? hooks,
  }) : _hooks = hooks;

  final LiveHeroPreviewHooks? _hooks;

  Timer? _debounce;
  Timer? _firstFrameTimer;
  int _gen = 0;
  bool _disposed = false;

  VlcPlayerController? _player;
  Key? _playerKey;
  String? _activeUrl;
  String? _activeTitle;
  String? _pendingUrl;
  String? _pendingTitle;
  LiveHeroPreviewPhase _phase = LiveHeroPreviewPhase.idle;
  bool _hasFirstFrame = false;
  bool _muted = true;
  PlayingState? _lastPlayingState;
  Size _lastSize = Size.zero;
  bool _mutedPlayScheduled = false;
  bool _muteAsserted = false;

  VlcPlayerController? get player => _player;
  Key? get playerKey => _playerKey;
  LiveHeroPreviewPhase get phase => _phase;
  bool get hasFirstFrame => _hasFirstFrame;
  bool get muted => _muted;
  String? get activeTitle => _activeTitle;
  String? get activeStreamUrl => _activeUrl;
  String get activeUrlHash => LivePreviewTrace.urlHash(_activeUrl);
  int get generation => _gen;

  /// LIVE channel focus only. Category chips / rail must not call this.
  void request(TvStreamRecord stream, {bool immediate = false}) {
    if (_disposed) return;
    if (!LiveHeroPreviewPolicy.isLivePreviewSource(stream)) return;

    final url = stream.streamUrl.trim();
    final title = stream.title;
    final sameUrl = url == _activeUrl;
    final skip = LiveHeroPreviewPolicy.shouldSkipReconnect(
      activeUrl: _activeUrl,
      nextUrl: url,
      phase: _phase,
    );

    _log(
      channel: title,
      sameUrl: sameUrl,
      state: skip ? _phase : LiveHeroPreviewPhase.loading,
    );
    LivePreviewTrace.log(
      'focused_record_selected',
      'channel=$title hasStreamUrl=true hash=${LivePreviewTrace.urlHash(url)} '
      'sameUrl=$sameUrl skip=$skip immediate=$immediate gen=$_gen '
      'phase=${_phase.name} looksHttp=${url.startsWith('http')} len=${url.length}',
    );

    if (skip) {
      _debounce?.cancel();
      _pendingUrl = null;
      _pendingTitle = null;
      unawaited(_forceMuted());
      return;
    }

    _pendingUrl = url;
    _pendingTitle = title;
    _debounce?.cancel();

    if (immediate) {
      LivePreviewTrace.log(
        'debounce_bypass_immediate',
        'gen=${_gen + 1} sameUrl=$sameUrl hash=${LivePreviewTrace.urlHash(url)}',
      );
      unawaited(_commitPending());
      return;
    }

    _debounce = Timer(LiveHeroPreviewPolicy.focusDebounce, () {
      LivePreviewTrace.log(
        'debounce_fires',
        'gen=${_gen + 1} sameUrl=${url == _activeUrl} '
        'hash=${LivePreviewTrace.urlHash(url)}',
      );
      unawaited(_commitPending());
    });
  }

  /// Public stop/dispose of the one preview connection.
  Future<void> stopAndRelease({String reason = 'release'}) =>
      release(reason: reason);

  /// Re-assert mute. Safe before init; setVolume runs once VLC is ready.
  Future<void> forceMuted() => _forceMuted();

  /// Stop the one preview connection. Safe to call when already idle.
  Future<void> release({String reason = 'release'}) async {
    if (_disposed) return;
    LivePreviewTrace.log(
      'stopAndRelease',
      'reason=$reason channel=${_activeTitle ?? ''} '
      'hash=${LivePreviewTrace.urlHash(_activeUrl)} gen=$_gen phase=${_phase.name}',
    );
    _debounce?.cancel();
    _firstFrameTimer?.cancel();
    _pendingUrl = null;
    _pendingTitle = null;
    _gen++;
    _mutedPlayScheduled = false;
    _muteAsserted = false;
    await _tearDownPlayer();
    _activeUrl = null;
    _activeTitle = null;
    _hasFirstFrame = false;
    _phase = LiveHeroPreviewPhase.idle;
    _log(
      channel: reason,
      sameUrl: false,
      state: LiveHeroPreviewPhase.idle,
    );
    _notify();
  }

  Future<void> _commitPending() async {
    if (_disposed) return;
    final url = _pendingUrl;
    final title = _pendingTitle ?? '';
    if (url == null || url.isEmpty) return;
    _pendingUrl = null;
    _pendingTitle = null;

    if (LiveHeroPreviewPolicy.shouldSkipReconnect(
      activeUrl: _activeUrl,
      nextUrl: url,
      phase: _phase,
    )) {
      unawaited(_forceMuted());
      return;
    }

    final gen = ++_gen;
    _activeTitle = title;
    _hasFirstFrame = false;
    _phase = LiveHeroPreviewPhase.loading;
    _muted = true;
    _log(channel: title, sameUrl: url == _activeUrl, state: _phase);
    _notify();

    if (_hooks != null) {
      final replace = _player != null || _activeUrl != null;
      _activeUrl = url;
      try {
        if (replace && _hooks.replace != null) {
          await _hooks.replace!(url, title);
        } else if (_hooks.open != null) {
          await _hooks.open!(url, title);
        }
      } catch (_) {
        if (gen != _gen || _disposed) return;
        _phase = LiveHeroPreviewPhase.failed;
        _log(channel: title, sameUrl: false, state: _phase);
        _notify();
      }
      return;
    }

    final canReplace =
        _player != null && _player!.value.isInitialized && _activeUrl != null;
    if (canReplace) {
      try {
        LivePreviewTrace.log(
          'initialize_open_begins',
          'mode=replace gen=$gen hash=${LivePreviewTrace.urlHash(url)}',
        );
        await _forceMuted();
        await _player!.stop();
        if (gen != _gen || _disposed) return;
        await _player!.setMediaFromNetwork(
          url,
          autoPlay: false,
          hwAcc: HwAcc.auto,
        );
        if (gen != _gen || _disposed) return;
        LivePreviewTrace.log(
          'initialize_open_completes',
          'mode=replace gen=$gen hash=${LivePreviewTrace.urlHash(url)}',
        );
        await _forceMuted();
        if (gen != _gen || _disposed) return;
        try {
          LivePreviewTrace.log(
            'play_requested_after_mute',
            'mode=replace gen=$gen',
          );
          await _player!.play();
        } catch (e) {
          LivePreviewTrace.log(
            'play_error',
            'mode=replace type=${e.runtimeType}',
          );
        }
        if (gen != _gen || _disposed) return;
        await _forceMuted();
        _activeUrl = url;
        _armFirstFrameTimeout(gen);
        return;
      } catch (e) {
        LivePreviewTrace.log(
          'initialize_open_errors',
          'mode=replace type=${e.runtimeType}',
        );
        if (gen != _gen || _disposed) return;
        await _openFreshPlayer(url, title, gen);
        return;
      }
    }

    await _openFreshPlayer(url, title, gen);
  }

  Future<void> _openFreshPlayer(String url, String title, int gen) async {
    await _tearDownPlayer();
    if (gen != _gen || _disposed) return;

    LivePreviewTrace.log(
      'controller_creation_begins',
      'gen=$gen hash=${LivePreviewTrace.urlHash(url)} channel=$title',
    );
    // Vanilla options (3015 proved LibVLC create). autoPlay MUST stay false —
    // mute via setVolume(0) before any play() to avoid audible race.
    final created = VlcPlayerController.network(
      url,
      hwAcc: HwAcc.auto,
      autoInitialize: true,
      autoPlay: false,
      options: VlcPlayerOptions(),
    );
    // Attach init listener BEFORE mounting/exposing the controller.
    created.addOnInitListener(_onVlcInit);
    created.addListener(_onVlc);
    _player = created;
    _playerKey = UniqueKey();
    _activeUrl = url;
    _activeTitle = title;
    _phase = LiveHeroPreviewPhase.loading;
    _hasFirstFrame = false;
    _lastPlayingState = null;
    _lastSize = Size.zero;
    _mutedPlayScheduled = false;
    _muteAsserted = false;
    LivePreviewTrace.log(
      'controller_created',
      'gen=$gen hash=${LivePreviewTrace.urlHash(url)} '
      'autoPlay=false initialized=${created.value.isInitialized}',
    );
    LivePreviewTrace.log(
      'initialize_open_begins',
      'mode=fresh gen=$gen waiting_platform_view=true',
    );
    _armFirstFrameTimeout(gen);
    Timer(const Duration(seconds: 2), () {
      if (_disposed || gen != _gen) return;
      final p = _player;
      LivePreviewTrace.log(
        'initialize_open_check',
        'gen=$gen initialized=${p?.value.isInitialized == true} '
        'hasError=${p?.value.hasError == true} '
        'state=${p?.value.playingState.name ?? 'none'} '
        'size=${p?.value.size.width.toInt() ?? 0}x${p?.value.size.height.toInt() ?? 0} '
        'mutedPlayScheduled=$_mutedPlayScheduled',
      );
      // Safety: if onInit was missed, still mute-then-play (never autoPlay).
      if (p?.value.isInitialized == true && !_mutedPlayScheduled) {
        unawaited(_startMutedPlay(reason: 'initialize_open_check'));
      }
    });
    _notify();
  }

  void _onVlcInit() {
    LivePreviewTrace.log(
      'initialize_open_completes',
      'mode=fresh gen=$_gen initialized=${_player?.value.isInitialized == true} '
      'size=${_player?.value.size.width.toInt() ?? 0}x${_player?.value.size.height.toInt() ?? 0}',
    );
    unawaited(_startMutedPlay(reason: 'onInit'));
  }

  /// Mute FIRST, then play. Never call play() before setVolume(0) succeeds.
  Future<void> _startMutedPlay({required String reason}) async {
    if (_disposed || _mutedPlayScheduled) return;
    _mutedPlayScheduled = true;
    final gen = _gen;
    LivePreviewTrace.log('muted_play_scheduled', 'reason=$reason gen=$gen');

    // Yield so plugin initialize() can finish before platform-channel calls.
    await Future<void>.delayed(Duration.zero);
    if (_disposed || gen != _gen) return;

    final p = _player;
    if (p == null || !p.value.isInitialized) {
      LivePreviewTrace.log(
        'initialize_open_errors',
        'mode=fresh deferred_not_initialized reason=$reason',
      );
      _mutedPlayScheduled = false;
      return;
    }

    try {
      await p.setVolume(0);
      _muted = true;
      _muteAsserted = true;
      LivePreviewTrace.log(
        'volume_forced_to_0',
        'initialized=true gen=$gen hash=${LivePreviewTrace.urlHash(_activeUrl)} '
        'before_play=true',
      );
    } catch (e) {
      LivePreviewTrace.log(
        'volume_force_error',
        'type=${e.runtimeType} before_play=true',
      );
      // Do not play if mute failed — prevents audible leak.
      _mutedPlayScheduled = false;
      return;
    }

    if (_disposed || gen != _gen) return;

    try {
      LivePreviewTrace.log(
        'play_requested_after_mute',
        'mode=fresh gen=$gen reason=$reason',
      );
      // Do not await play() on Chromecast — a blocked native play() wedges
      // the UI isolate and freezes the Welcome "Hold please" card.
      unawaited(
        p.play().then((_) {
          LivePreviewTrace.log(
            'play_future_done',
            'gen=$gen reason=$reason',
          );
        }).catchError((Object e) {
          LivePreviewTrace.log('play_error', 'mode=fresh type=${e.runtimeType}');
        }),
      );
    } catch (e) {
      LivePreviewTrace.log('play_error', 'mode=fresh type=${e.runtimeType}');
    }

    if (_disposed || gen != _gen) return;
    try {
      await p.setVolume(0);
      _muted = true;
      LivePreviewTrace.log(
        'volume_forced_to_0',
        'initialized=true gen=$gen after_play_request=true',
      );
    } catch (_) {}

    // Keep re-asserting mute once after play starts — not from _onVlc
    // (setVolume→listener→setVolume StackOverflow on Chromecast).
    Future<void>.delayed(const Duration(milliseconds: 400), () async {
      if (_disposed || gen != _gen) return;
      if (!_muteAsserted) await _forceMuted(log: false);
    });
  }

  void _onVlc() {
    if (_disposed) return;
    final p = _player;
    if (p == null) return;
    final v = p.value;

    if (_lastPlayingState != v.playingState) {
      _lastPlayingState = v.playingState;
      LivePreviewTrace.log(
        'vlc_state',
        'state=${v.playingState.name} initialized=${v.isInitialized} '
        'playing=${v.isPlaying} buffering=${v.isBuffering} '
        'hasError=${v.hasError} size=${v.size.width.toInt()}x${v.size.height.toInt()}',
      );
    }
    if (v.size != _lastSize && (v.size.width > 0 || v.size.height > 0)) {
      _lastSize = v.size;
      LivePreviewTrace.log(
        'video_size',
        '${v.size.width.toInt()}x${v.size.height.toInt()}',
      );
    }

    if (v.hasError) {
      _firstFrameTimer?.cancel();
      _phase = LiveHeroPreviewPhase.failed;
      _hasFirstFrame = false;
      LivePreviewTrace.log(
        'vlc_state',
        'state=error initialized=${v.isInitialized}',
      );
      LivePreviewTrace.log(
        'stopAndRelease',
        'reason=error channel=${_activeTitle ?? ''} '
        'hash=${LivePreviewTrace.urlHash(_activeUrl)} gen=$_gen',
      );
      _log(
        channel: _activeTitle ?? '',
        sameUrl: true,
        state: _phase,
      );
      unawaited(_safeStop(p));
      _notify();
      return;
    }

    final gotFrame = v.isInitialized &&
        (v.isPlaying || v.size.width > 0) &&
        !v.hasError;
    // Never re-enter setVolume from the VLC listener — it can StackOverflow
    // when setVolume synchronously notifies value listeners on Chromecast.

    if (gotFrame && !_hasFirstFrame) {
      _firstFrameTimer?.cancel();
      _hasFirstFrame = true;
      _phase = LiveHeroPreviewPhase.playing;
      LivePreviewTrace.log(
        'first_video_frame',
        'size=${v.size.width.toInt()}x${v.size.height.toInt()} '
        'playing=${v.isPlaying}',
      );
      if (!_muteAsserted) {
        unawaited(_forceMuted());
      }
      _log(
        channel: _activeTitle ?? '',
        sameUrl: true,
        state: _phase,
      );
      _notify();
    }
  }

  void _armFirstFrameTimeout(int gen) {
    _firstFrameTimer?.cancel();
    _firstFrameTimer = Timer(LiveHeroPreviewPolicy.firstFrameTimeout, () {
      if (_disposed || gen != _gen || _hasFirstFrame) return;
      _phase = LiveHeroPreviewPhase.failed;
      LivePreviewTrace.log(
        'first_frame_timeout',
        'gen=$gen hash=${LivePreviewTrace.urlHash(_activeUrl)} '
        'initialized=${_player?.value.isInitialized == true} '
        'size=${_player?.value.size.width.toInt() ?? 0}x${_player?.value.size.height.toInt() ?? 0}',
      );
      _log(
        channel: _activeTitle ?? '',
        sameUrl: true,
        state: _phase,
      );
      unawaited(_safeStop(_player));
      _notify();
    });
  }

  Future<void> _forceMuted({bool log = true}) async {
    _muted = true;
    final p = _player;
    if (p != null && p.value.isInitialized) {
      try {
        await p.setVolume(0);
        _muteAsserted = true;
        if (log) {
          LivePreviewTrace.log(
            'volume_forced_to_0',
            'initialized=true gen=$_gen hash=${LivePreviewTrace.urlHash(_activeUrl)}',
          );
        }
      } catch (e) {
        LivePreviewTrace.log(
          'volume_force_error',
          'type=${e.runtimeType} initialized=true',
        );
      }
      // Do not call setAudioTrack(-1): it can hang LibVLC on Chromecast.
      // Mute is volume=0 only (Dart-level), matching fullscreen mute style.
    } else if (log) {
      LivePreviewTrace.log(
        'volume_forced_to_0',
        'initialized=false skipped_setVolume gen=$_gen',
      );
    }
    _muted = true;
    if (log) {
      _log(
        channel: _activeTitle ?? '',
        sameUrl: true,
        state: _phase,
      );
    }
  }

  Future<void> _safeStop(VlcPlayerController? p) async {
    if (p == null) return;
    try {
      if (p.value.isInitialized) {
        await p.stop();
      }
    } catch (_) {}
  }

  Future<void> _tearDownPlayer() async {
    _firstFrameTimer?.cancel();
    final old = _player;
    _player = null;
    _playerKey = null;
    _hasFirstFrame = false;
    _notify();

    if (_hooks != null) {
      try {
        await _hooks.release?.call();
      } catch (_) {}
      return;
    }

    if (old == null) return;
    try {
      old.removeListener(_onVlc);
    } catch (_) {}
    try {
      old.removeOnInitListener(_onVlcInit);
    } catch (_) {}
    // Let the VlcPlayer widget unmount before native dispose.
    await Future<void>.delayed(Duration.zero);
    try {
      if (old.value.isInitialized) {
        await old.stop();
      }
    } catch (_) {}
    try {
      await old.stopRendererScanning();
    } catch (_) {}
    try {
      await old.dispose();
    } catch (_) {}
  }

  void _log({
    required String channel,
    required bool sameUrl,
    required LiveHeroPreviewPhase state,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[LIVE_PREVIEW] channel=$channel sameUrl=$sameUrl '
      'state=${state.name} muted=true',
    );
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _firstFrameTimer?.cancel();
    _pendingUrl = null;
    _gen++;
    _phase = LiveHeroPreviewPhase.disposed;
    LivePreviewTrace.log(
      'stopAndRelease',
      'reason=dispose channel=${_activeTitle ?? ''} '
      'hash=${LivePreviewTrace.urlHash(_activeUrl)}',
    );
    _log(
      channel: _activeTitle ?? '',
      sameUrl: false,
      state: _phase,
    );
    unawaited(_tearDownPlayer());
    super.dispose();
  }
}

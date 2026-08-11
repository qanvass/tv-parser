part of '../screens.dart';

// ─── Shared VOD constants / helpers (used by movie + series players) ──────────

const _kVodAspects = ['16:9', '4:3', '1:1', '21:9'];

bool _isSelectKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.select ||
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.gameButtonA;

/// Android TV remotes send [LogicalKeyboardKey.goBack]; emulators often send
/// [LogicalKeyboardKey.escape]. Swallowing goBack without popping finishes the
/// Activity → Google TV Home.
bool _isBackKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack;

/// Dead-stream actions: 0 = Try Again, 1 = Connection Test, 2 = Go Back.
class _DeadStreamOverlay extends StatelessWidget {
  const _DeadStreamOverlay({
    required this.focusedIdx,
    required this.onRetry,
    required this.onConnectionTest,
    required this.onBack,
    this.message =
        'This stream is temporarily unavailable. Try another source or run Connection Test.',
  });

  final int focusedIdx;
  final VoidCallback onRetry;
  final VoidCallback onConnectionTest;
  final VoidCallback onBack;
  final String message;

  @override
  Widget build(BuildContext context) {
    Widget actionButton({
      required int index,
      required String label,
      required IconData icon,
      required VoidCallback onPressed,
      required bool primary,
    }) {
      final focused = focusedIdx == index;
      if (primary) {
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: focused ? Colors.white : Colors.white70,
            foregroundColor: Colors.black,
            minimumSize: const Size(220, 48),
            side: BorderSide(
              color: focused ? Colors.amber : Colors.transparent,
              width: focused ? 3 : 0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        );
      }
      if (index == 2) {
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: focused ? Colors.white : Colors.white54,
            side: BorderSide(
              color: focused ? Colors.white54 : Colors.transparent,
              width: focused ? 2 : 0,
            ),
            minimumSize: const Size(220, 44),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: focused ? FontWeight.w800 : FontWeight.bold,
            ),
          ),
        );
      }
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(220, 48),
          side: BorderSide(
            color: focused ? Colors.white : Colors.white24,
            width: focused ? 2.5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFC62828),
                  size: 54,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Use Up/Down to choose · OK to confirm · Back to browse',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                actionButton(
                  index: 0,
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  primary: true,
                ),
                const SizedBox(height: 12),
                actionButton(
                  index: 1,
                  label: 'Connection Test',
                  icon: Icons.network_check_rounded,
                  onPressed: onConnectionTest,
                  primary: false,
                ),
                const SizedBox(height: 12),
                actionButton(
                  index: 2,
                  label: 'Go Back',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  primary: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared track-selection panel (Positioned, lives inside a Stack) ──────────

class _VodTrackPanel extends StatelessWidget {
  const _VodTrackPanel({
    required this.isSub,
    required this.list,
    required this.focusedIdx,
    required this.onSelect,
  });

  final bool isSub;
  final List<MapEntry<int, String>> list;
  final int focusedIdx;
  final void Function(int trackId) onSelect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72,
      right: 16,
      child: Container(
        width: 220,
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: const Color(0xF0101018),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSub
                        ? FontAwesomeIcons.closedCaptioning.data
                        : FontAwesomeIcons.volumeHigh.data,
                    size: 12,
                    color: kColorPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSub ? 'SUBTITLES' : 'AUDIO TRACKS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final focused = i == focusedIdx;
                  return GestureDetector(
                    onTap: () => onSelect(list[i].key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? kColorPrimary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: focused ? kColorFocus : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        list[i].value.isNotEmpty
                            ? list[i].value
                            : 'Track ${i + 1}',
                        style: TextStyle(
                          color: focused ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: focused
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Player ──────────────────────────────────────────────────────────────
// Standalone fullscreen player for a single live channel.
// Used when launching from Favourites (or anywhere outside LiveCategoriesScreen).
//
// D-pad focus layout:
//   Row 0 (top bar):    0=Back  1=SUB  2=AUD
//   Row 1 (bottom bar): 0=Play/Pause  1=Aspect

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({
    super.key,
    required this.link,
    required this.title,
    this.streamIcon,
    this.streamId,
  });

  final String link;
  final String title;
  final String? streamIcon;
  final String? streamId;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late VlcPlayerController _ctrl;
  bool _ctrlInitialized = false;
  bool _isCheckingHealth = true;
  bool _isDeadStream = false;
  String _deadStreamMessage =
      'This stream is temporarily unavailable. Try another source or run Connection Test.';
  int _deadActionIdx = 0;

  bool _isPlaying = false;
  bool _isBuffering = true;
  String? _castDevice;
  bool _isCastPlaying = true;

  bool _showControls = true;
  Timer? _hideTimer;

  Map<int, String> _audioTracks = {};
  Map<int, String> _subtitleTracks = {};
  bool _tracksLoaded = false;

  String? _trackPanel; // null | 'sub' | 'audio'
  int _trackPanelIdx = 0;

  int _aspectIdx = 0;

  int _focusRow = 1;
  int _focusCol = 0;
  final _focusNode = FocusNode();
  final Stopwatch _stopwatch = Stopwatch();

  List<MapEntry<int, String>> get _trackList =>
      (_trackPanel == 'sub' ? _subtitleTracks : _audioTracks).entries.toList();

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    debugPrint("[TV_PARSER_PERF] LivePlayerScreen: _initPlayer started for ${widget.title}");
    _stopwatch.reset();
    _stopwatch.start();

    // Classify entitlement/auth failures before VLC so we don't show "offline".
    final probe = await StreamHealthService.probe(widget.link);
    if (!mounted) return;
    if (probe == StreamProbeResult.subscriptionGated ||
        probe == StreamProbeResult.unauthorized ||
        probe == StreamProbeResult.unreachable) {
      setState(() {
        _isDeadStream = true;
        _isCheckingHealth = false;
        _ctrlInitialized = false;
        _deadStreamMessage = StreamHealthService.messageFor(probe);
      });
      OrientationGuard.applyPlayerOrientation();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
      return;
    }

    _ctrl = VlcPlayerController.network(
      widget.link,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: buildVlcPlaybackOptions(isLive: true, streamUrl: widget.link),
    );
    _ctrl.addListener(_onVlc);
    OrientationGuard.applyPlayerOrientation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHide();
    setState(() {
      _ctrlInitialized = true;
      _deadStreamMessage = StreamHealthService.messageFor(StreamProbeResult.unknown);
      // [TV_PARSER_PERF] Keep checking health active until the stream starts playing
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void deactivate() {
    if (_ctrlInitialized) {
      try {
        if (_ctrl.value.isInitialized) {
          _ctrl.pause().catchError((_) {});
          _ctrl.stop().catchError((_) {});
        }
      } catch (_) {}
    }
    super.deactivate();
  }

  @override
  void dispose() {
    if (_ctrlInitialized) {
      try {
        _ctrl.removeListener(_onVlc);
      } catch (_) {}
      _ctrl.stopRendererScanning().catchError((_) {});
      try {
        _ctrl.dispose().catchError((_) {});
      } catch (_) {}
    }
    _hideTimer?.cancel();
    _focusNode.dispose();
    OrientationGuard.applyPlayerExitOrientation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onVlc() {
    if (!mounted) return;
    final v = _ctrl.value;
    setState(() {
      _isPlaying = v.isPlaying;
      _isBuffering = !v.isInitialized || v.isBuffering;
    });
    if (v.isInitialized && _stopwatch.isRunning) {
      _stopwatch.stop();
      debugPrint("[TV_PARSER_PERF] LivePlayerScreen: player initialized in ${_stopwatch.elapsedMilliseconds}ms");
    }
    if (v.isInitialized && _isCheckingHealth && !v.isBuffering) {
      setState(() {
        _isCheckingHealth = false;
      });
    }
    if (v.hasError && !_isDeadStream) {
      debugPrint("[TV_PARSER_PERF] LivePlayerScreen: Player error detected");
      setState(() {
        _isDeadStream = true;
        _isCheckingHealth = false;
      });
    }
    if (v.isInitialized && !_tracksLoaded) {
      _tracksLoaded = true;
      _loadTracks();
    }
  }

  Future<void> _loadTracks() async {
    try {
      final audio = await _ctrl.getAudioTracks();
      final sub = await _ctrl.getSpuTracks();
      if (mounted)
        setState(() {
          _audioTracks = audio;
          _subtitleTracks = sub;
        });
    } catch (_) {}
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_trackPanel != null) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
    }
    _scheduleHide();
  }

  Future<void> _cycleAspect() async {
    final next = (_aspectIdx + 1) % _kVodAspects.length;
    try {
      await _ctrl.setVideoAspectRatio(_kVodAspects[next]);
    } catch (_) {}
    if (mounted) setState(() => _aspectIdx = next);
    _scheduleHide();
  }

  void _openTrackPanel(String type) {
    setState(() {
      _trackPanel = type;
      _trackPanelIdx = 0;
    });
    _hideTimer?.cancel();
  }

  void _selectTrack(int id) {
    try {
      if (_trackPanel == 'sub') {
        _ctrl.setSpuTrack(id);
      } else {
        _ctrl.setAudioTrack(id);
      }
    } catch (_) {}
    setState(() => _trackPanel = null);
    _scheduleHide();
  }

  bool _isFocused(int row, int col) =>
      _showControls && _focusRow == row && _focusCol == col;

  void _retryDeadStream() {
    setState(() {
      _isDeadStream = false;
      _isCheckingHealth = true;
      _ctrlInitialized = false;
      _deadActionIdx = 0;
      _deadStreamMessage =
          'This stream is temporarily unavailable. Try another source or run Connection Test.';
    });
    _initPlayer();
  }

  void _activateDeadAction() {
    switch (_deadActionIdx) {
      case 0:
        _retryDeadStream();
      case 1:
        Get.to(() => const ConnectionTestScreen());
      case 2:
        if (mounted && Navigator.of(context).canPop()) Get.back();
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (_trackPanel != null) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_trackPanelIdx > 0) setState(() => _trackPanelIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_trackPanelIdx < _trackList.length - 1)
          setState(() => _trackPanelIdx++);
      } else if (_isSelectKey(k)) {
        if (_trackList.isNotEmpty) _selectTrack(_trackList[_trackPanelIdx].key);
      } else if (_isBackKey(k) || k == LogicalKeyboardKey.arrowLeft) {
        setState(() => _trackPanel = null);
        _scheduleHide();
      }
      return KeyEventResult.handled;
    }

    // Dead stream: D-pad chooses Retry / Connection Test / Back.
    if (_isDeadStream) {
      if (_isBackKey(k)) {
        if (mounted && Navigator.of(context).canPop()) Get.back();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_deadActionIdx > 0) setState(() => _deadActionIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_deadActionIdx < 2) setState(() => _deadActionIdx++);
      } else if (_isSelectKey(k)) {
        _activateDeadAction();
      }
      return KeyEventResult.handled;
    }

    // Loading: Back exits to browse; other keys swallowed.
    if (_isCheckingHealth) {
      if (_isBackKey(k)) {
        if (mounted && Navigator.of(context).canPop()) Get.back();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Back always leaves the player (do not swallow goBack).
    if (_isBackKey(k)) {
      if (mounted && Navigator.of(context).canPop()) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    if (!_showControls) {
      setState(() => _showControls = true);
      _scheduleHide();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_focusRow == 1)
        setState(() {
          _focusRow = 0;
          // TV: Back/Fav/SUB/AUD (no Cast). Mobile: Back/Cast/SUB/AUD.
          _focusCol = _focusCol.clamp(0, 3);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusRow == 0)
        setState(() {
          _focusRow = 1;
          _focusCol = _focusCol.clamp(0, 1);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) setState(() => _focusCol--);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      final maxCol = _focusRow == 0 ? 3 : 1;
      if (_focusCol < maxCol) setState(() => _focusCol++);
      _scheduleHide();
    } else if (_isSelectKey(k)) {
      _activate();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _openCastDialog() {
    // TV gate: Cast is phone→TV only; hide entry on leanback devices.
    if (!supportsCasting()) return;
    _hideTimer?.cancel();
    showDialog(
      context: context,
      builder: (context) => CastSelectionDialog(
        controller: _ctrl,
        currentCastDevice: _castDevice,
        onCastSelected: (device) {
          setState(() {
            _castDevice = device;
          });
        },
      ),
    ).then((_) => _scheduleHide());
  }

  void _activate() {
    if (_focusRow == 0) {
      if (isTvDevice()) {
        // TV chrome: Back, Fav, SUB, AUD (Cast removed).
        switch (_focusCol) {
          case 0:
            Get.back();
          case 1:
            _toggleFavorite();
          case 2:
            if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
          case 3:
            if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
        }
      } else {
        switch (_focusCol) {
          case 0:
            Get.back();
          case 1:
            _openCastDialog();
          case 2:
            if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
          case 3:
            if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
        }
      }
    } else {
      switch (_focusCol) {
        case 0:
          _togglePlay();
        case 1:
          _cycleAspect();
      }
    }
  }

  void _toggleFavorite() {
    final sid = widget.streamId ?? extractStreamIdFromUrl(widget.link);
    if (sid == null) return;
    final favState = context.read<FavoritesCubit>().state;
    final existing = favState.lives.where((l) => l.streamId == sid).toList();
    if (existing.isNotEmpty) {
      context.read<FavoritesCubit>().addLive(existing.first, isAdd: false);
    } else {
      context.read<FavoritesCubit>().addLive(
            ChannelLive(
              streamId: sid,
              name: widget.title,
              streamIcon: widget.streamIcon,
            ),
            isAdd: true,
          );
    }
    _scheduleHide();
  }

  Widget _buildCastOverlay(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(
                Icons.cast_connected_rounded,
                size: 56,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Casting to $_castDevice",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Use your phone as a remote controller",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    _isCastPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isCastPlaying = !_isCastPlaying;
                    });
                    if (_isCastPlaying) {
                      CastMediaService().play();
                    } else {
                      CastMediaService().pause();
                    }
                  },
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    await CastMediaService().disconnect();
                    setState(() {
                      _castDevice = null;
                    });
                    _ctrl.play();
                  },
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text("Disconnect", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted && Navigator.of(context).canPop()) {
          Get.back();
        }
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final ratio = constraints.maxWidth / constraints.maxHeight;

              return Stack(
                children: [
                  // 1. The Video Player (Always in tree if initialized)
                  if (_ctrlInitialized)
                    VlcPlayer(
                      controller: _ctrl,
                      aspectRatio: ratio,
                      placeholder: const SizedBox(),
                    ),

                  // 2. Gesture Detector to toggle controls
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null)
                    GestureDetector(
                      onTap: _toggleControls,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),

                  // 3. Buffering Indicator
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null && _isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),

                  // 4. Controls Overlay
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null)
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: _buildOverlay(),
                      ),
                    ),

                  // 5. Track Selector Panel
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null && _trackPanel != null)
                    _VodTrackPanel(
                      isSub: _trackPanel == 'sub',
                      list: _trackList,
                      focusedIdx: _trackPanelIdx,
                      onSelect: _selectTrack,
                    ),

                  // 6. Loading screen overlay
                  if (_isCheckingHealth)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.topCenter,
                                    radius: 1.3,
                                    colors: [
                                      const Color(0xFF25112F).withValues(alpha: 0.4),
                                      const Color(0xFF08070C),
                                      const Color(0xFF030305),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/tv_parser_logo_transparent.png',
                                    height: 96,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.live_tv_rounded, size: 72, color: Colors.amber),
                                  ),
                                  const SizedBox(height: 28),
                                  const SandTimeclock(size: 36),
                                  const SizedBox(height: 24),
                                  const Text(
                                    "Hold please...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Loading your provider's stream...",
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 7. Dead Stream Overlay (D-pad focusable actions)
                  if (!_isCheckingHealth && _isDeadStream)
                    _DeadStreamOverlay(
                      focusedIdx: _deadActionIdx,
                      message: _deadStreamMessage,
                      onRetry: _retryDeadStream,
                      onConnectionTest: () {
                        Get.to(() => const ConnectionTestScreen());
                      },
                      onBack: () {
                        if (mounted && Navigator.of(context).canPop()) {
                          Get.back();
                        }
                      },
                    ),

                  // 8. Chromecast Overlay
                  if (!_isCheckingHealth && !_isDeadStream && supportsCasting() && _castDevice != null)
                    Positioned.fill(
                      child: _buildCastOverlay(context),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final streamId = widget.streamId ?? extractStreamIdFromUrl(widget.link);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          if (isTvDevice() && streamId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TvEpgPeek(streamId: streamId),
              ),
            ),
          const Spacer(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _FsBtn(
              icon: FontAwesomeIcons.chevronLeft.data,
              label: 'Back',
              isFocused: _isFocused(0, 0),
              onTap: Get.back,
            ),
            const SizedBox(width: 8),
            if (widget.streamIcon != null && widget.streamIcon!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CachedNetworkImage(
                  imageUrl: widget.streamIcon!,
                  width: 28,
                  height: 28,
                  memCacheWidth: 300,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isTvDevice()) ...[
              BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, favState) {
                  final sid = widget.streamId ?? extractStreamIdFromUrl(widget.link);
                  final isFav = sid != null &&
                      favState.lives.any((l) => l.streamId == sid);
                  return _FsBtn(
                    icon: isFav
                        ? FontAwesomeIcons.solidHeart.data
                        : FontAwesomeIcons.heart.data,
                    label: isFav ? 'Unfav' : 'Fav',
                    isFocused: _isFocused(0, 1),
                    onTap: _toggleFavorite,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            Container(
              margin: const EdgeInsets.only(left: 8, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            // Chromecast — phone/tablet only (not on Android TV / Google TV).
            if (supportsCasting()) ...[
              _FsBtn(
                icon: FontAwesomeIcons.chromecast.data,
                label: 'Cast',
                isFocused: _isFocused(0, 1),
                onTap: _openCastDialog,
              ),
              const SizedBox(width: 8),
            ],
            _FsBtn(
              icon: FontAwesomeIcons.closedCaptioning.data,
              label: 'SUB',
              badge: _subtitleTracks.isNotEmpty
                  ? '${_subtitleTracks.length}'
                  : null,
              // Live: TV Back/Fav/SUB/AUD; mobile Back/Cast/SUB/AUD — SUB/AUD both at 2/3.
              isFocused: _isFocused(0, 2),
              isDisabled: _subtitleTracks.isEmpty,
              onTap: () => _openTrackPanel('sub'),
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.volumeHigh.data,
              label: 'AUD',
              badge: _audioTracks.isNotEmpty ? '${_audioTracks.length}' : null,
              isFocused: _isFocused(0, 3),
              isDisabled: _audioTracks.isEmpty,
              onTap: () => _openTrackPanel('audio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _FsBtn(
              icon: _isPlaying ? FontAwesomeIcons.pause.data : FontAwesomeIcons.play.data,
              label: _isPlaying ? 'Pause' : 'Play',
              isFocused: _isFocused(1, 0),
              isLarge: true,
              onTap: _togglePlay,
            ),
            const Spacer(),
            _FsBtn(
              icon: FontAwesomeIcons.expand.data,
              label: _kVodAspects[_aspectIdx],
              isFocused: _isFocused(1, 1),
              onTap: _cycleAspect,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Movie Player ─────────────────────────────────────────────────────────────
// Full-screen VOD player for movies.
// Returns [positionSeconds, durationSeconds] on back for watch-history tracking.
//
// D-pad focus layout:
//   Row 0 (top bar):    0=Back  1=SUB  2=AUD
//   Row 1 (bottom bar): 0=-10s  1=Play  2=Aspect

class MoviePlayerScreen extends StatefulWidget {
  const MoviePlayerScreen({super.key, required this.link, required this.title});

  final String link;
  final String title;

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen> {
  late VlcPlayerController _ctrl;
  bool _ctrlInitialized = false;
  bool _isCheckingHealth = true;
  bool _isDeadStream = false;
  int _deadActionIdx = 0;

  // Playback state
  bool _isPlaying = false;
  bool _isBuffering = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _castDevice;
  bool _isCastPlaying = true;

  // Controls visibility
  bool _showControls = true;
  Timer? _hideTimer;

  // Tracks
  Map<int, String> _audioTracks = {};
  Map<int, String> _subtitleTracks = {};
  bool _tracksLoaded = false;

  // Track panel
  String? _trackPanel; // null | 'sub' | 'audio'
  int _trackPanelIdx = 0;

  // Aspect ratio
  int _aspectIdx = 0;

  // D-pad
  int _focusRow = 1;
  int _focusCol = 1; // default: Play/Pause
  final _focusNode = FocusNode();
  final Stopwatch _stopwatch = Stopwatch();

  List<MapEntry<int, String>> get _trackList =>
      (_trackPanel == 'sub' ? _subtitleTracks : _audioTracks).entries.toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    debugPrint("[TV_PARSER_PERF] MoviePlayerScreen: _initPlayer started for ${widget.title}");
    _stopwatch.reset();
    _stopwatch.start();

    _ctrl = VlcPlayerController.network(
      widget.link,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: buildVlcPlaybackOptions(isLive: false, streamUrl: widget.link),
    );
    _ctrl.addListener(_onVlc);
    OrientationGuard.applyPlayerOrientation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHide();
    setState(() {
      _ctrlInitialized = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void deactivate() {
    if (_ctrlInitialized) {
      try {
        if (_ctrl.value.isInitialized) {
          _ctrl.pause().catchError((_) {});
          _ctrl.stop().catchError((_) {});
        }
      } catch (_) {}
    }
    super.deactivate();
  }

  @override
  void dispose() {
    if (_ctrlInitialized) {
      try {
        _ctrl.removeListener(_onVlc);
      } catch (_) {}
      _ctrl.stopRendererScanning().catchError((_) {});
      try {
        _ctrl.dispose().catchError((_) {});
      } catch (_) {}
    }
    _hideTimer?.cancel();
    _focusNode.dispose();
    OrientationGuard.applyPlayerExitOrientation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── VLC listener ──────────────────────────────────────────────────────────

  void _onVlc() {
    if (!mounted) return;
    final v = _ctrl.value;
    setState(() {
      _isPlaying = v.isPlaying;
      _isBuffering = !v.isInitialized || v.isBuffering;
      _position = v.position;
      _duration = v.duration;
    });
    if (v.isInitialized && _stopwatch.isRunning) {
      _stopwatch.stop();
      debugPrint("[TV_PARSER_PERF] MoviePlayerScreen: player initialized in ${_stopwatch.elapsedMilliseconds}ms");
    }
    if (v.isInitialized && _isCheckingHealth && !v.isBuffering) {
      setState(() {
        _isCheckingHealth = false;
      });
    }
    if (v.hasError && !_isDeadStream) {
      debugPrint("[TV_PARSER_PERF] MoviePlayerScreen: Player error detected");
      setState(() {
        _isDeadStream = true;
        _isCheckingHealth = false;
      });
    }
    if (v.isInitialized && !_tracksLoaded) {
      _tracksLoaded = true;
      _loadTracks();
    }
  }

  Future<void> _loadTracks() async {
    try {
      final audio = await _ctrl.getAudioTracks();
      final sub = await _ctrl.getSpuTracks();
      if (mounted)
        setState(() {
          _audioTracks = audio;
          _subtitleTracks = sub;
        });
    } catch (_) {}
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_trackPanel != null) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
    }
    _scheduleHide();
  }

  Future<void> _rewind10s() async {
    try {
      final t = _position - const Duration(seconds: 30);
      await _ctrl.seekTo(t < Duration.zero ? Duration.zero : t);
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _forward10s() async {
    try {
      final t = _position + const Duration(seconds: 30);
      await _ctrl.seekTo(t > _duration ? _duration : t);
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _cycleAspect() async {
    final next = (_aspectIdx + 1) % _kVodAspects.length;
    try {
      await _ctrl.setVideoAspectRatio(_kVodAspects[next]);
    } catch (_) {}
    if (mounted) setState(() => _aspectIdx = next);
    _scheduleHide();
  }

  void _openTrackPanel(String type) {
    setState(() {
      _trackPanel = type;
      _trackPanelIdx = 0;
    });
    _hideTimer?.cancel();
  }

  void _selectTrack(int id) {
    try {
      if (_trackPanel == 'sub') {
        _ctrl.setSpuTrack(id);
      } else {
        _ctrl.setAudioTrack(id);
      }
    } catch (_) {}
    setState(() => _trackPanel = null);
    _scheduleHide();
  }

  void _goBack() {
    if (!mounted) return;
    if (!Navigator.of(context).canPop()) return;
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    Get.back(result: pos > 0 ? [pos, dur] : null);
  }

  void _retryDeadStream() {
    setState(() {
      _isDeadStream = false;
      _isCheckingHealth = true;
      _ctrlInitialized = false;
      _deadActionIdx = 0;
    });
    _initPlayer();
  }

  void _activateDeadAction() {
    switch (_deadActionIdx) {
      case 0:
        _retryDeadStream();
      case 1:
        Get.to(() => const ConnectionTestScreen());
      case 2:
        _goBack();
    }
  }

  // ── D-pad ─────────────────────────────────────────────────────────────────

  bool _isFocused(int row, int col) =>
      _showControls && _focusRow == row && _focusCol == col;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // Track panel open
    if (_trackPanel != null) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_trackPanelIdx > 0) setState(() => _trackPanelIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_trackPanelIdx < _trackList.length - 1)
          setState(() => _trackPanelIdx++);
      } else if (_isSelectKey(k)) {
        if (_trackList.isNotEmpty) _selectTrack(_trackList[_trackPanelIdx].key);
      } else if (_isBackKey(k) || k == LogicalKeyboardKey.arrowLeft) {
        setState(() => _trackPanel = null);
        _scheduleHide();
      }
      return KeyEventResult.handled;
    }

    // Dead stream: D-pad chooses Retry / Connection Test / Back.
    if (_isDeadStream) {
      if (_isBackKey(k)) {
        _goBack();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_deadActionIdx > 0) setState(() => _deadActionIdx--);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_deadActionIdx < 2) setState(() => _deadActionIdx++);
      } else if (_isSelectKey(k)) {
        _activateDeadAction();
      }
      return KeyEventResult.handled;
    }

    // Loading: Back exits to browse; other keys swallowed.
    if (_isCheckingHealth) {
      if (_isBackKey(k)) {
        _goBack();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Back always leaves the player (do not swallow goBack).
    if (_isBackKey(k)) {
      _goBack();
      return KeyEventResult.handled;
    }

    // Controls hidden: directional / select shows them
    if (!_showControls) {
      setState(() => _showControls = true);
      _scheduleHide();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_focusRow == 1)
        setState(() {
          _focusRow = 0;
          // TV: Back/SUB/AUD (no Cast). Mobile: Back/Cast/SUB/AUD.
          _focusCol = _focusCol.clamp(0, supportsCasting() ? 3 : 2);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusRow == 0)
        setState(() {
          _focusRow = 1;
          _focusCol = _focusCol.clamp(0, 3);
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) setState(() => _focusCol--);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      final maxCol = _focusRow == 0 ? (supportsCasting() ? 3 : 2) : 3;
      if (_focusCol < maxCol) setState(() => _focusCol++);
      _scheduleHide();
    } else if (_isSelectKey(k)) {
      _activate();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _openCastDialog() {
    // TV gate: Cast is phone→TV only.
    if (!supportsCasting()) return;
    _hideTimer?.cancel();
    showDialog(
      context: context,
      builder: (context) => CastSelectionDialog(
        controller: _ctrl,
        currentCastDevice: _castDevice,
        onCastSelected: (device) {
          setState(() {
            _castDevice = device;
          });
        },
      ),
    ).then((_) => _scheduleHide());
  }

  void _activate() {
    if (_focusRow == 0) {
      if (supportsCasting()) {
        switch (_focusCol) {
          case 0:
            _goBack();
          case 1:
            _openCastDialog();
          case 2:
            if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
          case 3:
            if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
        }
      } else {
        // TV chrome: Back, SUB, AUD (Cast removed).
        switch (_focusCol) {
          case 0:
            _goBack();
          case 1:
            if (_subtitleTracks.isNotEmpty) _openTrackPanel('sub');
          case 2:
            if (_audioTracks.isNotEmpty) _openTrackPanel('audio');
        }
      }
    } else {
      switch (_focusCol) {
        case 0:
          _rewind10s();
        case 1:
          _togglePlay();
        case 2:
          _forward10s();
        case 3:
          _cycleAspect();
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  Widget _buildCastOverlay(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(
                Icons.cast_connected_rounded,
                size: 56,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Casting to $_castDevice",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Use your phone as a remote controller",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    _isCastPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isCastPlaying = !_isCastPlaying;
                    });
                    if (_isCastPlaying) {
                      CastMediaService().play();
                    } else {
                      CastMediaService().pause();
                    }
                  },
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    await CastMediaService().disconnect();
                    setState(() {
                      _castDevice = null;
                    });
                    _ctrl.play();
                  },
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text("Disconnect", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack(); // _goBack guards canPop
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final ratio = constraints.maxWidth / constraints.maxHeight;

              return Stack(
                children: [
                  // 1. The Video Player (Always in tree if initialized)
                  if (_ctrlInitialized)
                    VlcPlayer(
                      controller: _ctrl,
                      aspectRatio: ratio,
                      placeholder: const SizedBox(),
                    ),

                  // 2. Gesture Detector to toggle controls
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null)
                    GestureDetector(
                      onTap: _toggleControls,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),

                  // 3. Buffering Indicator
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null && _isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),

                  // 4. Controls Overlay
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null)
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: _buildOverlay(),
                      ),
                    ),

                  // 5. Track Selector Panel
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice == null && _trackPanel != null)
                    _VodTrackPanel(
                      isSub: _trackPanel == 'sub',
                      list: _trackList,
                      focusedIdx: _trackPanelIdx,
                      onSelect: _selectTrack,
                    ),

                  // 6. Loading screen overlay
                  if (_isCheckingHealth)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.topCenter,
                                    radius: 1.3,
                                    colors: [
                                      const Color(0xFF25112F).withValues(alpha: 0.4),
                                      const Color(0xFF08070C),
                                      const Color(0xFF030305),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/tv_parser_logo_transparent.png',
                                    height: 96,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.live_tv_rounded, size: 72, color: Colors.amber),
                                  ),
                                  const SizedBox(height: 28),
                                  const SandTimeclock(size: 36),
                                  const SizedBox(height: 24),
                                  const Text(
                                    "Hold please...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Loading your provider's stream...",
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 7. Dead Stream Overlay (D-pad focusable actions)
                  if (!_isCheckingHealth && _isDeadStream)
                    _DeadStreamOverlay(
                      focusedIdx: _deadActionIdx,
                      onRetry: _retryDeadStream,
                      onConnectionTest: () {
                        Get.to(() => const ConnectionTestScreen());
                      },
                      onBack: _goBack,
                    ),

                  // 8. Chromecast Overlay
                  if (!_isCheckingHealth && !_isDeadStream && supportsCasting() && _castDevice != null)
                    Positioned.fill(
                      child: _buildCastOverlay(context),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        children: [_buildTopBar(), const Spacer(), _buildBottomBar()],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _FsBtn(
              icon: FontAwesomeIcons.chevronLeft.data,
              label: 'Back',
              isFocused: _isFocused(0, 0),
              onTap: _goBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 12),
            // Chromecast — phone/tablet only (not on Android TV / Google TV).
            if (supportsCasting()) ...[
              _FsBtn(
                icon: FontAwesomeIcons.chromecast.data,
                label: 'Cast',
                isFocused: _isFocused(0, 1),
                onTap: _openCastDialog,
              ),
              const SizedBox(width: 8),
            ],
            _FsBtn(
              icon: FontAwesomeIcons.closedCaptioning.data,
              label: 'SUB',
              badge: _subtitleTracks.isNotEmpty
                  ? '${_subtitleTracks.length}'
                  : null,
              isFocused: _isFocused(0, supportsCasting() ? 2 : 1),
              isDisabled: _subtitleTracks.isEmpty,
              onTap: () => _openTrackPanel('sub'),
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.volumeHigh.data,
              label: 'AUD',
              badge: _audioTracks.isNotEmpty ? '${_audioTracks.length}' : null,
              isFocused: _isFocused(0, supportsCasting() ? 3 : 2),
              isDisabled: _audioTracks.isEmpty,
              onTap: () => _openTrackPanel('audio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalMs = _duration.inMilliseconds;
    final pos = totalMs > 0
        ? (_position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _FsBtn(
              icon: FontAwesomeIcons.rotateLeft.data,
              label: '',
              isFocused: _isFocused(1, 0),
              onTap: _rewind10s,
            ),
            SizedBox(width: 8),
            _FsBtn(
              icon: _isPlaying ? FontAwesomeIcons.pause.data : FontAwesomeIcons.play.data,
              label: '',
              isFocused: _isFocused(1, 1),
              isLarge: true,
              onTap: _togglePlay,
            ),
            SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.rotateRight.data,
              label: '',
              isFocused: _isFocused(1, 2),
              onTap: _forward10s,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    _fmt(_position),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: kColorPrimary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: kColorFocus,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 0,
                        ),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: pos,
                        onChanged: (v) async {
                          try {
                            await _ctrl.seekTo(
                              Duration(milliseconds: (v * totalMs).round()),
                            );
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(_duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            _FsBtn(
              icon: FontAwesomeIcons.expand.data,
              label: _kVodAspects[_aspectIdx],
              isFocused: _isFocused(1, 3),
              onTap: _cycleAspect,
            ),
          ],
        ),
      ),
    );
  }
}

class _FsBtn extends StatelessWidget {
  const _FsBtn({
    required this.icon,
    required this.label,
    required this.isFocused,
    required this.onTap,
    this.badge,
    this.isDisabled = false,
    this.isLarge = false,
  });

  final IconData icon;
  final String label;
  final bool isFocused;
  final VoidCallback onTap;
  final String? badge;
  final bool isDisabled;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDisabled
        ? Colors.white24
        : isFocused
        ? Colors.white
        : Colors.white70;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isLarge ? 16 : 12,
              vertical: isLarge ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: isFocused
                  ? kColorPrimary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFocused
                    ? kColorFocus
                    : Colors.white.withValues(alpha: isDisabled ? 0.1 : 0.2),
                width: isFocused ? 1.5 : 1,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: kColorFocus.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(icon, size: isLarge ? 18 : 14, color: baseColor),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: TextStyle(
                      color: baseColor,
                      fontSize: isLarge ? 13 : 11,
                      fontWeight: isFocused
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -7,
              right: -7,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: kColorPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

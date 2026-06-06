part of '../screens.dart';

// ─── Series Player ────────────────────────────────────────────────────────────
// Full-screen VOD player for series episodes.
// Prev/Next episode navigation row above the main controls.
// Saves watch progress to WatchingCubit on episode change and on back.
//
// D-pad focus layout:
//   Row 0 (top bar):     0=Back  1=SUB  2=AUD
//   Row 1 (episode nav): 0=Prev  1=Next
//   Row 2 (bottom bar):  0=-10s  1=Play  2=Aspect

class SeriesPlayerScreen extends StatefulWidget {
  const SeriesPlayerScreen({
    super.key,
    required this.episodes,
    required this.initialIdx,
    required this.serverUrl,
    required this.username,
    required this.password,
    this.seriesCover = '',
  });

  final List<Episode> episodes;
  final int initialIdx;
  final String serverUrl;
  final String username;
  final String password;
  final String seriesCover;

  @override
  State<SeriesPlayerScreen> createState() => _SeriesPlayerScreenState();
}

class _SeriesPlayerScreenState extends State<SeriesPlayerScreen> {
  late VlcPlayerController _ctrl;
  bool _ctrlInitialized = false;
  bool _isCheckingHealth = true;
  bool _isDeadStream = false;
  late int _epIdx;

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

  // D-pad: 3 rows — 0=top, 1=episode nav, 2=bottom
  int _focusRow = 2;
  int _focusCol = 1; // default: Play
  final _focusNode = FocusNode();
  final Stopwatch _stopwatch = Stopwatch();

  Episode get _currentEp => widget.episodes[_epIdx];

  String get _currentUrl => PlaybackUrlBuilder.buildSeriesUrlSync(
        serverUrl: widget.serverUrl,
        username: widget.username,
        password: widget.password,
        episodeId: _currentEp.id ?? '',
        containerExtension: _currentEp.containerExtension,
      );

  List<MapEntry<int, String>> get _trackList =>
      (_trackPanel == 'sub' ? _subtitleTracks : _audioTracks).entries.toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _epIdx = widget.initialIdx;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (_ctrlInitialized) {
      try {
        _ctrl.removeListener(_onVlc);
        await _ctrl.stopRendererScanning();
        await _ctrl.dispose();
      } catch (_) {}
      _ctrlInitialized = false;
    }

    // [TV_PARSER_PERF] Bypass blocking pre-playback health checks to initialize VLC player instantly.
    // This aligns with MoviePlayerScreen and LivePlayerScreen designs and avoids false negatives.
    final buffers = getStreamQualityBuffers(isLive: false);
    _ctrl = VlcPlayerController.network(
      _currentUrl,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(buffers["network"]!),
          VlcAdvancedOptions.liveCaching(buffers["live"]!),
          VlcAdvancedOptions.fileCaching(buffers["file"]!),
        ]),
      ),
    );
    _ctrl.addListener(_onVlc);
    OrientationGuard.applyPlayerOrientation();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHide();
    setState(() {
      _ctrlInitialized = true;
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
        if (_ctrl.value.isInitialized) {
          _ctrl.dispose().catchError((_) {});
        }
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
    if (v.hasError && !_isDeadStream) {
      debugPrint("[TV_PARSER_PERF] SeriesPlayerScreen: Player error detected");
      setState(() {
        _isDeadStream = true;
        _isCheckingHealth = false;
      });
    }
    if (v.isInitialized && _isCheckingHealth && !v.isBuffering) {
      setState(() {
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

  void _saveProgress() {
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    if (pos <= 0) return;
    final ep = _currentEp;
    context.read<WatchingCubit>().addSerie(
      WatchingModel(
        sliderValue: pos,
        durationStrm: dur,
        stream: _currentUrl,
        title: ep.title ?? 'Episode ${_epIdx + 1}',
        image: ep.info?.movieImage ?? widget.seriesCover,
        streamId: ep.id.toString(),
      ),
    );
  }

  Future<void> _switchEpisode(int newIdx) async {
    if (newIdx < 0 || newIdx >= widget.episodes.length) return;
    _saveProgress();
    final newEp = widget.episodes[newIdx];
    final newUrl = PlaybackUrlBuilder.buildSeriesUrlSync(
      serverUrl: widget.serverUrl,
      username: widget.username,
      password: widget.password,
      episodeId: newEp.id ?? '',
      containerExtension: newEp.containerExtension,
    );

    setState(() {
      _epIdx = newIdx;
      _isBuffering = true;
      _isDeadStream = false; // Reset dead stream state for new episode
      _isCheckingHealth = true; // Reset checking health state for new episode
      _tracksLoaded = false;
      _audioTracks = {};
      _subtitleTracks = {};
      _trackPanel = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _aspectIdx = 0;
    });
    _stopwatch.reset();
    _stopwatch.start();
    try {
      await _ctrl.setMediaFromNetwork(
        newUrl,
        autoPlay: true,
        hwAcc: HwAcc.auto,
      );
    } catch (_) {}
    _scheduleHide();
  }

  void _goBack() {
    _saveProgress();
    Get.back();
  }

  // ── D-pad ─────────────────────────────────────────────────────────────────

  bool _isFocused(int row, int col) =>
      _showControls && _focusRow == row && _focusCol == col;

  int _maxColForRow(int row) => row == 1 ? 1 : (row == 0 ? 3 : 3);

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
      } else if (k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.arrowLeft) {
        setState(() => _trackPanel = null);
        _scheduleHide();
      }
      return KeyEventResult.handled;
    }

    // Controls hidden: any key shows them
    if (!_showControls) {
      setState(() => _showControls = true);
      _scheduleHide();
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_focusRow > 0)
        setState(() {
          _focusRow--;
          _focusCol = _focusCol.clamp(0, _maxColForRow(_focusRow));
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusRow < 2)
        setState(() {
          _focusRow++;
          _focusCol = _focusCol.clamp(0, _maxColForRow(_focusRow));
        });
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) setState(() => _focusCol--);
      _scheduleHide();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (_focusCol < _maxColForRow(_focusRow)) setState(() => _focusCol++);
      _scheduleHide();
    } else if (_isSelectKey(k)) {
      _activate();
    } else if (k == LogicalKeyboardKey.escape) {
      _goBack();
    }
    return KeyEventResult.handled;
  }

  void _openCastDialog() {
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
    } else if (_focusRow == 1) {
      switch (_focusCol) {
        case 0:
          if (_epIdx > 0) _switchEpisode(_epIdx - 1);
        case 1:
          if (_epIdx < widget.episodes.length - 1) _switchEpisode(_epIdx + 1);
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
        if (!didPop) _goBack();
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

                  // 7. Dead Stream Overlay
                  if (!_isCheckingHealth && _isDeadStream)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.9),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 54),
                                const SizedBox(height: 16),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    "This stream is temporarily unavailable. Try another source or run Connection Test.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size(180, 40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isDeadStream = false;
                                      _isCheckingHealth = true;
                                      _ctrlInitialized = false;
                                    });
                                    _initPlayer();
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text("Try Again", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(180, 40),
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () {
                                    Get.to(() => const ConnectionTestScreen());
                                  },
                                  icon: const Icon(Icons.network_check_rounded, size: 16),
                                  label: const Text("Connection Test", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _goBack,
                                  child: const Text("Go Back", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 8. Chromecast Overlay
                  if (!_isCheckingHealth && !_isDeadStream && _castDevice != null)
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
        children: [
          _buildTopBar(),
          const Spacer(),
          _buildEpisodeNavRow(),
          const SizedBox(height: 8),
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
              onTap: _goBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentEp.title ?? 'Episode ${_epIdx + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Episode ${_epIdx + 1} of ${widget.episodes.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            // Chromecast
            _FsBtn(
              icon: FontAwesomeIcons.chromecast.data,
              label: 'Cast',
              isFocused: _isFocused(0, 1),
              onTap: _openCastDialog,
            ),
            const SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.closedCaptioning.data,
              label: 'SUB',
              badge: _subtitleTracks.isNotEmpty
                  ? '${_subtitleTracks.length}'
                  : null,
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

  Widget _buildEpisodeNavRow() {
    final hasPrev = _epIdx > 0;
    final hasNext = _epIdx < widget.episodes.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FsBtn(
            icon: FontAwesomeIcons.chevronLeft.data,
            label: 'Prev',
            isFocused: _isFocused(1, 0),
            isDisabled: !hasPrev,
            onTap: hasPrev ? () => _switchEpisode(_epIdx - 1) : () {},
          ),
          const Spacer(),
          Text(
            'Episode ${_epIdx + 1} / ${widget.episodes.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _FsBtn(
            icon: FontAwesomeIcons.chevronRight.data,
            label: 'Next',
            isFocused: _isFocused(1, 1),
            isDisabled: !hasNext,
            onTap: hasNext ? () => _switchEpisode(_epIdx + 1) : () {},
          ),
        ],
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
              isFocused: _isFocused(2, 0),
              onTap: _rewind10s,
            ),
            SizedBox(width: 8),
            _FsBtn(
              icon: _isPlaying ? FontAwesomeIcons.pause.data : FontAwesomeIcons.play.data,
              label: '',
              isFocused: _isFocused(2, 1),
              isLarge: true,
              onTap: _togglePlay,
            ),
            SizedBox(width: 8),
            _FsBtn(
              icon: FontAwesomeIcons.rotateRight.data,
              label: '',
              isFocused: _isFocused(2, 2),
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
              isFocused: _isFocused(2, 3),
              onTap: _cycleAspect,
            ),
          ],
        ),
      ),
    );
  }
}

part of 'screens.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _showOverlay = true;
  double _progress = 0.0;
  Timer? _hardDismissTimer;
  late final DateTime _overlayDeadline;

  late AnimationController _fadeController;
  late AnimationController _progressController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<FavoritesCubit>().initialData();
    context.read<WatchingCubit>().initialData();
    // Wall-clock deadline so screensaver/pause cannot keep this card up.
    _overlayDeadline = DateTime.now().add(const Duration(seconds: 3));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addListener(() {
        setState(() {
          _progress = _progressController.value;
        });
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);

    _progressController.forward();

    Future.delayed(const Duration(milliseconds: 2500)).then((_) {
      if (mounted) _dismissOverlay(fade: true);
    });

    _hardDismissTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      if (!_showOverlay) {
        _hardDismissTimer?.cancel();
        return;
      }
      if (!DateTime.now().isBefore(_overlayDeadline)) {
        _dismissOverlay(fade: false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showOverlay) {
      // Never return from screensaver still trapping Live behind Hold please.
      if (!DateTime.now().isBefore(_overlayDeadline)) {
        _dismissOverlay(fade: false);
      }
    }
  }

  void _dismissOverlay({required bool fade}) {
    if (!mounted || !_showOverlay) return;
    _hardDismissTimer?.cancel();
    if (!fade) {
      setState(() => _showOverlay = false);
      LiveBrowseGate.markWelcomeCleared();
      return;
    }
    _fadeController.forward().then((_) {
      if (mounted && _showOverlay) {
        setState(() => _showOverlay = false);
      }
      LiveBrowseGate.markWelcomeCleared();
    });
    Future.delayed(const Duration(milliseconds: 400)).then((_) {
      if (mounted && _showOverlay) {
        setState(() => _showOverlay = false);
      }
      LiveBrowseGate.markWelcomeCleared();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hardDismissTimer?.cancel();
    _fadeController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _getStatusText() {
    if (_progress < 0.25) {
      return "Connecting to secure media gateway...";
    } else if (_progress < 0.55) {
      return "Parsing playlist headers & credentials...";
    } else if (_progress < 0.85) {
      return "Synchronizing buffer stream pipelines...";
    } else {
      return "Ready! Launching dashboard interface...";
    }
  }

  void _showTvAdultPinDialog(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        title: const Text(
          "Adult Content Locked",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter PIN to unlock 18+ channels.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                autofocus: true,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  hintText: "Enter PIN",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1E1A30),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              pinController.dispose();
              Navigator.of(dialogCtx).pop();
            },
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin == ProviderCurationRules.adultUnlockPin) {
                pinController.dispose();
                Navigator.of(dialogCtx).pop();
                Get.toNamed(screenAdultContent);
              } else {
                pinController.dispose();
                Navigator.of(dialogCtx).pop();
                Get.snackbar(
                  'Access Denied',
                  'Incorrect PIN.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFF2D0A0A),
                  colorText: Colors.white,
                );
              }
            },
            child: const Text(
              "Unlock",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget dashboardChild;
    if (isTv(context)) {
      dashboardChild = TvDashboardShell(
        onChannelSelected: (url) {
          if (url == "adult_locked") {
            _showTvAdultPinDialog(context);
          } else {
            final extractedStreamId = extractStreamIdFromUrl(url);
            // Preserve the actual Live record when crossing the URL-only shell
            // callback so fullscreen Favorites can persist the real channel id,
            // title, and logo instead of silently no-oping on M3U URLs.
            ChannelLive? selectedLive;
            if (isLikelyLiveStreamUrl(url)) {
              for (final ch in IptvProviderSession.instance.liveChannels()) {
                final direct = ch.directSource?.trim();
                final id = ch.streamId?.trim();
                if (direct == url ||
                    (extractedStreamId != null && id == extractedStreamId)) {
                  selectedLive = ch;
                  break;
                }
              }
              final selectedId = selectedLive?.streamId?.trim();
              final effectiveStreamId =
                  (selectedId != null && selectedId.isNotEmpty)
                      ? selectedId
                      : (extractedStreamId ?? url);
              final selectedName = selectedLive?.name?.trim();
              Get.to(
                () => LivePlayerScreen(
                  link: url,
                  title: (selectedName != null && selectedName.isNotEmpty)
                      ? selectedName
                      : 'TV Stream',
                  streamIcon: selectedLive?.streamIcon,
                  streamId: effectiveStreamId,
                ),
              );
            } else {
              Get.to(() => MoviePlayerScreen(link: url, title: 'TV Stream'));
            }
          }
        },
      );
    } else {
      dashboardChild = const MobileWatchScreen();
    }

    return Stack(
      children: [
        dashboardChild,
        if (_showOverlay)
          AnimatedBuilder(
            animation: _fadeController,
            builder: (context, _) {
              final opacity = 1.0 - _fadeController.value;
              if (opacity <= 0.0) return const SizedBox();

              return Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) => KeyEventResult.handled,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Glassmorphic background blur
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 12.0 * opacity,
                            sigmaY: 12.0 * opacity,
                          ),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.65 * opacity),
                          ),
                        ),
                        // Cinematic Center Popup Card
                        Center(
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: isTv(context) ? 450.0 : 320.0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 30,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0A1628),
                                    Color(0xFF050A18),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: kColorPrimary.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kColorPrimary.withValues(alpha: 0.18),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Pulsing TV Stream Icon
                                  ScaleTransition(
                                    scale: _pulseController,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: kColorPrimary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: kColorPrimary.withValues(alpha: 0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.live_tv_rounded,
                                        color: kColorPrimary,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // "Hold please..." title
                                  const Text(
                                    "Hold please...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Subtitle with exact requested copy
                                  const Text(
                                    "Loading your Live TV library…\nChannels appear as soon as they are ready",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  // Sleek premium progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      height: 6,
                                      width: double.infinity,
                                      color: Colors.white.withValues(alpha: 0.08),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: _progress,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  kColorPrimaryDark,
                                                  kColorPrimary,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Animated Status Loader Info Text
                                  Text(
                                    _getStatusText(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

part of '../screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _holdColor = Color(0xFF0F0F10);

  VideoPlayerController? _controller;
  bool _videoInitialized = false;
  bool _videoCompleted = false;
  bool _exiting = false;
  bool _navigated = false;
  String? _nextScreenTarget;

  void _checkNavigation() {
    if (_navigated) return;
    if (!_videoCompleted || _nextScreenTarget == null) return;
    _navigated = true;
    // Cover the last decoded frame with black before the route swap.
    if (mounted && !_exiting) {
      setState(() => _exiting = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      OrientationGuard.applyDeviceOrientation();
      Get.offAndToNamed(_nextScreenTarget!);
    });
  }

  void _markVideoDone() {
    if (!mounted || _videoCompleted) return;
    _controller?.pause();
    setState(() {
      _videoCompleted = true;
      _exiting = true;
    });
    _checkNavigation();
  }

  bool _isVideoFinished() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return false;
    final d = c.value.duration;
    if (d <= Duration.zero) return false;
    final p = c.value.position;
    return p >= d ||
        (!c.value.isPlaying && p >= d - const Duration(milliseconds: 120));
  }

  @override
  void initState() {
    super.initState();
    // Edge-to-edge for splash: no status/nav inset shrinking the reel.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OrientationGuard.init();
      context.read<SettingsCubit>().getSettingsCode();
      context.read<AuthBloc>().add(AuthGetUser());
    });

    // CRITICAL: DO NOT TOUCH THIS SPLASH SCREEN VIDEO PATH EVER. HARDCODED REQUIREMENT.
    _controller = VideoPlayerController.asset('assets/images/splash_video.mp4');
    _controller!.setLooping(false);
    _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _videoInitialized = true;
          });
          _controller?.play();
        }
      }).catchError((e) {
        debugPrint("Splash video player load error: $e");
        _markVideoDone();
      });

    _controller?.addListener(() {
      if (_isVideoFinished()) {
        _markVideoDone();
      }
    });

    // Last-resort hang guard only — must outlast the reel (was 5s and cut it off).
    Future.delayed(const Duration(seconds: 20)).then((_) {
      _markVideoDone();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _holdColor,
      body: OrientationBuilder(
        builder: (context, orientation) {
          return BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthSuccess) {
                context.read<LiveCatyBloc>().add(GetLiveCategories());
                context.read<MovieCatyBloc>().add(GetMovieCategories());
                // Series categories are an independent pipeline — not a VOD gate.
                Future<void>.microtask(() {
                  if (!context.mounted) return;
                  context.read<SeriesCatyBloc>().add(GetSeriesCategories());
                });
                _nextScreenTarget = screenWelcome;
                _checkNavigation();
              } else if (state is AuthFailed) {
                if (isTv(context)) {
                  _nextScreenTarget = screenRegisterTv;
                } else {
                  _nextScreenTarget = screenIntro;
                }
                _checkNavigation();
              }
            },
            child: (_videoInitialized && !_exiting && _controller != null)
                ? _SplashVideoFrame(controller: _controller!)
                : const ColoredBox(color: _holdColor),
          );
        },
      ),
    );
  }
}

/// Full-bleed splash: cover-scale so the reel fills the entire screen.
/// No 90% overscan shrink / contain letterboxing — edge-to-edge cover only.
class _SplashVideoFrame extends StatelessWidget {
  const _SplashVideoFrame({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final videoSize = controller.value.size;
    final videoW = videoSize.width == 0 ? 1920.0 : videoSize.width;
    final videoH = videoSize.height == 0 ? 1080.0 : videoSize.height;

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: ColoredBox(
        color: const Color(0xFF0F0F10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;
            final scaleW = screenW / videoW;
            final scaleH = screenH / videoH;
            final scale = scaleW > scaleH ? scaleW : scaleH;
            final drawnW = videoW * scale;
            final drawnH = videoH * scale;

            return ClipRect(
              child: OverflowBox(
                minWidth: drawnW,
                maxWidth: drawnW,
                minHeight: drawnH,
                maxHeight: drawnH,
                alignment: Alignment.center,
                child: SizedBox(
                  width: drawnW,
                  height: drawnH,
                  child: VideoPlayer(controller),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


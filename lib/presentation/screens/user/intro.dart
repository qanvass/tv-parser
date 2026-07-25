part of '../screens.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final FocusNode _getStartedFocusNode = FocusNode(
    debugLabel: 'IntroGetStarted',
  );

  @override
  void dispose() {
    _getStartedFocusNode.dispose();
    super.dispose();
  }

  void _goToRegister() {
    if (isTv(context)) {
      Get.toNamed(screenRegisterTv);
    } else {
      Get.toNamed(screenRegister);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: kDecorBackground,
        child: Column(
          children: [
            // ── Hero image with overlays ─────────────────────────────
            Expanded(
              flex: 5,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const _IntroHero(),

                    // Dark overlay at top (covers notch area)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [kColorBackDark, Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // Gradient fade into background at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 160,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, kColorBackDark],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feature pills
                    Row(
                      children: [
                        _FeaturePill(
                          icon: FontAwesomeIcons.tv.data,
                          label: 'Live TV',
                        ),
                        SizedBox(width: 8),
                        _FeaturePill(
                          icon: FontAwesomeIcons.film.data,
                          label: 'Movies',
                        ),
                        SizedBox(width: 8),
                        _FeaturePill(
                          icon: FontAwesomeIcons.clapperboard.data,
                          label: 'Series',
                        ),
                      ],
                    ),

                    SizedBox(height: 1.5.h),

                    Text(
                      'Your media,\nyour way.',
                      style: Get.textTheme.headlineLarge!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22.sp,
                        height: 1.25,
                      ),
                    ),

                    SizedBox(height: 1.h),

                    Text(
                      'Connect an authorized playlist or provider account.',
                      style: Get.textTheme.bodyMedium!.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.5,
                      ),
                    ),

                    const Spacer(),

                    // Get Started button — focusable so a D-pad/remote
                    // (no touchscreen) can reach and activate it.
                    Focus(
                      focusNode: _getStartedFocusNode,
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        final k = event.logicalKey;
                        if (k == LogicalKeyboardKey.select ||
                            k == LogicalKeyboardKey.enter ||
                            k == LogicalKeyboardKey.numpadEnter ||
                            k == LogicalKeyboardKey.space) {
                          _goToRegister();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(
                        builder: (context) {
                          final isFocused = Focus.of(context).hasFocus;
                          return GestureDetector(
                            onTap: _goToRegister,
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kColorPrimary, kColorPrimaryDark],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: isFocused
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: kColorPrimary.withValues(
                                      alpha: isFocused ? 0.75 : 0.45,
                                    ),
                                    blurRadius: isFocused ? 30 : 22,
                                    spreadRadius: isFocused ? 2 : 1,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    FontAwesomeIcons.arrowRight.data,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroHero extends StatelessWidget {
  const _IntroHero();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF35105E), Color(0xFF14101F), Color(0xFF07070B)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -80,
            top: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kColorPrimary.withValues(alpha: 0.18),
                boxShadow: [
                  BoxShadow(
                    color: kColorPrimary.withValues(alpha: 0.28),
                    blurRadius: 100,
                    spreadRadius: 28,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Image.asset(
                kIconLogoTransparent,
                fit: BoxFit.contain,
                semanticLabel: 'TV Parser',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: kColorPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kColorPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: kColorPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

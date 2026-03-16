part of '../screens.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

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
                    const IntroImageAnimated(),

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
                          icon: FontAwesomeIcons.tv,
                          label: 'Live TV',
                        ),
                        const SizedBox(width: 8),
                        _FeaturePill(
                          icon: FontAwesomeIcons.film,
                          label: 'Movies',
                        ),
                        const SizedBox(width: 8),
                        _FeaturePill(
                          icon: FontAwesomeIcons.clapperboard,
                          label: 'Series',
                        ),
                      ],
                    ),

                    SizedBox(height: 1.5.h),

                    Text(
                      'Watch anything,\nanywhere.',
                      style: Get.textTheme.headlineLarge!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22.sp,
                        height: 1.25,
                      ),
                    ),

                    SizedBox(height: 1.h),

                    Text(
                      'Live TV, movies and series — all in one place.',
                      style: Get.textTheme.bodyMedium!.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.5,
                      ),
                    ),

                    const Spacer(),

                    // Get Started button
                    GestureDetector(
                      onTap: () => Get.toNamed(screenRegister),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kColorPrimary, kColorPrimaryDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: kColorPrimary.withValues(alpha: 0.45),
                              blurRadius: 22,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
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
                              FontAwesomeIcons.arrowRight,
                              color: Colors.white,
                              size: 13,
                            ),
                          ],
                        ),
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

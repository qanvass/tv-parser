import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';
import '../../tv/cinematic/cinematic_tokens.dart';

/// Premium TV Parser overlay shown while a stream is opening.
/// Visual-only: callers keep their own show/hide timing.
class TvParserStreamLoadingOverlay extends StatefulWidget {
  const TvParserStreamLoadingOverlay({
    super.key,
    this.title = 'Preparing your stream',
    this.subtitle = 'TV Parser is connecting to your provider',
    this.logoAssetPath = kIconLogoTransparent,
    this.showIndicator = true,
    this.footer,
  });

  final String title;
  final String subtitle;
  final String logoAssetPath;
  final bool showIndicator;
  final Widget? footer;

  @override
  State<TvParserStreamLoadingOverlay> createState() =>
      _TvParserStreamLoadingOverlayState();
}

class _TvParserStreamLoadingOverlayState
    extends State<TvParserStreamLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (cinematicLowPower(context)) {
      _pulse
        ..stop()
        ..value = 0.65;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).shortestSide >= 600;
    final logoHeight = wide ? 136.0 : 108.0;

    return ColoredBox(
      color: const Color(0xFF070709),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.18),
                radius: 1.05,
                colors: [
                  Color(0xFF1A1A20),
                  Color(0xFF0B0B0E),
                  Color(0xFF050506),
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LogoLockup(
                      pulse: _pulse,
                      assetPath: widget.logoAssetPath,
                      height: logoHeight,
                    ),
                    const SizedBox(height: 36),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CinematicTokens.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CinematicTokens.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.15,
                        height: 1.45,
                      ),
                    ),
                    if (widget.showIndicator) ...[
                      const SizedBox(height: 28),
                      _ElegantDots(animation: _pulse),
                    ],
                    if (widget.footer != null) ...[
                      const SizedBox(height: 32),
                      widget.footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoLockup extends StatelessWidget {
  const _LogoLockup({
    required this.pulse,
    required this.assetPath,
    required this.height,
  });

  final Animation<double> pulse;
  final String assetPath;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final glow = 0.06 + (0.05 * pulse.value);
        return Container(
          width: height * 2.15,
          height: height * 1.55,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                CinematicTokens.accent.withValues(alpha: glow),
                const Color(0x00070709),
              ],
            ),
          ),
          child: child,
        );
      },
      child: Image.asset(
        assetPath,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.tv_rounded,
          size: height * 0.62,
          color: CinematicTokens.accent,
        ),
      ),
    );
  }
}

class _ElegantDots extends StatelessWidget {
  const _ElegantDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (i) {
            final phase = (animation.value + (i * 0.28)) % 1.0;
            final opacity =
                0.22 + (0.7 * (1 - ((phase - 0.5).abs() * 2)).clamp(0.0, 1.0));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CinematicTokens.accent.withValues(alpha: opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

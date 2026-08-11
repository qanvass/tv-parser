import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';

/// Soft gradient pulse used while poster / backdrop bytes load.
/// Never leaves a pitch-black empty card.
class TvArtworkShimmer extends StatefulWidget {
  final BorderRadius? borderRadius;

  const TvArtworkShimmer({super.key, this.borderRadius});

  @override
  State<TvArtworkShimmer> createState() => _TvArtworkShimmerState();
}

class _TvArtworkShimmerState extends State<TvArtworkShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.2 + t * 2.4, -0.4),
              end: Alignment(-0.2 + t * 2.4, 0.6),
              colors: const [
                Color(0xFF121C2C),
                Color(0xFF1C2A42),
                Color(0xFF0C1522),
              ],
            ),
          ),
          child: ColoredBox(
            color: kColorPrimary.withValues(alpha: 0.04 + 0.04 * (1 - t)),
          ),
        );
      },
    );
  }
}

/// Last-resort VOD fill — dark gradient, no giant teal letter.
class TvPosterFallbackGradient extends StatelessWidget {
  const TvPosterFallbackGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF121C2C),
            Color(0xFF070D16),
            Color(0xFF0A1420),
          ],
        ),
      ),
    );
  }
}

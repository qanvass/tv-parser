import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';

/// Branded empty pane — TV Parser mark + copy. No fake posters.
class TvBrandedEmpty extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? extra;
  final IconData icon;

  const TvBrandedEmpty({
    super.key,
    required this.title,
    required this.subtitle,
    this.extra,
    this.icon = Icons.sensors_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TvParserMark(icon: icon),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (extra != null) ...[
                const SizedBox(height: 22),
                extra!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TvParserMark extends StatelessWidget {
  final IconData icon;
  const _TvParserMark({this.icon = Icons.sensors_rounded});

  @override
  Widget build(BuildContext context) {
    final heart = icon == Icons.favorite_rounded;
    return Container(
      width: heart ? 112 : 88,
      height: heart ? 112 : 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: heart
              ? [
                  const Color(0x55FF4D6D),
                  const Color(0xFF050A18),
                ]
              : [
                  kColorPrimary.withValues(alpha: 0.28),
                  const Color(0xFF050A18),
                ],
        ),
        border: Border.all(
          color: heart ? const Color(0xFFFF4D6D) : kColorPrimary.withValues(alpha: 0.5),
          width: heart ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: heart
                ? const Color(0xAAFF4D6D)
                : kColorPrimary.withValues(alpha: 0.35),
            blurRadius: heart ? 36 : 22,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: heart ? const Color(0xFFFF4D6D) : kColorPrimary,
        size: heart ? 48 : 36,
      ),
    );
  }
}

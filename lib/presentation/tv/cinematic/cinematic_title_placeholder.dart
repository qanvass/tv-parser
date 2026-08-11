import 'package:flutter/material.dart';

import 'cinematic_tokens.dart';

/// Title-hashed cinematic fill. Never a flat black rectangle.
/// Hue is stable for a title so adjacent cards do not look identical.
class CinematicTitlePlaceholder extends StatelessWidget {
  final String title;
  final bool hero;

  const CinematicTitlePlaceholder({
    super.key,
    required this.title,
    this.hero = false,
  });

  static int hueFor(String title) {
    var hash = 0;
    for (final unit in title.toLowerCase().trim().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % 360;
  }

  static List<Color> colorsFor(String title) {
    final hue = hueFor(title).toDouble();
    final a = HSLColor.fromAHSL(1, hue, 0.34, 0.16).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 38) % 360, 0.28, 0.09).toColor();
    final c = HSLColor.fromAHSL(1, (hue + 72) % 360, 0.22, 0.13).toColor();
    return [a, b, c];
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(title);
    final label = title.trim().isEmpty ? 'Movie' : title.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: hero ? 0.06 : 0.04),
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              hero ? 22 : 10,
              hero ? 22 : 10,
              hero ? 22 : 10,
              hero ? 22 : 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    'MOVIE',
                    style: TextStyle(
                      color: CinematicTokens.textSecondary
                          .withValues(alpha: 0.95),
                      fontSize: hero ? 11 : 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  label,
                  maxLines: hero ? 3 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CinematicTokens.textPrimary
                        .withValues(alpha: 0.92),
                    fontSize: hero ? 28 : 13,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

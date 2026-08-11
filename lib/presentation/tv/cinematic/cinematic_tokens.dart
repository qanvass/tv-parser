import 'package:flutter/material.dart';

/// Single cinematic palette. Movies chrome must not invent extra blues.
abstract final class CinematicTokens {
  static const Color background = Color(0xFF0B0B0E);
  static const Color surface = Color(0xFF16161C);
  static const Color focus = Color(0xFFF2F2F5);
  static const Color textPrimary = Color(0xFFF7F7F8);
  static const Color textSecondary = Color(0xFFB8B8C0);
  static const Color accent = Color(0xFFE8ECF0);
  static const Color danger = Color(0xFFE11D2E);

  static const double radiusPoster = 10;
  static const double radiusChip = 14;
  static const double radiusStadium = 999;

  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  static const double focusScale = 1.08;

  static const Color glassFill = Color(0x24FFFFFF);
  static const Color glassFillStrong = Color(0x38FFFFFF);
  static const Color glassBorder = Color(0x38FFFFFF);

  static const Color scrimLeft = Color(0xE60B0B0E);
  static const Color scrimMid = Color(0x990B0B0E);
  static const Color scrimClear = Color(0x000B0B0E);
  static const Color scrimBottom = Color(0xF20B0B0E);
}

abstract final class CinematicMotion {
  static const Duration focus = Duration(milliseconds: 180);
  static const Duration backdrop = Duration(milliseconds: 350);
  static const Duration heroText = Duration(milliseconds: 250);
  static const Duration navCollapse = Duration(milliseconds: 220);
  static const Duration previewFade = Duration(milliseconds: 300);

  static const Duration artDebounce = Duration(milliseconds: 0);
  static const Duration trailerDebounce = Duration(milliseconds: 1100);
  static const Duration kenBurns = Duration(seconds: 22);

  static const Curve standard = Curves.easeOutCubic;
}

bool cinematicLowPower(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context);
}

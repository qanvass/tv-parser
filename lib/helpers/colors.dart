part of 'helpers.dart';

// Cinematic TV shell: midnight navy + electric cyan (mockup tokens).
const Color kColorPrimary = Color(0xFF00A3FF);
const Color kColorPrimaryDark = Color(0xFF0077CC);
const Color kColorPrimarySoft = Color(0xFF00D2FF);

const Color kColorFocus = Color(0xFF00D2FF);
const Color kColorAccentWarm = Color(0xFFFFC857);

const Color kColorBack = Color(0xFF0A0E14);
const Color kColorBackDark = Color(0xFF050A18);
const Color kColorBackMid = Color(0xFF0A1220);

const Color kColorCardLight = Color(0xFF121A28);
const Color kColorCardDark = Color(0xFF161E2E);
const Color kColorCardDarkness = Color(0xFF080C14);
const Color kColorGlass = Color(0xFF101826);

const Color kColorHint = Color(0xFF8B9BB8);
const Color kColorHintGrey = Color(0xFF6B7A94);
const Color kColorFontLight = Color(0xFFFFFFFF);

BoxDecoration kDecorBackground = const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050A18),
      Color(0xFF0A0E14),
      Color(0xFF0C1424),
      Color(0xFF050810),
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  ),
);

BoxDecoration kDecorGlassPanel = BoxDecoration(
  color: const Color(0xCC0A0E14),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ],
);

BoxDecoration kDecorIconCircle = const BoxDecoration(
  shape: BoxShape.circle,
  gradient: LinearGradient(
    colors: [kColorPrimaryDark, kColorPrimary],
  ),
);

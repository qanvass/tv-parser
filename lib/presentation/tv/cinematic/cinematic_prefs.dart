import 'package:get_storage/get_storage.dart';

enum HeroPreviewMode {
  off,
  muted,
  sound,
}

/// Browse-hero preview. Default is muted. Never requires sound.
class CinematicPrefs {
  static const _boxName = 'preferences';
  static const _key = 'tv_hero_preview_mode';

  static GetStorage get _box => GetStorage(_boxName);

  static HeroPreviewMode mode() {
    switch (_box.read(_key)?.toString()) {
      case 'off':
        return HeroPreviewMode.off;
      case 'sound':
        return HeroPreviewMode.sound;
      default:
        return HeroPreviewMode.muted;
    }
  }

  static void setMode(HeroPreviewMode mode) {
    _box.write(_key, mode.name);
  }

  static HeroPreviewMode cycle() {
    final next = switch (mode()) {
      HeroPreviewMode.muted => HeroPreviewMode.sound,
      HeroPreviewMode.sound => HeroPreviewMode.off,
      HeroPreviewMode.off => HeroPreviewMode.muted,
    };
    setMode(next);
    return next;
  }

  static String label(HeroPreviewMode mode) {
    switch (mode) {
      case HeroPreviewMode.off:
        return 'Off';
      case HeroPreviewMode.muted:
        return 'On (muted)';
      case HeroPreviewMode.sound:
        return 'On with sound';
    }
  }
}

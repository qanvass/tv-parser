part of 'helpers.dart';

class OrientationGuard {
  static const String _storageKey = 'allowMobileLandscape';
  static final _box = GetStorage("preferences");

  static bool _isTv = false;
  static bool get isTv => _isTv;

  /// Read the current setting (default: false)
  static bool get allowMobileLandscape {
    return _box.read<bool>(_storageKey) ?? false;
  }

  /// Lock mobile to portraitUp on boot, and TV to landscape.
  static Future<void> init() async {
    // Check native method channel first for TV status
    try {
      final bool? result = await const MethodChannel(
        "main_activity_channel",
      ).invokeMethod<bool>("isTvDevice");
      _isTv = result ?? false;
    } catch (_) {
      _isTv = _detectIsTvFallback();
    }

    if (_isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      debugPrint(
        '[OrientationGuard] BOOT platform=tv allowMobileLandscape=false applied=landscape',
      );
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      debugPrint('[OrientationGuard] BOOT mobile forced portraitUp');
      debugPrint(
        '[OrientationGuard] allowMobileLandscape=false applied=portraitUp',
      );
    }
  }

  /// Fallback checks to distinguish mobile from TV/Tablet using shortest dimension.
  static bool _detectIsTvFallback() {
    try {
      final view = PlatformDispatcher.instance.views.first;
      final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
      final logicalHeight = view.physicalSize.height / view.devicePixelRatio;
      final minDim = logicalWidth < logicalHeight
          ? logicalWidth
          : logicalHeight;
      return minDim > 600;
    } catch (_) {
      return false;
    }
  }

  /// Apply correct orientations based on whether it is a TV or mobile device settings.
  static void applyDeviceOrientation() {
    if (_isTv) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      if (allowMobileLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        debugPrint(
          '[OrientationGuard] allowMobileLandscape=true applied=portrait+landscape',
        );
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        debugPrint(
          '[OrientationGuard] allowMobileLandscape=false applied=portraitUp',
        );
      }
    }
  }

  /// Persist the setting and update device orientations immediately.
  static Future<void> setAllowLandscape(bool allowed) async {
    await _box.write(_storageKey, allowed);
    applyDeviceOrientation();
  }

  /// Lock player to landscape mode.
  static void applyPlayerOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Restore user orientations when exiting player.
  static void applyPlayerExitOrientation() {
    applyDeviceOrientation();
    debugPrint('[OrientationGuard] Player exit restored orientation mode');
  }
}

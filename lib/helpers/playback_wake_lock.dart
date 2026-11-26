import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while something is playing.
///
/// Without it Android TV starts the screensaver after the screen timeout
/// (10 minutes on a Chromecast) even though video is playing, which stops the
/// stream. Each player holds the lock while it plays and lets go when it is
/// paused or closed, so a paused title still lets the TV sleep.
class PlaybackWakeLock {
  PlaybackWakeLock._();

  static final Set<Object> _holders = <Object>{};
  static bool _on = false;

  @visibleForTesting
  static bool get isHeld => _holders.isNotEmpty;

  /// Test seam: receives every on/off change instead of the platform.
  @visibleForTesting
  static void Function(bool on)? debugSink;

  static void acquire(Object holder) {
    _holders.add(holder);
    _apply();
  }

  static void release(Object holder) {
    _holders.remove(holder);
    _apply();
  }

  static void _apply() {
    final want = _holders.isNotEmpty;
    if (want == _on) return;
    _on = want;
    final sink = debugSink;
    if (sink != null) {
      sink(want);
      return;
    }
    try {
      WakelockPlus.toggle(enable: want).catchError((Object e) {
        debugPrint('[WAKE_LOCK] toggle skipped: ${e.runtimeType}');
      });
    } catch (e) {
      debugPrint('[WAKE_LOCK] toggle skipped: ${e.runtimeType}');
    }
  }
}

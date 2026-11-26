import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/helpers/playback_wake_lock.dart';

void main() {
  final changes = <bool>[];

  setUp(() {
    changes.clear();
    PlaybackWakeLock.debugSink = changes.add;
  });

  tearDown(() => PlaybackWakeLock.debugSink = null);

  test('screen stays on while any player holds the lock', () {
    final a = Object();
    final b = Object();
    PlaybackWakeLock.acquire(a);
    PlaybackWakeLock.acquire(a);
    PlaybackWakeLock.acquire(b);
    expect(changes, [true]);
    expect(PlaybackWakeLock.isHeld, isTrue);

    PlaybackWakeLock.release(a);
    expect(changes, [true], reason: 'b is still playing');

    PlaybackWakeLock.release(b);
    expect(changes, [true, false]);
    expect(PlaybackWakeLock.isHeld, isFalse);
  });

  test('releasing a holder that never acquired changes nothing', () {
    PlaybackWakeLock.release(Object());
    expect(changes, isEmpty);
  });

  test('pause then resume turns the lock off and on again', () {
    final player = Object();
    PlaybackWakeLock.acquire(player);
    PlaybackWakeLock.release(player);
    PlaybackWakeLock.acquire(player);
    PlaybackWakeLock.release(player);
    expect(changes, [true, false, true, false]);
  });
}

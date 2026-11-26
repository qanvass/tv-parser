import 'package:flutter_test/flutter_test.dart';

int getAdaptiveStepSeconds(int streak) {
  if (streak <= 1) return 10;
  if (streak == 2) return 15;
  if (streak == 3) return 30;
  if (streak == 4) return 60;
  if (streak == 5) return 120;
  return 300;
}

double getScrubSpeed(int heldMilliseconds) {
  if (heldMilliseconds < 1500) return 15.0;
  if (heldMilliseconds < 3500) return 45.0;
  return 120.0;
}

Duration calculateClampedSeek({
  required Duration current,
  required int deltaSeconds,
  required Duration totalDuration,
}) {
  final target = current + Duration(seconds: deltaSeconds);
  if (target < Duration.zero) return Duration.zero;
  if (target > totalDuration) return totalDuration;
  return target;
}

void main() {
  group('Player Adaptive Seeking & Scrubbing UX', () {
    test('streak progression matches adaptive acceleration curve', () {
      expect(getAdaptiveStepSeconds(1), 10);
      expect(getAdaptiveStepSeconds(2), 15);
      expect(getAdaptiveStepSeconds(3), 30);
      expect(getAdaptiveStepSeconds(4), 60);
      expect(getAdaptiveStepSeconds(5), 120);
      expect(getAdaptiveStepSeconds(6), 300);
      expect(getAdaptiveStepSeconds(10), 300);
    });

    test('clamping ensures target never goes below zero or above duration', () {
      const total = Duration(hours: 2);

      // Rewind past beginning clamps to 0
      final rewClamped = calculateClampedSeek(
        current: const Duration(seconds: 5),
        deltaSeconds: -10,
        totalDuration: total,
      );
      expect(rewClamped, Duration.zero);

      // Forward past end clamps to totalDuration
      final ffClamped = calculateClampedSeek(
        current: const Duration(hours: 1, minutes: 59, seconds: 50),
        deltaSeconds: 60,
        totalDuration: total,
      );
      expect(ffClamped, total);

      // Normal seek
      final normal = calculateClampedSeek(
        current: const Duration(minutes: 30),
        deltaSeconds: 15,
        totalDuration: total,
      );
      expect(normal, const Duration(minutes: 30, seconds: 15));
    });

    test('hold-to-scrub speed increases over held duration', () {
      expect(getScrubSpeed(500), 15.0);
      expect(getScrubSpeed(1499), 15.0);
      expect(getScrubSpeed(1500), 45.0);
      expect(getScrubSpeed(3499), 45.0);
      expect(getScrubSpeed(3500), 120.0);
      expect(getScrubSpeed(6000), 120.0);
    });
  });
}

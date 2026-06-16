// Mid-session momentum pulse decision (studio #4, 2026-06-16): the
// 「あと N問で きょうの目標！」 nudge fires at a VARIABLE cadence (3,7,12,18) ONLY while
// the daily goal is still unmet — so the "あと N問" message is always honest and
// the pulse never nags a child who already hit today's goal. Variable-ratio
// schedules sustain engagement better than a predictable every-5th.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/battle/battle_screen.dart';

void main() {
  group('shouldShowMomentumPulse', () {
    test('fires at the variable cadence while the goal is unmet', () {
      for (final n in kMomentumCadence) {
        final (show, remaining) = shouldShowMomentumPulse(n, 7, false);
        expect(show, isTrue, reason: 'answer #$n should pulse');
        expect(remaining, 7);
      }
    });

    test('does NOT fire off-cadence (incl. the old 5/10/15)', () {
      for (final n in [1, 2, 4, 5, 6, 8, 10, 11, 15, 20]) {
        expect(shouldShowMomentumPulse(n, 7, false).$1, isFalse,
            reason: 'answer #$n is off-cadence → no pulse');
      }
    });

    test('never fires once the daily goal is met (no nagging)', () {
      expect(shouldShowMomentumPulse(3, 0, true).$1, isFalse);
      expect(shouldShowMomentumPulse(12, 3, true).$1, isFalse,
          reason: 'goalMet wins even if remaining looks > 0');
    });

    test('does not fire when nothing remains (honest "あと N問")', () {
      expect(shouldShowMomentumPulse(3, 0, false).$1, isFalse,
          reason: 'remaining 0 → no "あと 0問" message');
    });

    test('answer 0 never pulses', () {
      expect(shouldShowMomentumPulse(0, 7, false).$1, isFalse);
    });
  });
}

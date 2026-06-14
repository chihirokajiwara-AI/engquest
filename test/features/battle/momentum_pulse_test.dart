// Mid-session momentum pulse decision (studio build 2026-06-14): the
// 「あと N問で きょうの目標！」 nudge fires on every 5th answer (5/10/15…) ONLY while
// the daily goal is still unmet — so the "あと N問" message is always honest and
// the pulse never nags a child who already hit today's goal.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/battle/battle_screen.dart';

void main() {
  group('shouldShowMomentumPulse', () {
    test('fires on every 5th answer while the goal is unmet', () {
      for (final n in [5, 10, 15, 20]) {
        final (show, remaining) = shouldShowMomentumPulse(n, 7, false);
        expect(show, isTrue, reason: 'answer #$n should pulse');
        expect(remaining, 7);
      }
    });

    test('does NOT fire on non-5th answers', () {
      for (final n in [1, 2, 3, 4, 6, 7, 9, 11]) {
        expect(shouldShowMomentumPulse(n, 7, false).$1, isFalse,
            reason: 'answer #$n should not pulse');
      }
    });

    test('never fires once the daily goal is met (no nagging)', () {
      expect(shouldShowMomentumPulse(5, 0, true).$1, isFalse);
      expect(shouldShowMomentumPulse(10, 3, true).$1, isFalse,
          reason: 'goalMet wins even if remaining looks > 0');
    });

    test('does not fire when nothing remains (honest "あと N問")', () {
      expect(shouldShowMomentumPulse(5, 0, false).$1, isFalse,
          reason: 'remaining 0 → no "あと 0問" message');
    });

    test('answer 0 never pulses', () {
      expect(shouldShowMomentumPulse(0, 7, false).$1, isFalse);
    });
  });
}

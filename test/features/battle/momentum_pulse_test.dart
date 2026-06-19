// Mid-session momentum pulse decision (studio #4, 2026-06-16; run-3 live-count
// fix): the 「あと N問で きょうの目標！」 nudge fires at a VARIABLE cadence (3,7,12,18)
// ONLY while the daily goal is still unmet — and the "あと N問" is the LIVE
// remaining (pre-session remaining MINUS answers already given this session),
// because the goal count only commits at session end. So it decrements as the
// child answers and never shows a stale, non-closing number.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/battle/battle_screen.dart';

void main() {
  group('shouldShowMomentumPulse', () {
    test('fires at the variable cadence with LIVE-decrementing remaining', () {
      // Pre-session remaining 20 stays positive at every cadence point, so each
      // pulse shows the live remaining = 20 - answersThisSession.
      for (final n in kMomentumCadence) {
        final (show, remaining) = shouldShowMomentumPulse(n, 20, false);
        expect(show, isTrue, reason: 'answer #$n should pulse');
        expect(remaining, 20 - n,
            reason: 'remaining must be LIVE (20 - $n), not the stale 20');
      }
    });

    test('does NOT fire off-cadence (incl. the old 5/10/15)', () {
      for (final n in [1, 2, 4, 5, 6, 8, 10, 11, 15, 20]) {
        expect(shouldShowMomentumPulse(n, 20, false).$1, isFalse,
            reason: 'answer #$n is off-cadence → no pulse');
      }
    });

    test('no stale pulse once in-session answers reach the goal (the fix)', () {
      // Pre-session remaining 7; by answer 7 the live remaining is 0, so even at
      // the cadence point there is no dishonest "あと N問" pulse.
      expect(shouldShowMomentumPulse(7, 7, false).$1, isFalse,
          reason: 'live remaining 0 at cadence → no pulse');
      expect(shouldShowMomentumPulse(12, 7, false).$1, isFalse,
          reason: 'already past the goal in-session → no pulse');
      // ...but earlier in the same session it still pulses with a live count.
      final (show3, rem3) = shouldShowMomentumPulse(3, 7, false);
      expect(show3, isTrue);
      expect(rem3, 4, reason: '7 - 3 = 4 remaining');
    });

    test('never fires once the daily goal is met (no nagging)', () {
      expect(shouldShowMomentumPulse(3, 0, true).$1, isFalse);
      expect(shouldShowMomentumPulse(3, 8, true).$1, isFalse,
          reason: 'goalMet wins even when live remaining > 0');
    });

    test('does not fire when nothing remains (honest "あと N問")', () {
      expect(shouldShowMomentumPulse(3, 0, false).$1, isFalse,
          reason: 'remaining 0 → no "あと 0問" message');
    });

    test('answer 0 never pulses', () {
      expect(shouldShowMomentumPulse(0, 20, false).$1, isFalse);
    });
  });
}

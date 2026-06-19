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

  // #170 (diverse-values first-run panel, 2026-06-19): the Battle header must
  // never show the raw "N / 600" grade-deck total — 3 personas flagged it as the
  // clearest "endless drill" demotivator. It shows the achievable daily-goal
  // near-horizon instead, consistent with the momentum pulse's live count.
  group('battleHeaderGoalLabel', () {
    test('null while the goal context is still loading (never shows 600)', () {
      expect(
        battleHeaderGoalLabel(
            hasGoalContext: false,
            answersThisSession: 0,
            remainingToGoal: 0,
            goalMet: false),
        isNull,
      );
    });

    test('shows the live near-horizon, decrementing as the child answers', () {
      expect(
        battleHeaderGoalLabel(
            hasGoalContext: true,
            answersThisSession: 0,
            remainingToGoal: 10,
            goalMet: false),
        'あと 10 もん',
      );
      expect(
        battleHeaderGoalLabel(
            hasGoalContext: true,
            answersThisSession: 3,
            remainingToGoal: 10,
            goalMet: false),
        'あと 7 もん',
      );
    });

    test('positive ✓ state once the goal is met or the horizon closes', () {
      expect(
        battleHeaderGoalLabel(
            hasGoalContext: true,
            answersThisSession: 0,
            remainingToGoal: 8,
            goalMet: true),
        'きょうの目標 ✓',
      );
      expect(
        battleHeaderGoalLabel(
            hasGoalContext: true,
            answersThisSession: 10,
            remainingToGoal: 10,
            goalMet: false),
        'きょうの目標 ✓',
        reason: 'live 0 → done state, never "あと 0 もん"',
      );
    });
  });

  group('battleHeaderGoalFraction', () {
    test('null while loading → caller uses the session-queue fraction', () {
      expect(
        battleHeaderGoalFraction(
            hasGoalContext: false,
            answersThisSession: 0,
            remainingToGoal: 0,
            goalMet: false),
        isNull,
      );
    });

    test('fills proportionally toward the daily goal', () {
      expect(
        battleHeaderGoalFraction(
            hasGoalContext: true,
            answersThisSession: 3,
            remainingToGoal: 10,
            goalMet: false),
        closeTo(0.3, 1e-9),
      );
    });

    test('full bar when the goal is met (no crawling 1/600)', () {
      expect(
        battleHeaderGoalFraction(
            hasGoalContext: true,
            answersThisSession: 0,
            remainingToGoal: 0,
            goalMet: true),
        1.0,
      );
    });

    test('clamps to 1.0 past the goal (bonus practice)', () {
      expect(
        battleHeaderGoalFraction(
            hasGoalContext: true,
            answersThisSession: 15,
            remainingToGoal: 10,
            goalMet: false),
        1.0,
      );
    });
  });
}

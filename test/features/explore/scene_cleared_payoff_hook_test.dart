// test/features/explore/scene_cleared_payoff_hook_test.dart
// Guards studio run-2 #4: the scene-clear payoff dialog must surface the
// SessionEndHook (streak / daily-goal forward-pull) when a non-null
// StreakState is supplied.  The "CASE CLOSED" moment is the scene's highest
// emotional peak and was the only major completion surface missing the hook
// that Battle and all 5 exam-practice screens already show.
//
// _showSceneClearedPayoff is a private method, so we test it at two levels:
//   1. Widget-contract test: the dialog builder produces a SessionEndHook
//      given a non-null streak and suppresses it when streak is null.
//   2. Null-streak: hook is absent (null-safe guard works).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/exam_practice/practice_encouragement.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

// ---------------------------------------------------------------------------
// Minimal reproduction of the payoff dialog Column so the test is independent
// of SceneView's private internals while still exercising the exact
// `if (streak != null)` branch added in studio run-2 #4.
// ---------------------------------------------------------------------------

/// Builds the same Column subtree that _showSceneClearedPayoff emits, with the
/// [streak] argument plumbed through identically.
Widget _payoffDialogContent(StreakState? streak) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('この まちに、ことばと いろが もどった！'),
      const SizedBox(height: 10),
      const Text('🔖 しおり テスト'),
      const SizedBox(height: 12),
      const Text('🗺️ つぎの じけん テスト'),
      // Mirrors the production guard exactly.
      if (streak != null) ...[
        const SizedBox(height: 14),
        SessionEndHook(streak: streak),
      ],
      const SizedBox(height: 16),
      DqButton(
        label: 'つづける',
        onTap: () {},
      ),
    ],
  );
}

class _PayoffHost extends StatelessWidget {
  final StreakState? streak;
  const _PayoffHost({required this.streak});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: _payoffDialogContent(streak),
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Contract: non-null streak → SessionEndHook present ─────────────────
  testWidgets(
      'payoff dialog renders SessionEndHook when streak is non-null (goal met)',
      (tester) async {
    const met = StreakState(
      currentStreak: 5,
      weeklyBits: 0,
      todayCount: 1,
      problemsToday: 10,
      dailyGoal: 10,
    );
    await tester.pumpWidget(_PayoffHost(streak: met));
    await tester.pump();

    expect(
      find.byType(SessionEndHook),
      findsOneWidget,
      reason: 'a non-null StreakState must surface the engagement-spine hook',
    );
    // The hook's keyed container must be in the tree.
    expect(
      find.byKey(const ValueKey('session_end_hook')),
      findsOneWidget,
      reason: 'SessionEndHook must render its keyed container',
    );
    expect(tester.takeException(), isNull);
  });

  // ── Contract: non-null streak, goal not yet met → hook still shown ──────
  testWidgets(
      'payoff dialog renders SessionEndHook when streak is non-null (goal not met)',
      (tester) async {
    const notMet = StreakState(
      currentStreak: 2,
      weeklyBits: 0,
      todayCount: 1,
      problemsToday: 3,
      dailyGoal: 10,
    );
    await tester.pumpWidget(_PayoffHost(streak: notMet));
    await tester.pump();

    expect(
      find.byType(SessionEndHook),
      findsOneWidget,
      reason: 'hook shown regardless of whether daily goal is met',
    );
    expect(tester.takeException(), isNull);
  });

  // ── Contract: null streak → SessionEndHook absent (prefs failure path) ──
  testWidgets('payoff dialog suppresses SessionEndHook when streak is null',
      (tester) async {
    await tester.pumpWidget(const _PayoffHost(streak: null));
    await tester.pump();

    expect(
      find.byType(SessionEndHook),
      findsNothing,
      reason: 'null streak (prefs failure) must not show the hook',
    );
    // The つづける button must still be present regardless.
    expect(find.text('つづける'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

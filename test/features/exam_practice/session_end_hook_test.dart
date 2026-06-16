// The session-end retention hook must make the goal-MET moment FEEL distinct from
// the calm "keep going" state — not the same blue box with different words. A met
// goal shows a gold 「達成」 achievement stamp; a not-met state shows the calm スラ
// header and no stamp. (Engagement spine, CEO 951 — the daily-goal crossing is the
// strongest daily-return reinforcement and must read as a win.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/practice_encouragement.dart';
import 'package:engquest/features/home/streak_service.dart';

void main() {
  const stamp = '✦ もくひょう 達成（たっせい）✦';

  Widget host(StreakState s) =>
      MaterialApp(home: Scaffold(body: SessionEndHook(streak: s)));

  testWidgets('goal MET shows the gold 達成 stamp + たっせい line', (tester) async {
    const met = StreakState(
      currentStreak: 3,
      weeklyBits: 0,
      todayCount: 1,
      problemsToday: 10,
      dailyGoal: 10,
    );
    expect(met.goalMet, isTrue, reason: 'fixture must be a met-goal state');
    await tester.pumpWidget(host(met));
    await tester.pump(const Duration(milliseconds: 600)); // settle the pop

    expect(find.text(stamp), findsOneWidget);
    expect(find.textContaining('たっせい'), findsWidgets);
    // The calm スラ header is replaced by the achievement stamp when met.
    expect(find.text('🔵 スラ'), findsNothing);
  });

  testWidgets('goal NOT met shows calm スラ header, no 達成 stamp', (tester) async {
    const notMet = StreakState(
      currentStreak: 1,
      weeklyBits: 0,
      todayCount: 1,
      problemsToday: 4,
      dailyGoal: 10,
    );
    expect(notMet.goalMet, isFalse, reason: 'fixture must be a not-met state');
    await tester.pumpWidget(host(notMet));
    await tester.pump();

    expect(find.text(stamp), findsNothing);
    expect(find.text('🔵 スラ'), findsOneWidget);
    expect(find.textContaining('あと'), findsWidgets); // "あと N問で…"
  });
}

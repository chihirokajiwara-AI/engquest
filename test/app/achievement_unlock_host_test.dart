// ENG Quest — Widget tests for the global AchievementUnlockHost (app.dart).
//
// Regression guard for the engagement bug: the「バッジ獲得！」popup used to live
// ONLY inside BattleScreen, and checkAndUpdate was never called from exam
// practice — so an exam-focused child's streak/level unlocks were silent. The
// host now listens to the static AchievementService.unlockEvents at the app
// root, so an unlock published from ANY source is celebrated.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/app.dart';
import 'package:engquest/core/gamification/achievement_service.dart';

void main() {
  tearDown(() => AchievementService.unlockEvents.value = const []);

  Widget host() => const MaterialApp(
        home: Scaffold(
          body: AchievementUnlockHost(child: SizedBox.expand()),
        ),
      );

  testWidgets('celebrates an unlock published from any source', (t) async {
    await t.pumpWidget(host());
    expect(find.text('バッジ獲得！'), findsNothing);

    // Exactly what AchievementService.checkAndUpdate does on a new unlock.
    AchievementService.unlockEvents.value = const ['streak_3'];
    await t.pump(); // notifier → listener → setState
    await t.pump(const Duration(milliseconds: 300)); // banner pops in

    expect(find.text('バッジ獲得！'), findsOneWidget);

    // Auto-dismisses (3s) and clears the broadcast so the next one fires.
    await t.pump(const Duration(milliseconds: 3200));
    expect(find.text('バッジ獲得！'), findsNothing);
    expect(AchievementService.unlockEvents.value, isEmpty);
  });

  testWidgets('ignores an unknown achievement id', (t) async {
    await t.pumpWidget(host());
    AchievementService.unlockEvents.value = const ['not_a_real_badge'];
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('バッジ獲得！'), findsNothing);
  });
}

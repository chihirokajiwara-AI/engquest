// ENG Quest — Widget tests for the global LevelUpCelebrationHost (app.dart).
//
// Regression guard for the engagement bug fixed alongside the exam-practice XP
// award: the level-up celebration used to live ONLY inside BattleScreen, so an
// exam-focused child (the primary 英検 path) levelled up silently. The host now
// listens to XpService.levelUpNotifier at the app root, so a level-up from ANY
// source — battle, every exam section, scene ナゾ — is celebrated. These tests
// publish a level-up the way XpService does and assert the banner appears, and
// that a non-level-up (same level) stays quiet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/app.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/core/gamification/xp_profile.dart';

void main() {
  // Keep the static broadcast notifier clean between tests (it is app-wide).
  tearDown(() => XpService.levelUpEvents.value = null);

  Widget host() => const MaterialApp(
        home: Scaffold(
          body: LevelUpCelebrationHost(child: SizedBox.expand()),
        ),
      );

  testWidgets('celebrates a level-up published from any XP source', (t) async {
    await t.pumpWidget(host());
    expect(find.text('レベルアップ！'), findsNothing);

    // Exactly what XpService.awardXp / awardXpAmount do on a threshold cross.
    XpService.levelUpEvents.value = XpAwardResult(
      xpGained: 100,
      before: XpProfile(uid: 'u', totalXp: 90, level: 1),
      after: XpProfile(uid: 'u', totalXp: 190, level: 2),
    );
    await t.pump(); // notifier → listener → setState
    await t.pump(const Duration(milliseconds: 300)); // banner pops in

    expect(find.text('レベルアップ！'), findsOneWidget);
    expect(find.text('Lv.2 に到達！'), findsOneWidget);

    // It auto-dismisses (2.8s) and clears the notifier so the next one fires.
    await t.pump(const Duration(milliseconds: 3000));
    expect(find.text('レベルアップ！'), findsNothing);
    expect(XpService.levelUpEvents.value, isNull);
  });

  testWidgets('stays quiet when the notifier is cleared (no level-up)',
      (t) async {
    await t.pumpWidget(host());
    XpService.levelUpEvents.value = null;
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('レベルアップ！'), findsNothing);
  });
}

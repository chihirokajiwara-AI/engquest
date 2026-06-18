// test/features/exam_practice/pass/pass_meter_smoke_test.dart
// R3 smoke test: pump PassMeterScreen and assert tester.takeException() == null.
// R4: No Firebase, no network — data injected via constructor.
//
// Tests cover:
//   1. Default (null estimate → demo profile) — always renderable
//   2. Below-passing state (pointsNeeded > 0, weakest-skill CTA shown)
//   3. Passing state (readinessPct = 100, celebration shown)
//   4. Each supported grade key pumps without exception

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/mastery_advisor.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/paywall/grade_gate_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(home: child);

CseEstimate _estimate({
  required String grade,
  required double reading,
  required double listening,
  double writing = 0.0,
  bool hasWriting = false,
}) {
  final accuracies = <SkillAccuracy>[
    SkillAccuracy(
        skill: EikenSkill.reading, accuracy: reading, itemsAttempted: 10),
    SkillAccuracy(
        skill: EikenSkill.listening, accuracy: listening, itemsAttempted: 10),
    if (hasWriting)
      SkillAccuracy(
          skill: EikenSkill.writing, accuracy: writing, itemsAttempted: 1),
  ];
  return CseEstimator.estimate(grade: grade, accuracies: accuracies)!;
}

// ── Smoke tests (R3) ──────────────────────────────────────────────────────────

void main() {
  group('PassMeterScreen — smoke tests (R3)', () {
    testWidgets('null estimate (demo profile) — pumps without exception',
        (tester) async {
      await tester.pumpWidget(_wrap(const PassMeterScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('null estimate — shows percentage text', (tester) async {
      await tester.pumpWidget(_wrap(const PassMeterScreen()));
      await tester.pump();
      // Should show a %-sign somewhere in the hero
      expect(find.textContaining('%'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('null estimate — shows pass prediction label', (tester) async {
      await tester.pumpWidget(_wrap(const PassMeterScreen()));
      await tester.pump();
      expect(find.textContaining('Readiness guide'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below-passing estimate — shows weakest-skill CTA',
        (tester) async {
      final est = _estimate(
          grade: '3',
          reading: 0.4,
          listening: 0.8,
          writing: 0.2,
          hasWriting: true);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      // Weak skill CTA section should be visible
      expect(find.textContaining('のばそう'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('passing estimate — shows celebration, no CTA', (tester) async {
      final est = _estimate(grade: '5', reading: 1.0, listening: 1.0);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(find.textContaining('ごうかくけん'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 5 estimate — pumps without exception', (tester) async {
      final est = _estimate(grade: '5', reading: 0.65, listening: 0.70);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 4 estimate — pumps without exception', (tester) async {
      final est = _estimate(grade: '4', reading: 0.75, listening: 0.80);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 3 estimate — pumps without exception', (tester) async {
      final est = _estimate(
          grade: '3',
          reading: 0.7,
          listening: 0.65,
          writing: 0.5,
          hasWriting: true);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre2 estimate — pumps without exception',
        (tester) async {
      final est = _estimate(
          grade: 'pre2',
          reading: 0.8,
          listening: 0.75,
          writing: 0.6,
          hasWriting: true);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // #151: the mock pushes PassMeterScreen WITH an earnedStreak so the streak
    // reward shows at the completion peak. The prior smoke tests all passed
    // earnedStreak == null, so the SessionEndHook path was never actually
    // rendered in-test — these cover it (and catch any overflow/layout throw).
    testWidgets('earnedStreak goal-met — renders SessionEndHook, no exception',
        (tester) async {
      final est = _estimate(grade: '5', reading: 0.7, listening: 0.7);
      const streak = StreakState(
        currentStreak: 7,
        weeklyBits: 0x7F,
        todayCount: 1,
        problemsToday: 12,
        dailyGoal: 10, // problemsToday >= dailyGoal → goalMet
      );
      await tester.pumpWidget(
          _wrap(PassMeterScreen(estimate: est, earnedStreak: streak)));
      await tester.pump();
      expect(find.byKey(const ValueKey('session_end_hook')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('earnedStreak goal-not-met — renders SessionEndHook',
        (tester) async {
      final est = _estimate(grade: '3', reading: 0.6, listening: 0.6);
      const streak = StreakState(
        currentStreak: 3,
        weeklyBits: 0x0F,
        todayCount: 1,
        problemsToday: 4,
        dailyGoal: 10, // not met
      );
      await tester.pumpWidget(
          _wrap(PassMeterScreen(estimate: est, earnedStreak: streak)));
      await tester.pump();
      expect(find.byKey(const ValueKey('session_end_hook')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no earnedStreak — SessionEndHook absent (live meter path)',
        (tester) async {
      final est = _estimate(grade: '5', reading: 0.7, listening: 0.7);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(find.byKey(const ValueKey('session_end_hook')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 2 estimate — pumps without exception', (tester) async {
      final est = _estimate(
          grade: '2',
          reading: 0.80,
          listening: 0.70,
          writing: 0.55,
          hasWriting: true);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre1 estimate — pumps without exception',
        (tester) async {
      final est = _estimate(
          grade: 'pre1',
          reading: 0.85,
          listening: 0.80,
          writing: 0.70,
          hasWriting: true);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('zero-accuracy estimate — pumps without exception',
        (tester) async {
      final est = _estimate(
          grade: '3',
          reading: 0.0,
          listening: 0.0,
          writing: 0.0,
          hasWriting: true);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('back arrow is present', (tester) async {
      await tester.pumpWidget(_wrap(const PassMeterScreen()));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('skill tiers carry a non-colour icon cue (#127 colour-blind)',
        (tester) async {
      // A strong skill and a weak skill must be distinguishable by SHAPE, not
      // only the bar hue (8% of boys are red-green colour-blind, WCAG 1.4.1).
      final est = _estimate(grade: '5', reading: 0.95, listening: 0.30);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_outline), findsWidgets,
          reason: 'strong skill → ✓ shape, independent of green');
      expect(find.byIcon(Icons.priority_high), findsWidgets,
          reason: 'weak skill → ! shape, independent of amber');
      expect(tester.takeException(), isNull);
    });

    testWidgets('skill bars section is present', (tester) async {
      await tester.pumpWidget(_wrap(const PassMeterScreen()));
      await tester.pump();
      // DqPanel renders the title in toUpperCase() → "SKILLS"
      expect(find.textContaining('SKILLS'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('motivational note (アドバイス) is present', (tester) async {
      await tester.pumpWidget(_wrap(const PassMeterScreen()));
      await tester.pump();
      expect(find.textContaining('アドバイス'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // #68: the 合格率 must DISCLOSE its basis (how many questions back it) so a
  // high % built on few answers reads as provisional, not fabricated.
  group('PassMeterScreen — basis disclosure (#68)', () {
    testWidgets('hero shows the total-answers basis', (tester) async {
      // reading 10 + listening 10 = 20 answers.
      final est = _estimate(grade: '5', reading: 0.7, listening: 0.7);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(find.textContaining('based on 20 answers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each skill row shows its sample count (もん)', (tester) async {
      final est = _estimate(grade: '5', reading: 0.7, listening: 0.7);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      // Two measured skills → at least two "…もん" readouts.
      expect(find.textContaining('もん'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('thin sample (<20) shows the "rough estimate" caption',
        (tester) async {
      final est = CseEstimator.estimate(grade: '5', accuracies: const [
        SkillAccuracy(
            skill: EikenSkill.reading, accuracy: 0.8, itemsAttempted: 3),
        SkillAccuracy(
            skill: EikenSkill.listening, accuracy: 0.8, itemsAttempted: 2),
      ])!;
      expect(est.totalItemsAttempted, 5);
      await tester.pumpWidget(_wrap(PassMeterScreen(estimate: est)));
      await tester.pump();
      expect(find.textContaining('おおよその めやす'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('estimate carries per-skill itemsAttempted + correct total', () {
      final est = CseEstimator.estimate(grade: '3', accuracies: const [
        SkillAccuracy(
            skill: EikenSkill.reading, accuracy: 0.7, itemsAttempted: 31),
        SkillAccuracy(
            skill: EikenSkill.writing, accuracy: 0.6, itemsAttempted: 2),
        SkillAccuracy(
            skill: EikenSkill.listening, accuracy: 0.7, itemsAttempted: 30),
      ])!;
      expect(est.itemsAttempted[EikenSkill.writing], 2);
      expect(est.totalItemsAttempted, 63);
    });
  });

  // #68: the meter must turn its diagnosis into action — the CTA names the
  // weakest skill and pops it so the caller routes straight into practising it.
  group('PassMeterScreen — diagnose→practice CTA (#68)', () {
    testWidgets('CTA names + pops the weakest skill', (tester) async {
      // Both below mastery (so NOT predicted-pass) with listening the weakest.
      final est = _estimate(grade: '5', reading: 0.5, listening: 0.2);
      expect(est.isPredictedPass, isFalse, reason: 'sanity: not passing');
      expect(est.limitingSkill, EikenSkill.listening,
          reason: 'sanity: listening is the bottleneck here');

      EikenSkill? popped;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.push<EikenSkill?>(
                ctx,
                MaterialPageRoute(
                    builder: (_) => PassMeterScreen(estimate: est)),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The CTA explicitly names the weak skill ("…を れんしゅうする").
      expect(find.textContaining('を れんしゅうする'), findsOneWidget);

      await tester.ensureVisible(find.textContaining('を れんしゅうする'));
      await tester.tap(find.textContaining('を れんしゅうする'));
      await tester.pumpAndSettle();

      expect(popped, EikenSkill.listening,
          reason: 'tapping practice must pop the limiting skill so the caller '
              'can route into it');
    });

    testWidgets('passing state CTA pops null (no weak-skill routing)',
        (tester) async {
      final est = _estimate(grade: '5', reading: 1.0, listening: 1.0);
      Object? popped = 'sentinel';
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.push<EikenSkill?>(
                ctx,
                MaterialPageRoute(
                    builder: (_) => PassMeterScreen(estimate: est)),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('もどる'));
      await tester.tap(find.text('もどる'));
      await tester.pumpAndSettle();
      expect(popped, isNull);
    });
  });

  // #14: the mastery-based progression advice card renders when supplied and is
  // absent (no fabrication) when null.
  group('PassMeterScreen — mastery progression advice (#14)', () {
    testWidgets('advance recommendation renders its card + reason',
        (tester) async {
      const rec = MasteryRecommendation(
        advice: ProgressionAdvice.advance,
        suggestedGrade: '4',
        reasonJa: 'たくさん せいかいできてるね！',
      );
      await tester
          .pumpWidget(_wrap(const PassMeterScreen(recommendation: rec)));
      await tester.pump();
      // The advance card names the concrete target grade — now in TWO places:
      // the headline AND the one-tap advance button (actionable, not a dead-end).
      expect(find.textContaining('英けん4きゅう'), findsNWidgets(2));
      expect(find.textContaining('いける かも'), findsOneWidget);
      expect(find.textContaining('せいかいできてる'), findsOneWidget);
      // The advance action is present + tappable.
      expect(
          find.byKey(const ValueKey('advice_advance_button')), findsOneWidget);
      expect(find.textContaining('に すすむ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('advance button opens a reversible confirm dialog (free grade)',
        (tester) async {
      // edilab = all grades free → advancing is a direct (reversible) confirm.
      FlavorConfig.setFlavor(Flavor.edilab);
      addTearDown(() => FlavorConfig.setFlavor(Flavor.edilab));
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const rec = MasteryRecommendation(
        advice: ProgressionAdvice.advance,
        suggestedGrade: '4',
        reasonJa: 'たくさん せいかいできてるね！',
      );
      await tester
          .pumpWidget(_wrap(const PassMeterScreen(recommendation: rec)));
      await tester.pump();

      final btn = find.byKey(const ValueKey('advice_advance_button'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      // Confirms before changing the grade + reassures it is reversible.
      expect(find.textContaining('すすむ？'), findsOneWidget);
      expect(find.textContaining('もどせるよ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('advance to a PAID grade opens the paywall, not a free switch',
        (tester) async {
      // aken freemium: only 5級 is free, so advancing to 4級 must hit the paywall
      // (GradeGateScreen), never a one-tap free advance — no bypass.
      FlavorConfig.setFlavor(Flavor.aken);
      addTearDown(() => FlavorConfig.setFlavor(Flavor.edilab));
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const rec = MasteryRecommendation(
        advice: ProgressionAdvice.advance,
        suggestedGrade: '4',
        reasonJa: 'たくさん せいかいできてるね！',
      );
      await tester
          .pumpWidget(_wrap(const PassMeterScreen(recommendation: rec)));
      await tester.pump();

      final btn = find.byKey(const ValueKey('advice_advance_button'));
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      // The paywall — NOT the free confirm dialog.
      expect(find.byType(GradeGateScreen), findsOneWidget);
      expect(find.textContaining('すすむ？'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review recommendation renders its card', (tester) async {
      const rec = MasteryRecommendation(
        advice: ProgressionAdvice.reviewBasics,
        suggestedGrade: '5',
        reasonJa: 'あせらず きそを かためよう。',
      );
      await tester
          .pumpWidget(_wrap(const PassMeterScreen(recommendation: rec)));
      await tester.pump();
      expect(find.textContaining('きそを かためよう'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('null recommendation → no advice card', (tester) async {
      await tester.pumpWidget(_wrap(const PassMeterScreen()));
      await tester.pump();
      expect(find.textContaining('いける かも'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

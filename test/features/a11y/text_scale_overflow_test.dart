// #114 / WCAG 2.2 SC 1.4.4 — text must resize to 200% (2.0x) without clipping.
// 実測 (never assume), 2026-06-11: swept screens at textScaler 2.0 and hardened the
// culprits. VERIFIED-SAFE & LOCKED below at 2.0x: home (after the daily-goal ring
// got a FittedBox(scaleDown) — it was the 62px culprit), pass-meter, onboarding.
// STILL OVERFLOWING (tracked #114, not yet locked): ExamPracticeScreen (~88px
// horizontal at 2.0x) + the reading/listening/mock screens (untested). The global
// text-scale cap in app.dart stays 1.6x until EVERY high-traffic screen passes 2.0x
// here — then it rises to 2.0 in one honest step. Raising the cap before that would
// clip content (a false WCAG claim); this test is the gate that prevents it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';

Future<void> _pumpAt2x(WidgetTester tester, double width, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 2200); // tall: vertical content scrolls
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: child,
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  // VERIFIED-SAFE at WCAG 200% — locked against regression.
  for (final width in <double>[320, 360, 390]) {
    testWidgets('home OK @ textScaler 2.0, ${width}px (WCAG SC 1.4.4)',
        (tester) async {
      await _pumpAt2x(tester, width,
          KotobaHomeScreen(
              cardRepository: InMemoryFsrsCardRepository(), initialEikenLevel: '5'));
      expect(tester.takeException(), isNull,
          reason: 'home clipped @ 2.0x ${width}px — WCAG SC 1.4.4 regression');
    });
  }

  testWidgets('pass-meter OK @ textScaler 2.0 (WCAG SC 1.4.4)', (tester) async {
    await _pumpAt2x(tester, 360, const PassMeterScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding OK @ textScaler 2.0 (WCAG SC 1.4.4)', (tester) async {
    await _pumpAt2x(tester, 360, OnboardingFlow(onComplete: (_) {}));
    expect(tester.takeException(), isNull);
  });

  // Exam hub — hardened (the overview chips Row → Wrap, d-commit).
  testWidgets('exam-practice OK @ textScaler 2.0 (WCAG SC 1.4.4)', (tester) async {
    await _pumpAt2x(tester, 360, const ExamPracticeScreen(eikenGrade: '5'));
    expect(tester.takeException(), isNull);
  });
  // Remaining before the app.dart cap can rise 1.6→2.0 (#114): the reading /
  // listening / mock / conversation / word-ordering screens still need 2.0x
  // verification + hardening. Add them here as they are cleared.
}

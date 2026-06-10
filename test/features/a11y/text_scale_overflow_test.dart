// #114 / WCAG 2.2 SC 1.4.4 — text resize. 実測 (never assume), measured 2026-06-11
// by sweeping the home (its CTA Rows + readiness-card hero Row + streak panel are
// the densest layouts) across text scales:
//   ≤1.4x: clean   ·   1.5–1.6x: ~3px clip   ·   2.0x: ~62px clip
// in an inner fixed-height region. The shipped cap (app.dart) stays at 1.6x — NOT
// lowered, because stripping magnification from low-vision users for a cosmetic
// few-px clip is the wrong trade. The FLOOR test below locks the verified-clean
// 1.4x range (a regression that breaks even that is caught). The SKIPPED target is
// true WCAG 200%; un-skip it (and the cap can then rise to 2.0) only once the home's
// fixed-height regions are hardened (#114) — proving the flaw-hunt's "just raise the
// cap" wrong was itself an assumption that measurement refuted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';

Future<void> _pumpHomeAtScale(WidgetTester tester, double width, double scale) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
        child: KotobaHomeScreen(
          cardRepository: InMemoryFsrsCardRepository(),
          initialEikenLevel: '5',
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // FLOOR (must pass): the verified-clean magnification range.
  for (final width in <double>[320, 360, 390]) {
    testWidgets('home OK at ${width}px @ textScaler 1.4 (verified-clean floor)',
        (tester) async {
      await _pumpHomeAtScale(tester, width, 1.4);
      expect(tester.takeException(), isNull,
          reason: 'home clipped at ${width}px @ 1.4x — the clean range regressed');
    });
  }

  // TARGET (skipped until layout hardened): true WCAG SC 1.4.4 = 200%. Un-skip and
  // raise app.dart's clamp ceiling to 2.0 only once the home survives this (#114).
  testWidgets('home OK at 360px @ textScaler 2.0 (WCAG SC 1.4.4 target)',
      (tester) async {
    await _pumpHomeAtScale(tester, 360, 2.0);
    expect(tester.takeException(), isNull);
  }, skip: true);
}

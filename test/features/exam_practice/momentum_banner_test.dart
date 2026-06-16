// The momentum banner celebrates a correct streak (positive mirror of the
// cold-streak encouragement) — engagement spine (CEO 951), COPPA-safe own-progress.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/practice_encouragement.dart';

void main() {
  testWidgets('momentum banner shows the streak count + 🔥', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PracticeMomentumBanner(streak: 5)),
    ));
    expect(
        find.byKey(const ValueKey('practice_momentum_banner')), findsOneWidget);
    expect(find.textContaining('5問'), findsOneWidget);
    expect(find.textContaining('れんぞく 正解'), findsOneWidget);
    expect(find.textContaining('🔥'), findsOneWidget);
  });

  // The banner is a NEW UI element on 4 practice screens; the screen-level 2.0x
  // guard pumps the no-streak initial state, so it never exercises the banner.
  // Lock it directly at textScaler 2.0 (WCAG SC 1.4.4) + a 320px phone.
  testWidgets(
      'momentum banner survives textScaler 2.0 at 320px (WCAG SC 1.4.4)',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: PracticeMomentumBanner(streak: 8),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'momentum banner clipped at 200% font — WCAG SC 1.4.4');
  });

  test('momentum threshold is a sane small streak', () {
    expect(kMomentumThreshold, greaterThanOrEqualTo(3));
  });
}

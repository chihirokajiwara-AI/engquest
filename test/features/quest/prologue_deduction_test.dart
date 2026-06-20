// test/features/quest/prologue_deduction_test.dart
//
// Locks the 英検5級 大問1 word-deduction beat contract introduced in the opening
// prologue (replaces the old s·a·t blend beat).
//
// Contracts locked:
//   (a) The deduction frame shows three numbered AudioOptionButton choices on the
//       interactive panel (index 3).
//   (b) Tapping the CORRECT choice (LIGHT, slot ②) sets its DqChoiceState to
//       correct and sets _restored, which drives the colour bloom and auto-advance.
//   (c) A WRONG tap (NIGHT or RIGHT) sets that button to DqChoiceState.wrong but
//       does NOT advance the panel (the interactive panel remains visible, the child
//       can retry).
//   (d) The deduction panel does NOT show a "つぎの てがかりへ" advance button while
//       the correct word has not yet been tapped (choice buttons replace it).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/quest/prologue_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

// Panel index for the interactive deduction beat (0-based).
const _kDeductionIndex = 3;

/// Pump the PrologueScreen directly on the interactive deduction panel using
/// [startIndex] so we do not have to navigate through the full prologue.
Future<void> _pumpDeductionPanel(WidgetTester tester) async {
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(MaterialApp(
    home: PrologueScreen(
      onDone: () {},
      startIndex: _kDeductionIndex,
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PrologueScreen — deduction beat contract', () {
    testWidgets(
        '(a) deduction panel shows three numbered AudioOptionButton choices',
        (tester) async {
      await _pumpDeductionPanel(tester);

      // Three choice tiles must be present.
      expect(
        find.byType(AudioOptionButton),
        findsNWidgets(3),
        reason: 'three -IGHT choice buttons must render on the deduction panel',
      );

      // Each expected word label must appear.
      expect(find.text('NIGHT'), findsOneWidget, reason: 'distractor NIGHT');
      expect(find.text('LIGHT'), findsOneWidget,
          reason: 'correct answer LIGHT');
      expect(find.text('RIGHT'), findsOneWidget, reason: 'distractor RIGHT');

      // The DetectiveCaseFrame must be present (wraps the evidence sign + choices).
      expect(
        find.byType(DetectiveCaseFrame),
        findsOneWidget,
        reason: 'DetectiveCaseFrame wraps the deduction card',
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '(b) tapping LIGHT (correct) marks it DqChoiceState.correct and '
        'does NOT immediately navigate away', (tester) async {
      await _pumpDeductionPanel(tester);

      final lightTile = find.widgetWithText(AudioOptionButton, 'LIGHT');
      expect(lightTile, findsOneWidget);

      await tester.tap(lightTile);
      // Pump just the immediate frame — NOT the 900ms auto-advance delay — so we
      // can inspect the in-between "correct" state before navigation fires.
      await tester.pump();

      // The tapped LIGHT tile must now be in DqChoiceState.correct.
      final tappedWidget = tester.widget<AudioOptionButton>(lightTile);
      expect(
        tappedWidget.state,
        equals(DqChoiceState.correct),
        reason:
            'LIGHT tile must be DqChoiceState.correct immediately after tap',
      );

      // The panel must still be the deduction panel (not yet advanced).
      expect(
        find.byType(AudioOptionButton),
        findsNWidgets(3),
        reason: 'deduction panel is still on-screen during the 900ms hold',
      );

      expect(tester.takeException(), isNull);

      // Cancel pending timers so the test teardown doesn't see a pending timer.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        '(c) tapping a wrong choice (NIGHT) marks it DqChoiceState.wrong '
        'and does NOT advance the panel', (tester) async {
      await _pumpDeductionPanel(tester);

      final nightTile = find.widgetWithText(AudioOptionButton, 'NIGHT');
      expect(nightTile, findsOneWidget);

      await tester.tap(nightTile);
      await tester.pump();

      // NIGHT tile must be wrong — not correct, not normal.
      final nightWidget = tester.widget<AudioOptionButton>(nightTile);
      expect(
        nightWidget.state,
        equals(DqChoiceState.wrong),
        reason: 'NIGHT must be DqChoiceState.wrong after tap',
      );

      // Panel has NOT advanced — all three tiles still on screen, and the LIGHT
      // tile is still in DqChoiceState.normal (not correct yet).
      expect(
        find.byType(AudioOptionButton),
        findsNWidgets(3),
        reason: 'panel does not advance on a wrong tap',
      );
      final lightWidget = tester.widget<AudioOptionButton>(
          find.widgetWithText(AudioOptionButton, 'LIGHT'));
      expect(
        lightWidget.state,
        equals(DqChoiceState.normal),
        reason: 'LIGHT tile stays normal after a wrong tap on NIGHT',
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '(d) interactive panel hides 「つぎの てがかりへ」 while LIGHT not yet tapped',
        (tester) async {
      await _pumpDeductionPanel(tester);

      // The standard advance button must NOT appear while the deduction is pending.
      expect(
        find.textContaining('てがかりへ'),
        findsNothing,
        reason:
            '「つぎの てがかりへ」 must be hidden on the deduction panel before restoration',
      );

      expect(tester.takeException(), isNull);
    });
  });
}

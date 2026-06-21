// a11y: the onboarding is the gateway — its selections (age, daily goal) were
// icon-only GestureDetectors with no Semantics, so a low-vision parent could not
// set them and the child could never start. Lock the named buttons.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';

void main() {
  testWidgets('age stepper exposes named +/- buttons for screen readers',
      (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(home: OnboardingFlow(onComplete: (_) {})));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel(RegExp('ねんれいを ふやす')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('ねんれいを へらす')), findsOneWidget);
    h.dispose();
    expect(t.takeException(), isNull);
  });

  // F1 honesty fix: Step 4 goal presets must be labelled in 問 (questions),
  // NOT in 分 (minutes).  Guard the source of truth — the onboarding_flow.dart
  // source — so that "ふんの もくひょう" (minutes label) can never re-appear in
  // _StepGoal and the unit/field rename is never reverted without a test failure.
  //
  // We guard the source directly because driving the widget to Step 4 in a test
  // is fragile (FadeTransition + ScrollSafe + GestureDetector hit-testing in
  // the headless 800×600 test viewport). The brand_test (onboarding_brand_test)
  // uses the same source-scan pattern for the "ENG Quest" guard.
  test('Step 4 goal presets use 問 (もん) not 分 (ふん/min) in onboarding_flow.dart',
      () {
    final source = File(
      'lib/features/onboarding/onboarding_flow.dart',
    ).readAsStringSync();

    // Collect every non-comment line and check it.
    final lines = const LineSplitter().convert(source);
    final minutesLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) continue; // skip comments

      // Inside _StepGoal (lines between the class definition and the end of its
      // build method), neither 'min' as a sub-label nor 'ふんの もくひょう' should
      // appear.  We scan the full file: if either string is present in
      // non-comment source, the unit has been re-introduced.
      if (line.contains('ふんの もくひょう')) {
        minutesLines.add(line.trim());
      }
      // The string 'min' as a bare sub-label in the goal tile ('min').  Allowed:
      //   - variable named 'reminder_minute', 'minute', 'reminderMinute', etc.
      //   - the word 'minimum' / 'min('  (method names)
      // Disallowed: exactly the string 'min' as a Dart string literal that forms
      // the visible label ('min') in the goal tile.
      // Match the exact patterns from the OLD code: Text('min', ...) or 'min'
      // as a string value used in a Semantics/Text in the _StepGoal widget.
      if (RegExp(r"""Text\(\s*'min'""").hasMatch(line) ||
          RegExp(r"""value:\s*'.*min'""").hasMatch(line)) {
        minutesLines.add(line.trim());
      }
    }

    expect(minutesLines, isEmpty,
        reason: 'onboarding_flow.dart must not use "ふんの もくひょう" (minutes) '
            'or bare "min" string literal in Step 4 goal tiles after the '
            'F1 honesty fix (goal is in 問/もん, not 分/min):\n'
            '${minutesLines.join('\n')}');
  });

  test(
      'Step 4 goal tile uses もん and OnboardingResult exposes dailyGoalQuestions',
      () {
    final source = File(
      'lib/features/onboarding/onboarding_flow.dart',
    ).readAsStringSync();

    // (a) The sub-label inside the goal tile must use 'もん', not 'min'.
    expect(source.contains("'もん'"), isTrue,
        reason: "Step 4 goal tile must contain the string literal 'もん' "
            "(the question-unit sub-label).");

    // (b) The Semantics label must use もんの もくひょう.
    expect(source.contains('もんの もくひょう'), isTrue,
        reason: "Step 4 Semantics label must contain 'もんの もくひょう'.");

    // (c) The field is named dailyGoalQuestions, not dailyGoalMinutes.
    expect(source.contains('dailyGoalQuestions'), isTrue,
        reason: 'OnboardingResult must expose dailyGoalQuestions.');
    expect(source.contains('dailyGoalMinutes'), isFalse,
        reason: 'dailyGoalMinutes must be renamed to dailyGoalQuestions.');
  });
}

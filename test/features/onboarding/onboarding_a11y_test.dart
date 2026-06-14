// a11y: the onboarding is the gateway — its selections (age, daily goal) were
// icon-only GestureDetectors with no Semantics, so a low-vision parent could not
// set them and the child could never start. Lock the named buttons.
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
}

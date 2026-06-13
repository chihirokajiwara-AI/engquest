// Guards the child-safe error fallback (app.dart friendlyErrorWidget, wired in
// bootstrap for release builds). If a widget throws during build, a child must
// see a calm message — never Flutter's grey/red default. The fallback itself
// must be robust (self-contained, no inherited-widget assumptions) and must not
// throw, or the error screen would itself error.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/app.dart';

void main() {
  testWidgets(
      'friendlyErrorWidget shows a calm message and does not itself throw',
      (tester) async {
    final details =
        FlutterErrorDetails(exception: Exception('simulated build failure'));

    // Pump it bare (no MaterialApp) — it must be self-contained, the way it
    // renders in place of a failed widget.
    await tester.pumpWidget(friendlyErrorWidget(details));

    expect(tester.takeException(), isNull,
        reason: 'the error fallback must not itself throw');
    expect(find.textContaining('うまく いかなかった'), findsOneWidget);
    expect(find.textContaining('もどってみてね'), findsOneWidget);
  });
}

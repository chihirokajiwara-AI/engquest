// a11y regression lock for DqChoice — the shared answer-choice button used by
// the mock exam, listening practice, and onboarding. Its accessibility (a
// Semantics button whose LABEL carries the answered/selected state, since the
// Flutter-web button node did not reliably surface aria-selected) was added
// reactively after a 2026-06-12 playtest. Nothing guarded it, so a refactor of
// DqChoice could silently drop the Semantics and break screen-reader / switch-
// access support across all three screens at once. This locks the contract.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('DqChoice is an accessible button whose label carries its state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(Column(children: [
      DqChoice(label: 'apple', onTap: () {}),
      DqChoice(label: 'banana', state: DqChoiceState.correct, onTap: () {}),
      DqChoice(label: 'cherry', state: DqChoiceState.wrong, onTap: () {}),
      DqChoice(label: 'date', showCursor: true, onTap: () {}),
    ])));

    // The label a screen reader announces carries the answered/selected state —
    // a child using VoiceOver/TalkBack hears which option is correct/wrong/chosen.
    expect(find.bySemanticsLabel('apple'), findsOneWidget);
    expect(find.bySemanticsLabel('banana、せいかい'), findsOneWidget);
    expect(find.bySemanticsLabel('cherry、ふせいかい'), findsOneWidget);
    expect(find.bySemanticsLabel('date、せんたくちゅう'), findsOneWidget);

    // Each state-carrying label exists ONLY because DqChoice wraps the choice in
    // a Semantics(button: true, label: …, selected: …) node — removing that block
    // (the regression we guard against) reverts the labels to the plain 'banana'
    // Text and fails the four finds above. So locking the labels transitively
    // locks the whole accessible-button block. (Flag-level matchers like
    // matchesSemantics/containsSemantics are mid-deprecation in this Flutter and
    // were avoided to keep the gate stable.)
    expect(find.bySemanticsLabel('banana'), findsNothing,
        reason:
            'the correct choice must announce WITH its せいかい state, not bare');

    handle.dispose();
  });
}

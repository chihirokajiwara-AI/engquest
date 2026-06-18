// test/features/quest/ui/dq_ui_semantics_test.dart
// Accessibility (#5): the shared dq_ui interactive widgets must expose a
// screen-reader button node (VoiceOver/TalkBack) — before this they had ZERO
// Semantics, so the whole app's tap targets were invisible to assistive tech.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  group('dq_ui interactive widgets — screen-reader semantics (#5)', () {
    testWidgets('DqButton exposes an enabled button with its label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DqButton(label: 'はじめる', onTap: () {})),
      ));
      // The node exists with the button's label → screen readers announce it.
      // (Widget sets button: true; matchesSemantics is avoided as it is brittle
      // across Flutter versions and --fatal-infos rejects the deprecated flag
      // accessors.)
      expect(find.bySemanticsLabel('はじめる'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('DqChoice announces the choice text + answered state',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            DqChoice(label: 'りんご', onTap: () {}),
            const DqChoice(label: 'みかん', state: DqChoiceState.correct),
            const DqChoice(label: 'ぶどう', state: DqChoiceState.wrong),
          ]),
        ),
      ));
      // Plain choice → just the text, as a button.
      expect(find.bySemanticsLabel('りんご'), findsOneWidget);
      // Answered states are spoken so a non-sighted child knows the outcome.
      expect(find.bySemanticsLabel('みかん、せいかい'), findsOneWidget);
      expect(find.bySemanticsLabel('ぶどう、ふせいかい'), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        'DqTile, DqReplayButton, AudioOptionButton are labelled buttons',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            DqTile(
                jp: '単語バトル', en: 'Word Battle', icon: Icons.bolt, onTap: () {}),
            DqReplayButton(label: 'もう いちど きく', onTap: () {}),
            AudioOptionButton(label: 'cat', onChoose: () {}),
          ]),
        ),
      ));
      expect(find.bySemanticsLabel('単語バトル Word Battle'), findsOneWidget);
      expect(find.bySemanticsLabel('もう いちど きく'), findsOneWidget);
      // The audio option hints that it can also be heard.
      expect(find.bySemanticsLabel(RegExp('cat')), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        'AudioOptionButton exposes a LISTEN action so AT users can preview without committing',
        (tester) async {
      // a11y core-loop guarantee: with excludeSemantics hiding the inner 🔊
      // GestureDetector, a screen-reader / switch child previously had NO way to
      // hear an option without committing. The label must announce the listen
      // affordance AND a separate custom action must back it (the default activate
      // commits; this action only previews).
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body:
              AudioOptionButton(label: 'cat', onAudio: () {}, onChoose: () {}),
        ),
      ));
      // The label announces the listen affordance — only when audio exists.
      expect(find.bySemanticsLabel(RegExp('おとを きく')), findsOneWidget);
      // …backed by a distinct custom action on the same node.
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('cat')));
      final listenId = CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'おとを きく'));
      expect(node.getSemanticsData().customSemanticsActionIds ?? const <int>[],
          contains(listenId),
          reason: 'a screen-reader child needs LISTEN separate from choose');
      handle.dispose();
    });
  });
}

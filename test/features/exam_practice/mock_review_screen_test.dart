// test/features/exam_practice/mock_review_screen_test.dart
// Smoke + behaviour for the post-mock 答え合わせ (review) screen (R3): it must
// render the items, mark correct vs the child's answer, and default to a
// wrong-only focus. This is the pedagogy loop the timed mock previously lacked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/listening_data.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/mock_exam.dart';
import 'package:engquest/features/exam_practice/pass/mock_review_screen.dart';

MockMcqItem _item(String id, int correct) => MockMcqItem(
      id: id,
      questionText: 'Question $id?',
      choices: const ['alpha', 'beta', 'gamma', 'delta'],
      correctIdx: correct,
      skill: EikenSkill.reading,
      sectionId: 'sec',
    );

void main() {
  final items = [
    _item('q1', 0), // will be answered correctly
    _item('q2', 1), // will be answered wrong
    _item('q3', 2), // will be left unanswered
  ];
  final answers = <String, int>{
    'q1': 0, // correct
    'q2': 3, // wrong
    // q3 unanswered
  };

  Widget harness() => MaterialApp(
        home: MockReviewScreen(
          items: items,
          answers: answers,
          gradeLabel: '英検2級',
        ),
      );

  testWidgets('renders the review without crashing and shows the score',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 1 of 3 correct.
    expect(find.text('正解（せいかい） 1 / 3'), findsOneWidget);
  });

  testWidgets(
      'defaults to wrong-only: shows the 2 missed items, not the correct one',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    // q2 (wrong) and q3 (unanswered) are review targets; q1 (correct) is hidden.
    expect(find.text('Question q2?'), findsOneWidget);
    expect(find.text('Question q3?'), findsOneWidget);
    expect(find.text('Question q1?'), findsNothing);
    // Verdict labels for the two missed items.
    expect(find.text('不正解'), findsOneWidget);
    expect(find.text('みかいとう'), findsOneWidget);
  });

  testWidgets(
      'toggling off wrong-only reveals every item including the correct',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('まちがいだけ'));
    await tester.pumpAndSettle();
    expect(find.text('Question q1?'), findsOneWidget);
    expect(find.text('Question q2?'), findsOneWidget);
    expect(find.text('Question q3?'), findsOneWidget);
  });

  testWidgets(
      'a missed LISTENING item reveals its transcript (read what you misheard)',
      (tester) async {
    // Pull a real listening item so the transcript lookup (by audioKey) resolves.
    final listening =
        kListeningItems['5']!.firstWhere((it) => it.choices.length == 4);
    final mcq = MockMcqItem(
      id: listening.audioKey,
      questionText: listening.question,
      choices: listening.choices,
      correctIdx: listening.correctIndex,
      skill: EikenSkill.listening,
      sectionId: '5_l',
    );
    // Answer it wrong so it shows in the default wrong-only review.
    final wrong = (listening.correctIndex + 1) % listening.choices.length;
    await tester.pumpWidget(MaterialApp(
      home: MockReviewScreen(
        items: [mcq],
        answers: {mcq.id: wrong},
        gradeLabel: '英検5級',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('🔊 スクリプト / Script'), findsOneWidget);
    // The first transcript line should be visible somewhere in the card.
    expect(
      find.textContaining(listening.transcripts.first.split('\n').first),
      findsWidgets,
    );
  });

  testWidgets('all-correct shows a celebratory empty-review message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MockReviewScreen(
        items: [_item('q1', 0)],
        answers: const {'q1': 0},
        gradeLabel: '英検5級',
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('全問正解'), findsOneWidget);
  });
}

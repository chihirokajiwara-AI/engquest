// Render coverage for the 見本解答 (model-answer) card added 2026-06-13. Drives the
// writing screen to the OFFLINE result phase (no network in flutter_test → the AI
// grade call fails fast → apiAvailable:false) and asserts the example-answer card:
//   (1) appears on the result screen,
//   (2) hides the model answer until the learner taps to reveal (attempt-first),
//   (3) shows the model answer text after the reveal tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/writing_practice_screen.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';

void main() {
  const writingSection = ExamSection(
    id: '3_w1',
    nameJa: '筆記4: ライティング（Eメール）',
    nameEn: 'Writing: Email Reply',
    type: ExamSectionType.writing,
    questionCount: 1,
    timeLimitMinutes: 15,
    description: 'Model-answer card test',
  );

  // A phrase that appears ONLY in 3_email_1's model answer, never in the learner
  // text below — so the reveal assertion is unambiguous.
  const modelOnlyPhrase = 'Thank you for your message';

  testWidgets('writing result shows a reveal-on-demand 見本解答 model answer',
      (tester) async {
    tester.view.physicalSize = const Size(440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: WritingPracticeScreen(eikenGrade: '3', section: writingSection),
    ));
    await tester.pump();

    // Write a valid-length answer (3_email_1 range is 15–25 words) that shares no
    // phrase with the model answer.
    await tester.enterText(
      find.byType(TextField),
      'I got a cute little kitten last week and she likes to drink milk '
      'and play with a small ball every day.',
    );
    await tester.pump();

    // Submit → offline result (AI call fails fast in the test harness).
    final submit = find.text('AIに採点してもらう  /  Get AI feedback');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The example-answer card is present...
    expect(find.textContaining('見本解答'), findsOneWidget,
        reason: 'the result screen should offer a 見本解答 example card');
    // ...but the model answer is hidden until the learner chooses to reveal it.
    expect(find.textContaining(modelOnlyPhrase), findsNothing,
        reason: 'model answer must not spoil before the reveal tap');

    await tester.tap(find.textContaining('見本（みほん）を 見る'));
    await tester.pumpAndSettle();

    expect(find.textContaining(modelOnlyPhrase), findsOneWidget,
        reason: 'tapping reveal must show the model answer text');
    expect(tester.takeException(), isNull);
  });
}

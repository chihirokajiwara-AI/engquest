// test/features/exam_practice/mock_exam_screen_test.dart
// Covers the playable フル模試: the mock engine (assemble + score) and that the
// screen renders its first question under the countdown without crashing (R3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/mock_exam_screen.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/mock_exam.dart';

void main() {
  group('MockExam engine', () {
    test('assembles a 5級 mock with reading + listening MCQ items', () {
      final exam = MockExamAssembler.assemble('5', seed: 1);
      expect(exam.grade, '5');
      expect(exam.mcqItems, isNotEmpty);
      // 5級 has no writing section.
      expect(exam.writingSlots, isEmpty);
      // Items carry only reading/listening skills for 5級.
      final skills = exam.mcqItems.map((i) => i.skill).toSet();
      expect(skills.contains(EikenSkill.writing), isFalse);
    });

    test('all-correct answers score higher readiness than all-wrong', () {
      final exam = MockExamAssembler.assemble('5', seed: 1);

      final allCorrect = <String, int>{
        for (final it in exam.mcqItems) it.id: it.correctIdx,
      };
      // Pick a deliberately wrong index for every item.
      final allWrong = <String, int>{
        for (final it in exam.mcqItems) it.id: (it.correctIdx + 1) % 4,
      };

      final hi = MockExamScorer.score(exam: exam, answers: allCorrect);
      final lo = MockExamScorer.score(exam: exam, answers: allWrong);

      expect(hi, isNotNull);
      expect(lo, isNotNull);
      expect(hi!.readinessPct, greaterThan(lo!.readinessPct));
      expect(hi.readinessPct, greaterThan(0));
    });
  });

  group('MockExamScreen', () {
    testWidgets('renders the first question and the countdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MockExamScreen(eikenGrade: '5', seed: 1)),
      );
      await tester.pump(); // one frame; periodic timer is active

      // Countdown clock (⏱ MM:SS) and the Next button must be present.
      expect(find.textContaining('⏱'), findsOneWidget);
      expect(find.textContaining('Next'), findsOneWidget);
      // Progress label "1 / N".
      expect(find.textContaining('1 / '), findsOneWidget);

      // Dispose the screen to cancel the periodic timer (avoids pending-timer
      // failure in the test harness).
      await tester.pumpWidget(const SizedBox());
    });
  });
}

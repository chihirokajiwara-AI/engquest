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

    test('reading items carry the passage/sentence, not just the instruction',
        () {
      // Regression: cloze items once rendered only "Choose the best word for
      // the blank." with no sentence to answer. Every reading item must now
      // include its passage text (composed above the instruction).
      final exam = MockExamAssembler.assemble('5', seed: 1);
      final reading =
          exam.mcqItems.where((i) => i.skill == EikenSkill.reading);
      expect(reading, isNotEmpty);
      for (final item in reading) {
        expect(item.questionText.contains('\n'), isTrue,
            reason: 'reading item ${item.id} is missing its passage text');
        expect(item.questionText.trim(), isNot('Choose the best word for the blank.'));
      }
    });

    test('injected writingAccuracy raises 3級 readiness (writing no longer 0%)',
        () {
      // 3級 has a writing section; the mock injects the learner's accumulated
      // writing accuracy. A non-zero writing score must raise readiness vs 0%.
      final exam = MockExamAssembler.assemble('3', seed: 1);
      expect(exam.writingSlots, isNotEmpty,
          reason: '3級 mock must include a writing slot');
      final answers = <String, int>{
        for (final it in exam.mcqItems) it.id: it.correctIdx,
      };
      // When writing HAS been practiced (writingAttempted>0), a higher writing
      // score must raise readiness vs a measured 0.
      final zeroWriting = MockExamScorer.score(
          exam: exam, answers: answers, writingAccuracy: 0.0, writingAttempted: 2);
      final goodWriting = MockExamScorer.score(
          exam: exam, answers: answers, writingAccuracy: 0.9, writingAttempted: 2);
      expect(zeroWriting, isNotNull);
      expect(goodWriting, isNotNull);
      expect(goodWriting!.readinessPct,
          greaterThan(zeroWriting!.readinessPct));

      // #36: UNATTEMPTED writing (writingAttempted==0) is flagged 未測定 (so the
      // PassMeter shows it as such, not a failed 0-bar), whereas a measured 0
      // (writingAttempted>0) is NOT. The banked readiness number is the same in
      // both cases — the honest difference is the 未測定 flag, and neither lets
      // the meter falsely read "ready".
      final unpracticedWriting = MockExamScorer.score(
          exam: exam, answers: answers, writingAccuracy: 0.0, writingAttempted: 0)!;
      expect(unpracticedWriting.unmeasuredSkills, contains(EikenSkill.writing));
      expect(zeroWriting.unmeasuredSkills, isNot(contains(EikenSkill.writing)));
      expect(unpracticedWriting.readinessPct, equals(zeroWriting.readinessPct));
    });

    test('CseEstimator marks skills with no data as unmeasured (not failed)',
        () {
      // 3級 tests reading + writing + listening. Give only reading data.
      final est = CseEstimator.estimate(
        grade: '3',
        accuracies: const [
          SkillAccuracy(
              skill: EikenSkill.reading, accuracy: 0.8, itemsAttempted: 10),
        ],
      );
      expect(est, isNotNull);
      expect(est!.unmeasuredSkills, contains(EikenSkill.writing));
      expect(est.unmeasuredSkills, contains(EikenSkill.listening));
      expect(est.unmeasuredSkills, isNot(contains(EikenSkill.reading)));
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

// test/features/exam_practice/writing_screen_smoke_test.dart
// R3 smoke test: pump WritingPracticeScreen and assert no render exception.
// No Firebase, no network, no ClaudeClient calls during build/initState (R4).

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
    description: 'Smoke test',
  );

  const summarySection = ExamSection(
    id: '2_w1',
    nameJa: '筆記4: ライティング（要約＋意見）',
    nameEn: 'Writing: Summary + Opinion',
    type: ExamSectionType.writing,
    questionCount: 2,
    timeLimitMinutes: 30,
    description: 'Smoke test',
  );

  const pre1Section = ExamSection(
    id: 'p1_w1',
    nameJa: '筆記4: ライティング（要約＋意見）',
    nameEn: 'Writing: Summary + Opinion',
    type: ExamSectionType.writing,
    questionCount: 2,
    timeLimitMinutes: 30,
    description: 'Smoke test',
  );

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('WritingPracticeScreen — smoke tests (R3)', () {
    testWidgets('grade 3 email — pumps without exception', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
        ),
      ));
      await tester.pump(); // one frame settle
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 3 email — shows prompt stimulus text', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
        ),
      ));
      await tester.pump();
      // The stimulus of 3_email_1 contains this string
      expect(find.textContaining('new pet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 3 email — shows underlined questions', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
        ),
      ));
      await tester.pump();
      // Both underlined questions must be visible (may appear in stimulus + list)
      expect(find.textContaining('kind of animal'), findsWidgets);
      expect(find.textContaining('like to eat'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 3 email — word count bar present', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
        ),
      ));
      await tester.pump();
      // Word count range displayed
      expect(find.textContaining('15〜25語'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 3 email — submit disabled when empty', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
        ),
      ));
      await tester.pump();
      // Submit button label shows the disabled-state instruction
      expect(find.textContaining('15語以上書いてから'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 2 summary — pumps without exception', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '2',
          section: summarySection,
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 2 summary — shows 45–55 word range', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '2',
          section: summarySection,
        ),
      ));
      await tester.pump();
      expect(find.textContaining('45〜55語'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre1 summary — pumps without exception', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: 'pre1',
          section: pre1Section,
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre1 summary — shows 60–70 word range', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: 'pre1',
          section: pre1Section,
        ),
      ));
      await tester.pump();
      expect(find.textContaining('60〜70語'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('previewPromptId forces specific prompt', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
          previewPromptId: '3_email_2',
        ),
      ));
      await tester.pump();
      // 3_email_2 stimulus contains "Japan next summer"
      expect(find.textContaining('Japan next summer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'unknown grade shows empty-state, no crash (no cross-grade fallback)',
        (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: 'unknown_grade',
          section: writingSection,
        ),
      ));
      await tester.pump();
      expect(find.textContaining('ライティングは'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('live word count updates on text input', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
        ),
      ));
      await tester.pump();

      // Type a short text
      await tester.enterText(
        find.byType(TextField),
        'Hello how are you doing today',
      );
      await tester.pump();

      // Should show 6-word count
      expect(find.textContaining('語数 / Word count: 6語'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('submit enabled at word-count minimum', (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(
          eikenGrade: '3',
          section: writingSection,
        ),
      ));
      await tester.pump();

      // Enter exactly 15 words
      const fifteenWords =
          'I have a cat she is black and she likes to eat fish every day';
      await tester.enterText(find.byType(TextField), fifteenWords);
      await tester.pump();

      // Count = 15: in range → button says "AIに採点してもらう"
      expect(find.textContaining('AIに採点してもらう'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('WritingPrompt data integrity', () {
    test('all prompts have non-empty stimulus', () {
      for (final p in kWritingPrompts) {
        expect(p.stimulus.isNotEmpty, isTrue,
            reason: '${p.id} has empty stimulus');
      }
    });

    // 2024-reform email format differs by grade (#41):
    //   • answer-mode (3級) → exactly 2 underlinedQuestions to ANSWER.
    //   • ask-mode (準2級)  → an underlinedTopic to ASK 2 questions about, and
    //                         NO underlinedQuestions (those would be a 3級 leak).
    test('email prompts match their grade format (answer vs ask)', () {
      for (final p
          in kWritingPrompts.where((p) => p.type == WritingTaskType.email)) {
        if (p.emailAsksQuestions) {
          expect(p.underlinedTopic, isNotNull,
              reason: '${p.id} (ask-mode) must name an underlined topic');
          expect(p.underlinedTopic!.trim(), isNotEmpty,
              reason: '${p.id} (ask-mode) underlined topic must be non-empty');
          expect(p.underlinedQuestions, isEmpty,
              reason: '${p.id} (ask-mode) must NOT list answerable questions '
                  '(that is the score-fatal 3級 format)');
        } else {
          expect(p.underlinedQuestions.length, equals(2),
              reason: '${p.id} (answer-mode) must have 2 underlined questions');
        }
      }
    });

    // #41 regression: 準2級 email must be ask-mode (the bug shipped it as 3級
    // answer-mode → a child practising the wrong task fails the real exam).
    test('all 準2級 (pre2) email prompts are ask-mode', () {
      final pre2Emails = kWritingPrompts.where(
          (p) => p.type == WritingTaskType.email && p.id.startsWith('pre2_'));
      expect(pre2Emails, isNotEmpty);
      for (final p in pre2Emails) {
        expect(p.emailAsksQuestions, isTrue,
            reason: '${p.id}: 準2級 must ASK 2 questions, not answer them');
      }
    });

    // 3級 email must remain answer-mode (do not over-correct the fix).
    test('all 3級 email prompts are answer-mode', () {
      final g3Emails = kWritingPrompts.where(
          (p) => p.type == WritingTaskType.email && p.id.startsWith('3_'));
      expect(g3Emails, isNotEmpty);
      for (final p in g3Emails) {
        expect(p.emailAsksQuestions, isFalse,
            reason: '${p.id}: 3級 must ANSWER the 2 underlined questions');
      }
    });

    test('all prompts have wordCountMin < wordCountMax', () {
      for (final p in kWritingPrompts) {
        expect(p.wordCountMin < p.wordCountMax, isTrue,
            reason:
                '${p.id}: min ${p.wordCountMin} must be < max ${p.wordCountMax}');
      }
    });

    test('email prompts have 3 rubric points', () {
      for (final p
          in kWritingPrompts.where((p) => p.type == WritingTaskType.email)) {
        expect(p.rubricPoints.length, equals(3),
            reason: '${p.id} must have 3 観点 (内容/語彙/文法)');
      }
    });

    test('summary and opinion prompts have 4 rubric points', () {
      // All non-email writing (summary + opinion, incl. 英検3級 意見論述) is scored
      // on 4 観点 (内容・構成・語彙・文法), 0–4 each = 16点満点 — official 英検 rubric.
      // (3_opinion was previously exempted here, enshrining a 3-観点 copy-paste bug.)
      for (final p
          in kWritingPrompts.where((p) => p.type != WritingTaskType.email)) {
        expect(p.rubricPoints.length, equals(4),
            reason: '${p.id} must have 4 観点 (内容/構成/語彙/文法)');
      }
    });

    test('prompts for grade 3 exist', () {
      expect(promptsForGrade('3').isNotEmpty, isTrue);
    });

    test('prompts for grade pre2 exist', () {
      expect(promptsForGrade('pre2').isNotEmpty, isTrue);
    });

    test('prompts for grade 2 exist', () {
      expect(promptsForGrade('2').isNotEmpty, isTrue);
    });

    test('prompts for grade pre1 exist', () {
      expect(promptsForGrade('pre1').isNotEmpty, isTrue);
    });

    // 準2級プラス (2025 new grade) writing was 準備中 — no pre2plus_ prompts. Now
    // its 要約 + 意見論述 prompts exist, so the writing section is no longer empty.
    test('prompts for grade pre2plus exist (要約 + 意見)', () {
      final p = promptsForGrade('pre2plus');
      expect(p, isNotEmpty);
      expect(p.any((q) => q.type == WritingTaskType.summary), isTrue);
      expect(p.any((q) => q.type == WritingTaskType.opinion), isTrue);
    });

    // P0-2 regression: 5級/4級 have NO writing section → empty (NOT cross-grade
    // opinion essays); "pre2" must not leak "pre2plus" prompts (prefix guard).
    test('grade 5 and 4 have NO writing prompts', () {
      expect(promptsForGrade('5'), isEmpty);
      expect(promptsForGrade('4'), isEmpty);
    });

    test('grade pre2 prompts exclude any pre2plus prompt', () {
      expect(
        promptsForGrade('pre2').any((p) => p.id.startsWith('pre2plus_')),
        isFalse,
      );
    });

    testWidgets('grade 5 writing screen shows honest empty-state, no crash',
        (tester) async {
      await tester.pumpWidget(wrap(
        const WritingPracticeScreen(eikenGrade: '5', section: writingSection),
      ));
      await tester.pump();
      expect(find.textContaining('ライティングは'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // 書き方のヒント structure scaffold (構成 is a scored 観点). Each task type must
  // return a non-empty, canonical 型 — and the opinion essay must carry the full
  // opinion→2-reasons→conclusion shape (4 steps).
  group('writingStructureGuide', () {
    for (final type in [WritingTaskType.summary, WritingTaskType.opinion]) {
      test('$type returns a non-empty, well-formed structure scaffold', () {
        final steps = writingStructureGuide(type);
        expect(steps, isNotEmpty);
        for (final s in steps) {
          expect(s.labelJa.trim(), isNotEmpty);
          expect(s.starter.trim(), isNotEmpty);
        }
      });
    }

    // 3級 answer-mode email has no single safe shared 型 → empty (better none
    // than a wrong one). 準2級 ask-mode has a SAFE generic 型 (answer friend's Q →
    // ask Q1 → ask Q2 → close) that names no answer. #41 grade-aware.
    test('email (answer-mode default) returns no shared scaffold', () {
      expect(writingStructureGuide(WritingTaskType.email), isEmpty);
    });

    test('email ask-mode (準2級) returns the answer→ask→ask→close scaffold', () {
      final steps = writingStructureGuide(WritingTaskType.email,
          emailAsksQuestions: true);
      expect(steps.length, equals(4));
      for (final s in steps) {
        expect(s.labelJa.trim(), isNotEmpty);
        expect(s.starter.trim(), isNotEmpty);
      }
      // Must cue ASKING (a question-mark starter), never an answer.
      expect(steps.any((s) => s.starter.contains('?')), isTrue);
    });

    test('opinion essay has the full opinion→2 reasons→conclusion shape', () {
      expect(writingStructureGuide(WritingTaskType.opinion).length, 4);
    });

    test('summary guide cues paraphrase, not copying', () {
      final joined = writingStructureGuide(WritingTaskType.summary)
          .map((s) => s.starter)
          .join();
      expect(joined.contains('コピー'), isTrue,
          reason: 'summary must warn against copy-verbatim (官製 rubric)');
    });
  });
}

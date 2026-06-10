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

    test('all email prompts have exactly 2 underlined questions', () {
      for (final p
          in kWritingPrompts.where((p) => p.type == WritingTaskType.email)) {
        expect(p.underlinedQuestions.length, equals(2),
            reason: '${p.id} must have 2 underlined questions');
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

    test('summary and opinion prompts have 4 rubric points for pre2+', () {
      for (final p in kWritingPrompts.where((p) =>
          p.type != WritingTaskType.email && !p.id.startsWith('3_opinion'))) {
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
}

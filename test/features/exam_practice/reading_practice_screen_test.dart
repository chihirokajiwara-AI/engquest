import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/reading_practice_screen.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';

void main() {
  const grade5Section = ExamSection(
    id: '5_r3',
    nameJa: '筆記3: 長文読解',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 4,
    timeLimitMinutes: 10,
    description: 'テスト用',
  );

  const grade4Section = ExamSection(
    id: '4_r4',
    nameJa: '筆記4: 長文の内容一致選択',
    nameEn: 'Reading 4: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 5,
    timeLimitMinutes: 10,
    description: 'テスト用',
  );

  const grade3Section = ExamSection(
    id: '3_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 10,
    timeLimitMinutes: 15,
    description: 'テスト用',
  );

  const pre2Section = ExamSection(
    id: 'p2_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 7,
    timeLimitMinutes: 20,
    description: 'テスト用',
  );

  const grade2Section = ExamSection(
    id: '2_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 12,
    timeLimitMinutes: 25,
    description: 'テスト用',
  );

  const grade2FillInSection = ExamSection(
    id: '2_r2',
    nameJa: '筆記2: 長文の語句空所補充',
    nameEn: 'Reading 2: Passage Fill-in',
    type: ExamSectionType.readingComprehension,
    questionCount: 6,
    timeLimitMinutes: 15,
    description: 'テスト用',
  );

  const pre1Section = ExamSection(
    id: 'p1_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 10,
    timeLimitMinutes: 25,
    description: 'テスト用',
  );

  const pre1FillInSection = ExamSection(
    id: 'p1_r2',
    nameJa: '筆記2: 長文の語句空所補充',
    nameEn: 'Reading 2: Passage Fill-in',
    type: ExamSectionType.readingComprehension,
    questionCount: 6,
    timeLimitMinutes: 15,
    description: 'テスト用',
  );

  Widget buildScreen(String grade, ExamSection section) {
    return MaterialApp(
      home: ReadingPracticeScreen(
        eikenGrade: grade,
        section: section,
      ),
    );
  }

  // Answer positions are now shuffled per session (positional answer-key-bias
  // fix), so locate a choice by its TEXT regardless of which slot it landed in.
  // A choice renders as "<n>. <answer>", so an anchored regex matches the choice
  // exactly and can never accidentally hit the passage body.
  Finder choice(String answer) => find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data != null &&
            RegExp('^\\d+\\. ${RegExp.escape(answer)}\$').hasMatch(w.data!),
        description: 'choice "$answer" at any position',
      );

  Future<void> answer(WidgetTester tester, String correct) async {
    await tester.tap(choice(correct));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
  }

  group('ReadingPracticeScreen', () {
    testWidgets('renders passage and question for grade 5', (tester) async {
      await tester.pumpWidget(buildScreen('5', grade5Section));
      await tester.pumpAndSettle();

      // Should show the title '長文読解'
      expect(find.text('長文読解'), findsOneWidget);
      // Should show passage type badge
      expect(find.text('NOTICE'), findsOneWidget);
      // Should show first question
      expect(find.text('When is the school festival?'), findsOneWidget);
      // Should show the answer choice (now at a shuffled position)
      expect(choice('On Saturday, November 15'), findsOneWidget);
    });

    testWidgets('selecting an answer highlights correct/wrong', (tester) async {
      await tester.pumpWidget(buildScreen('5', grade5Section));
      await tester.pumpAndSettle();

      // Tap correct answer (wherever it shuffled to)
      await tester.tap(choice('On Saturday, November 15'));
      await tester.pumpAndSettle();

      // Next button should appear
      expect(find.text('次へ'), findsOneWidget);
    });

    testWidgets('advances through questions and shows results', (tester) async {
      await tester.pumpWidget(buildScreen('5', grade5Section));
      await tester.pumpAndSettle();

      // Answer all 4 questions (2 passages × 2 questions). Tap whatever choice
      // is in slot 0 — we only need to advance, not be correct.
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('reading_choice_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('次へ'));
        await tester.pumpAndSettle();
      }

      // Should show results
      expect(find.text('戻る'), findsOneWidget);
    });

    testWidgets('grade 4 shows correct number of passages', (tester) async {
      await tester.pumpWidget(buildScreen('4', grade4Section));
      await tester.pumpAndSettle();

      // Grade 4 should show article type first
      expect(find.text('ARTICLE'), findsOneWidget);
      expect(find.text('Summer Camp'), findsOneWidget);
    });

    testWidgets('grade 3 has at least 10 questions total', (tester) async {
      await tester.pumpWidget(buildScreen('3', grade3Section));
      await tester.pumpAndSettle();

      // Grade 3 should show notice type first
      expect(find.text('NOTICE'), findsOneWidget);
      // Progress should show /10
      expect(find.textContaining('/10'), findsOneWidget);
    });

    testWidgets('pre-2 has at least 7 questions total', (tester) async {
      await tester.pumpWidget(buildScreen('pre2', pre2Section));
      await tester.pumpAndSettle();

      // Progress should show /7
      expect(find.textContaining('/7'), findsOneWidget);
    });

    testWidgets('grade 2 comprehension has 12 questions', (tester) async {
      await tester.pumpWidget(buildScreen('2', grade2Section));
      await tester.pumpAndSettle();

      // Progress should show /12
      expect(find.textContaining('/12'), findsOneWidget);
    });

    testWidgets('grade 2 fill-in shows correct title', (tester) async {
      await tester.pumpWidget(buildScreen('2', grade2FillInSection));
      await tester.pumpAndSettle();

      // Should show fill-in specific title
      expect(find.text('長文語句空所補充'), findsOneWidget);
      // Progress should show /6
      expect(find.textContaining('/6'), findsOneWidget);
    });

    testWidgets('pre-1 comprehension has 10 questions', (tester) async {
      await tester.pumpWidget(buildScreen('pre1', pre1Section));
      await tester.pumpAndSettle();

      // Progress should show /10
      expect(find.textContaining('/10'), findsOneWidget);
    });

    testWidgets('pre-1 fill-in shows correct title and count', (tester) async {
      await tester.pumpWidget(buildScreen('pre1', pre1FillInSection));
      await tester.pumpAndSettle();

      expect(find.text('長文語句空所補充'), findsOneWidget);
      expect(find.textContaining('/6'), findsOneWidget);
    });

    testWidgets('results show pass when >= 60%', (tester) async {
      await tester.pumpWidget(buildScreen('5', grade5Section));
      await tester.pumpAndSettle();

      // Answer all 4 correctly by their TEXT (positions are now shuffled).
      await answer(tester, 'On Saturday, November 15');
      await answer(tester, 'Sell rice balls');
      await answer(tester, 'A cat');
      await answer(tester, "On Yuki's bed");

      // Should show pass result
      expect(find.text('合格ライン到達！'), findsOneWidget);
      expect(find.text('4 / 4 正解 (100%)'), findsOneWidget);
    });
  });
}

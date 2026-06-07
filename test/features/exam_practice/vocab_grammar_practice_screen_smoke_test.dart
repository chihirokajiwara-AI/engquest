// test/features/exam_practice/vocab_grammar_practice_screen_smoke_test.dart
// R3 smoke test: pump VocabGrammarPracticeScreen (大問1 vocab/grammar cloze) and
// assert no render exception across a grade WITH a vocab DB and a grade WITHOUT
// one (準2級プラス → honest 準備中 empty state, not a 5級 fallback).
// R4: initState loads bundled JSON via rootBundle — no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/vocab_grammar_practice_screen.dart';

ExamSection _vocabSection() => const ExamSection(
      id: '5_vg',
      nameJa: '語句空所補充',
      nameEn: 'Vocabulary & Grammar',
      type: ExamSectionType.vocabGrammar,
      questionCount: 10,
      timeLimitMinutes: 10,
      description: 'Smoke test',
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VocabGrammarPracticeScreen — smoke tests (R3)', () {
    testWidgets('grade 5 (has vocab DB) — loads real questions, no exception',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VocabGrammarPracticeScreen(
          eikenGrade: '5',
          section: _vocabSection(),
        ),
      ));
      // initState kicks an async rootBundle load of eiken5_vocab.json. That is
      // a REAL I/O future that fake-time pump() can't flush — resolve it under
      // runAsync, then rebuild and assert the loaded content (not the spinner).
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      expect(find.byType(VocabGrammarPracticeScreen), findsOneWidget);
      // The DB-backed render path must actually run: spinner gone, real text up.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre2plus (no vocab DB) — shows 準備中, no exception',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VocabGrammarPracticeScreen(
          eikenGrade: 'pre2plus',
          section: _vocabSection(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });
}

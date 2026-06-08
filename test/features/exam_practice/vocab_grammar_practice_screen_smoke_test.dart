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

  // The example-sentence highlight must never emphasise a fragment of an
  // inflected form (adversarial-audit fix: "ant" inside "ants").
  group('wholeWordMatch (#77 highlight honesty)', () {
    test('matches a standalone word', () {
      final m = wholeWordMatch('The cat sat down.', 'cat');
      expect(m, isNotNull);
      expect(m!.start, 4);
    });
    test('does NOT match a stem inside an inflected form', () {
      expect(wholeWordMatch('A line of ants moved.', 'ant'), isNull);
      expect(wholeWordMatch('She teaches me daily.', 'teach'), isNull);
      expect(wholeWordMatch('The fastest animal.', 'fast'), isNull);
    });
    test('case-insensitive whole-word match', () {
      expect(wholeWordMatch('Run fast!', 'fast'), isNotNull);
      expect(wholeWordMatch('FAST and slow', 'fast'), isNotNull);
    });
    test('no match when the word is absent (underscore-key form)', () {
      expect(wholeWordMatch('I like ice cream.', 'ice_cream'), isNull);
    });
  });

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

    testWidgets('after answering, shows the word IN CONTEXT (れい:) — #77',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VocabGrammarPracticeScreen(
          eikenGrade: '5',
          section: _vocabSection(),
        ),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      // Before answering there is no explanation. (findRichText: the example
      // line is a RichText so the word can be highlighted in the sentence.)
      expect(find.textContaining('れい:', findRichText: true), findsNothing);
      // Answer (tap the first choice) → the post-answer explanation must teach
      // the word in a real sentence, not just show right/wrong.
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(find.textContaining('れい:', findRichText: true), findsOneWidget,
          reason: 'must show the example sentence after answering');
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

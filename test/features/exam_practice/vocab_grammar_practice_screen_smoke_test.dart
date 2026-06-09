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

  // A cloze must never leak the answer via a suffix/compound (#78).
  group('hasCleanCloze (#78 no-leak filter)', () {
    test('accepts a clean single whole-word occurrence', () {
      expect(hasCleanCloze('The cat sat on the mat.', 'cat'), isTrue);
    });
    test('rejects an inflected form (would blank "(  )s")', () {
      expect(hasCleanCloze('A line of ants moved along.', 'ant'), isFalse);
      expect(hasCleanCloze('She teaches every morning.', 'teach'), isFalse);
    });
    test('rejects a compound substring leak (snow in snowman)', () {
      expect(hasCleanCloze('We built a snowman in the snow.', 'snow'), isFalse);
    });
    test('rejects a hyphenated compound (E-commerce leaks "E-")', () {
      expect(hasCleanCloze('E-commerce platforms changed retail.', 'commerce'),
          isFalse);
      expect(hasCleanCloze('It is water-soluble, so it dissolves.', 'soluble'),
          isFalse);
    });
    test('rejects a double whole-word occurrence', () {
      expect(hasCleanCloze('I see a dog and a dog.', 'dog'), isFalse);
    });
    test('rejects multi-word / underscore keys', () {
      expect(hasCleanCloze('I like ice cream a lot.', 'ice cream'), isFalse);
      expect(hasCleanCloze('Say thank you to her.', 'thank_you'), isFalse);
    });
    test('rejects when the word is absent', () {
      expect(hasCleanCloze('A short sentence.', 'elephant'), isFalse);
    });
  });

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
    // #40: assert REAL content, not just "no spinner + some Text". A weak
    // assertion let pre2plus silently serve ZERO questions while the test passed
    // (#34) — the same class of bug can hit any grade if its bank degrades or its
    // distractor pool can't field a single clean item. So every grade with a
    // vocab DB must prove its 大問1 actually builds questions (debugCorrectChoices
    // non-empty), not merely that the spinner cleared.
    for (final grade in ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1']) {
      testWidgets('grade $grade builds REAL 大問1 questions, not an empty '
          'shell (#40)', (tester) async {
        // Tall surface so the cloze + choices lay out (default 800x600 is short).
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: VocabGrammarPracticeScreen(
            eikenGrade: grade,
            section: _vocabSection(),
          ),
        ));
        // Skeleton-first (#52): fire the post-frame _loadQuestions, then flush the
        // REAL rootBundle I/O under runAsync (fake-time pump can't), then rebuild.
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 700)));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing,
            reason: 'grade $grade: load must finish (no stuck spinner)');
        final state =
            tester.state(find.byType(VocabGrammarPracticeScreen)) as dynamic;
        expect((state.debugCorrectChoices as List), isNotEmpty,
            reason: 'grade $grade: 大問1 must build real questions, not an '
                'empty/準備中 shell');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('after answering, shows the word IN CONTEXT (れい:) — #77',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VocabGrammarPracticeScreen(
          eikenGrade: '5',
          section: _vocabSection(),
        ),
      ));
      await tester.pump(); // fire the post-frame _loadQuestions (#52)
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      // Before answering there is no explanation. (findRichText: the example
      // line is a RichText so the word can be highlighted in the sentence.)
      expect(find.textContaining('れい:', findRichText: true), findsNothing);
      // Answer (tap the first choice) → the post-answer explanation must teach
      // the word in a real sentence, not just show right/wrong.
      await tester.tap(find.byKey(const ValueKey('vg_choice_0')));
      await tester.pump();
      expect(find.textContaining('れい:', findRichText: true), findsOneWidget,
          reason: 'must show the example sentence after answering');
      // The reveal now teaches the wrong choices too (#97): each distractor is a
      // real same-grade word with a meaning, so the panel lists them.
      expect(find.text('ほかの言葉 / Other choices'), findsOneWidget,
          reason: 'reveal must gloss the other choices as a vocab lesson');
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre2plus now has a vocab DB — builds real questions, '
        'not 準備中 (#34)', (tester) async {
      // Tall surface so the cloze + 4 choices lay out on-screen (default 800x600
      // is too short), mirroring the record-path harness.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: VocabGrammarPracticeScreen(
          eikenGrade: 'pre2plus',
          section: _vocabSection(),
        ),
      ));
      // Skeleton-first (#52): fire the post-frame _loadQuestions, then flush the
      // REAL rootBundle I/O under runAsync (fake-time pump can't), then rebuild.
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // pre2plus is no longer a 準備中 grade — its derived B1 bank fills 大問1.
      expect(find.textContaining('準備中'), findsNothing,
          reason: 'pre2plus now serves a real 大問1 bank (#34)');
      // Proof the questions actually built (layout-independent): the screen's
      // correct-answer list is non-empty.
      final state =
          tester.state(find.byType(VocabGrammarPracticeScreen)) as dynamic;
      expect((state.debugCorrectChoices as List), isNotEmpty,
          reason: 'derived pre2plus bank must yield real 大問1 questions');
      expect(find.byType(InkWell), findsWidgets,
          reason: 'the question must render tappable answer choices');
    });
  });
}

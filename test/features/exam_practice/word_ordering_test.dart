// test/features/exam_practice/word_ordering_test.dart
//
// Content invariant for 英検 大問3 語句整序 (task #12). Every item MUST be the
// authentic exam shape: exactly 5 語句 (chunks) forming one sentence, with no
// duplicate chunk (a duplicate would let a wrong arrangement string-match the
// answer and silently grade as correct). Guards against future drift.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/word_ordering_practice_screen.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';

void main() {
  // 語句整序 (大問3) exists only at 英検 5級 / 4級 / 3級.
  for (final grade in ['5', '4', '3']) {
    test('英検$grade級 word-ordering items are authentic 大問3 (5 chunks, unique)',
        () {
      final items = wordOrderingChunksForTest(grade);
      expect(items, isNotEmpty, reason: 'no items for grade $grade');

      for (final chunks in items) {
        // Authentic 英検 大問3 = exactly five 語句.
        expect(chunks.length, 5, reason: 'grade $grade: $chunks');

        // No duplicate chunk → the exact-match grader cannot be fooled by a
        // string tie between two different arrangements.
        expect(chunks.toSet().length, chunks.length,
            reason: 'duplicate chunk in grade $grade: $chunks');

        // Each chunk is non-empty and already trimmed (no stray spaces that
        // would break the join-and-compare grader).
        for (final c in chunks) {
          expect(c.trim(), isNotEmpty, reason: 'empty chunk in $chunks');
          expect(c, c.trim(), reason: 'untrimmed chunk "$c" in $chunks');
        }

        // Regression guard for the exact defect class content-QA caught
        // (2026-06-07): a standalone movable sentence-adverb or a bare
        // coordinator as its own chunk creates a SECOND valid order that the
        // exact-match grader would wrongly reject. Bundle them
        // ("very much", "X and Y" as one chunk) instead of leaving them loose.
        // NOTE: only words that are movable/coordinating AS A STANDALONE chunk.
        // Excludes e.g. "so"/"not" which also serve as locked intensifiers
        // ("not so difficult").
        const movable = {
          'now',
          'usually',
          'sometimes',
          'often',
          'always',
          'today',
          'yesterday',
          'tomorrow',
          'and',
          'or',
        };
        for (final c in chunks) {
          expect(movable.contains(c.toLowerCase()), isFalse,
              reason: 'standalone movable/coordinator chunk "$c" risks a '
                  'second valid order in $chunks');
        }
      }
    });
  }

  test('grades without 大問3 fall back to a valid 5-chunk set', () {
    // The screen routes any non-5/4 grade to the 3級 bank; assert it is still
    // structurally valid so nothing renders a malformed item.
    final fallback = wordOrderingChunksForTest('pre2');
    expect(fallback, isNotEmpty);
    for (final chunks in fallback) {
      expect(chunks.length, 5);
    }
  });

  testWidgets(
      'completing a problem shows the 2番目/4番目 exam reveal with no overflow at 320px',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 2400); // 320 logical @ 2x
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: WordOrderingPracticeScreen(
        eikenGrade: '4',
        section: ExamSection(
          id: '4_p3',
          nameJa: '筆記3: 語句の並びかえ',
          nameEn: 'Word Ordering',
          type: ExamSectionType.wordOrdering,
          questionCount: 10,
          timeLimitMinutes: 10,
          description: 'test',
        ),
      ),
    ));
    await tester.pump();

    // Place all 5 chunks of the first 4級 item in the correct order. Each chunk
    // text is unique, and once placed it leaves the bank, so tapping each word
    // once fills the answer area.
    for (final chunk in wordOrderingChunksForTest('4').first) {
      await tester.tap(find.text(chunk));
      await tester.pump();
    }

    // Grade it → the exam-format reveal should appear.
    await tester.tap(find.text('答え合わせ'));
    await tester.pump();

    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('📝 本番（英検）の問い方'), findsOneWidget);
    expect(find.textContaining('2番目'), findsWidgets);
    expect(find.textContaining('4番目'), findsWidgets);
    // The grammar-rule reveal (#106) must also render — teaches WHY the order is
    // correct, not just the answer. Every 5/4級 item carries a whyExplanation.
    expect(find.text('💡 ルール / なぜこの順番？'), findsOneWidget);
  });

  // Teach-why completeness (flaw-hunt 2026-06-14): the 3級 (default) items used to
  // ship with NO whyExplanation, so a child got no grammar teaching on them. Lock
  // that EVERY word-ordering item, in every grade that has the section, teaches
  // WHY — a future item added without an explanation must fail here.
  for (final grade in ['5', '4', '3']) {
    test('every 英検$grade word-ordering item has a non-empty whyExplanation',
        () {
      final whys = wordOrderingWhyForTest(grade);
      expect(whys, isNotEmpty);
      for (var i = 0; i < whys.length; i++) {
        final w = whys[i];
        expect(w != null && w.trim().isNotEmpty, isTrue,
            reason: '英検$grade item #$i has no whyExplanation — it would teach '
                'the child nothing about the grammar pattern');
      }
    });
  }
}

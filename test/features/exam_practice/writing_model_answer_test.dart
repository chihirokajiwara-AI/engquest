// Contract for 見本解答 (writing model answers, added 2026-06-13): a model answer
// is a content exemplar the learner imitates, so it must itself obey the prompt's
// official word-count range — an out-of-range example would teach the wrong length.
// Locks every authored modelAnswer (current and future) to its prompt's range.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/writing_practice_screen.dart';

void main() {
  final withModel =
      kWritingPrompts.where((p) => p.modelAnswer != null).toList();

  test('at least one prompt has an authored model answer', () {
    expect(withModel, isNotEmpty);
  });

  for (final p in withModel) {
    test(
        '${p.id} model answer is within its ${p.wordCountMin}-'
        '${p.wordCountMax} word range', () {
      final words = p.modelAnswer!.trim().split(RegExp(r'\s+')).length;
      expect(words, inInclusiveRange(p.wordCountMin, p.wordCountMax),
          reason: '${p.id} model answer is $words words — outside the official '
              '${p.wordCountMin}-${p.wordCountMax} range a learner should imitate');
    });

    test('${p.id} model answer has no unescaped-apostrophe risk markers', () {
      // Authored apostrophe-free (single-quoted Dart strings); guard the style.
      expect(p.modelAnswer!.contains("'"), isFalse,
          reason: '${p.id} model answer contains a raw apostrophe');
    });
  }
}

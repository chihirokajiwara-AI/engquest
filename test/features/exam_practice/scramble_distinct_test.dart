// Gate (flaw-hunt 2026-06-13): a 語句整序 (word-ordering) puzzle must never be
// presented already-solved. A plain ..shuffle() reproduces the correct order
// ≈1/120 of the time for 5 chunks (~4% per 5-item session), letting a child tap
// ①②③④⑤ in order and "pass" with zero comprehension — inflating the reading
// 合格率. scrambleDistinct() guarantees a genuinely scrambled start, while still
// terminating on degenerate inputs where every permutation looks identical.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/choice_shuffle.dart';

void main() {
  test('distinct 5-chunk order is NEVER returned identical (1000 trials)', () {
    final correct = ['I', 'want', 'to', 'play', 'soccer'];
    for (var i = 0; i < 1000; i++) {
      final s = scrambleDistinct(correct, Random(i));
      expect(s.join(' '), isNot(correct.join(' ')),
          reason: 'trial $i produced an already-solved puzzle');
      // Same multiset — only the order moved, no chunk lost/duplicated.
      expect([...s]..sort(), [...correct]..sort());
    }
  });

  test('all-identical chunks terminate (no infinite loop) and preserve items',
      () {
    // Degenerate: every permutation joins identically — must return, not hang.
    final same = ['a', 'a', 'a', 'a', 'a'];
    final s = scrambleDistinct(same, Random(1));
    expect(s, same);
  });

  test('a single-item or empty list is returned unchanged', () {
    expect(scrambleDistinct(['x']), ['x']);
    expect(scrambleDistinct(<String>[]), <String>[]);
  });
}

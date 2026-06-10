// Listening answer-key de-skew (flaw-hunt R7).
//
// The authored listening pool clusters the correct answer at position 2 (~40%,
// position 4 nearly unused at ~3%). Reading + conversation already shuffle at
// load (#79), but listening did NOT — so a child who always taps choice 1 scored
// ~40% on listening with zero comprehension, inflating the CSE 合格率 (the SOLE
// honest value of the product). This locks that the mock assembler now shuffles
// listening choices: the correct-answer position must be ~uniform, not clustered.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/pass/mock_exam.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';

void main() {
  test('MockExamAssembler shuffles listening keys — de-skews the ~40% cluster',
      () {
    // Grade 2 has the largest listening pool → most samples.
    final counts = List<int>.filled(4, 0);
    var total = 0;
    for (var seed = 0; seed < 40; seed++) {
      final mock = MockExamAssembler.assemble('2', seed: seed);
      for (final m
          in mock.mcqItems.where((m) => m.skill == EikenSkill.listening)) {
        if (m.correctIdx >= 0 && m.correctIdx < 4) counts[m.correctIdx]++;
        total++;
      }
    }

    expect(total, greaterThan(200),
        reason: 'need a real sample of drawn listening items');
    final maxShare = counts.reduce(max) / total;
    // Unshuffled, one position holds ~40%. A genuine shuffle lands every
    // position near 25%; allow slack but well under the authored skew.
    expect(maxShare, lessThan(0.34),
        reason: 'listening answer key still clustered — shuffle not applied '
            '(distribution: $counts / $total)');
  });
}

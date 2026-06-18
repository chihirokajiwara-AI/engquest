// Reading answer-key de-skew (flaw-hunt, 2026-06-18).
//
// The authored reading pool carries a strong, undisclosed position bias (e.g.
// 準1級 idx0 ≈ 17/31 = 55%, 3級 idx0 = 13/30). Listening + the standalone
// reading screen already shuffle at load (#79), but the MOCK reading path did
// NOT — so a child who always taps the same column banked most of the reading
// 合格圏 with zero comprehension, inflating the CSE 合格率 (the SOLE honest value
// of the product). This locks that the mock assembler now shuffles reading
// choices too: the correct-answer position must be ~uniform, not clustered.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/pass/mock_exam.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';

void main() {
  test('MockExamAssembler shuffles reading keys — de-skews the authored bias',
      () {
    // Sample every grade so the total is large and the worst-skewed grades
    // (準1級 idx0 ≈ 55%) are represented.
    const grades = ['5', '4', '3', 'p2', 'p2p', '2', 'p1'];
    final counts = List<int>.filled(4, 0);
    var total = 0;
    for (final grade in grades) {
      for (var seed = 0; seed < 20; seed++) {
        final mock = MockExamAssembler.assemble(grade, seed: seed);
        for (final m
            in mock.mcqItems.where((m) => m.skill == EikenSkill.reading)) {
          if (m.correctIdx >= 0 && m.correctIdx < 4) counts[m.correctIdx]++;
          total++;
        }
      }
    }

    expect(total, greaterThan(200),
        reason: 'need a real sample of drawn reading items');
    final maxShare = counts.reduce(max) / total;
    // Unshuffled, one position holds 40%+. A genuine shuffle lands every
    // position near 25%; allow slack but well under the authored skew.
    expect(maxShare, lessThan(0.34),
        reason: 'reading answer key still clustered — shuffle not applied '
            '(distribution: $counts / $total)');
  });
}

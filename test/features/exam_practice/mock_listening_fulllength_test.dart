// Gate (post-#22 listening expansion, 2026-06-13): the 模試 (mock exam) draws its
// listening section from kListeningItems and is capped at min(target, pool size).
// Before the expansion the upper-grade pools were far short (準2級 had 8 vs a target
// of 30), so the mock's listening section was silently short — an inauthentic
// simulation that also under-counted the listening contribution to the CSE estimate.
// Now every pool meets its official 大問 target, so every grade's mock listening
// section must be full-length. This locks that against a future content deletion.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/pass/mock_exam.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';

void main() {
  const grades = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];

  for (final g in grades) {
    test('英検$g mock exam listening section is full-length (meets 大問 target)',
        () {
      final mock = MockExamAssembler.assemble(g, seed: 7);
      final target = mock.targetCounts[EikenSkill.listening] ?? 0;
      final available = mock.availableCounts[EikenSkill.listening] ?? 0;
      expect(target, greaterThan(0), reason: '$g has no listening target');
      expect(available, greaterThanOrEqualTo(target),
          reason: '$g mock listening is short: $available/$target — a pool '
              'fell below its official 大問 target');

      // The assembled MCQ list must actually carry a full listening section.
      final listeningItems =
          mock.mcqItems.where((m) => m.skill == EikenSkill.listening).toList();
      expect(listeningItems.length, greaterThanOrEqualTo(target),
          reason:
              '$g mock serves only ${listeningItems.length}/$target listening items');

      // Teach-why must survive assembly: every listening item has an authored
      // 解説 (listening_explanation_coverage_test), so every assembled listening
      // MockMcqItem must carry it into the 模試review — it used to be dropped.
      for (final m in listeningItems) {
        expect(
            m.explanation != null && m.explanation!.trim().isNotEmpty, isTrue,
            reason: '$g mock listening item ${m.id} lost its 解説 in assembly '
                '(模試review would teach nothing for it)');
      }
    });
  }
}

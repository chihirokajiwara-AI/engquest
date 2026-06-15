// test/features/exam_practice/pre2_listening_structure_test.dart
// Structural gate for 英検準2級 listening (#62 fix, 2026-06-15).
//
// Official 準2級 listening structure (verified eiken.or.jp/eiken/en/grades/grade_p2/,
// 2026-06-15):
//   第1部: 会話の応答文選択 — 10 questions
//   第2部: 会話の内容一致  — 10 questions
//   第3部: 文の内容一致    — 10 questions
//   Total: 30 questions
//
// Previously the pool had only 2 parts (Part1=会話内容一致, Part2=文内容一致) and
// was MISSING the authentic 第1部 (応答文選択).  This test locks the corrected
// 3-part structure so a future edit cannot silently revert it.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';

void main() {
  group('準2級 listening — 3-part structure (official eiken.or.jp spec)', () {
    final allPre2 = kListeningItems['pre2'] ?? const [];

    test('pre2 pool is non-empty', () {
      expect(allPre2, isNotEmpty,
          reason: 'kListeningItems must contain an entry for "pre2"');
    });

    test('pre2 pool has items with all three parts (1, 2, 3)', () {
      final parts = allPre2.map((it) => it.part).toSet();
      expect(parts, containsAll([1, 2, 3]),
          reason: '準2級 listening must have parts 1, 2 and 3 (official: '
              '第1部応答文選択/第2部会話内容一致/第3部文内容一致); found parts: $parts');
    });

    test('pre2 第1部 (会話の応答文選択) has ≥10 items', () {
      final part1 = allPre2.where((it) => it.part == 1).toList();
      expect(part1.length, greaterThanOrEqualTo(10),
          reason: '第1部 must have ≥10 items (official count = 10); '
              'found ${part1.length}');
    });

    test('pre2 第2部 (会話の内容一致) has ≥10 items', () {
      final part2 = allPre2.where((it) => it.part == 2).toList();
      expect(part2.length, greaterThanOrEqualTo(10),
          reason: '第2部 must have ≥10 items (official count = 10); '
              'found ${part2.length}');
    });

    test('pre2 第3部 (文の内容一致) has ≥10 items', () {
      final part3 = allPre2.where((it) => it.part == 3).toList();
      expect(part3.length, greaterThanOrEqualTo(10),
          reason: '第3部 must have ≥10 items (official count = 10); '
              'found ${part3.length}');
    });

    test('pre2 total pool meets the official 30-question target', () {
      expect(allPre2.length, greaterThanOrEqualTo(30),
          reason:
              '準2級 pool must cover the 30-question official listening section '
              '(10+10+10); found ${allPre2.length}');
    });

    test('pre2 第1部 items use dialogueQA questionType', () {
      final part1 = allPre2.where((it) => it.part == 1).toList();
      for (final item in part1) {
        expect(item.questionType, ListeningQuestionType.dialogueQA,
            reason: '準2級 第1部 item ${item.audioKey} should be dialogueQA '
                '(会話の応答文選択 style)');
      }
    });

    test('pre2 第1部 audio keys use the lp2_resp_ prefix', () {
      final part1 = allPre2.where((it) => it.part == 1).toList();
      for (final item in part1) {
        expect(item.audioKey.startsWith('lp2_resp_'), isTrue,
            reason: '第1部 item ${item.audioKey} should use lp2_resp_ prefix '
                '(keeps audio namespace distinct from Part2/3 lp2_p1_/lp2_p2_ keys)');
      }
    });

    test('all pre2 items carry the correct grade tag', () {
      for (final item in allPre2) {
        expect(item.grade, 'pre2',
            reason: 'item ${item.audioKey} has wrong grade "${item.grade}"');
      }
    });

    test('pre2 第1部 audio keys are unique within the grade', () {
      final part1Keys =
          allPre2.where((it) => it.part == 1).map((it) => it.audioKey).toList();
      expect(part1Keys.toSet().length, equals(part1Keys.length),
          reason: '第1部 contains duplicate audio keys: $part1Keys');
    });
  });
}

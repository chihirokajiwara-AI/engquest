// test/features/exam_practice/eiken_exam_config_test.dart
// Guards EikenExamDef.totalMinutes against the OFFICIAL 一次試験 durations
// (筆記/リーディング・ライティング + リスニング), verified vs eiken.or.jp June 2026.
// This is shown to the child as 「試験時間 X分」 on the exam hub AND drives the
// mock-exam countdown, so a wrong value misstates the real test length. The app
// previously stored 筆記-only / pre-2024-reform times (e.g. 3級 50 vs the
// post-reform 65+25=90) — this locks the corrected, full-一次 values.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';

void main() {
  // grade → official 一次 total minutes (R/W筆記 + リスニング約N), eiken.or.jp 2026-06.
  const official = <String, int>{
    '5': 45, // 25 + ~20
    '4': 65, // 35 + ~30
    '3': 90, // 65 + ~25 (post-2024 reform)
    'pre2': 105, // 80 + ~25 (post-2024 reform)
    'pre2plus': 110, // 85 + ~25
    '2': 110, // 85 + ~25
    'pre1': 120, // 90 + ~30
  };

  test('totalMinutes matches the official 英検 一次試験 duration per grade', () {
    for (final entry in official.entries) {
      final def = kEikenExams[entry.key];
      expect(def, isNotNull, reason: 'missing exam def for ${entry.key}');
      expect(def!.totalMinutes, entry.value,
          reason: '英検${entry.key} 一次 should be ${entry.value}分 '
              '(was likely a 筆記-only / pre-reform value)');
    }
  });

  // grade → official post-2024-reform 大問1 (短文の語句空所補充 / vocab) question
  // count. The exam hub shows this number AND the vocab-cloze screen generates
  // exactly this many items, so a stale value both misstates the real exam and
  // over/under-serves practice. The 2024 reform cut 準1級 25→18, 2級 20→17,
  // 準2級 20→15; 3/4/5級 大問1 unchanged at 15. Verified eiken.or.jp +
  // 旺文社/eslclub 2024renewal (reading totals 準1 41→31, 2級 38→31, 準2 37→29;
  // 準2 reconciles only as 15+5+2+7=29, matching this app's mock reading target),
  // accessed 2026-06-09. 準2級プラス has no standalone 大問1 vocab section here.
  const vocabQ1 = <String, int>{
    '5': 15,
    '4': 15,
    '3': 15,
    'pre2': 15,
    '2': 17,
    'pre1': 18,
  };

  test('大問1 (vocabGrammar) question count matches the official post-2024 spec',
      () {
    for (final entry in vocabQ1.entries) {
      final def = kEikenExams[entry.key];
      expect(def, isNotNull, reason: 'missing exam def for ${entry.key}');
      final vocab = def!.sections
          .where((s) => s.type == ExamSectionType.vocabGrammar)
          .toList();
      expect(vocab, isNotEmpty,
          reason: '英検${entry.key} should have a 大問1 vocab section');
      expect(vocab.first.questionCount, entry.value,
          reason: '英検${entry.key} 大問1 should be ${entry.value}問 '
              '(post-2024 reform; 準1級 was a stale pre-reform 25)');
    }
  });
}

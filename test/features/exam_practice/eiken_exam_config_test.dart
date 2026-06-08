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
}

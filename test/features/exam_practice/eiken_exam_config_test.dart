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

  // grade → official number of WRITING tasks (筆記 ライティング). Post-2024 reform:
  // 5級/4級 have NO writing; 3級/準2級 = Eメール + 意見論述 (2); 準2級プラス/2級/準1級
  // = 要約 + 意見論述 (2). The exam hub shows this count and mock_exam/cse_model
  // already weight writing as 2 for these grades, so a config saying 1 (as 3級 did)
  // both misstates the exam and contradicts the app's own scoring. Verified
  // eiken.or.jp + docs/design/EIKEN-MASTERY-AND-GAPS-2026-06-06.json, 2026-06-09.
  const writingTasks = <String, int>{
    '5': 0,
    '4': 0,
    '3': 2,
    'pre2': 2,
    'pre2plus': 2,
    '2': 2,
    'pre1': 2,
  };

  test('writing task count matches the official post-2024 spec per grade', () {
    for (final entry in writingTasks.entries) {
      final def = kEikenExams[entry.key];
      expect(def, isNotNull, reason: 'missing exam def for ${entry.key}');
      final writingCount = def!.sections
          .where((s) => s.type == ExamSectionType.writing)
          .fold<int>(0, (sum, s) => sum + s.questionCount);
      expect(writingCount, entry.value,
          reason: '英検${entry.key} writing should be ${entry.value}題 '
              '(5/4級=なし; 3級〜準1級=2題). 3級 was a stale 1.');
    }
  });

  // grade → official total 筆記 READING-skill question count (大問1〜4: 語句空所補充
  // + 会話空所 + 語句整序 + 長文内容一致). SETTLED grades 5/4/3 are locked here, plus
  // 準1級 (#137): 大問1=18 + 大問2=6 + 大問3=7 = 31, matching the official post-2024
  // count — 大問3 was a stale 10 (over-stating the section); fixing it to 7 settled
  // the pre1 total. 準2級〜2級 reading sections still sum off official pending content
  // re-author (#60/#108), tracked by mock_exam/reading-pool targets, not pinned here.
  // 4級 was a stale 30 (大問4=5) — this guard would have caught it.
  // Verified eiken.or.jp: 5級=25, 4級=35, 3級=30, 準1級=31 (post-2024). 2026-06-11.
  const readingTotal = <String, int>{'5': 25, '4': 35, '3': 30, 'pre1': 31};
  const readingTypes = {
    ExamSectionType.vocabGrammar,
    ExamSectionType.conversationComplete,
    ExamSectionType.wordOrdering,
    ExamSectionType.readingComprehension,
  };

  test('筆記 reading-skill total matches official for the settled grades 5/4/3',
      () {
    for (final entry in readingTotal.entries) {
      final def = kEikenExams[entry.key];
      expect(def, isNotNull, reason: 'missing exam def for ${entry.key}');
      final total = def!.sections
          .where((s) => readingTypes.contains(s.type))
          .fold<int>(0, (sum, s) => sum + s.questionCount);
      expect(total, entry.value,
          reason: '英検${entry.key} 筆記 reading total should be ${entry.value}問 '
              '(大問1〜4). 4級 was a stale 30 (大問4 was 5, should be 10).');
    }
  });
}

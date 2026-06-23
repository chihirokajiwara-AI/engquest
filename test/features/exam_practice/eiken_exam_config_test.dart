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
  // + 会話空所 + 語句整序 + 長文内容一致). ALL 7 grades now pinned (準2 closed via
  // Task#32, which added its missing 大問3). Post-2024-reform official totals
  // (eiken.or.jp 2024renewal + 旺文社/eslclub, verified 2026-06-09/14):
  //   5=25, 4=35 (was a stale 30 — 大問4 was 5, should be 10), 3=30,
  //   準2=29 (15+5+2+7), 準2プラス=31 (17+6+8), 2級=31 (17+6+8, was 38),
  //   準1=31 (18+6+7, was 41 — 大問3 was a stale 10).
  // 3級 correctly has NO 語句整序 (verified: 語句整序 is 5級/4級 only); its reading
  // is 15+5+10=30. 2級/準2プラス STRUCTURE is correct here; only their content
  // QUALITY re-author is pending (#108), which this count test does not gate.
  const readingTotal = <String, int>{
    '5': 25,
    '4': 35,
    '3': 30,
    'pre2': 29,
    'pre2plus': 31,
    '2': 31,
    'pre1': 31,
  };
  const readingTypes = {
    ExamSectionType.vocabGrammar,
    ExamSectionType.conversationComplete,
    ExamSectionType.wordOrdering,
    ExamSectionType.readingComprehension,
  };

  test('筆記 reading-skill total matches official post-2024 for ALL 7 grades',
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

  // #60/Task#32: the 準2級 大問3 長文の語句空所補充 used to be MISSING — the config
  // went vocab→conv→内容一致, skipping a whole 大問 a real test has. Lock that it
  // exists with the post-2024-reform count (2 blanks; 大問3B 設問28-30 was removed).
  test('準2級 has the 大問3 長文の語句空所補充 section (2 blanks, post-reform)', () {
    final pre2 = kEikenExams['pre2']!;
    final fillIn =
        pre2.sections.where((s) => s.nameJa.contains('長文の語句空所補充')).toList();
    expect(fillIn, hasLength(1),
        reason: '準2 大問3 長文の語句空所補充 missing — a whole 大問 was unpracticeable');
    expect(fillIn.first.questionCount, 2,
        reason: 'post-2024 reform 準2 大問3 = 2 blanks (大問3B 設問28-30 removed)');
    expect(fillIn.first.id, 'pre2_r3',
        reason:
            'sectionId drives the _pre2FillIn passage in the reading screen');
  });

  // CEFR labels are shown to children + parents (exam-hub tile + grade-selector
  // card) and are cross-checkable against the official MEXT / eiken.or.jp table.
  // Lock each grade's CEFR so a regression (e.g. 準2級 wrongly = 'B1' = one band
  // too high; 2級 is B1) can't silently ship. Verified vs eiken.or.jp 2026-06-23.
  test('each grade CEFR label matches the official 英検 correspondence', () {
    const expected = {
      '5': 'A1',
      '4': 'A1-A2',
      '3': 'A2',
      'pre2': 'A2', // 準2級 = A2 (NOT B1 — that is 2級)
      'pre2plus': 'A2', // 準2級プラス CSE range A1-A2, pass score in the A2 band
      '2': 'B1-B2',
      'pre1': 'B2',
    };
    expected.forEach((grade, cefr) {
      expect(kEikenExams[grade]?.cefrLevel, cefr,
          reason: '$grade CEFR must be $cefr (official 英検↔CEFR table); a wrong '
              'band misrepresents what the certification attests to a parent.');
    });
  });
}

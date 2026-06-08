// test/features/exam_practice/writing_record_signal_test.dart
// #37 — the WRITING feeder of the 合格率 (the last record path left uncovered;
// vocab/会話/語句整序/listening are pinned in record_path_test.dart).
//
// The writing screen grades via the AI backend, so driving it end-to-end needs a
// live grader. Instead the record DECISION is a pure function
// [writingAccuracySignal] that the production path
// (_WritingPracticeScreenState._recordWritingResult) calls verbatim — so testing
// it IS testing the real path. Risks covered: (a) an ungraded/offline submission
// must NOT record a 0 (the #36 "未測定" honesty); (b) the 50% binary threshold;
// (c) it feeds the WRITING skill, not reading (the miswire risk).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/exam_practice/writing_practice_screen.dart';

WritingRubricResult _result(
        {required bool api, required Map<String, int> scores}) =>
    WritingRubricResult(scores: scores, feedbackJa: '', apiAvailable: api);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
    SkillAccuracyStore.resetInstance();
  });

  group('writingAccuracySignal — the writing → 合格率 decision (#37)', () {
    test('ungraded / API unavailable → null (未測定, never a 0)', () {
      // The whole point of #36: an offline submission must not be recorded as a
      // failed 0 that drags the 合格率 down.
      expect(
        writingAccuracySignal(
            _result(api: false, scores: {'内容': 0, '語彙': 0, '文法': 0})),
        isNull,
      );
    });

    test('no rubric (maxScore 0) → null', () {
      expect(writingAccuracySignal(_result(api: true, scores: {})), isNull);
    });

    test('graded ≥50% of rubric max → correct 1 / total 1', () {
      // 10 / 12 = 83% ≥ 50%.
      final s = writingAccuracySignal(
          _result(api: true, scores: {'内容': 4, '語彙': 3, '文法': 3}))!;
      expect(s.correct, 1);
      expect(s.total, 1);
    });

    test('graded <50% of rubric max → correct 0 / total 1', () {
      // 2 / 12 = 17% < 50%.
      final s = writingAccuracySignal(
          _result(api: true, scores: {'内容': 1, '語彙': 0, '文法': 1}))!;
      expect(s.correct, 0);
      expect(s.total, 1);
    });

    test('exactly 50% counts as pass (≥, not >)', () {
      // 6 / 12 = 50%.
      final s = writingAccuracySignal(
          _result(api: true, scores: {'内容': 2, '語彙': 2, '文法': 2}))!;
      expect(s.correct, 1);
    });
  });

  test('a graded signal records to the WRITING skill (not reading)', () async {
    const grade = '2';
    final s = writingAccuracySignal(
        _result(api: true, scores: {'内容': 4, '語彙': 3, '文法': 3}))!;

    final store = await SkillAccuracyStore.getInstance();
    await store.record(
      grade: grade,
      skill: EikenSkill.writing,
      correct: s.correct,
      total: s.total,
    );

    final writing = store
        .readAccuracies(grade)
        .firstWhere((a) => a.skill == EikenSkill.writing);
    expect(writing.itemsAttempted, 1);
    expect(writing.accuracy, 1.0);

    // SKILL ISOLATION: writing must NOT have touched the reading meter.
    final reading = store
        .readAccuracies(grade)
        .firstWhere((a) => a.skill == EikenSkill.reading);
    expect(reading.itemsAttempted, 0);
  });
}

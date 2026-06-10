// test/features/exam_practice/pass/skill_accuracy_store_test.dart
// Unit tests for SkillAccuracyStore.
//
// Verifies:
//   1. record() accumulates correct + total across multiple calls
//   2. readAccuracies() maps stored data to List<SkillAccuracy> correctly
//   3. Empty / no-data paths return zero-accuracy SkillAccuracy (guarded)
//   4. hasAnyData() returns false for a fresh grade, true after recording
//   5. resetGrade() zeroes stored counts for the given grade
//   6. record() with total=0 is a no-op
//   7. accuracy is clamped to [0,1] when correct > total (defensive)
//   8. readAccuracies returns all three EikenSkill values
//
// Uses SharedPreferences.setMockInitialValues({}) so no platform channels are
// needed (pure unit test, no Flutter widget test overhead).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';

void main() {
  setUp(() {
    // Reset singletons before each test so state doesn't bleed between tests.
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
    SkillAccuracyStore.resetInstance();
  });

  // ── 1. record accumulates across multiple calls ─────────────────────────────

  test('record: accumulates correct and total across two sessions', () async {
    final store = await SkillAccuracyStore.getInstance();

    await store.record(
        grade: 'pre1', skill: EikenSkill.reading, correct: 7, total: 10);
    await store.record(
        grade: 'pre1', skill: EikenSkill.reading, correct: 8, total: 10);

    final accuracies = store.readAccuracies('pre1');
    final reading = accuracies.firstWhere((a) => a.skill == EikenSkill.reading);

    expect(reading.itemsAttempted, equals(20));
    // 15 correct / 20 total = 0.75
    expect(reading.accuracy, closeTo(0.75, 0.001));
    expect(reading.attempted, isTrue);
  });

  // ── 2. readAccuracies maps stored data correctly ─────────────────────────────

  test('readAccuracies: returns correct SkillAccuracy for each skill',
      () async {
    final store = await SkillAccuracyStore.getInstance();

    await store.record(
        grade: '2', skill: EikenSkill.reading, correct: 9, total: 10);
    await store.record(
        grade: '2', skill: EikenSkill.writing, correct: 1, total: 2);
    await store.record(
        grade: '2', skill: EikenSkill.listening, correct: 6, total: 10);

    final accuracies = store.readAccuracies('2');

    final r = accuracies.firstWhere((a) => a.skill == EikenSkill.reading);
    final w = accuracies.firstWhere((a) => a.skill == EikenSkill.writing);
    final l = accuracies.firstWhere((a) => a.skill == EikenSkill.listening);

    expect(r.accuracy, closeTo(0.9, 0.001));
    expect(r.itemsAttempted, equals(10));
    expect(w.accuracy, closeTo(0.5, 0.001));
    expect(w.itemsAttempted, equals(2));
    expect(l.accuracy, closeTo(0.6, 0.001));
    expect(l.itemsAttempted, equals(10));
  });

  // ── 3. Empty / no-data paths — guarded, zero accuracy ────────────────────────

  test('readAccuracies: returns zero accuracy for skills with no data',
      () async {
    final store = await SkillAccuracyStore.getInstance();

    final accuracies = store.readAccuracies('3');

    expect(accuracies.length, equals(3));
    for (final a in accuracies) {
      expect(a.itemsAttempted, equals(0));
      expect(a.accuracy, equals(0.0));
      expect(a.attempted, isFalse);
    }
  });

  // ── 4. hasAnyData ─────────────────────────────────────────────────────────────

  test('hasAnyData: false for fresh grade, true after recording', () async {
    final store = await SkillAccuracyStore.getInstance();

    expect(store.hasAnyData('4'), isFalse);

    await store.record(
        grade: '4', skill: EikenSkill.listening, correct: 5, total: 10);

    expect(store.hasAnyData('4'), isTrue);
    // Other grades unaffected
    expect(store.hasAnyData('5'), isFalse);
  });

  // ── 5. resetGrade zeroes counts ───────────────────────────────────────────────

  test('resetGrade: clears counts for the given grade only', () async {
    final store = await SkillAccuracyStore.getInstance();

    await store.record(
        grade: 'pre2', skill: EikenSkill.reading, correct: 8, total: 10);
    await store.record(
        grade: 'pre2', skill: EikenSkill.listening, correct: 7, total: 10);
    await store.record(
        grade: '3', skill: EikenSkill.reading, correct: 6, total: 10);

    await store.resetGrade('pre2');

    expect(store.hasAnyData('pre2'), isFalse);
    // Grade '3' data unaffected
    expect(store.hasAnyData('3'), isTrue);

    final pre2Accuracies = store.readAccuracies('pre2');
    for (final a in pre2Accuracies) {
      expect(a.itemsAttempted, equals(0));
    }
  });

  // ── 6. record with total=0 is a no-op ─────────────────────────────────────────

  test('record: total=0 is a no-op', () async {
    final store = await SkillAccuracyStore.getInstance();

    await store.record(
        grade: '5', skill: EikenSkill.reading, correct: 0, total: 0);

    expect(store.hasAnyData('5'), isFalse);
  });

  // ── 7. accuracy is clamped to [0,1] ──────────────────────────────────────────

  test('record: correct clamped to total if it exceeds total', () async {
    final store = await SkillAccuracyStore.getInstance();

    // Passing correct > total (should not happen, but we guard it).
    await store.record(
        grade: '5', skill: EikenSkill.listening, correct: 15, total: 10);

    final accuracies = store.readAccuracies('5');
    final l = accuracies.firstWhere((a) => a.skill == EikenSkill.listening);

    // correct is clamped to total=10, accuracy = 10/10 = 1.0
    expect(l.accuracy, closeTo(1.0, 0.001));
    expect(l.itemsAttempted, equals(10));
  });

  // ── 8. readAccuracies always returns all three skills ─────────────────────────

  test('readAccuracies: always returns all three EikenSkill values', () async {
    final store = await SkillAccuracyStore.getInstance();

    // Record only one skill
    await store.record(
        grade: 'pre1', skill: EikenSkill.writing, correct: 3, total: 4);

    final accuracies = store.readAccuracies('pre1');

    expect(accuracies.length, equals(3));
    final skills = accuracies.map((a) => a.skill).toSet();
    expect(
        skills,
        containsAll([
          EikenSkill.reading,
          EikenSkill.writing,
          EikenSkill.listening,
        ]));

    // Only writing has data
    final w = accuracies.firstWhere((a) => a.skill == EikenSkill.writing);
    expect(w.itemsAttempted, equals(4));
    expect(w.accuracy, closeTo(0.75, 0.001));

    final r = accuracies.firstWhere((a) => a.skill == EikenSkill.reading);
    expect(r.itemsAttempted, equals(0));
  });

  // ── 9. CseEstimator integration: store output feeds CseEstimator cleanly ─────

  test('readAccuracies output is valid input for CseEstimator.estimate()',
      () async {
    final store = await SkillAccuracyStore.getInstance();

    await store.record(
        grade: '3', skill: EikenSkill.reading, correct: 8, total: 10);
    await store.record(
        grade: '3', skill: EikenSkill.writing, correct: 2, total: 3);
    await store.record(
        grade: '3', skill: EikenSkill.listening, correct: 7, total: 10);

    final accuracies = store.readAccuracies('3');
    final estimate = CseEstimator.estimate(grade: '3', accuracies: accuracies);

    expect(estimate, isNotNull);
    expect(estimate!.readinessPct, greaterThan(0.0));
    expect(estimate.readinessPct, lessThanOrEqualTo(100.0));
    expect(estimate.totalScore, greaterThan(0));
    expect(estimate.grade, equals('3'));
  });
}

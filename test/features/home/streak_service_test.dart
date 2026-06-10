// test/features/home/streak_service_test.dart
// Unit tests for StreakService streak logic.
//
// Uses SharedPreferences.setMockInitialValues so PreferencesService resolves.
// Each test resets the singleton so they are fully isolated.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/home/streak_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
  });

  test('First session sets streak to 1', () async {
    final service = StreakService();
    final state = await service.recordStudySession();
    expect(state.currentStreak, 1);
    expect(state.todayCount, 1);
  });

  test('Two sessions on same day do not double-count streak', () async {
    final service = StreakService();
    await service.recordStudySession();
    final state = await service.recordStudySession();
    // Streak stays 1, but todayCount increments.
    expect(state.currentStreak, 1);
    expect(state.todayCount, 2);
  });

  // #123 — load() must show the TRUE streak, not a stale value, after a lapse.
  String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  test('lapsed streak (last study 14 days ago) loads as 0 + streakBroken',
      () async {
    final now = DateTime(2026, 6, 10);
    SharedPreferences.setMockInitialValues({
      'streak_current': 9,
      'streak_last_study_date': iso(now.subtract(const Duration(days: 14))),
    });
    PreferencesService.resetInstance();
    final state = await StreakService().load(now: now);
    expect(state.currentStreak, 0,
        reason: 'a broken streak must not show stale 9');
    expect(state.streakBroken, isTrue);
  });

  test('alive streak (studied yesterday) loads the real value, not broken',
      () async {
    final now = DateTime(2026, 6, 10);
    SharedPreferences.setMockInitialValues({
      'streak_current': 9,
      'streak_last_study_date': iso(now.subtract(const Duration(days: 1))),
    });
    PreferencesService.resetInstance();
    final state = await StreakService().load(now: now);
    expect(state.currentStreak, 9);
    expect(state.streakBroken, isFalse);
  });

  test('studied today → streak alive', () async {
    final now = DateTime(2026, 6, 10);
    SharedPreferences.setMockInitialValues({
      'streak_current': 3,
      'streak_last_study_date': iso(now),
    });
    PreferencesService.resetInstance();
    final state = await StreakService().load(now: now);
    expect(state.currentStreak, 3);
    expect(state.streakBroken, isFalse);
  });

  test('StreakState.studiedOn returns false for unset bits', () {
    const state = StreakState(
      currentStreak: 1,
      weeklyBits: 0,
      todayCount: 0,
    );
    for (int i = 0; i < 7; i++) {
      expect(state.studiedOn(i), isFalse);
    }
  });

  test('StreakState.studiedOn returns true for set bits', () {
    // Bits 0 (Mon) and 4 (Fri) set.
    const bits = (1 << 0) | (1 << 4);
    const state = StreakState(
      currentStreak: 2,
      weeklyBits: bits,
      todayCount: 1,
    );
    expect(state.studiedOn(0), isTrue); // Monday
    expect(state.studiedOn(4), isTrue); // Friday
    expect(state.studiedOn(1), isFalse); // Tuesday
    expect(state.studiedOn(3), isFalse); // Thursday
  });

  test('load() returns zero state when no data stored', () async {
    final service = StreakService();
    final state = await service.load();
    expect(state.currentStreak, 0);
    expect(state.weeklyBits, 0);
    expect(state.todayCount, 0);
  });

  test('recordStudySession sets today weekday bit', () async {
    final service = StreakService();
    final state = await service.recordStudySession();
    final todayBit = DateTime.now().weekday - 1;
    expect(state.studiedOn(todayBit), isTrue);
  });

  test('load() returns previously recorded state', () async {
    final service = StreakService();
    await service.recordStudySession();
    // Create a fresh service instance (same prefs backing store).
    final service2 = StreakService();
    final state = await service2.load();
    expect(state.currentStreak, 1);
    expect(state.todayCount, 1);
  });

  // ── Daily-goal ring (きょうの目標) ──────────────────────────────────────────

  test('default daily goal is kDefaultDailyGoal and starts empty', () async {
    final service = StreakService();
    final state = await service.load();
    expect(state.dailyGoal, kDefaultDailyGoal);
    expect(state.problemsToday, 0);
    expect(state.goalMet, isFalse);
    expect(state.remainingToGoal, kDefaultDailyGoal);
  });

  test('recordProgress accumulates today and computes remaining', () async {
    final service = StreakService();
    await service.recordProgress(4);
    final state = await service.recordProgress(3);
    expect(state.problemsToday, 7);
    expect(state.remainingToGoal, kDefaultDailyGoal - 7);
    expect(state.goalMet, isFalse);
    expect(state.goalRatio, closeTo(7 / kDefaultDailyGoal, 1e-9));
  });

  test('recordProgress marks goalMet once the target is reached', () async {
    final service = StreakService();
    final state = await service.recordProgress(kDefaultDailyGoal + 2);
    expect(state.goalMet, isTrue);
    expect(state.remainingToGoal, 0);
    expect(state.goalRatio, 1.0);
  });

  test('progress resets when the calendar day rolls over', () async {
    final service = StreakService();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await service.recordProgress(8, now: yesterday);
    // A fresh day → load reports 0, not yesterday's 8.
    final today = await service.load();
    expect(today.problemsToday, 0);
    // And recording today starts from 0, not 8.
    final afterToday = await service.recordProgress(2);
    expect(afterToday.problemsToday, 2);
  });

  test('recordProgress ignores negative counts', () async {
    final service = StreakService();
    final state = await service.recordProgress(-5);
    expect(state.problemsToday, 0);
  });

  test('goalMet never true on a zero/empty goal (honesty guard)', () {
    const s = StreakState(
      currentStreak: 0,
      weeklyBits: 0,
      todayCount: 0,
      problemsToday: 0,
      dailyGoal: 0,
    );
    // 0 >= 0 must NOT celebrate 達成.
    expect(s.goalMet, isFalse);
  });

  test('recordStudySession returns a complete snapshot incl. daily fields',
      () async {
    final service = StreakService();
    await service.recordProgress(3);
    final state = await service.recordStudySession();
    // The streak-session result must carry the already-recorded daily progress,
    // not silently reset it to the field default.
    expect(state.problemsToday, 3);
    expect(state.dailyGoal, kDefaultDailyGoal);
  });

  // recordExamHabit is the helper every exam-practice screen calls on session
  // end — it makes the streak/daily-goal reflect ALL 英検 practice, not just the
  // FSRS battle (the engagement spine was behaviourally dead elsewhere before).
  test('recordExamHabit advances the streak + adds problems to the daily goal',
      () async {
    recordExamHabit(5);
    // Fire-and-forget (unawaited) — let the writes settle before asserting.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final state = await StreakService().load();
    expect(state.currentStreak, greaterThanOrEqualTo(1),
        reason: 'a completed exam session must mark today a study day');
    expect(state.problemsToday, 5,
        reason: 'the answered count must feed the daily-goal ring');
  });

  test('recordExamHabit(0) is a no-op (no credit for an empty session)',
      () async {
    recordExamHabit(0);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final state = await StreakService().load();
    expect(state.currentStreak, 0);
    expect(state.problemsToday, 0);
  });
}

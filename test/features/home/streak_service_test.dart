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

  // Display freshness on a pure load() — recordStudySession resets weekly dots /
  // today-count only when the child STUDIES; load() must not show stale activity.

  test('load() in a NEW week shows an empty weekly calendar, not last week\'s',
      () async {
    // Last study: Wed 2026-06-03 (week of Mon 06-01), full week of dots set.
    // Now: Wed 2026-06-10 (week of Mon 06-08) — a different week.
    final now = DateTime(2026, 6, 10);
    SharedPreferences.setMockInitialValues({
      'streak_current': 5,
      'streak_weekly_bits': 127, // all 7 days "studied" last week
      'streak_today_count': 4,
      'streak_last_study_date': '2026-06-03',
    });
    PreferencesService.resetInstance();
    final state = await StreakService().load(now: now);
    expect(state.weeklyBits, 0,
        reason: 'a new week must not display last week\'s weekday dots');
    expect(state.todayCount, 0, reason: 'no sessions today yet');
  });

  test('recordStudySession in a NEW week clears last week\'s dots (#125)',
      () async {
    // Two-weeks-ago last study with a full dot row; studying TODAY must reset the
    // dots to only today — never OR last week\'s 127 into this week. Pre-#125 the
    // write path used a different constant (`>= 7`) than the display path (`!= 0`)
    // for the same "new week" rule; both now share _isNewWeek so they cannot
    // diverge (and it compares Monday DATES, so a DST week can\'t desync them).
    // This locks the write-path reset, which previously had no test.
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'streak_current': 5,
      'streak_weekly_bits': 127, // all 7 days "studied" two weeks ago
      'streak_today_count': 4,
      'streak_last_study_date': iso(now.subtract(const Duration(days: 14))),
    });
    PreferencesService.resetInstance();
    final state = await StreakService().recordStudySession();
    expect(state.weeklyBits, 1 << (now.weekday - 1),
        reason:
            'a new-week study session must clear last week, not OR into it');
  });

  test('load() a NEW day in the SAME week keeps the dots, resets today-count',
      () async {
    // Last study: Tue 06-09; now: Wed 06-10 — same week (Mon 06-08).
    final now = DateTime(2026, 6, 10);
    SharedPreferences.setMockInitialValues({
      'streak_current': 3,
      'streak_weekly_bits': 1 << 1, // Tuesday bit
      'streak_today_count': 3,
      'streak_last_study_date': '2026-06-09',
    });
    PreferencesService.resetInstance();
    final state = await StreakService().load(now: now);
    expect(state.weeklyBits, 1 << 1,
        reason: 'same-week dots stay — Tuesday was genuinely studied');
    expect(state.studiedOn(1), isTrue);
    expect(state.todayCount, 0,
        reason: 'yesterday\'s sessions are not today\'s');
  });

  test('load() the SAME day preserves weekly dots and today-count', () async {
    final now = DateTime(2026, 6, 10);
    SharedPreferences.setMockInitialValues({
      'streak_current': 3,
      'streak_weekly_bits': 1 << 2, // Wednesday bit
      'streak_today_count': 2,
      'streak_last_study_date': '2026-06-10',
    });
    PreferencesService.resetInstance();
    final state = await StreakService().load(now: now);
    expect(state.weeklyBits, 1 << 2);
    expect(state.todayCount, 2);
  });

  // ── Daily goal honours the onboarding choice ───────────────────────────────
  // Regression (flaw-hunt 2026-06-14): the onboarding goal-picker wrote
  // onboarding_goal_minutes, but nothing ever wrote streak_daily_goal, so the
  // ring always showed kDefaultDailyGoal regardless of the parent's choice.

  test('dailyGoal falls back to the onboarding goal when no explicit goal set',
      () async {
    SharedPreferences.setMockInitialValues({'onboarding_goal_minutes': 25});
    PreferencesService.resetInstance();
    final state = await StreakService().load();
    expect(state.dailyGoal, 25,
        reason: "the parent's onboarding goal must drive the ring");
  });

  test('an explicit streak_daily_goal takes precedence over onboarding',
      () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_goal_minutes': 25,
      'streak_daily_goal': 15,
    });
    PreferencesService.resetInstance();
    final state = await StreakService().load();
    expect(state.dailyGoal, 15);
  });

  test('dailyGoal is the default when neither goal is set', () async {
    final state = await StreakService().load();
    expect(state.dailyGoal, kDefaultDailyGoal);
  });

  test('recordStudySession also reports the onboarding-derived goal', () async {
    SharedPreferences.setMockInitialValues({'onboarding_goal_minutes': 30});
    PreferencesService.resetInstance();
    final state = await StreakService().recordStudySession();
    expect(state.dailyGoal, 30);
  });

  // In-app goal editor (parent dashboard, flaw-hunt 2026-06-14): setDailyGoal
  // persists the explicit goal, which drives the home ring and overrides the
  // onboarding proxy. Previously the parent's daily-goal pick was setState-only
  // (lost on close, never connected to the ring).

  test('setDailyGoal persists and drives the home ring (load + current)',
      () async {
    final svc = StreakService();
    await svc.setDailyGoal(30);
    expect(await svc.currentDailyGoal(), 30);
    expect((await svc.load()).dailyGoal, 30,
        reason: 'the explicit goal must drive the home ring');
  });

  test('an explicit setDailyGoal overrides the onboarding proxy', () async {
    SharedPreferences.setMockInitialValues({'onboarding_goal_minutes': 15});
    PreferencesService.resetInstance();
    await StreakService().setDailyGoal(25);
    expect((await StreakService().load()).dailyGoal, 25);
  });

  test('setDailyGoal clamps to a sane range', () async {
    final svc = StreakService();
    await svc.setDailyGoal(99999);
    expect(await svc.currentDailyGoal(), lessThanOrEqualTo(200));
    await svc.setDailyGoal(0);
    expect(await svc.currentDailyGoal(), greaterThanOrEqualTo(1));
  });

  // Lost-update gate (gamification flaw-hunt 2026-06-19): recordProgress is a
  // read-modify-write of the shared 'streak_problems_today' key, fired UNAWAITED
  // from both battle (_recordDailyHabit) and exam (recordExamHabitAndGet) session
  // ends. Without serialization, two concurrent calls read the same baseline and
  // the last write clobbers the other → the daily-goal ring under-counts and the
  // child is told「あと N問」when they already met today's goal. Fire several
  // concurrent recordProgress calls (distinct instances, like the real call
  // sites) and assert EVERY problem is counted. (Pre-fix this collapses to the
  // last writer's count.)
  test('concurrent recordProgress calls do not lost-update the daily count',
      () async {
    final today = DateTime(2026, 6, 19, 10);
    final futures = <Future<StreakState>>[
      for (var i = 0; i < 8; i++) StreakService().recordProgress(5, now: today),
    ];
    await Future.wait(futures);

    final state = await StreakService().load(now: today);
    expect(state.problemsToday, 8 * 5,
        reason: 'all 8 concurrent +5 writes must accumulate (no lost-update)');
  });

  test('concurrent recordStudySession calls keep todayCount exact', () async {
    final futures = <Future<StreakState>>[
      for (var i = 0; i < 6; i++) StreakService().recordStudySession(),
    ];
    await Future.wait(futures);

    final state = await StreakService().load();
    expect(state.todayCount, 6,
        reason: 'six same-day sessions = todayCount 6 (no lost-update)');
    expect(state.currentStreak, 1,
        reason: 'same-day sessions never inflate the streak');
  });
}

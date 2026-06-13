// lib/features/home/streak_service.dart
// ENG Quest — Daily Streak Tracking Service
//
// Tracks consecutive study days using SharedPreferences.
// Keys:
//   streak_last_study_date  : ISO-8601 date string (yyyy-MM-dd) of last study
//   streak_current          : int — current consecutive streak
//   streak_weekly_bits      : int — 7-bit bitmask, bit 0 = Monday, bit 6 = Sunday
//   streak_daily_goal       : int — questions target (mirrors onboarding_goal_minutes as proxy)
//   streak_today_count      : int — sessions completed today
//
// Streak logic:
//   - recordStudySession() called after any battle/exam completion
//   - If today is the same as lastStudyDate → no change to streak (already counted)
//   - If today is exactly one day after lastStudyDate → streak++
//   - If today is 2+ days after lastStudyDate → streak resets to 1
//   - New user with no lastStudyDate → streak starts at 1

import 'dart:async';

import 'package:engquest/core/storage/preferences_service.dart';

// ── Streak state ──────────────────────────────────────────────────────────────

/// Immutable snapshot of the current streak state.
class StreakState {
  /// Current consecutive day streak.
  final int currentStreak;

  /// Bit-mask of the current week's study days.
  /// Bit 0 = Monday, bit 6 = Sunday (ISO weekday - 1).
  final int weeklyBits;

  /// Number of sessions completed today.
  final int todayCount;

  /// Number of practice questions ATTEMPTED today (resets at midnight). This is
  /// a deliberate practice-VOLUME signal, not a mastery one: spaced repetition
  /// works through repeated exposure, so a card answered「もういちど」still counts
  /// as practice and still earns daily-goal credit. Correctness is shown
  /// honestly elsewhere — the 合格率 gauge weights accuracy. Drives the
  ///「きょうの目標」ring (Duolingo-style: a visible goal you fill each day).
  final int problemsToday;

  /// The daily question target the child is working toward today.
  final int dailyGoal;

  /// True when the child HAD a streak but it lapsed (last study ≥ 2 days ago),
  /// so [currentStreak] now honestly reads 0. Lets the home greet a returner
  /// gracefully (「おかえり！またはじめよう」) instead of silently zeroing the count.
  final bool streakBroken;

  const StreakState({
    required this.currentStreak,
    required this.weeklyBits,
    required this.todayCount,
    this.problemsToday = 0,
    this.dailyGoal = kDefaultDailyGoal,
    this.streakBroken = false,
  });

  const StreakState.zero()
      : currentStreak = 0,
        weeklyBits = 0,
        todayCount = 0,
        problemsToday = 0,
        dailyGoal = kDefaultDailyGoal,
        streakBroken = false;

  /// Whether the given [weekdayIndex] (0=Mon, 6=Sun) was studied.
  bool studiedOn(int weekdayIndex) => (weeklyBits >> weekdayIndex) & 1 == 1;

  /// Whether today's question goal has been reached. Guards a corrupted/zero
  /// goal so the ring never celebrates「達成」on zero work.
  bool get goalMet => dailyGoal > 0 && problemsToday >= dailyGoal;

  /// Questions still needed to hit today's goal (never negative).
  int get remainingToGoal =>
      (dailyGoal - problemsToday) < 0 ? 0 : dailyGoal - problemsToday;

  /// Goal completion ratio, clamped to 0..1.
  double get goalRatio =>
      dailyGoal <= 0 ? 0 : (problemsToday / dailyGoal).clamp(0.0, 1.0);
}

/// Default daily question goal — a calm, attainable target for a young child
/// (≈one short review). Visible-progress beats a big number you never finish.
const int kDefaultDailyGoal = 10;

// ── Service ───────────────────────────────────────────────────────────────────

class StreakService {
  static const _kLastDate = 'streak_last_study_date';
  static const _kCurrent = 'streak_current';
  static const _kWeeklyBits = 'streak_weekly_bits';
  static const _kTodayCount = 'streak_today_count';
  static const _kProblemsToday = 'streak_problems_today';
  static const _kProblemsTodayDate = 'streak_problems_today_date';
  static const _kDailyGoal = 'streak_daily_goal';

  // ISO-8601 date string for a given DateTime.
  static String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  // Difference in days between two date-only values (ignores time component).
  static int _daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// Load the current streak state without modifying storage.
  ///
  /// [now] is injectable for tests; production uses the wall clock. The daily
  /// question count is reported as 0 once the calendar day has rolled over, so
  /// the goal ring starts empty each morning without a write.
  Future<StreakState> load({DateTime? now}) async {
    final prefs = await PreferencesService.getInstance();
    final nowDt = now ?? DateTime.now();
    final storedStreak = prefs.getInt(_kCurrent);
    final bits = prefs.getInt(_kWeeklyBits);
    final today = prefs.getInt(_kTodayCount);

    // HONESTY (#123): a streak is only ALIVE if the last study was today or
    // yesterday (you can still continue it today). If the child lapsed (last
    // study ≥ 2 days ago), the streak is BROKEN — show the true value (0), not a
    // stale 「9にち れんぞく」 they no longer have. The persisted reset still happens
    // in recordStudySession on the next session; this just stops the display from
    // lying in between. [streakBroken] lets the home greet a returner gracefully.
    final lastDateStr = prefs.getString(_kLastDate);
    final lastDate =
        lastDateStr != null ? DateTime.tryParse(lastDateStr) : null;
    final alive = lastDate != null && _daysBetween(lastDate, nowDt) <= 1;
    final streak = alive ? storedStreak : 0;
    final streakBroken = !alive && storedStreak > 0;

    final todayKey = _dateKey(nowDt);
    final problemsDate = prefs.getString(_kProblemsTodayDate);
    final problemsToday =
        (problemsDate == todayKey) ? prefs.getInt(_kProblemsToday) : 0;
    final storedGoal = prefs.getInt(_kDailyGoal);
    final dailyGoal = storedGoal > 0 ? storedGoal : kDefaultDailyGoal;

    return StreakState(
      currentStreak: streak,
      weeklyBits: bits,
      todayCount: today,
      problemsToday: problemsToday,
      dailyGoal: dailyGoal,
      streakBroken: streakBroken,
    );
  }

  /// Record [count] practice questions answered toward today's goal.
  ///
  /// Resets the running count when the calendar day changes, so the goal ring
  /// fills from zero each day. Independent of [recordStudySession] (which counts
  /// sessions/streak) so call ordering does not matter. Returns the updated
  /// [StreakState].
  Future<StreakState> recordProgress(int count, {DateTime? now}) async {
    final prefs = await PreferencesService.getInstance();
    final todayKey = _dateKey(now ?? DateTime.now());

    final problemsDate = prefs.getString(_kProblemsTodayDate);
    final base = (problemsDate == todayKey) ? prefs.getInt(_kProblemsToday) : 0;
    final updated = base + (count < 0 ? 0 : count);

    await prefs.setInt(_kProblemsToday, updated);
    await prefs.setString(_kProblemsTodayDate, todayKey);

    return load(now: now);
  }

  /// Record a completed study session (called after battle/exam finish).
  ///
  /// Returns the updated [StreakState].
  Future<StreakState> recordStudySession() async {
    final prefs = await PreferencesService.getInstance();
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    final lastDateStr = prefs.getString(_kLastDate);
    int streak = prefs.getInt(_kCurrent);
    int bits = prefs.getInt(_kWeeklyBits);
    int todayCount = prefs.getInt(_kTodayCount);

    // Reset weekly bits if we're in a new week.
    // We track the Monday of the stored last-date vs now.
    if (lastDateStr != null) {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        final lastMonday =
            lastDate.subtract(Duration(days: lastDate.weekday - 1));
        final nowMonday = now.subtract(Duration(days: now.weekday - 1));
        if (_daysBetween(lastMonday, nowMonday) >= 7) {
          bits = 0;
          todayCount = 0;
        }
      }
    }

    // Update streak counter.
    if (lastDateStr == null) {
      // First ever session.
      streak = 1;
      todayCount = 1;
    } else if (lastDateStr == todayKey) {
      // Already counted today — only increment todayCount.
      todayCount++;
    } else {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        final diff = _daysBetween(lastDate, now);
        if (diff == 1) {
          streak++;
        } else {
          streak = 1; // missed day — reset
        }
      } else {
        streak = 1;
      }
      todayCount = 1;
    }

    // Mark today's weekday bit (ISO weekday 1=Mon → bit 0).
    final bitIndex = now.weekday - 1; // 0-6
    bits = bits | (1 << bitIndex);

    // Persist.
    await prefs.setString(_kLastDate, todayKey);
    await prefs.setInt(_kCurrent, streak);
    await prefs.setInt(_kWeeklyBits, bits);
    await prefs.setInt(_kTodayCount, todayCount);

    // Return a COMPLETE snapshot (incl. the daily-goal fields) so a caller that
    // displays this result never sees problemsToday/dailyGoal default to 0.
    final problemsDate = prefs.getString(_kProblemsTodayDate);
    final problemsToday =
        (problemsDate == todayKey) ? prefs.getInt(_kProblemsToday) : 0;
    final storedGoal = prefs.getInt(_kDailyGoal);
    return StreakState(
      currentStreak: streak,
      weeklyBits: bits,
      todayCount: todayCount,
      problemsToday: problemsToday,
      dailyGoal: storedGoal > 0 ? storedGoal : kDefaultDailyGoal,
    );
  }
}

/// Record a completed 英検 study session into the home engagement spine: marks
/// today as a study day (advances the streak) and adds [answered] problems to
/// the daily-goal ring. Fire-and-forget — every exam-practice surface should
/// call this on session-end so the streak/goal reflect ALL practice, not just
/// the FSRS battle (StreakService's doc contract says "after any battle/exam
/// completion"; previously only the battles honoured it). Prefs failures are
/// swallowed; never blocks or interrupts the learner.
void recordExamHabit(int answered) {
  if (answered <= 0) return;
  unawaited(recordExamHabitAndGet(answered));
}

/// Same as [recordExamHabit] but RETURNS the updated [StreakState] so a session-
/// end screen can SHOW the streak/daily-goal the child just earned — surfacing
/// the engagement spine at the emotional peak (session end), not only on the next
/// home visit. Returns null on no-op or a (rare) prefs failure, so the caller can
/// simply skip the hook. Fire-and-forget callers use the void wrapper above.
Future<StreakState?> recordExamHabitAndGet(int answered) async {
  if (answered <= 0) return null;
  try {
    final streak = StreakService();
    await streak.recordStudySession();
    return await streak.recordProgress(answered);
  } catch (_) {
    // Non-fatal: SharedPreferences failure is rare and must not surface.
    return null;
  }
}

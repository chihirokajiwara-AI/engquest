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

  const StreakState({
    required this.currentStreak,
    required this.weeklyBits,
    required this.todayCount,
  });

  const StreakState.zero()
      : currentStreak = 0,
        weeklyBits = 0,
        todayCount = 0;

  /// Whether the given [weekdayIndex] (0=Mon, 6=Sun) was studied.
  bool studiedOn(int weekdayIndex) => (weeklyBits >> weekdayIndex) & 1 == 1;
}

// ── Service ───────────────────────────────────────────────────────────────────

class StreakService {
  static const _kLastDate = 'streak_last_study_date';
  static const _kCurrent = 'streak_current';
  static const _kWeeklyBits = 'streak_weekly_bits';
  static const _kTodayCount = 'streak_today_count';

  // ISO-8601 date string for a given DateTime.
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  // Difference in days between two date-only values (ignores time component).
  static int _daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// Load the current streak state without modifying storage.
  Future<StreakState> load() async {
    final prefs = await PreferencesService.getInstance();
    final streak = prefs.getInt(_kCurrent);
    final bits = prefs.getInt(_kWeeklyBits);
    final today = prefs.getInt(_kTodayCount);
    return StreakState(
      currentStreak: streak,
      weeklyBits: bits,
      todayCount: today,
    );
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

    return StreakState(
      currentStreak: streak,
      weeklyBits: bits,
      todayCount: todayCount,
    );
  }
}

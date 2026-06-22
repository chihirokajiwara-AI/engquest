// lib/features/home/streak_service.dart
// ENG Quest — Daily Streak Tracking Service
//
// Tracks consecutive study days using SharedPreferences.
// Keys:
//   streak_last_study_date  : ISO-8601 date string (yyyy-MM-dd) of last study
//   streak_current          : int — current consecutive streak
//   streak_weekly_bits      : int — 7-bit bitmask, bit 0 = Monday, bit 6 = Sunday
//   streak_daily_goal       : int — questions target (fallback: onboarding_goal_minutes key, which stores a question count)
//   streak_today_count      : int — sessions completed today
//
// Streak logic:
//   - recordStudySession() called after any battle/exam completion
//   - If today is the same as lastStudyDate → no change to streak (already counted)
//   - If today is exactly one day after lastStudyDate → streak++
//   - If today is 2+ days after lastStudyDate → streak resets to 1
//   - New user with no lastStudyDate → streak starts at 1

import 'dart:async';

import 'package:engquest/core/analytics/analytics_service.dart';
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

  /// True ONLY on the record-time snapshot when the child just RECOVERED a streak
  /// that would otherwise have hard-reset — a missed day was graced (see
  /// [StreakService._doRecordStudySession]). Lets the session-end surface show a
  /// distinct「とりもどした！」win instead of the generic streak line. Always false on
  /// [load] (a pure read never repairs); transient — not persisted.
  final bool repaired;

  const StreakState({
    required this.currentStreak,
    required this.weeklyBits,
    required this.todayCount,
    this.problemsToday = 0,
    this.dailyGoal = kDefaultDailyGoal,
    this.streakBroken = false,
    this.repaired = false,
  });

  const StreakState.zero()
      : currentStreak = 0,
        weeklyBits = 0,
        todayCount = 0,
        problemsToday = 0,
        dailyGoal = kDefaultDailyGoal,
        streakBroken = false,
        repaired = false;

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

/// Minimum established streak before a missed day is GRACED instead of hard-reset
/// (see [StreakService._doRecordStudySession]). A 1–2 day streak isn't worth
/// "repairing" (and gracing tiny streaks would just dull the consecutive-days
/// meaning); a child who has shown ≥3 days of habit is the one worth keeping.
const int kStreakRepairMinToGrace = 3;

// ── Service ───────────────────────────────────────────────────────────────────

class StreakService {
  static const _kLastDate = 'streak_last_study_date';
  static const _kCurrent = 'streak_current';
  static const _kWeeklyBits = 'streak_weekly_bits';
  static const _kTodayCount = 'streak_today_count';
  static const _kProblemsToday = 'streak_problems_today';
  static const _kProblemsTodayDate = 'streak_problems_today_date';
  static const _kDailyGoal = 'streak_daily_goal';

  // The onboarding goal (written by OnboardingStorage.save).
  // Key string is the legacy 'onboarding_goal_minutes' — the stored value is a
  // question count (OnboardingResult.dailyGoalQuestions), not minutes.
  static const _kOnboardingGoal = 'onboarding_goal_minutes';

  /// The effective daily question goal, honouring the parent's onboarding pick.
  /// Precedence: an explicit streak_daily_goal (a future in-app goal editor) →
  /// the onboarding goal → the default. Before this, the onboarding choice was
  /// captured but DEAD: nothing ever wrote streak_daily_goal, so the ring always
  /// showed the default regardless of what the parent set up.
  static int _effectiveDailyGoal(PreferencesService prefs) {
    final explicit = prefs.getInt(_kDailyGoal);
    if (explicit > 0) return explicit;
    final onboarding = prefs.getInt(_kOnboardingGoal);
    if (onboarding > 0) return onboarding;
    return kDefaultDailyGoal;
  }

  /// The current effective daily question goal — what the home ring targets.
  /// The in-app goal editor (parent dashboard) reads this to show the active
  /// value, and writes it via [setDailyGoal].
  Future<int> currentDailyGoal() async =>
      _effectiveDailyGoal(await PreferencesService.getInstance());

  /// Set the daily question goal (the in-app goal editor). Persists the explicit
  /// `streak_daily_goal`, which takes precedence over the onboarding proxy in
  /// [_effectiveDailyGoal] — so the parent's choice immediately drives the home
  /// ring. Values are clamped to a sane range (1..200).
  Future<void> setDailyGoal(int goal) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setInt(_kDailyGoal, goal.clamp(1, 200));
  }

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

  /// Whether [now] is in a different ISO week than [last] — i.e. their Mondays
  /// differ. Used by BOTH the display (`load`) and write (`recordStudySession`)
  /// paths so the weekly dots can never reset on one but not the other (#125: the
  /// two paths previously encoded the same "new week" rule with two different
  /// constants — `!= 0` vs `>= 7`). Compares the Monday DATES directly rather
  /// than a day-count, so a DST week (where `Duration.inDays` can read a 7-day
  /// gap as 6) can't desync the two paths or leave stale weekday dots showing.
  static bool _isNewWeek(DateTime last, DateTime now) {
    DateTime monday(DateTime d) {
      final m = d.subtract(Duration(days: d.weekday - 1));
      return DateTime(m.year, m.month, m.day);
    }

    return monday(last) != monday(now);
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
    int bits = prefs.getInt(_kWeeklyBits);
    int today = prefs.getInt(_kTodayCount);

    // HONESTY (#123): a streak is only ALIVE if the last study was today or
    // yesterday (you can still continue it today). If the child lapsed (last
    // study ≥ 2 days ago), the streak is BROKEN — show the true value (0), not a
    // stale 「9にち れんぞく」 they no longer have. The persisted reset still happens
    // in recordStudySession on the next session; this just stops the display from
    // lying in between. [streakBroken] lets the home greet a returner gracefully.
    final lastDateStr = prefs.getString(_kLastDate);
    final lastDate =
        lastDateStr != null ? DateTime.tryParse(lastDateStr) : null;
    // ALIVE = last study was today or yesterday. Guard the LOWER bound too: a
    // future lastDate (device clock jumped forward then corrected, or a web/TZ
    // skew) makes _daysBetween negative, which would slip past a bare `<= 1` and
    // freeze the streak "alive" forever — a child sees an ever-growing
    // 「Nにち れんぞく」 with zero real practice, killing the daily-study motivation
    // that is the whole point of the streak. Only [0, 1] days counts.
    final daysSinceLast = lastDate != null ? _daysBetween(lastDate, nowDt) : -1;
    final alive = daysSinceLast >= 0 && daysSinceLast <= 1;
    final streak = alive ? storedStreak : 0;
    final streakBroken = !alive && storedStreak > 0;

    final todayKey = _dateKey(nowDt);
    final problemsDate = prefs.getString(_kProblemsTodayDate);
    final problemsToday =
        (problemsDate == todayKey) ? prefs.getInt(_kProblemsToday) : 0;
    final dailyGoal = _effectiveDailyGoal(prefs);

    // Display-side freshness (#123 sibling): recordStudySession only resets the
    // weekly dots / today-count when the child STUDIES. On a pure load — opening
    // the app in a new week or a new day WITHOUT studying yet — the raw prefs
    // would show last week's weekday dots as this week's, and yesterday's session
    // count as today's. Reset them for display so the engagement spine is honest.
    if (lastDate != null) {
      if (_isNewWeek(lastDate, nowDt)) bits = 0; // a new week
      if (lastDateStr != todayKey) today = 0; // no sessions TODAY yet
    } else {
      bits = 0;
      today = 0;
    }

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
  // Serialize every streak WRITE (recordProgress + recordStudySession) so
  // concurrent fire-and-forget callers never lose a read-modify-write on the
  // shared prefs counters. Both writes are unawaited at their call sites — a
  // battle session-end (_recordDailyHabit) and an exam session-end
  // (recordExamHabitAndGet) can have writes in flight at once during fast screen
  // navigation; without serialization both read the same baseline and the last
  // setInt clobbers the other, so the daily-goal ring silently UNDER-COUNTS —
  // telling a child「あと N問」when they already met today's goal (a direct honesty
  // violation on the engagement spine, CEO 951). Static = process-wide, since
  // StreakService is constructed ad-hoc per call site. Same remediation the repo
  // already uses for the FSRS deck and SkillAccuracyStore (#147). The chain never
  // rejects (one failed write can't wedge the queue); the caller still gets its
  // own result/error.
  static Future<void> _writeQueue = Future<void>.value();

  static Future<T> _serialize<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Record [count] practice questions answered toward today's goal.
  Future<StreakState> recordProgress(int count, {DateTime? now}) =>
      _serialize(() => _doRecordProgress(count, now: now));

  Future<StreakState> _doRecordProgress(int count, {DateTime? now}) async {
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
  Future<StreakState> recordStudySession() => _serialize(_doRecordStudySession);

  Future<StreakState> _doRecordStudySession() async {
    final prefs = await PreferencesService.getInstance();
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    final lastDateStr = prefs.getString(_kLastDate);
    int streak = prefs.getInt(_kCurrent);
    int bits = prefs.getInt(_kWeeklyBits);
    int todayCount = prefs.getInt(_kTodayCount);
    // Set true below when a missed day is graced rather than hard-reset, so the
    // session-end surface can celebrate the recovery. Transient (never persisted).
    bool repaired = false;

    // Reset weekly bits if we're in a new week.
    // We track the Monday of the stored last-date vs now.
    if (lastDateStr != null) {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        if (_isNewWeek(lastDate, now)) {
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
        } else if (diff == 2 && streak >= kStreakRepairMinToGrace) {
          // GRACE (#retention): one missed day is forgiven for an ESTABLISHED
          // streak (≥ kStreakRepairMinToGrace). Hard-resetting a 9-day streak to
          // 1 over a single homework-night miss is the cruelest churn point — the
          // exact reliable child worth keeping. 2026 streak-freeze research
          // (Duolingo) shows a repair window yields ~48% longer streaks, the
          // D7→D30 paid-retention inflection. Keep the streak; today extends it.
          // Tradeoff (accepted): a child studying every OTHER day keeps the streak
          // alive — still real practice; a 2-day gap below decays it, a 3-day gap
          // resets it. This also unlocks the streak_7/10/30 achievements, which
          // were structurally unreachable for any child who ever missed a night.
          streak = streak + 1;
          repaired = true;
        } else if (diff == 3 && streak >= kStreakRepairMinToGrace) {
          // Two missed days: PARTIAL credit (halve, floor, min 1) — better than a
          // hard reset, but a real gap costs more than a single night.
          final halved = (streak / 2).floor();
          streak = halved < 1 ? 1 : halved;
          repaired = true;
        } else {
          streak = 1; // 3+ missed days, or too small to grace — reset
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
    return StreakState(
      currentStreak: streak,
      weeklyBits: bits,
      todayCount: todayCount,
      problemsToday: problemsToday,
      dailyGoal: _effectiveDailyGoal(prefs),
      repaired: repaired,
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
    final state = await streak.recordProgress(answered);
    // Core retention signal (session_complete) — fires for battle AND every exam
    // type at this single chokepoint. Inert until a parent grants analytics
    // consent (NoOp sink otherwise), so no data is collected pre-consent.
    unawaited(AnalyticsService.instance
        .logPracticeSessionComplete(wordsPracticed: answered));
    return state;
  } catch (_) {
    // Non-fatal: SharedPreferences failure is rare and must not surface.
    return null;
  }
}

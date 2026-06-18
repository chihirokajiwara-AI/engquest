// lib/features/exam_practice/pass/skill_accuracy_store.dart
// A-KEN Quest — Per-grade, per-skill running accuracy store.
//
// RESPONSIBILITY:
//   Accumulates correct/total answer counts across practice sessions for each
//   (grade, EikenSkill) pair. On demand, produces a List<SkillAccuracy> suitable
//   for passing directly to CseEstimator.estimate().
//
// STORAGE:
//   PreferencesService-backed (SharedPreferences under the hood). One ATOMIC key
//   per (grade, skill) holding both counters as JSON:
//     pass_acc_<grade>_<skill>  → {"c": <correct>, "t": <total>}
//   e.g. "pass_acc_pre1_reading" → {"c":15,"t":20}.
//
//   This is a single setString (one localStorage write) so correct + total can
//   never tear apart. The PREVIOUS layout used two independent int keys
//   (..._correct / ..._total) and updated them with two separate awaited writes;
//   a tab-close/crash between the two left correct advanced but total stale,
//   silently INFLATING the 合格率 meter (correct/total with a too-low total).
//   Those legacy int keys are still READ as a migration fallback so existing
//   learners keep their accumulated 合格率 across the format change.
//
// SECTION → SKILL MAPPING (英検 一次試験):
//   ExamSectionType.vocabGrammar       → EikenSkill.reading
//   ExamSectionType.conversationComplete→ EikenSkill.reading
//   ExamSectionType.wordOrdering       → EikenSkill.reading
//   ExamSectionType.readingComprehension→ EikenSkill.reading
//   ExamSectionType.listening          → EikenSkill.listening
//   ExamSectionType.writing            → EikenSkill.writing
//
// RATIONALE: vocabGrammar + conversation + word-ordering + reading comprehension
//   all map to the CSE Reading skill because they appear in the 一次 Reading
//   section of the 英検 exam (Part 1–3/4 = Reading大問; Part 5/6 = Writing; Part 7 = Listening).
//
// GUARDED: never throws. If PreferencesService is unavailable the in-memory
//   fallback inside PreferencesService is used transparently.
//
// NO dart:io. No Firebase. No network (R4).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/preferences_service.dart';
import 'cse_model.dart';
import 'mastery_advisor.dart';

// ── Key helpers ───────────────────────────────────────────────────────────────

/// Atomic combined key: holds {"c":correct,"t":total} as a single JSON string.
String _key(String grade, EikenSkill skill) =>
    'pass_acc_${grade}_${_skillId(skill)}';

// Legacy two-int keys — READ ONLY (migration fallback for data written before the
// atomic-key change). New writes never touch these.
String _legacyCorrectKey(String grade, EikenSkill skill) =>
    'pass_acc_${grade}_${_skillId(skill)}_correct';

String _legacyTotalKey(String grade, EikenSkill skill) =>
    'pass_acc_${grade}_${_skillId(skill)}_total';

String _skillId(EikenSkill skill) {
  switch (skill) {
    case EikenSkill.reading:
      return 'reading';
    case EikenSkill.writing:
      return 'writing';
    case EikenSkill.listening:
      return 'listening';
  }
}

// ── SkillAccuracyStore ────────────────────────────────────────────────────────

/// Persists and reads per-grade, per-skill accuracy data for the 合格メーター.
///
/// Usage — recording a session result:
/// ```dart
/// final store = await SkillAccuracyStore.getInstance();
/// await store.record(
///   grade: 'pre1',
///   skill: EikenSkill.reading,
///   correct: 7,
///   total: 10,
/// );
/// ```
///
/// Usage — reading data for the meter:
/// ```dart
/// final store = await SkillAccuracyStore.getInstance();
/// final accuracies = await store.readAccuracies('pre1');
/// final estimate = CseEstimator.estimate(grade: 'pre1', accuracies: accuracies);
/// ```
class SkillAccuracyStore {
  SkillAccuracyStore._internal(this._prefs);

  final PreferencesService _prefs;

  static SkillAccuracyStore? _instance;

  // ── Singleton ───────────────────────────────────────────────────────────────

  /// Returns the singleton instance. Safe to call multiple times.
  static Future<SkillAccuracyStore> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = await PreferencesService.getInstance();
    _instance = SkillAccuracyStore._internal(prefs);
    return _instance!;
  }

  /// Clears the singleton (for tests only).
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  // ── record ───────────────────────────────────────────────────────────────────

  /// Accumulates [correct] correct answers and [total] attempts for the given
  /// [grade] + [skill] pair.
  ///
  /// [correct] and [total] must be non-negative. [correct] ≤ [total] is not
  /// enforced (defensive: any positive total contributes meaningful data).
  ///
  /// Guarded: any storage error is caught and logged in debug mode; the in-memory
  /// fallback inside PreferencesService handles it transparently.
  Future<void> record({
    required String grade,
    required EikenSkill skill,
    required int correct,
    required int total,
  }) async {
    if (total <= 0) return; // Nothing to record for empty sessions.
    try {
      final prev = _readCounts(grade, skill);
      final newCorrect = prev.correct + correct.clamp(0, total);
      final newTotal = prev.total + total;
      // SINGLE atomic write: both counters live in one JSON value, so a
      // tab-close/crash mid-write can never leave correct advanced but total
      // stale (which used to inflate the live 合格率 meter).
      await _prefs.setString(
        _key(grade, skill),
        jsonEncode({'c': newCorrect, 't': newTotal}),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SkillAccuracyStore] record failed: $e');
      }
    }
  }

  /// Reads the accumulated (correct, total) for a (grade, skill). Prefers the
  /// atomic combined key; falls back to the legacy two-int keys so learners who
  /// recorded data before the format change keep their accumulated 合格率.
  ({int correct, int total}) _readCounts(String grade, EikenSkill skill) {
    final raw = _prefs.getString(_key(grade, skill));
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final c = (m['c'] as num?)?.toInt() ?? 0;
        final t = (m['t'] as num?)?.toInt() ?? 0;
        return (correct: c, total: t);
      } catch (_) {
        // Corrupt JSON → fall through to legacy / zero rather than throw.
      }
    }
    final c = _prefs.getInt(_legacyCorrectKey(grade, skill));
    final t = _prefs.getInt(_legacyTotalKey(grade, skill));
    return (correct: c, total: t);
  }

  // ── readAccuracies ───────────────────────────────────────────────────────────

  /// Returns a [List<SkillAccuracy>] for all three skills for [grade].
  ///
  /// Skills with no recorded data have [itemsAttempted] = 0 and [accuracy] = 0.0,
  /// which CseEstimator correctly treats as "no data → conservative 0 score".
  ///
  /// Always returns all three skills so CseEstimator can work with any grade
  /// (it internally filters to the skills that apply to the grade).
  List<SkillAccuracy> readAccuracies(String grade) {
    return [
      _readSkill(grade, EikenSkill.reading),
      _readSkill(grade, EikenSkill.writing),
      _readSkill(grade, EikenSkill.listening),
    ];
  }

  SkillAccuracy _readSkill(String grade, EikenSkill skill) {
    try {
      final counts = _readCounts(grade, skill);
      if (counts.total <= 0) {
        return SkillAccuracy(skill: skill, accuracy: 0.0, itemsAttempted: 0);
      }
      final accuracy = (counts.correct / counts.total).clamp(0.0, 1.0);
      return SkillAccuracy(
          skill: skill, accuracy: accuracy, itemsAttempted: counts.total);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SkillAccuracyStore] readSkill failed: $e');
      }
      return SkillAccuracy(skill: skill, accuracy: 0.0, itemsAttempted: 0);
    }
  }

  // ── resetGrade ───────────────────────────────────────────────────────────────

  /// Resets all accuracy data for a grade (e.g. when user changes grade).
  /// Useful for testing or if the parent wants to restart tracking.
  Future<void> resetGrade(String grade) async {
    for (final skill in EikenSkill.values) {
      try {
        // Remove all three keys (combined + both legacy) so neither the atomic
        // value nor a stale legacy pair can resurrect the count after a reset.
        await _prefs.remove(_key(grade, skill));
        await _prefs.remove(_legacyCorrectKey(grade, skill));
        await _prefs.remove(_legacyTotalKey(grade, skill));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SkillAccuracyStore] resetGrade failed: $e');
        }
      }
    }
  }

  // ── hasAnyData ───────────────────────────────────────────────────────────────

  /// True if the learner has at least one recorded answer for this grade.
  bool hasAnyData(String grade) {
    for (final skill in EikenSkill.values) {
      try {
        if (_readCounts(grade, skill).total > 0) return true;
      } catch (_) {}
    }
    return false;
  }
}

/// Builds the learner's LIVE 合格率 estimate from their accumulated practice
/// accuracy, or null when there is no data yet (→ show a "practice first"
/// prompt) or the grade is unsupported. Shared so the parent sees pass-readiness
/// at the top level (home readiness card, #66/#68).
Future<CseEstimate?> liveCseEstimate(String grade) async {
  try {
    final store = await SkillAccuracyStore.getInstance();
    if (!store.hasAnyData(grade)) return null;
    return CseEstimator.estimate(
      grade: grade,
      accuracies: store.readAccuracies(grade),
    );
  } catch (_) {
    return null;
  }
}

/// Mastery-based progression advice (#14) from the learner's accumulated
/// accuracy at [grade]; null when there is no data yet. Reuses the same
/// per-skill accuracy the 合格率 reads, so the advice and the meter never disagree.
Future<MasteryRecommendation?> liveMasteryAdvice(String grade) async {
  try {
    final store = await SkillAccuracyStore.getInstance();
    if (!store.hasAnyData(grade)) return null;
    return adviseProgression(grade, store.readAccuracies(grade));
  } catch (_) {
    return null;
  }
}

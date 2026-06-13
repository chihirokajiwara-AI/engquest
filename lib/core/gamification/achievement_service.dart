// lib/core/gamification/achievement_service.dart
// ENG Quest — Achievement Service (T06)
//
// Responsibilities:
//   1. Load achievement state from Firestore: users/{uid}/achievements/{id}
//   2. Check progress against definitions and unlock when target is met
//   3. Expose newly unlocked achievements via ValueNotifier for UI popups
//   4. Persist updates to Firestore with merge writes
//
// Usage:
//   final svc = AchievementService();
//   await svc.init(uid);
//   final newlyUnlocked = await svc.checkAndUpdate(
//     uid: uid,
//     totalMastered: 50,
//     currentStreak: 7,
//     totalPracticed: 200,
//     level: 3,
//   );

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'achievement.dart';

class AchievementService {
  // Lazily resolved — see XpService for the rationale. Constructing this
  // service must never touch FirebaseFirestore.instance, which throws when
  // Firebase failed to initialize (offline/placeholder keys). All _db usages
  // are guarded, so a lazy throw degrades gracefully.
  final FirebaseFirestore? _injectedDb;
  FirebaseFirestore? _dbCache;

  AchievementService({FirebaseFirestore? firestore}) : _injectedDb = firestore;

  FirebaseFirestore get _db =>
      _dbCache ??= (_injectedDb ?? FirebaseFirestore.instance);

  // ── In-memory cache ──────────────────────────────────────────────────────
  Map<String, AchievementState>? _cache;
  String? _cachedUid;

  /// Notifies UI when a new achievement is unlocked.
  /// Value is the list of newly unlocked achievement IDs (cleared by UI).
  ///
  /// NOTE: per-instance — and `AchievementService()` is constructed ad hoc per
  /// screen, so this was never an effective cross-screen signal (no production
  /// listener ever existed; the battle read checkAndUpdate's return value). Use
  /// [unlockEvents] for the app-wide celebration. Kept for the unit test + any
  /// same-instance use.
  final ValueNotifier<List<String>> unlockedNotifier = ValueNotifier([]);

  /// App-wide achievement-unlock broadcast. STATIC (mirrors
  /// [XpService.levelUpEvents]) so the one app-root [AchievementUnlockHost] can
  /// celebrate an unlock from ANY source — the vocab battle AND 英検 exam
  /// practice. Carries the newly-unlocked achievement IDs; the host clears it.
  static final ValueNotifier<List<String>> unlockEvents = ValueNotifier([]);

  // ── Firestore helpers ────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _achievementsCol(String uid) =>
      _db.collection('users').doc(uid).collection('achievements');

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Loads all achievement state from Firestore (or cache).
  Future<Map<String, AchievementState>> init(String uid) async {
    if (_cache != null && _cachedUid == uid) return _cache!;

    final states = <String, AchievementState>{};

    try {
      final snap = await _achievementsCol(uid).get(
        const GetOptions(source: Source.serverAndCache),
      );
      for (final doc in snap.docs) {
        states[doc.id] = AchievementState.fromFirestore(doc.id, doc.data());
      }
    } catch (_) {
      // Offline cold start — proceed with empty state
    }

    // Ensure every defined achievement has a state entry
    for (final def in kAchievements) {
      states.putIfAbsent(def.id, () => AchievementState.empty(def.id));
    }

    _cache = states;
    _cachedUid = uid;
    return states;
  }

  /// Returns cached states (null if init hasn't been called).
  Map<String, AchievementState>? get cachedStates => _cache;

  // ── Check & update ────────────────────────────────────────────────────────

  /// Checks all achievements against current player stats.
  /// Returns a list of newly unlocked achievement IDs.
  Future<List<String>> checkAndUpdate({
    required String uid,
    required int totalMastered,
    required int currentStreak,
    required int totalPracticed,
    required int level,
  }) async {
    final states = await init(uid);
    final newlyUnlocked = <String>[];

    for (final def in kAchievements) {
      final state = states[def.id]!;
      if (state.unlocked) continue;

      final currentProgress = _progressFor(
        def,
        totalMastered: totalMastered,
        currentStreak: currentStreak,
        totalPracticed: totalPracticed,
        level: level,
      );

      // Progress is monotonic non-decreasing: a partial-stat check from another
      // surface — e.g. exam practice calls checkAndUpdate with the streak/level
      // it knows but 0 for the mastery/practice counts it doesn't track — must
      // NEVER regress a stored value. Taking the max makes checkAndUpdate safe
      // to call from any screen with only the stats that screen has, which is
      // what lets streak/level unlocks fire during exam practice, not only the
      // battle. (Previously this overwrote progress with currentProgress, so a
      // 0 would erase real progress.)
      final newProgress =
          currentProgress > state.progress ? currentProgress : state.progress;
      final reached = newProgress >= def.target;
      if (newProgress != state.progress || reached) {
        final now = DateTime.now();
        final updated = state.copyWith(
          progress: newProgress,
          unlocked: reached,
          unlockedAt: reached ? now : null,
        );
        states[def.id] = updated;

        // Persist to Firestore
        _saveAchievement(uid, def.id, updated).catchError((_) {});

        if (reached) {
          newlyUnlocked.add(def.id);
        }
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      unlockedNotifier.value = List.unmodifiable(newlyUnlocked);
      unlockEvents.value =
          List.unmodifiable(newlyUnlocked); // app-wide celebration (any source)
    }

    return newlyUnlocked;
  }

  /// Returns the relevant progress value for a given achievement definition.
  int _progressFor(
    AchievementDef def, {
    required int totalMastered,
    required int currentStreak,
    required int totalPracticed,
    required int level,
  }) {
    switch (def.category) {
      case AchievementCategory.mastery:
        return totalMastered;
      case AchievementCategory.streak:
        return currentStreak;
      case AchievementCategory.practice:
        return totalPracticed;
      case AchievementCategory.level:
        return level;
    }
  }

  Future<void> _saveAchievement(
      String uid, String id, AchievementState state) async {
    await _achievementsCol(uid).doc(id).set(
          state.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Clears in-memory cache (for logout / testing).
  void clearCache() {
    _cache = null;
    _cachedUid = null;
    unlockedNotifier.value = [];
  }
}

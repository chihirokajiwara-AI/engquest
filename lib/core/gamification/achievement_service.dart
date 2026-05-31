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
  final FirebaseFirestore _db;

  AchievementService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ── In-memory cache ──────────────────────────────────────────────────────
  Map<String, AchievementState>? _cache;
  String? _cachedUid;

  /// Notifies UI when a new achievement is unlocked.
  /// Value is the list of newly unlocked achievement IDs (cleared by UI).
  final ValueNotifier<List<String>> unlockedNotifier = ValueNotifier([]);

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

      final reached = currentProgress >= def.target;
      if (currentProgress != state.progress || reached) {
        final now = DateTime.now();
        final updated = state.copyWith(
          progress: currentProgress,
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

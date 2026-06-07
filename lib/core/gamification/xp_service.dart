// lib/core/gamification/xp_service.dart
// ENG Quest — XP/Level Service (P2-7)
//
// Responsibilities:
//   1. Award XP per FSRS grade (Again=0, Hard=5, Good=10, Easy=15)
//   2. Derive level from totalXp using threshold table
//   3. Persist totalXp to Firestore: users/{uid}/profile.totalXp + .level
//   4. Expose level-up events (ValueNotifier<LevelUpEvent?>)
//   5. Provide XpProfile stream for UI consumption (ValueNotifier)
//   6. Local in-memory cache to avoid extra Firestore reads on same session
//   7. Graceful offline handling — Firestore offline cache queues writes
//
// Usage:
//   final xpService = XpService();
//   await xpService.init(uid);           // load from Firestore
//   final event = await xpService.awardXp(uid, Grade.good);
//   if (event.didLevelUp) { /* show level-up animation */ }
//
// Thread safety: all methods must be called from the Flutter UI isolate.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'xp_profile.dart';
import '../fsrs/fsrs_card.dart';

// ── Level-up event ────────────────────────────────────────────────────────────

/// Returned by [XpService.awardXp]. Describes the XP award outcome.
class XpAwardResult {
  /// XP awarded this grade.
  final int xpGained;

  /// Profile BEFORE this award.
  final XpProfile before;

  /// Profile AFTER this award (updated totalXp, possibly new level).
  final XpProfile after;

  /// True if [after.level] > [before.level].
  bool get didLevelUp => after.level > before.level;

  const XpAwardResult({
    required this.xpGained,
    required this.before,
    required this.after,
  });

  @override
  String toString() => 'XpAwardResult(+$xpGained XP, '
      'level ${before.level}→${after.level}, '
      'totalXp ${before.totalXp}→${after.totalXp})';
}

// ── XpService ─────────────────────────────────────────────────────────────────

class XpService {
  // Lazily resolved so constructing this service never touches
  // FirebaseFirestore.instance — which throws when Firebase failed to
  // initialize (e.g. demo/offline with placeholder keys). All _db usages
  // below are inside try/catch or async-with-catchError, so a lazy throw on
  // offline access degrades gracefully instead of blanking the screen.
  final FirebaseFirestore? _injectedDb;
  FirebaseFirestore? _dbCache;

  XpService({FirebaseFirestore? firestore}) : _injectedDb = firestore;

  FirebaseFirestore get _db =>
      _dbCache ??= (_injectedDb ?? FirebaseFirestore.instance);

  // ── In-memory cache ────────────────────────────────────────────────────────

  XpProfile? _cached;

  // ── Notifiers (UI can listen to these) ────────────────────────────────────

  /// Current player XP profile. Null until [init] completes.
  final ValueNotifier<XpProfile?> profileNotifier = ValueNotifier(null);

  /// Most recent level-up event. Null if no level-up has occurred.
  /// UI should clear this after showing the animation.
  final ValueNotifier<XpAwardResult?> levelUpNotifier = ValueNotifier(null);

  // ── Firestore helpers ─────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _db.collection('users').doc(uid);

  // ── Initialise ────────────────────────────────────────────────────────────

  /// Loads the player's XP profile from Firestore (or cache-first).
  /// Safe to call multiple times; skips network if already cached.
  Future<XpProfile> init(String uid) async {
    if (_cached != null && _cached!.uid == uid) return _cached!;

    try {
      final snap = await _profileRef(uid).get(
        const GetOptions(source: Source.serverAndCache),
      );
      final profile = snap.exists && snap.data() != null
          ? XpProfile.fromFirestore(uid, snap.data()!)
          : XpProfile.zero(uid);
      _cached = profile;
      profileNotifier.value = profile;
      return profile;
    } catch (_) {
      // Offline cold start — return zero profile; writes will sync later.
      final profile = _cached ?? XpProfile.zero(uid);
      _cached = profile;
      profileNotifier.value = profile;
      return profile;
    }
  }

  // ── Award XP for a grade ──────────────────────────────────────────────────

  /// Awards XP for [grade], updates Firestore, returns [XpAwardResult].
  ///
  /// Calling [init] first is recommended but not required — if [_cached] is
  /// null this method will call [init] internally.
  Future<XpAwardResult> awardXp(String uid, Grade grade) async {
    final before = await init(uid);

    final xpGained = _xpForGrade(grade);
    final newTotalXp = before.totalXp + xpGained;
    final newLevel = levelFromXp(newTotalXp);

    final after = XpProfile(uid: uid, totalXp: newTotalXp, level: newLevel);
    _cached = after;
    profileNotifier.value = after;

    // Persist to Firestore (merge — does not overwrite other profile fields)
    _saveToFirestore(uid, after).catchError((_) {
      // Offline: Firestore queues the write; will sync on reconnect.
    });

    final result =
        XpAwardResult(xpGained: xpGained, before: before, after: after);

    if (result.didLevelUp) {
      levelUpNotifier.value = result;
    }

    return result;
  }

  /// Awards XP for multiple grades in sequence (end-of-session batch).
  /// Returns the final [XpAwardResult] after all awards.
  Future<XpAwardResult> awardXpBatch(String uid, List<Grade> grades) async {
    if (grades.isEmpty) {
      final profile = await init(uid);
      return XpAwardResult(xpGained: 0, before: profile, after: profile);
    }

    XpAwardResult? last;
    for (final grade in grades) {
      last = await awardXp(uid, grade);
    }
    return last!;
  }

  // ── Get current profile (sync, from cache) ────────────────────────────────

  /// Returns the cached profile, or null if [init] hasn't been called yet.
  XpProfile? currentProfile(String uid) {
    if (_cached?.uid == uid) return _cached;
    return null;
  }

  // ── Reset (test/logout helper) ────────────────────────────────────────────

  /// Clears the in-memory cache. Does NOT delete Firestore data.
  void clearCache() {
    _cached = null;
    profileNotifier.value = null;
    levelUpNotifier.value = null;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  int _xpForGrade(Grade grade) {
    switch (grade) {
      case Grade.again:
        return kGradeXp['again']!;
      case Grade.hard:
        return kGradeXp['hard']!;
      case Grade.good:
        return kGradeXp['good']!;
      case Grade.easy:
        return kGradeXp['easy']!;
    }
  }

  Future<void> _saveToFirestore(String uid, XpProfile profile) async {
    await _profileRef(uid).set(
      {
        ...profile.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

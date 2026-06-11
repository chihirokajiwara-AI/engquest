// lib/core/analytics/firestore_progress_repository.dart
// ENG Quest — Firestore-backed Progress Repository (P1-5)
//
// Persists and reads learning progress for the Parent Dashboard.
// Schema:
//   users/{uid}/profile              → streak, totalMastered, totalPracticed
//   users/{uid}/sessions/{dateISO}   → DailyProgress per day (YYYY-MM-DD key)
//
// Features:
//   - Real Firestore reads/writes with offline cache
//   - Graceful fallback: returns null on read error (caller uses MockData)
//   - recordSession() merges into today's daily doc and updates profile doc
//   - getLast7Days() reads sessions/{date} for the last 7 calendar days
//   - Offline persistence inherited from FirestoreFsrsCardRepository settings
//     (persistenceEnabled is process-global; we set it defensively here too)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engquest/core/models/progress_data.dart';

class FirestoreProgressRepository {
  // Lazily resolved so constructing the repository never touches
  // FirebaseFirestore.instance, which throws when Firebase failed to
  // initialize (offline/placeholder keys). Every read/write below returns
  // null / falls back on error, so a lazy throw degrades gracefully rather
  // than blanking the Parent Dashboard at construction.
  final FirebaseFirestore? _injectedDb;
  FirebaseFirestore? _dbCache;

  FirestoreProgressRepository({FirebaseFirestore? firestore})
      : _injectedDb = firestore;

  /// Resolves (and memoizes) the Firestore instance on first use, configuring
  /// offline persistence once. May throw if Firebase is unavailable — callers
  /// wrap usage in try/catch and fall back to mock data.
  FirebaseFirestore get _db {
    final cached = _dbCache;
    if (cached != null) return cached;
    final db = _injectedDb ?? FirebaseFirestore.instance;
    _dbCache = db;
    _configureOfflinePersistence(db);
    return db;
  }

  // ── Offline persistence ───────────────────────────────────────────────────

  void _configureOfflinePersistence(FirebaseFirestore db) {
    try {
      db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {
      // Settings can only be set once per Firestore instance.
    }
  }

  // ── Document references ───────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _sessionDoc(
          String uid, String dateKey) =>
      _db.collection('users').doc(uid).collection('sessions').doc(dateKey);

  // ── Date key helper ───────────────────────────────────────────────────────

  static String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  // ── Read profile ──────────────────────────────────────────────────────────

  /// Returns null on any Firestore error (caller falls back to mock).
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await _profileDoc(uid).get(
        const GetOptions(source: Source.serverAndCache),
      );
      if (!snap.exists) return null;
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  // ── Read last 7 days sessions ─────────────────────────────────────────────

  /// Returns list of DailyProgress for the last 7 calendar days.
  /// Days with no Firestore doc return zeros (child had a rest day — normal).
  Future<List<DailyProgress>?> getLast7Days(String uid) async {
    try {
      final now = DateTime.now();
      final keys = List.generate(
        7,
        (i) => _dateKey(now.subtract(Duration(days: 6 - i))),
      );

      // Fetch all 7 docs in parallel
      final futures = keys.map((k) => _sessionDoc(uid, k).get(
            const GetOptions(source: Source.serverAndCache),
          ));
      final snaps = await Future.wait(futures);

      return List.generate(7, (i) {
        final snap = snaps[i];
        final day = now.subtract(Duration(days: 6 - i));
        final dayMidnight = DateTime(day.year, day.month, day.day);

        if (!snap.exists || snap.data() == null) {
          return DailyProgress(
            date: dayMidnight,
            wordsPracticed: 0,
            sessionMinutes: 0,
            averageScore: 0.0,
          );
        }
        final d = snap.data()!;
        return DailyProgress(
          date: dayMidnight,
          wordsPracticed: (d['wordsPracticed'] as num? ?? 0).toInt(),
          sessionMinutes: (d['sessionMinutes'] as num? ?? 0).toInt(),
          averageScore: (d['averageScore'] as num? ?? 0.0).toDouble(),
        );
      });
    } catch (_) {
      return null;
    }
  }

  // ── Write session ─────────────────────────────────────────────────────────

  /// Merges today's session data and updates profile aggregates.
  /// Uses a batch write for atomicity.
  Future<void> recordSession({
    required String uid,
    required int wordsPracticed,
    required int minutes,
    required double avgScore,
    required int totalMastered,
    required int totalPracticed,
    required int streak,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey = _dateKey(now);
      final batch = _db.batch();

      // Session doc: merge (increment) today's totals
      final sessionRef = _sessionDoc(uid, dateKey);
      final sessionSnap = await sessionRef.get(
        const GetOptions(source: Source.serverAndCache),
      );

      if (sessionSnap.exists && sessionSnap.data() != null) {
        final existing = sessionSnap.data()!;
        final prevWords = (existing['wordsPracticed'] as num? ?? 0).toInt();
        final prevMins = (existing['sessionMinutes'] as num? ?? 0).toInt();
        final prevScore = (existing['averageScore'] as num? ?? 0.0).toDouble();

        // Weighted average for score
        final totalWords = prevWords + wordsPracticed;
        final newAvg = totalWords > 0
            ? (prevScore * prevWords + avgScore * wordsPracticed) / totalWords
            : avgScore;

        batch.set(
          sessionRef,
          {
            'wordsPracticed': totalWords,
            'sessionMinutes': prevMins + minutes,
            'averageScore': newAvg,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        batch.set(
          sessionRef,
          {
            'wordsPracticed': wordsPracticed,
            'sessionMinutes': minutes,
            'averageScore': avgScore,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      // Profile doc: update aggregates
      batch.set(
        _profileDoc(uid),
        {
          'totalWordsMastered': totalMastered,
          'totalWordsPracticed': totalPracticed,
          'currentStreak': streak,
          'lastStudyDate': dateKey,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (_) {
      // Offline: Firestore will queue the write and sync when online.
      // No action needed — offline persistence handles this.
    }
  }

  // ── Streak calculator ─────────────────────────────────────────────────────

  /// Calculates current streak from Firestore session docs.
  /// Streak = consecutive calendar days with wordsPracticed > 0 ending today or yesterday.
  Future<int> calculateStreak(String uid) async {
    try {
      final now = DateTime.now();
      // Check up to 60 days back (generous limit)
      var streak = 0;
      var checkDay = DateTime(now.year, now.month, now.day);

      // If today has no session yet, allow yesterday to still count (streak not broken)
      final todayKey = _dateKey(checkDay);
      final todaySnap = await _sessionDoc(uid, todayKey).get(
        const GetOptions(source: Source.serverAndCache),
      );
      final todayHasSession = todaySnap.exists &&
          ((todaySnap.data()?['wordsPracticed'] as num?)?.toInt() ?? 0) > 0;

      if (!todayHasSession) {
        // Start counting from yesterday
        checkDay = checkDay.subtract(const Duration(days: 1));
      }

      // Count back consecutive days
      for (var i = 0; i < 60; i++) {
        final key = _dateKey(checkDay);
        final snap = await _sessionDoc(uid, key).get(
          const GetOptions(source: Source.serverAndCache),
        );
        if (!snap.exists) break;
        final words = (snap.data()?['wordsPracticed'] as num?)?.toInt() ?? 0;
        if (words <= 0) break;
        streak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      }

      return streak;
    } catch (_) {
      return 0;
    }
  }

  // ── Next review due ───────────────────────────────────────────────────────

  /// Returns the earliest FSRS due date from users/{uid}/cards.
  Future<DateTime?> getNextReviewDue(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('cards')
          .where('state', isEqualTo: 'review')
          .orderBy('dueDate')
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isEmpty) return null;
      final ts = snap.docs.first.data()['dueDate'] as Timestamp?;
      return ts?.toDate();
    } catch (_) {
      return null;
    }
  }

  // ── Mastery count ─────────────────────────────────────────────────────────

  /// Counts cards in 'review' state (proxy for mastered: stability > 0, due in future).
  Future<int> getMasteredCount(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('cards')
          .where('state', isEqualTo: 'review')
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  // ── All cards (for category mastery + schedule computation) ───────────────

  /// Returns all card documents as raw field maps.
  /// Returns empty list on error (caller shows "no data" state).
  Future<List<Map<String, dynamic>>> getAllCards(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('cards')
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Account / data deletion (#67 — store-submission requirement) ──────────

  /// Best-effort deletion of all Firestore data under users/{uid}.
  ///
  /// Schema covered:
  ///   users/{uid}                    → profile doc
  ///   users/{uid}/sessions/{*}       → daily session docs
  ///   users/{uid}/cards/{*}          → FSRS card docs
  ///
  /// All sub-collection deletes run in parallel to minimise latency.
  /// NEVER throws: if Firestore is offline / Firebase unavailable the method
  /// returns false (caller must still clear local prefs — see data_deletion_service.dart).
  Future<bool> deleteUserData(String uid) async {
    try {
      // Fetch sub-collection docs in parallel (server-only so the cache doesn't
      // give stale results, but fall back to cache on network error).
      final getOpts = const GetOptions(source: Source.serverAndCache);

      final sessionsFuture = _db
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .get(getOpts)
          .then((snap) => snap.docs.map((d) => d.reference).toList())
          .catchError((_) => <DocumentReference<Map<String, dynamic>>>[]);

      final cardsFuture = _db
          .collection('users')
          .doc(uid)
          .collection('cards')
          .get(getOpts)
          .then((snap) => snap.docs.map((d) => d.reference).toList())
          .catchError((_) => <DocumentReference<Map<String, dynamic>>>[]);

      final results = await Future.wait([sessionsFuture, cardsFuture]);
      final sessionRefs = results[0];
      final cardRefs = results[1];

      // Delete all sub-docs first, then the profile doc.
      final deleteFutures = [
        ...sessionRefs.map((r) => r.delete().catchError((_) {})),
        ...cardRefs.map((r) => r.delete().catchError((_) {})),
      ];
      await Future.wait(deleteFutures);

      // Finally delete the profile doc itself.
      await _profileDoc(uid).delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}

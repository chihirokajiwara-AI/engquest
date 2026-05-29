// lib/core/analytics/progress_service.dart
// ENG Quest — Progress Service (C08 + P1-5 Parent Dashboard Real Data)
//
// Real Firestore integration: reads from users/{uid}/profile + sessions/{date}.
// Graceful fallback: if Firestore returns null (offline cold-start or no data yet),
// returns mock data so the UI always has something to show.
//
// Data hierarchy (precedence):
//   1. Firestore (online or cached)   ← real data
//   2. Mock data                      ← first-run / error safety net

import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';

class ProgressService {
  static const int _totalVocabPool = 300;

  final FirestoreProgressRepository _repo;

  ProgressService({FirestoreProgressRepository? repository})
      : _repo = repository ?? FirestoreProgressRepository();

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Returns learning progress for [uid].
  /// Reads from Firestore first; falls back to mock if unavailable.
  Future<LearningProgress> getProgress(String uid) async {
    // Parallel reads for performance
    final results = await Future.wait([
      _repo.getProfile(uid),
      _repo.getLast7Days(uid),
      _repo.calculateStreak(uid),
      _repo.getNextReviewDue(uid),
      _repo.getMasteredCount(uid),
    ]);

    final profile = results[0] as Map<String, dynamic>?;
    final last7 = results[1] as List<DailyProgress>?;
    final streakFromFirestore = results[2] as int;
    final nextReview = results[3] as DateTime?;
    final masteredCount = results[4] as int;

    // If no Firestore data at all, return mock
    if (profile == null && last7 == null) {
      return _buildMockProgress(uid);
    }

    // Build progress from real data (with mock fallback for missing fields)
    final mock = _buildMockProgress(uid);

    final totalMastered =
        profile != null && profile.containsKey('totalWordsMastered')
            ? (profile['totalWordsMastered'] as num).toInt()
            : masteredCount > 0
                ? masteredCount
                : mock.totalWordsMastered;

    final totalPracticed =
        profile != null && profile.containsKey('totalWordsPracticed')
            ? (profile['totalWordsPracticed'] as num).toInt()
            : mock.totalWordsPracticed;

    final streak = streakFromFirestore > 0
        ? streakFromFirestore
        : profile != null && profile.containsKey('currentStreak')
            ? (profile['currentStreak'] as num).toInt()
            : mock.currentStreak;

    final masteryPct = totalMastered / _totalVocabPool;

    final progress = LearningProgress(
      uid: uid,
      currentStreak: streak,
      totalWordsMastered: totalMastered,
      totalWordsPracticed: totalPracticed,
      masteryPercent: masteryPct,
      last7Days: last7 ?? mock.last7Days,
      eikenReadiness: 0, // placeholder, recalculated below
      nextReviewDue: nextReview ?? mock.nextReviewDue,
    );

    return LearningProgress(
      uid: uid,
      currentStreak: progress.currentStreak,
      totalWordsMastered: progress.totalWordsMastered,
      totalWordsPracticed: progress.totalWordsPracticed,
      masteryPercent: progress.masteryPercent,
      last7Days: progress.last7Days,
      eikenReadiness: calculateEikenReadiness(progress),
      nextReviewDue: progress.nextReviewDue,
    );
  }

  /// Records a study session to Firestore.
  Future<void> recordSession({
    required String uid,
    required int wordsPracticed,
    required int minutes,
    required double avgScore,
    required int totalMastered,
    required int totalPracticed,
    required int streak,
  }) async {
    await _repo.recordSession(
      uid: uid,
      wordsPracticed: wordsPracticed,
      minutes: minutes,
      avgScore: avgScore,
      totalMastered: totalMastered,
      totalPracticed: totalPracticed,
      streak: streak,
    );
  }

  /// Eiken readiness score (0–100).
  /// 90% mastery → 100; linear below that.
  double calculateEikenReadiness(LearningProgress progress) {
    const double threshold = 0.9;
    if (progress.masteryPercent >= threshold) return 100.0;
    return (progress.masteryPercent / threshold) * 100.0;
  }

  // -----------------------------------------------------------------------
  // Mock data builder (safety net for first-run / Firestore unavailable)
  // -----------------------------------------------------------------------

  LearningProgress _buildMockProgress(String uid) {
    final now = DateTime.now();

    final last7 = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      // Simulate realistic practice counts with a rest day on day 3
      final practiced = i == 3 ? 0 : (10 + i * 3);
      return DailyProgress(
        date: DateTime(day.year, day.month, day.day),
        wordsPracticed: practiced,
        sessionMinutes: i == 3 ? 0 : (8 + i * 2),
        averageScore: i == 3 ? 0.0 : (1.5 + i * 0.15),
      );
    });

    const mastered = 0; // New user — no mastered words yet
    const masteryPct = mastered / _totalVocabPool;
    final readiness = calculateEikenReadiness(
      LearningProgress(
        uid: uid,
        currentStreak: 0,
        totalWordsMastered: mastered,
        totalWordsPracticed: 0,
        masteryPercent: masteryPct,
        last7Days: last7,
        eikenReadiness: 0,
        nextReviewDue: now.add(const Duration(hours: 1)),
      ),
    );

    return LearningProgress(
      uid: uid,
      currentStreak: 0,
      totalWordsMastered: mastered,
      totalWordsPracticed: 0,
      masteryPercent: masteryPct,
      last7Days: last7,
      eikenReadiness: readiness,
      nextReviewDue: now.add(const Duration(hours: 1)),
    );
  }
}

import 'package:engquest/core/models/progress_data.dart';

/// ENG Quest — Progress Service (C08 Parent Dashboard)
/// Currently returns mock data; Firestore integration is stubbed.
class ProgressService {
  static const int _totalVocabPool = 300;

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Returns learning progress for [uid].
  /// Falls back to mock data when no persisted data is available.
  Future<LearningProgress> getProgress(String uid) async {
    // TODO: replace with real Firestore / sqflite lookup
    return _buildMockProgress(uid);
  }

  /// Records a study session.
  /// Stub — will persist to local DB in a future sprint.
  Future<void> recordSession({
    required int wordsPracticed,
    required int minutes,
    required double avgScore,
  }) async {
    // TODO: persist to sqflite and sync to Firestore
  }

  /// Eiken readiness score (0–100).
  /// 90 % mastery → 100; linear below that.
  double calculateEikenReadiness(LearningProgress progress) {
    const double threshold = 0.9;
    if (progress.masteryPercent >= threshold) return 100.0;
    return (progress.masteryPercent / threshold) * 100.0;
  }

  // -----------------------------------------------------------------------
  // Firestore stubs (future)
  // -----------------------------------------------------------------------

  /// Stub: sync local progress to Firestore.
  Future<void> syncToFirestore(LearningProgress progress) async {
    // TODO: Firestore integration (Sprint C09)
  }

  // -----------------------------------------------------------------------
  // Mock data builder
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

    const mastered = 162;
    const masteryPct = mastered / _totalVocabPool; // ≈ 54 %
    final readiness = calculateEikenReadiness(
      LearningProgress(
        uid: uid,
        currentStreak: 6,
        totalWordsMastered: mastered,
        totalWordsPracticed: 210,
        masteryPercent: masteryPct,
        last7Days: last7,
        eikenReadiness: 0, // placeholder
        nextReviewDue: now.add(const Duration(hours: 3)),
      ),
    );

    return LearningProgress(
      uid: uid,
      currentStreak: 6,
      totalWordsMastered: mastered,
      totalWordsPracticed: 210,
      masteryPercent: masteryPct,
      last7Days: last7,
      eikenReadiness: readiness,
      nextReviewDue: now.add(const Duration(hours: 3)),
    );
  }
}

// lib/core/analytics/progress_service.dart
// ENG Quest — Progress Service (C08 + P1-5 Parent Dashboard Real Data)
//
// Real Firestore integration: reads from users/{uid}/profile + sessions/{date}.
// Graceful fallback: if Firestore returns null (offline cold-start or no data yet),
// returns honest empty-state progress so the UI shows "no data yet" messages
// rather than fabricated numbers.
//
// Data hierarchy (precedence):
//   1. Firestore (online or cached)   ← real data
//   2. Empty/zero defaults            ← first-run / no data yet

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';

class ProgressService {
  final FirestoreProgressRepository _repo;

  ProgressService({FirestoreProgressRepository? repository})
      : _repo = repository ?? FirestoreProgressRepository();

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Returns learning progress for [uid].
  /// All values are derived from real Firestore data.
  /// When no data exists yet, returns honest zero-state progress.
  Future<LearningProgress> getProgress(String uid) async {
    // Parallel reads for performance
    final results = await Future.wait([
      _repo.getProfile(uid),
      _repo.getLast7Days(uid),
      _repo.calculateStreak(uid),
      _repo.getNextReviewDue(uid),
      _repo.getMasteredCount(uid),
      _repo.getAllCards(uid),
    ]);

    final profile = results[0] as Map<String, dynamic>?;
    final last7 = results[1] as List<DailyProgress>?;
    final streakFromFirestore = results[2] as int;
    final nextReview = results[3] as DateTime?;
    final masteredCount = results[4] as int;
    final allCards = results[5] as List<Map<String, dynamic>>;

    // Compute category mastery from real card data
    final categoryMastery = _buildCategoryMastery(allCards);

    // Compute review schedule from real card data
    final reviewSchedule = _buildReviewSchedule(allCards);

    // Derive aggregate counts
    final totalMastered =
        profile != null && profile.containsKey('totalWordsMastered')
            ? (profile['totalWordsMastered'] as num).toInt()
            : masteredCount;

    final totalPracticed =
        profile != null && profile.containsKey('totalWordsPracticed')
            ? (profile['totalWordsPracticed'] as num).toInt()
            : 0;

    final streak = streakFromFirestore > 0
        ? streakFromFirestore
        : profile != null && profile.containsKey('currentStreak')
            ? (profile['currentStreak'] as num).toInt()
            : 0;

    // Mastery % is progress through the child's ACTUAL vocab deck, which scales
    // with their 英検 grade (5級 ~300 words … 準1級 ~3000). This was a hardcoded
    // 300 (the 5級/A1 pool), so a 3級 child who had mastered 270 of their 1,300
    // words showed 90% mastery → "100% 英検 ready" to the paying parent. Use the
    // real loaded deck size (already fetched as [allCards]); clamp because
    // totalMastered is a cumulative profile counter that can briefly exceed the
    // current deck right after a grade switch. Empty deck (nothing loaded) → 0.
    final deckSize = allCards.length;
    final masteryPct =
        deckSize > 0 ? (totalMastered / deckSize).clamp(0.0, 1.0) : 0.0;

    return LearningProgress(
      uid: uid,
      currentStreak: streak,
      totalWordsMastered: totalMastered,
      totalWordsPracticed: totalPracticed,
      masteryPercent: masteryPct,
      last7Days: last7 ?? _emptyLast7Days(),
      nextReviewDue: nextReview,
      vocabPoolSize: deckSize,
      categoryMastery: categoryMastery,
      reviewSchedule: reviewSchedule,
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

  // -----------------------------------------------------------------------
  // Category mastery builder (from real Firestore card data)
  // -----------------------------------------------------------------------

  /// Derives per-category mastery from raw Firestore card documents.
  ///
  /// Card document IDs follow the pattern "{eikenLevel}_{seq}" (e.g. "eiken5_001").
  /// The vocab content db defines the category for each vocabId; however, since
  /// we only have card state data in Firestore (not category), we use the
  /// vocabId prefix to group cards.
  ///
  /// Category mapping is derived from the known A1 vocab structure.
  /// Cards with no recognizable category prefix are grouped as "その他 / Other".
  ///
  /// Returns empty list when [allCards] is empty (no study activity yet).
  List<CategoryMastery> _buildCategoryMastery(
      List<Map<String, dynamic>> allCards) {
    if (allCards.isEmpty) return [];

    // Group cards by category using the vocabId → category lookup table.
    // The category data is embedded in the vocabId prefix for A1 words.
    // We compute this from the known category-to-id-range mapping in vocab_a1_300.
    final Map<String, _CategoryAgg> byCategory = {};

    for (final card in allCards) {
      final vocabId = card['id'] as String? ?? '';
      final state = card['state'] as String? ?? 'new';
      final category = _categoryForVocabId(vocabId);

      byCategory.putIfAbsent(category, () => _CategoryAgg());
      byCategory[category]!.total++;
      if (state == 'review') {
        byCategory[category]!.mastered++;
      }
    }

    // Convert to sorted list (highest mastery first)
    final result = byCategory.entries
        .map((e) => CategoryMastery(
              name: e.key,
              masteredCount: e.value.mastered,
              totalCount: e.value.total,
            ))
        .toList();

    result.sort((a, b) => b.ratio.compareTo(a.ratio));
    return result;
  }

  // -----------------------------------------------------------------------
  // Review schedule builder (from real Firestore card data)
  // -----------------------------------------------------------------------

  /// Computes how many cards are due today, tomorrow, and this week.
  ///
  /// - new / learning / relearning: always count as due today
  /// - review: due when dueDate <= end of the target day
  ///
  /// Returns ReviewSchedule.empty() when [allCards] is empty.
  ReviewSchedule _buildReviewSchedule(List<Map<String, dynamic>> allCards) {
    if (allCards.isEmpty) return const ReviewSchedule.empty();

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final tomorrowEnd = todayEnd.add(const Duration(days: 1));
    final weekEnd = todayEnd.add(const Duration(days: 6));

    var todayDue = 0;
    var tomorrowDue = 0;
    var weekDue = 0;

    for (final card in allCards) {
      final state = card['state'] as String? ?? 'new';
      final dueDateRaw = card['dueDate'];

      DateTime? dueDate;
      if (dueDateRaw is Timestamp) {
        dueDate = dueDateRaw.toDate();
      }

      if (state == 'new' || state == 'learning' || state == 'relearning') {
        // Always due now
        todayDue++;
        weekDue++;
      } else if (state == 'review') {
        if (dueDate == null || !dueDate.isAfter(todayEnd)) {
          todayDue++;
          weekDue++;
        } else if (!dueDate.isAfter(tomorrowEnd)) {
          tomorrowDue++;
          weekDue++;
        } else if (!dueDate.isAfter(weekEnd)) {
          weekDue++;
        }
      }
    }

    return ReviewSchedule(
      todayDue: todayDue,
      tomorrowDue: tomorrowDue,
      weekDue: weekDue,
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Maps a vocabId to its display category name.
  ///
  /// The A1 vocab database uses IDs like "eiken5_001" through "eiken5_300".
  /// Categories are assigned in contiguous blocks in the JSON asset:
  ///   001-030 Animals, 031-060 Food, 061-090 Colors & Shapes,
  ///   091-120 Numbers & Time, 121-150 Family & People, 151-180 Body,
  ///   181-210 Home & Objects, 211-240 Nature, 241-270 Actions,
  ///   271-300 School & Transport
  ///
  /// If the vocabId doesn't follow the expected pattern, returns "その他 / Other".
  String _categoryForVocabId(String vocabId) {
    // Support both "eiken5_NNN" and "a2_NNN" patterns
    final match = RegExp(r'_(\d+)$').firstMatch(vocabId);
    if (match == null) return 'その他 / Other';

    final seq = int.tryParse(match.group(1)!);
    if (seq == null) return 'その他 / Other';

    if (seq <= 30) return 'どうぶつ / Animals';
    if (seq <= 60) return 'たべもの / Food';
    if (seq <= 90) return 'いろ・かたち / Colors & Shapes';
    if (seq <= 120) return 'かず・じかん / Numbers & Time';
    if (seq <= 150) return 'かぞく・ひと / Family & People';
    if (seq <= 180) return 'からだ / Body';
    if (seq <= 210) return 'いえ・もの / Home & Objects';
    if (seq <= 240) return 'しぜん / Nature';
    if (seq <= 270) return 'うごき / Actions';
    if (seq <= 300) return 'がっこう・のりもの / School & Transport';
    return 'その他 / Other';
  }

  /// Returns 7 days of zero-activity DailyProgress for honest empty state.
  List<DailyProgress> _emptyLast7Days() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return DailyProgress(
        date: DateTime(day.year, day.month, day.day),
        wordsPracticed: 0,
        sessionMinutes: 0,
        averageScore: 0.0,
      );
    });
  }
}

/// Accumulator used during category grouping.
class _CategoryAgg {
  int total = 0;
  int mastered = 0;
}

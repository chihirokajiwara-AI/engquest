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
import 'package:engquest/core/data/vocab_repository.dart';
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

    // Compute category mastery from real card data + the REAL vocab category
    // (looked up from the vocab DB, not inferred from the id's sequence number).
    final categoryMastery = aggregateCategoryMastery(
        allCards, await _loadVocabCategoryMap(allCards));

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

  /// Builds a vocabId → REAL category map from the bundled vocab DBs, for
  /// whatever 英検 grades appear in the child's cards (the vocabId embeds the
  /// grade). Replaces the old sequence-number inference, which mislabeled every
  /// word past the first two categories and collapsed most of the deck into
  /// "Other" — a paying parent saw a wrong category breakdown.
  Future<Map<String, String>> _loadVocabCategoryMap(
      List<Map<String, dynamic>> allCards) async {
    final grades = <String>{};
    for (final card in allCards) {
      final g = vocabGradeFromId(card['id'] as String? ?? '');
      if (g != null) grades.add(g);
    }
    final map = <String, String>{};
    for (final g in grades) {
      if (!VocabRepository.hasGrade(g)) continue;
      try {
        final repo = VocabRepository();
        await repo.initialize(eikenGrade: g);
        for (final v in repo.getAll()) {
          map[v.id] = v.category;
        }
      } catch (_) {
        // Vocab DB unavailable for this grade → its cards fall back to "Other".
      }
    }
    return map;
  }

  // -----------------------------------------------------------------------
  // Review schedule builder (from real Firestore card data)
  // -----------------------------------------------------------------------

  /// Computes how many cards are due today, tomorrow, and this week.
  /// Thin wrapper over the pure [buildReviewSchedule] (uses the wall clock).
  ReviewSchedule _buildReviewSchedule(List<Map<String, dynamic>> allCards) =>
      buildReviewSchedule(allCards, DateTime.now());

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Maps a vocabId to its display category name.
  ///
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

/// vocabId → 英検 grade key, from the id prefix (the prefixes are irregular per
/// grade — mirrors the bundled vocab file naming). Non-overlapping under
/// startsWith, so no id maps to two grades. Null when no prefix matches.
const Map<String, String> _kGradeIdPrefixes = {
  'eiken5_': '5',
  'eiken4_': '4',
  'eiken3_': '3',
  'eikenpre2_': 'pre2',
  'pre2plus_': 'pre2plus',
  'eiken2_': '2',
  'eiken_pre1_': 'pre1',
};

/// Resolves a vocabId to its 英検 grade key, or null if unrecognised.
String? vocabGradeFromId(String vocabId) {
  for (final e in _kGradeIdPrefixes.entries) {
    if (vocabId.startsWith(e.key)) return e.value;
  }
  return null;
}

/// Pure category-mastery aggregation: group cards by their REAL category (from
/// [idToCategory]) and count 'review'-state cards as mastered, sorted by ratio.
/// A vocabId absent from the map falls back to "その他 / Other" (e.g. a grade
/// whose vocab DB didn't load). Empty cards → empty list (honest "no data").
List<CategoryMastery> aggregateCategoryMastery(
  List<Map<String, dynamic>> allCards,
  Map<String, String> idToCategory,
) {
  if (allCards.isEmpty) return [];
  final byCategory = <String, _CategoryAgg>{};
  for (final card in allCards) {
    final vocabId = card['id'] as String? ?? '';
    final state = card['state'] as String? ?? 'new';
    final category = idToCategory[vocabId] ?? 'その他 / Other';
    byCategory.putIfAbsent(category, () => _CategoryAgg());
    byCategory[category]!.total++;
    if (state == 'review') byCategory[category]!.mastered++;
  }
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

/// Pure review-schedule bucketing as of [now]. Counts how many cards are due
/// today / tomorrow / this-week (7 days inclusive of today):
///   • new / learning / relearning → always due today (and this week)
///   • review → bucketed by dueDate (a null or past dueDate = overdue = today)
/// [card]['dueDate'] may be a Firestore Timestamp or a DateTime (tests).
/// Empty cards → ReviewSchedule.empty(). Pure + public so it is unit-tested.
ReviewSchedule buildReviewSchedule(
  List<Map<String, dynamic>> allCards,
  DateTime now,
) {
  if (allCards.isEmpty) return const ReviewSchedule.empty();

  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final tomorrowEnd = todayEnd.add(const Duration(days: 1));
  final weekEnd = todayEnd.add(const Duration(days: 6));

  var todayDue = 0;
  var tomorrowDue = 0;
  var weekDue = 0;

  for (final card in allCards) {
    final state = card['state'] as String? ?? 'new';
    final dueRaw = card['dueDate'];
    final DateTime? dueDate = dueRaw is Timestamp
        ? dueRaw.toDate()
        : dueRaw is DateTime
            ? dueRaw
            : null;

    if (state == 'new' || state == 'learning' || state == 'relearning') {
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

// ENG Quest — Progress data models (C08 Parent Dashboard)

class DailyProgress {
  final DateTime date;
  final int wordsPracticed;
  final int sessionMinutes;
  final double averageScore; // 0.0-3.0  (Again=0, Hard=1, Good=2, Easy=3)

  const DailyProgress({
    required this.date,
    required this.wordsPracticed,
    required this.sessionMinutes,
    required this.averageScore,
  });

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    return DailyProgress(
      date: DateTime.parse(json['date'] as String),
      wordsPracticed: (json['wordsPracticed'] as num).toInt(),
      sessionMinutes: (json['sessionMinutes'] as num).toInt(),
      averageScore: (json['averageScore'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'wordsPracticed': wordsPracticed,
        'sessionMinutes': sessionMinutes,
        'averageScore': averageScore,
      };
}

/// Per-category mastery data derived from real FSRS card states.
class CategoryMastery {
  /// Display name of the category (e.g. "Animals")
  final String name;

  /// Number of cards in this category in 'review' state (mastered)
  final int masteredCount;

  /// Total number of cards in this category
  final int totalCount;

  /// Mastery ratio 0.0–1.0 (masteredCount / totalCount)
  double get ratio => totalCount > 0 ? masteredCount / totalCount : 0.0;

  const CategoryMastery({
    required this.name,
    required this.masteredCount,
    required this.totalCount,
  });
}

/// FSRS-derived review schedule counts.
class ReviewSchedule {
  /// Cards due today (dueDate <= end-of-today or state is new/learning/relearning)
  final int todayDue;

  /// Cards due tomorrow
  final int tomorrowDue;

  /// Cards due within the next 7 days (inclusive of today)
  final int weekDue;

  const ReviewSchedule({
    required this.todayDue,
    required this.tomorrowDue,
    required this.weekDue,
  });

  /// All zeros — used when no card data is available yet.
  const ReviewSchedule.empty()
      : todayDue = 0,
        tomorrowDue = 0,
        weekDue = 0;
}

class LearningProgress {
  final String uid;
  final int currentStreak;        // consecutive study days
  final int totalWordsMastered;   // Retrievability > 0.9
  final int totalWordsPracticed;
  final double masteryPercent;    // totalWordsMastered / 300
  final List<DailyProgress> last7Days;
  final double eikenReadiness;    // 0-100
  final DateTime? nextReviewDue;  // earliest FSRS due date

  /// Real category mastery from Firestore FSRS cards.
  /// Empty list = no card data yet (show "no data" state in UI).
  final List<CategoryMastery> categoryMastery;

  /// Real review schedule from Firestore FSRS cards.
  final ReviewSchedule reviewSchedule;

  const LearningProgress({
    required this.uid,
    required this.currentStreak,
    required this.totalWordsMastered,
    required this.totalWordsPracticed,
    required this.masteryPercent,
    required this.last7Days,
    required this.eikenReadiness,
    this.nextReviewDue,
    this.categoryMastery = const [],
    this.reviewSchedule = const ReviewSchedule.empty(),
  });

  factory LearningProgress.fromJson(Map<String, dynamic> json) {
    return LearningProgress(
      uid: json['uid'] as String,
      currentStreak: (json['currentStreak'] as num).toInt(),
      totalWordsMastered: (json['totalWordsMastered'] as num).toInt(),
      totalWordsPracticed: (json['totalWordsPracticed'] as num).toInt(),
      masteryPercent: (json['masteryPercent'] as num).toDouble(),
      last7Days: (json['last7Days'] as List<dynamic>)
          .map((e) => DailyProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
      eikenReadiness: (json['eikenReadiness'] as num).toDouble(),
      nextReviewDue: json['nextReviewDue'] != null
          ? DateTime.parse(json['nextReviewDue'] as String)
          : null,
      // categoryMastery and reviewSchedule are runtime-only; not serialized
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'currentStreak': currentStreak,
        'totalWordsMastered': totalWordsMastered,
        'totalWordsPracticed': totalWordsPracticed,
        'masteryPercent': masteryPercent,
        'last7Days': last7Days.map((d) => d.toJson()).toList(),
        'eikenReadiness': eikenReadiness,
        'nextReviewDue': nextReviewDue?.toIso8601String(),
      };
}

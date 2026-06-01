// lib/core/fsrs/fsrs_card.dart
// ENG Quest — FSRS-4.5 Card State Model (C05)
// Immutable card data class with copyWith for functional updates

import 'dart:math' as math;

/// FSRS card learning state
enum CardState { newCard, learning, review, relearning }

extension CardStateExtension on CardState {
  String get value {
    switch (this) {
      case CardState.newCard:
        return 'new';
      case CardState.learning:
        return 'learning';
      case CardState.review:
        return 'review';
      case CardState.relearning:
        return 'relearning';
    }
  }

  static CardState fromString(String s) {
    switch (s) {
      case 'learning':
        return CardState.learning;
      case 'review':
        return CardState.review;
      case 'relearning':
        return CardState.relearning;
      default:
        return CardState.newCard;
    }
  }
}

/// 4-level rating grade passed to FSRS scheduler
enum Grade { again, hard, good, easy }

extension GradeExtension on Grade {
  /// 1-indexed integer value matching FSRS-4.5 formula convention
  int get index1 => index + 1;

  String get label {
    switch (this) {
      case Grade.again:
        return 'Again';
      case Grade.hard:
        return 'Hard';
      case Grade.good:
        return 'Good';
      case Grade.easy:
        return 'Easy';
    }
  }
}

/// Immutable FSRS card — represents one vocabulary word's SRS state.
///
/// Use [copyWith] to produce updated states rather than mutating in place.
class FSRSCard {
  /// Links to [VocabItem.id] (e.g., "eiken5_001")
  final String vocabId;

  /// Current learning state
  final CardState state;

  /// Memory stability in days (how long before R drops to 0.9)
  final double stability;

  /// Difficulty 0–10 (higher = harder)
  final double difficulty;

  /// Total review count (including lapses)
  final int reps;

  /// Forgetting / lapse count
  final int lapses;

  /// Scheduled next review timestamp (null = never reviewed = show immediately)
  final DateTime? dueDate;

  /// Timestamp of the last review
  final DateTime? lastReview;

  const FSRSCard({
    required this.vocabId,
    this.state = CardState.newCard,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.reps = 0,
    this.lapses = 0,
    this.dueDate,
    this.lastReview,
  });

  /// True when card should appear in today's session
  bool get isDue => dueDate == null || DateTime.now().isAfter(dueDate!);

  /// Current retrievability R(t, S) using FSRS-4.5 formula.
  /// Returns 0 if card has never been reviewed.
  double retrievabilityNow() {
    if (lastReview == null || stability <= 0) return 0.0;
    final t = DateTime.now().difference(lastReview!).inSeconds / 86400.0;
    if (t < 0) return 1.0;
    const factor = 19.0 / 81.0;
    const decay = -0.5;
    final base = 1.0 + factor * t / stability;
    return math.pow(base, decay).toDouble();
  }

  FSRSCard copyWith({
    String? vocabId,
    CardState? state,
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
    DateTime? dueDate,
    DateTime? lastReview,
    bool clearDueDate = false,
    bool clearLastReview = false,
  }) {
    return FSRSCard(
      vocabId: vocabId ?? this.vocabId,
      state: state ?? this.state,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      lastReview: clearLastReview ? null : (lastReview ?? this.lastReview),
    );
  }

  Map<String, dynamic> toJson() => {
        'vocabId': vocabId,
        'state': state.value,
        'stability': stability,
        'difficulty': difficulty,
        'reps': reps,
        'lapses': lapses,
        'dueDate': dueDate?.toIso8601String(),
        'lastReview': lastReview?.toIso8601String(),
      };

  factory FSRSCard.fromJson(Map<String, dynamic> json) {
    return FSRSCard(
      vocabId: json['vocabId'] as String,
      state: CardStateExtension.fromString(json['state'] as String? ?? 'new'),
      stability: (json['stability'] as num? ?? 0).toDouble(),
      difficulty: (json['difficulty'] as num? ?? 0).toDouble(),
      reps: json['reps'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      lastReview: json['lastReview'] != null
          ? DateTime.parse(json['lastReview'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'FSRSCard($vocabId | ${state.value} | S=$stability D=$difficulty '
      'reps=$reps lapses=$lapses due=$dueDate)';
}

// Locks the achievement IDs to the firestore.rules write pattern.
//
// firestore.rules gates writes to users/{uid}/achievements/{achievementId} with
//   achievementId.matches('[a-zA-Z0-9_]{3,50}')
// If a future achievement id does NOT match that pattern, the deployed rule would
// silently DENY its write (AchievementService swallows the error) — the badge
// would never persist once a real Firebase project is enabled. There is no
// Firebase emulator in this toolchain, so this test enforces the data↔rule
// contract directly: keep this pattern in sync with firestore.rules.
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/gamification/achievement.dart';

void main() {
  // Must equal the pattern in firestore.rules (achievements match block).
  final ruleIdPattern = RegExp(r'^[a-zA-Z0-9_]{3,50}$');

  test('every achievement id is writable under the firestore.rules pattern',
      () {
    expect(kAchievements, isNotEmpty);
    for (final def in kAchievements) {
      expect(ruleIdPattern.hasMatch(def.id), isTrue,
          reason: 'achievement id "${def.id}" would be DENIED by the '
              'firestore.rules achievements write pattern — the badge would '
              'never persist. Fix the id or widen the rule (keep them in sync).');
    }
  });

  // Reward-runway depth: a committed learner used to exhaust each category early
  // (streak capped at 10, mastery at 200, level at 5) and then had nothing left
  // to chase — a retention dead-end. Lock an aspirational top tier per category
  // so a future refactor can't silently shrink the runway. Grounded in 2026
  // retention practice (e.g. Duolingo's first Streak-Society milestone = 30 days).
  test('each category keeps an aspirational top tier (reward runway)', () {
    int topTarget(AchievementCategory c) => kAchievements
        .where((d) => d.category == c)
        .map((d) => d.target)
        .fold(0, (a, b) => a > b ? a : b);

    expect(topTarget(AchievementCategory.streak), greaterThanOrEqualTo(30),
        reason: 'a month-long streak milestone anchors the daily-return habit');
    expect(topTarget(AchievementCategory.mastery), greaterThanOrEqualTo(500),
        reason: 'grades carry 1,300–3,000 words; 200 ran out too early');
    expect(topTarget(AchievementCategory.level), greaterThanOrEqualTo(10),
        reason: 'XP progression must stay rewarding past the early game');
  });

  // Capstone = the top tier of a category; its unlock celebration is amplified
  // (proportional reward). The newly-added top tiers must register as capstones,
  // and an early badge must NOT — else a 30-day streak feels like a 3-day one.
  group('isCapstoneAchievement (proportional reward)', () {
    AchievementDef byId(String id) =>
        kAchievements.firstWhere((d) => d.id == id);

    test('the top tier of each category is a capstone', () {
      for (final id in [
        'streak_30',
        'mastery_500',
        'level_10',
        'practice_500'
      ]) {
        expect(isCapstoneAchievement(byId(id)), isTrue,
            reason: '$id is a top tier');
      }
    });

    test('an early/mid badge is NOT a capstone', () {
      for (final id in ['streak_3', 'mastery_10', 'level_3', 'practice_50']) {
        expect(isCapstoneAchievement(byId(id)), isFalse,
            reason: '$id is not the category top tier');
      }
    });

    test('exactly one capstone per category', () {
      for (final c in AchievementCategory.values) {
        final caps = kAchievements
            .where((d) => d.category == c && isCapstoneAchievement(d))
            .length;
        expect(caps, 1, reason: 'category $c should have a single capstone');
      }
    });
  });
}

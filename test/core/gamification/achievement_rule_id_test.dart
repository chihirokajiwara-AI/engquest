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
}

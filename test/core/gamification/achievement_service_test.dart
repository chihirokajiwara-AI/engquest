// test/core/gamification/achievement_service_test.dart
// ENG Quest — Unit tests for Achievement model + AchievementService (T06)
//
// Tests:
//   - AchievementState serialization (toFirestore / fromFirestore)
//   - AchievementService.init() — loads from Firestore, creates empty states
//   - AchievementService.checkAndUpdate() — progress tracking, unlock detection
//   - Multiple achievements unlocked in single check
//   - Already-unlocked achievements are not re-triggered
//   - Firestore persistence of achievement state
//   - achievementDefById lookup
//
// Run: flutter test test/core/gamification/achievement_service_test.dart

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/core/gamification/achievement.dart';
import 'package:engquest/core/gamification/achievement_service.dart';

void main() {
  const uid = 'test_user_ach_001';

  // ── AchievementState serialization ────────────────────────────────────────

  group('AchievementState', () {
    test('empty state has zero progress and is locked', () {
      final state = AchievementState.empty('mastery_10');
      expect(state.achievementId, 'mastery_10');
      expect(state.progress, 0);
      expect(state.unlocked, false);
      expect(state.unlockedAt, isNull);
    });

    test('toFirestore / fromFirestore round-trip', () {
      final now = DateTime(2026, 6, 1, 12, 0);
      final original = AchievementState(
        achievementId: 'streak_7',
        progress: 7,
        unlocked: true,
        unlockedAt: now,
      );

      final map = original.toFirestore();
      final restored = AchievementState.fromFirestore('streak_7', map);

      expect(restored.achievementId, 'streak_7');
      expect(restored.progress, 7);
      expect(restored.unlocked, true);
      expect(restored.unlockedAt, now);
    });

    test('fromFirestore handles missing fields gracefully', () {
      final state = AchievementState.fromFirestore('mastery_10', {});
      expect(state.progress, 0);
      expect(state.unlocked, false);
      expect(state.unlockedAt, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      final state = AchievementState.empty('mastery_10');
      final updated = state.copyWith(progress: 5);
      expect(updated.progress, 5);
      expect(updated.unlocked, false);
      expect(state.progress, 0); // original unchanged
    });
  });

  // ── achievementDefById ────────────────────────────────────────────────────

  group('achievementDefById', () {
    test('returns definition for valid id', () {
      final def = achievementDefById('mastery_10');
      expect(def, isNotNull);
      expect(def!.target, 10);
      expect(def.category, AchievementCategory.mastery);
    });

    test('returns null for unknown id', () {
      expect(achievementDefById('nonexistent'), isNull);
    });
  });

  // ── AchievementService.init ───────────────────────────────────────────────

  group('AchievementService.init', () {
    test('creates empty states for all achievements on first run', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      final states = await svc.init(uid);

      expect(states.length, kAchievements.length);
      for (final def in kAchievements) {
        expect(states[def.id], isNotNull);
        expect(states[def.id]!.progress, 0);
        expect(states[def.id]!.unlocked, false);
      }
    });

    test('loads existing state from Firestore', () async {
      final db = FakeFirebaseFirestore();
      // Pre-populate one achievement
      await db
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .doc('mastery_10')
          .set({'progress': 8, 'unlocked': false});

      final svc = AchievementService(firestore: db);
      final states = await svc.init(uid);

      expect(states['mastery_10']!.progress, 8);
      expect(states['mastery_10']!.unlocked, false);
    });

    test('returns cached data on second call', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      final first = await svc.init(uid);
      final second = await svc.init(uid);
      expect(identical(first, second), true);
    });
  });

  // ── AchievementService.checkAndUpdate ─────────────────────────────────────

  group('AchievementService.checkAndUpdate', () {
    test('unlocks mastery_10 when totalMastered >= 10', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      final unlocked = await svc.checkAndUpdate(
        uid: uid,
        totalMastered: 12,
        currentStreak: 0,
        totalPracticed: 30,
        level: 1,
      );

      expect(unlocked, contains('mastery_10'));
      expect(svc.cachedStates!['mastery_10']!.unlocked, true);
      expect(svc.cachedStates!['mastery_10']!.progress, 12);
    });

    test('does not unlock mastery_10 when totalMastered < 10', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      final unlocked = await svc.checkAndUpdate(
        uid: uid,
        totalMastered: 5,
        currentStreak: 0,
        totalPracticed: 10,
        level: 1,
      );

      expect(unlocked, isEmpty);
      expect(svc.cachedStates!['mastery_10']!.progress, 5);
      expect(svc.cachedStates!['mastery_10']!.unlocked, false);
    });

    test('unlocks multiple achievements at once', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      final unlocked = await svc.checkAndUpdate(
        uid: uid,
        totalMastered: 100,
        currentStreak: 10,
        totalPracticed: 500,
        level: 5,
      );

      // Should unlock mastery_10, mastery_50, mastery_100
      expect(unlocked, contains('mastery_10'));
      expect(unlocked, contains('mastery_50'));
      expect(unlocked, contains('mastery_100'));
      // Should unlock streak_3, streak_7, streak_10
      expect(unlocked, contains('streak_3'));
      expect(unlocked, contains('streak_7'));
      expect(unlocked, contains('streak_10'));
      // Should unlock practice_50, practice_200, practice_500
      expect(unlocked, contains('practice_50'));
      expect(unlocked, contains('practice_200'));
      expect(unlocked, contains('practice_500'));
      // Should unlock level_3, level_5
      expect(unlocked, contains('level_3'));
      expect(unlocked, contains('level_5'));
    });

    test('does not re-trigger already unlocked achievements', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      // First call unlocks
      await svc.checkAndUpdate(
        uid: uid,
        totalMastered: 15,
        currentStreak: 0,
        totalPracticed: 0,
        level: 1,
      );

      // Second call with same stats should not re-unlock
      final secondUnlocked = await svc.checkAndUpdate(
        uid: uid,
        totalMastered: 15,
        currentStreak: 0,
        totalPracticed: 0,
        level: 1,
      );

      expect(secondUnlocked, isEmpty);
    });

    test('persists unlocked achievement to Firestore', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      await svc.checkAndUpdate(
        uid: uid,
        totalMastered: 10,
        currentStreak: 0,
        totalPracticed: 0,
        level: 1,
      );

      // Verify Firestore doc was written
      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .doc('mastery_10')
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['unlocked'], true);
      expect(doc.data()!['progress'], 10);
    });

    test('fires unlockedNotifier on new unlock', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);

      List<String>? notified;
      svc.unlockedNotifier.addListener(() {
        notified = svc.unlockedNotifier.value;
      });

      await svc.checkAndUpdate(
        uid: uid,
        totalMastered: 10,
        currentStreak: 0,
        totalPracticed: 0,
        level: 1,
      );

      expect(notified, isNotNull);
      expect(notified, contains('mastery_10'));
    });
  });

  // ── clearCache ────────────────────────────────────────────────────────────

  group('clearCache', () {
    test('resets cached states and notifier', () async {
      final db = FakeFirebaseFirestore();
      final svc = AchievementService(firestore: db);
      await svc.init(uid);

      svc.clearCache();

      expect(svc.cachedStates, isNull);
      expect(svc.unlockedNotifier.value, isEmpty);
    });
  });
}

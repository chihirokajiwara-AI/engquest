// test/core/gamification/xp_service_test.dart
// ENG Quest — Unit tests for XpService + XpProfile
//
// Tests:
//   - levelFromXp() threshold boundaries
//   - xpInCurrentLevel() / xpNeededForLevel() calculations
//   - XpProfile.levelProgress fraction
//   - XpService.awardXp() — grade→XP mapping, level-up detection
//   - XpService.awardXpBatch() — multi-grade batch
//   - XpService.init() — loads from Firestore, falls back on error
//   - Firestore persistence (fake_cloud_firestore)
//   - Level-up notifier fires correctly
//
// Run: flutter test test/core/gamification/xp_service_test.dart

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/core/gamification/xp_profile.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';

void main() {
  const uid = 'test_user_xp_001';

  // ── levelFromXp ─────────────────────────────────────────────────────────────

  group('levelFromXp()', () {
    test('Lv.1 at 0 XP', () => expect(levelFromXp(0), 1));
    test('Lv.1 at 99 XP', () => expect(levelFromXp(99), 1));
    test('Lv.2 at exactly 100 XP', () => expect(levelFromXp(100), 2));
    test('Lv.2 at 249 XP', () => expect(levelFromXp(249), 2));
    test('Lv.3 at exactly 250 XP', () => expect(levelFromXp(250), 3));
    test('Lv.4 at exactly 500 XP', () => expect(levelFromXp(500), 4));
    test('Lv.5 at exactly 1000 XP', () => expect(levelFromXp(1000), 5));
    test('Lv.6 at exactly 2000 XP', () => expect(levelFromXp(2000), 6));
    test('Lv.7 at exactly 4000 XP', () => expect(levelFromXp(4000), 7));
    test('Lv.8 at exactly 7000 XP', () => expect(levelFromXp(7000), 8));
    test('Lv.8 at 99999 XP (beyond max defined)',
        () => expect(levelFromXp(99999), 8));
  });

  // ── xpInCurrentLevel / xpNeededForLevel ────────────────────────────────────

  group('xp progress helpers', () {
    test('xpInCurrentLevel at Lv.1, 50 XP → 50', () {
      expect(xpInCurrentLevel(50), 50);
    });

    test('xpInCurrentLevel at Lv.2 start (100 XP) → 0', () {
      expect(xpInCurrentLevel(100), 0);
    });

    test('xpInCurrentLevel at Lv.2, 175 XP → 75 (175-100)', () {
      expect(xpInCurrentLevel(175), 75);
    });

    test('xpNeededForLevel Lv.1 = 100 (100-0)', () {
      expect(xpNeededForLevel(1), 100);
    });

    test('xpNeededForLevel Lv.2 = 150 (250-100)', () {
      expect(xpNeededForLevel(2), 150);
    });

    test('xpNeededForLevel Lv.3 = 250 (500-250)', () {
      expect(xpNeededForLevel(3), 250);
    });
  });

  // ── XpProfile.levelProgress ────────────────────────────────────────────────

  group('XpProfile.levelProgress', () {
    test('50% through Lv.1 (50 XP out of 100)', () {
      final p = XpProfile(uid: uid, totalXp: 50, level: 1);
      expect(p.levelProgress, closeTo(0.5, 0.001));
    });

    test('0% at Lv.2 start (100 XP)', () {
      final p = XpProfile(uid: uid, totalXp: 100, level: 2);
      expect(p.levelProgress, closeTo(0.0, 0.001));
    });

    test('50% through Lv.2 at 175 XP (75 of 150)', () {
      final p = XpProfile(uid: uid, totalXp: 175, level: 2);
      expect(p.levelProgress, closeTo(0.5, 0.001));
    });

    test('clamped to 1.0 at max level', () {
      final p = XpProfile(uid: uid, totalXp: 99999, level: 8);
      expect(p.levelProgress, 0.0); // 9999 span → 0.0 (max level)
    });
  });

  // ── XpProfile.fromFirestore / toFirestore round-trip ──────────────────────

  group('XpProfile serialisation', () {
    test('fromFirestore round-trips correctly', () {
      final original = XpProfile(uid: uid, totalXp: 340, level: 4);
      final data = original.toFirestore();
      final restored = XpProfile.fromFirestore(uid, data);
      expect(restored.totalXp, 340);
      expect(restored.level,
          levelFromXp(340)); // derived, not stored independently
    });

    test('fromFirestore with missing totalXp defaults to 0', () {
      final p = XpProfile.fromFirestore(uid, {});
      expect(p.totalXp, 0);
      expect(p.level, 1);
    });

    test('XpProfile.zero has level=1 totalXp=0', () {
      final p = XpProfile.zero(uid);
      expect(p.level, 1);
      expect(p.totalXp, 0);
    });
  });

  // ── XpService.awardXp ─────────────────────────────────────────────────────

  group('XpService.awardXp()', () {
    late FakeFirebaseFirestore fakeFirestore;
    late XpService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = XpService(firestore: fakeFirestore);
    });

    tearDown(() => service.clearCache());

    test('Again grade awards 0 XP', () async {
      final result = await service.awardXp(uid, Grade.again);
      expect(result.xpGained, 0);
      expect(result.after.totalXp, 0);
      expect(result.didLevelUp, false);
    });

    test('Hard grade awards 5 XP', () async {
      final result = await service.awardXp(uid, Grade.hard);
      expect(result.xpGained, 5);
      expect(result.after.totalXp, 5);
    });

    test('Good grade awards 10 XP', () async {
      final result = await service.awardXp(uid, Grade.good);
      expect(result.xpGained, 10);
      expect(result.after.totalXp, 10);
    });

    test('Easy grade awards 15 XP', () async {
      final result = await service.awardXp(uid, Grade.easy);
      expect(result.xpGained, 15);
      expect(result.after.totalXp, 15);
    });

    test('XP accumulates across multiple awards', () async {
      await service.awardXp(uid, Grade.good); // +10 = 10
      await service.awardXp(uid, Grade.easy); // +15 = 25
      final result = await service.awardXp(uid, Grade.hard); // +5 = 30
      expect(result.after.totalXp, 30);
    });

    test('Level-up fires when crossing threshold', () async {
      // Lv.1→Lv.2 at 100 XP — need 10 Good awards
      for (int i = 0; i < 9; i++) {
        final r = await service.awardXp(uid, Grade.good); // 90 XP total
        expect(r.didLevelUp, false, reason: 'should not level up at award $i');
      }
      final levelUpResult = await service.awardXp(uid, Grade.good); // 100 XP
      expect(levelUpResult.didLevelUp, true);
      expect(levelUpResult.after.level, 2);
      expect(levelUpResult.before.level, 1);
    });

    test('levelUpNotifier is set when level-up occurs', () async {
      expect(service.levelUpNotifier.value, isNull);
      for (int i = 0; i < 9; i++) {
        await service.awardXp(uid, Grade.good);
      }
      await service.awardXp(uid, Grade.good); // level-up
      expect(service.levelUpNotifier.value, isNotNull);
      expect(service.levelUpNotifier.value!.didLevelUp, true);
    });

    test('profileNotifier updates after each award', () async {
      expect(service.profileNotifier.value, isNull);
      await service.awardXp(uid, Grade.easy);
      expect(service.profileNotifier.value, isNotNull);
      expect(service.profileNotifier.value!.totalXp, 15);
    });
  });

  // ── XpService.awardXpBatch ────────────────────────────────────────────────

  group('XpService.awardXpBatch()', () {
    late FakeFirebaseFirestore fakeFirestore;
    late XpService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = XpService(firestore: fakeFirestore);
    });

    tearDown(() => service.clearCache());

    test('empty batch returns current profile unchanged', () async {
      final result = await service.awardXpBatch(uid, []);
      expect(result.xpGained, 0);
      expect(result.after.totalXp, 0);
    });

    test('batch of [Good, Easy, Hard] awards 10+15+5=30 XP', () async {
      final result =
          await service.awardXpBatch(uid, [Grade.good, Grade.easy, Grade.hard]);
      expect(result.after.totalXp, 30);
    });

    test('batch level-up detection works', () async {
      // 10 x Good = 100 XP → Lv.2
      final grades = List.filled(10, Grade.good);
      final result = await service.awardXpBatch(uid, grades);
      expect(result.after.level, 2);
      expect(result.after.totalXp, 100);
    });
  });

  // ── XpService.init — Firestore persistence ────────────────────────────────

  group('XpService.init() — Firestore round-trip', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('new user gets zero profile', () async {
      final service = XpService(firestore: fakeFirestore);
      final profile = await service.init(uid);
      expect(profile.totalXp, 0);
      expect(profile.level, 1);
    });

    test('profile persisted to Firestore and re-read on new service instance',
        () async {
      // Write 150 XP via service1
      final service1 = XpService(firestore: fakeFirestore);
      for (int i = 0; i < 10; i++) {
        await service1.awardXp(uid, Grade.easy); // 10 x 15 = 150 XP
      }

      // New service instance (simulates app restart) reads from Firestore
      final service2 = XpService(firestore: fakeFirestore);
      final profile = await service2.init(uid);
      expect(profile.totalXp, 150);
      expect(profile.level, 2); // 150 ≥ 100 → Lv.2
    });

    test('init with existing Firestore data loads correct level', () async {
      // Pre-seed Firestore with 500 XP directly
      await fakeFirestore.collection('users').doc(uid).set({
        'totalXp': 500,
        'level': 4,
        'updatedAt': null,
      });

      final service = XpService(firestore: fakeFirestore);
      final profile = await service.init(uid);
      expect(profile.totalXp, 500);
      expect(profile.level, 4);
    });

    test('clearCache forces re-read from Firestore on next init', () async {
      final service = XpService(firestore: fakeFirestore);
      await service.awardXp(uid, Grade.easy); // 15 XP cached

      service.clearCache();
      expect(service.currentProfile(uid), isNull);

      final reloaded = await service.init(uid);
      expect(reloaded.totalXp, 15); // re-read from Firestore
    });
  });

  // ── kGradeXp constant validation ──────────────────────────────────────────

  group('kGradeXp constants', () {
    test('again = 0', () => expect(kGradeXp['again'], 0));
    test('hard = 5', () => expect(kGradeXp['hard'], 5));
    test('good = 10', () => expect(kGradeXp['good'], 10));
    test('easy = 15', () => expect(kGradeXp['easy'], 15));
  });

  // ── kLevelThresholds ordering ─────────────────────────────────────────────

  group('kLevelThresholds', () {
    test('thresholds are strictly increasing from index 1', () {
      for (int i = 2; i < kLevelThresholds.length; i++) {
        expect(kLevelThresholds[i], greaterThan(kLevelThresholds[i - 1]),
            reason: 'threshold at index $i should exceed index ${i - 1}');
      }
    });

    test('Lv.1 threshold is 0', () => expect(kLevelThresholds[1], 0));
    test('Lv.5 threshold is 1000', () => expect(kLevelThresholds[5], 1000));
  });
}

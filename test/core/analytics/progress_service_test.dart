// test/core/analytics/progress_service_test.dart
// ENG Quest — ProgressService unit tests (P1-5)
//
// Tests Firestore-integrated ProgressService with mock repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreProgressRepository repo;
  late ProgressService service;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = FirestoreProgressRepository(firestore: fakeDb);
    service = ProgressService(repository: repo);
  });

  // Seeds [count] FSRS card docs under users/{uid}/cards — the child's deck.
  // masteryPercent is measured against this real deck size (which scales with
  // 英検 grade), not a hardcoded 300.
  Future<void> seedDeck(String uid, int count, {String state = 'new'}) async {
    for (var i = 0; i < count; i++) {
      await fakeDb
          .collection('users')
          .doc(uid)
          .collection('cards')
          .doc('c$i')
          .set({'state': state});
    }
  }

  // ── getProgress fallback ──────────────────────────────────────────────────

  group('getProgress — no Firestore data', () {
    test('returns mock progress for new user', () async {
      final progress = await service.getProgress('new_user');
      expect(progress.uid, equals('new_user'));
      expect(progress.last7Days.length, equals(7));
      // Mock returns 0 mastered for new user
      expect(progress.totalWordsMastered, equals(0));
    });

    test('masteryPercent is 0 for new user (no deck loaded)', () async {
      final progress = await service.getProgress('new_user');
      expect(progress.masteryPercent, closeTo(0.0, 0.001));
    });
  });

  // ── getProgress with Firestore data ──────────────────────────────────────

  group('getProgress — with Firestore data', () {
    test('uses Firestore streak when available', () async {
      // Write 3 consecutive days of sessions
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        final day = now.subtract(Duration(days: i));
        final key = '${day.year.toString().padLeft(4, '0')}-'
            '${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        await fakeDb
            .collection('users')
            .doc('active_user')
            .collection('sessions')
            .doc(key)
            .set({'wordsPracticed': 20});
      }

      final progress = await service.getProgress('active_user');
      expect(progress.currentStreak, equals(3));
    });

    test('reads totalWordsMastered from profile doc', () async {
      await fakeDb.collection('users').doc('prof_user').set({
        'totalWordsMastered': 88,
        'totalWordsPracticed': 200,
        'currentStreak': 4,
      });

      final progress = await service.getProgress('prof_user');
      expect(progress.totalWordsMastered, equals(88));
      expect(progress.totalWordsPracticed, equals(200));
    });

    test('masteryPercent reaches ~0.9 near full deck mastery', () async {
      await fakeDb.collection('users').doc('readiness_user').set({
        'totalWordsMastered': 9, // 9/10 of the deck
        'totalWordsPracticed': 10,
        'currentStreak': 10,
      });
      await seedDeck('readiness_user', 10);

      final progress = await service.getProgress('readiness_user');
      expect(progress.masteryPercent, closeTo(0.9, 0.001));
    });

    test('masteryPercent is mastered/deck below full', () async {
      await fakeDb.collection('users').doc('half_user').set({
        'totalWordsMastered': 9, // 9/20 = 45%
        'totalWordsPracticed': 20,
        'currentStreak': 2,
      });
      await seedDeck('half_user', 20);

      final progress = await service.getProgress('half_user');
      expect(progress.masteryPercent, closeTo(0.45, 0.001));
    });

    test('masteryPercent scales with the real deck size, not a fixed 300',
        () async {
      // A higher-grade child: mastered 3 of a 12-word deck. The denominator must
      // be the child's actual deck (which scales with 英検 grade), so the paying
      // parent sees a true %: 3/12 = 0.25, NOT 3/300 = 0.01 (the old hardcoded
      // pool). The inverse bug overstated readiness: 270 mastered of a 1,300
      // deck used to show 270/300 = 90% → "100% 英検 ready".
      await fakeDb.collection('users').doc('grade3_user').set({
        'totalWordsMastered': 3,
        'totalWordsPracticed': 12,
      });
      await seedDeck('grade3_user', 12);

      final progress = await service.getProgress('grade3_user');
      expect(progress.masteryPercent, closeTo(0.25, 0.001));
      // The real deck size is surfaced so the dashboard shows "3 / 12 習得".
      expect(progress.vocabPoolSize, equals(12));
    });

    test('masteryPercent clamps to 1.0 when the counter exceeds the deck',
        () async {
      // totalWordsMastered is a cumulative profile counter; after a grade switch
      // to a smaller deck it can briefly exceed the deck size. Clamp, never >100%.
      await fakeDb.collection('users').doc('switch_user').set({
        'totalWordsMastered': 15,
      });
      await seedDeck('switch_user', 10);

      final progress = await service.getProgress('switch_user');
      expect(progress.masteryPercent, closeTo(1.0, 0.001));
    });

    test('reads last7Days from session subcollection', () async {
      final now = DateTime.now();
      // Write today's session
      final key = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await fakeDb
          .collection('users')
          .doc('session_user')
          .collection('sessions')
          .doc(key)
          .set({
        'wordsPracticed': 30,
        'sessionMinutes': 15,
        'averageScore': 2.8,
      });

      final progress = await service.getProgress('session_user');
      final today = progress.last7Days.last; // index 6 = today
      expect(today.wordsPracticed, equals(30));
      expect(today.sessionMinutes, equals(15));
      expect(today.averageScore, closeTo(2.8, 0.001));
    });
  });

  // ── recordSession ─────────────────────────────────────────────────────────

  group('recordSession', () {
    test('writes session doc without throwing', () async {
      await expectLater(
        service.recordSession(
          uid: 'write_user',
          wordsPracticed: 15,
          minutes: 8,
          avgScore: 2.3,
          totalMastered: 15,
          totalPracticed: 30,
          streak: 2,
        ),
        completes,
      );
    });

    test('progress reflects recorded session on next load', () async {
      await service.recordSession(
        uid: 'round_trip_user',
        wordsPracticed: 20,
        minutes: 10,
        avgScore: 2.5,
        totalMastered: 20,
        totalPracticed: 30,
        streak: 1,
      );

      final progress = await service.getProgress('round_trip_user');
      expect(progress.totalWordsMastered, equals(20));
      expect(progress.last7Days.last.wordsPracticed, equals(20));
    });
  });
}

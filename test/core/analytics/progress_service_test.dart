// test/core/analytics/progress_service_test.dart
// ENG Quest — ProgressService unit tests (P1-5)
//
// Tests Firestore-integrated ProgressService with mock repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';
import 'package:engquest/core/models/progress_data.dart';
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

  // ── getProgress fallback ──────────────────────────────────────────────────

  group('getProgress — no Firestore data', () {
    test('returns mock progress for new user', () async {
      final progress = await service.getProgress('new_user');
      expect(progress.uid, equals('new_user'));
      expect(progress.last7Days.length, equals(7));
      // Mock returns 0 mastered for new user
      expect(progress.totalWordsMastered, equals(0));
    });

    test('eiken readiness is 0 for new user', () async {
      final progress = await service.getProgress('new_user');
      expect(progress.eikenReadiness, closeTo(0.0, 0.001));
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

    test('calculates eikenReadiness from mastery percent', () async {
      await fakeDb.collection('users').doc('readiness_user').set({
        'totalWordsMastered': 270, // 270/300 = 90% = 100 readiness
        'totalWordsPracticed': 300,
        'currentStreak': 10,
      });

      final progress = await service.getProgress('readiness_user');
      expect(progress.eikenReadiness, closeTo(100.0, 0.1));
    });

    test('eikenReadiness is linear below 90% mastery', () async {
      await fakeDb.collection('users').doc('half_user').set({
        'totalWordsMastered': 135, // 135/300 = 45% → 50% of 100 = 50.0
        'totalWordsPracticed': 200,
        'currentStreak': 2,
      });

      final progress = await service.getProgress('half_user');
      // 45% / 90% * 100 = 50.0
      expect(progress.eikenReadiness, closeTo(50.0, 0.5));
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

  // ── calculateEikenReadiness ───────────────────────────────────────────────

  group('calculateEikenReadiness', () {
    test('returns 100 at 90% mastery', () {
      final p = _makeProgress(mastered: 270); // 270/300 = 90%
      expect(service.calculateEikenReadiness(p), closeTo(100.0, 0.001));
    });

    test('returns 100 above 90% mastery', () {
      final p = _makeProgress(mastered: 300); // 100%
      expect(service.calculateEikenReadiness(p), closeTo(100.0, 0.001));
    });

    test('returns 0 at 0% mastery', () {
      final p = _makeProgress(mastered: 0);
      expect(service.calculateEikenReadiness(p), closeTo(0.0, 0.001));
    });

    test('returns ~55.6 at 50% mastery', () {
      final p = _makeProgress(mastered: 150); // 150/300 = 50%
      // 50% / 90% * 100 ≈ 55.56
      expect(service.calculateEikenReadiness(p), closeTo(55.56, 0.1));
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

LearningProgress _makeProgress({required int mastered}) {
  final now = DateTime.now();
  return LearningProgress(
    uid: 'test',
    currentStreak: 0,
    totalWordsMastered: mastered,
    totalWordsPracticed: mastered,
    masteryPercent: mastered / 300.0,
    last7Days: List.generate(
      7,
      (i) => DailyProgress(
        date: now.subtract(Duration(days: 6 - i)),
        wordsPracticed: 0,
        sessionMinutes: 0,
        averageScore: 0.0,
      ),
    ),
    eikenReadiness: 0,
  );
}

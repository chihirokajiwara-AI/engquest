// Durability gate (flaw-hunt 2026-06-13): a child's FSRS deck — the spaced-
// repetition CORE — must SURVIVE a page reload, including OFFLINE where Firestore
// is unreachable. Before this, FirestoreFsrsCardRepository's offline fallback was
// InMemoryFsrsCardRepository, whose Map is wiped on reload → every offline review
// evaporated and the child re-saw mastered cards. PrefsFsrsCardRepository persists
// each user's deck to SharedPreferences (= localStorage on web). This test proves
// a saved card is read back by a FRESH repository instance (the reload), which the
// in-memory repo cannot do.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/storage/preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
  });

  test('a saved card survives a fresh repository instance (reload survival)',
      () async {
    const uid = 'offline_user';
    final card = FSRSCard(
      vocabId: 'eiken5_001',
      state: CardState.review,
      stability: 12.5,
      difficulty: 3.3,
      reps: 4,
      lapses: 1,
      dueDate: DateTime(2026, 7, 1),
      lastReview: DateTime(2026, 6, 13),
    );

    // Session A: review a card offline, then "close the tab".
    await PrefsFsrsCardRepository().saveCard(uid, card);

    // Session B: a brand-new repository instance (= page reload) must see it.
    final reloaded = await PrefsFsrsCardRepository().loadDeck(uid);
    expect(reloaded, hasLength(1));
    final got = reloaded.single;
    expect(got.vocabId, 'eiken5_001');
    expect(got.state, CardState.review);
    expect(got.stability, 12.5);
    expect(got.difficulty, 3.3);
    expect(got.reps, 4);
    expect(got.lapses, 1);
    expect(got.dueDate, DateTime(2026, 7, 1));
  });

  test('contrast: InMemory repo loses the deck on a fresh instance', () async {
    const uid = 'offline_user';
    await InMemoryFsrsCardRepository()
        .saveCard(uid, const FSRSCard(vocabId: 'eiken5_002'));
    // A new in-memory instance has an empty Map — the reload-loss this fix cures.
    final reloaded = await InMemoryFsrsCardRepository().loadDeck(uid);
    expect(reloaded, isEmpty);
  });

  test('getDueCards reads through the persisted store', () async {
    const uid = 'u';
    final due = FSRSCard(
      vocabId: 'due1',
      state: CardState.review,
      dueDate: DateTime(2026, 6, 1),
      lastReview: DateTime(2026, 5, 20),
    );
    final notDue = FSRSCard(
      vocabId: 'later1',
      state: CardState.review,
      dueDate: DateTime(2026, 12, 1),
      lastReview: DateTime(2026, 6, 1),
    );
    await PrefsFsrsCardRepository().saveCards(uid, [due, notDue]);

    final dueCards =
        await PrefsFsrsCardRepository().getDueCards(uid, DateTime(2026, 6, 13));
    expect(dueCards.map((c) => c.vocabId), ['due1']);
  });

  test('clearDeck removes the persisted entry', () async {
    const uid = 'u';
    final repo = PrefsFsrsCardRepository();
    await repo.saveCard(uid, const FSRSCard(vocabId: 'x'));
    await repo.clearDeck(uid);
    expect(await PrefsFsrsCardRepository().loadDeck(uid), isEmpty);
  });

  // Lost-update gate (data-integrity flaw-hunt 2026-06-19): the whole deck lives
  // under one prefs key, so saveCard is a read-modify-write of that blob. Battle
  // fires saveCard() per answer UNAWAITED, so a fast answerer has several in
  // flight at once. Without serialization they all read the same baseline and the
  // last _write clobbers the others → FSRS progress (the learning record) is
  // silently lost. Fire 30 concurrent saves of DISTINCT cards; every one must
  // survive. (Pre-fix this collapses to ~1 card.)
  test('concurrent fire-and-forget saveCard calls do not lost-update',
      () async {
    const uid = 'rapid';
    final repo = PrefsFsrsCardRepository();
    final futures = <Future<void>>[
      for (var i = 0; i < 30; i++)
        repo.saveCard(
            uid, FSRSCard(vocabId: 'eiken5_${i.toString().padLeft(3, '0')}')),
    ];
    await Future.wait(futures);

    final reloaded = await PrefsFsrsCardRepository().loadDeck(uid);
    expect(reloaded, hasLength(30),
        reason: 'all 30 concurrent saves must persist (no lost-update)');
    expect(
      reloaded.map((c) => c.vocabId).toSet(),
      {for (var i = 0; i < 30; i++) 'eiken5_${i.toString().padLeft(3, '0')}'},
    );
  });

  // The serialization must also order a clear against in-flight saves: a save
  // queued after clearDeck still lands (does not vanish), and a save queued
  // before the clear is wiped — i.e. FIFO ordering, not arbitrary interleave.
  test('clearDeck is ordered against concurrent saves (FIFO)', () async {
    const uid = 'order';
    final repo = PrefsFsrsCardRepository();
    final before = repo.saveCard(uid, const FSRSCard(vocabId: 'before'));
    final clear = repo.clearDeck(uid);
    final after = repo.saveCard(uid, const FSRSCard(vocabId: 'after'));
    await Future.wait([before, clear, after]);

    final reloaded = await PrefsFsrsCardRepository().loadDeck(uid);
    expect(reloaded.map((c) => c.vocabId), ['after'],
        reason: 'before-clear save wiped, after-clear save survives');
  });
}

// test/features/explore/scene_solved_store_test.dart
//
// #115: the explorable world must REMEMBER which ナゾ were solved so it stays
// coloured across sessions (it used to re-grey every visit). Locks the store's
// persist round-trip + per-scene namespace isolation.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/scene_solved_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('markSolved persists and solvedIndices reads it back', () async {
    expect(await SceneSolvedStore.solvedIndices('5'), isEmpty);
    await SceneSolvedStore.markSolved('5', 1);
    await SceneSolvedStore.markSolved('5', 15);
    final got = await SceneSolvedStore.solvedIndices('5');
    expect(got, containsAll(<int>{1, 15}));
    expect(got.length, equals(2));
  });

  test('markSolved is idempotent (no duplicate keys)', () async {
    await SceneSolvedStore.markSolved('5', 1);
    await SceneSolvedStore.markSolved('5', 1);
    expect(await SceneSolvedStore.solvedIndices('5'), equals(<int>{1}));
  });

  test('scenes are namespaced — 5級 solves do not leak into 4級', () async {
    await SceneSolvedStore.markSolved('5', 1);
    await SceneSolvedStore.markSolved('4', 9);
    expect(await SceneSolvedStore.solvedIndices('5'), equals(<int>{1}));
    expect(await SceneSolvedStore.solvedIndices('4'), equals(<int>{9}));
  });

  // ── Collected coins (anti re-farm) ─────────────────────────────────────────

  test('markCoinCollected persists and collectedCoinIndices reads it back',
      () async {
    expect(await SceneSolvedStore.collectedCoinIndices('5'), isEmpty);
    await SceneSolvedStore.markCoinCollected('5', 3);
    expect(await SceneSolvedStore.collectedCoinIndices('5'), equals(<int>{3}));
  });

  test('markCoinCollected is idempotent — a coin is collectable once, ever',
      () async {
    await SceneSolvedStore.markCoinCollected('5', 3);
    await SceneSolvedStore.markCoinCollected('5', 3);
    expect(await SceneSolvedStore.collectedCoinIndices('5'), equals(<int>{3}));
  });

  test('coin-state and solve-state are independent namespaces', () async {
    // A collected coin at idx 3 must NOT register as a solved ナゾ at idx 3
    // (and vice-versa) — they drive different hotspot kinds.
    await SceneSolvedStore.markCoinCollected('5', 3);
    await SceneSolvedStore.markSolved('5', 1);
    expect(await SceneSolvedStore.solvedIndices('5'), equals(<int>{1}));
    expect(await SceneSolvedStore.collectedCoinIndices('5'), equals(<int>{3}));
  });

  test('collected coins are per-scene namespaced (5級 ≠ 4級)', () async {
    await SceneSolvedStore.markCoinCollected('5', 3);
    expect(await SceneSolvedStore.collectedCoinIndices('4'), isEmpty);
  });

  // ── Investigated observations (#124: lore beat must leave a trace) ──────────

  test('markObservationSeen persists and seenObservationIndices reads it back',
      () async {
    expect(await SceneSolvedStore.seenObservationIndices('5'), isEmpty);
    await SceneSolvedStore.markObservationSeen('5', 7);
    await SceneSolvedStore.markObservationSeen('5', 7); // idempotent
    expect(
        await SceneSolvedStore.seenObservationIndices('5'), equals(<int>{7}));
  });

  test('observation-state is independent of solve- and coin-state', () async {
    await SceneSolvedStore.markObservationSeen('5', 2);
    await SceneSolvedStore.markCoinCollected('5', 2);
    await SceneSolvedStore.markSolved('5', 2);
    // Same index, three different stores — must not bleed across kinds.
    expect(
        await SceneSolvedStore.seenObservationIndices('5'), equals(<int>{2}));
    expect(await SceneSolvedStore.collectedCoinIndices('5'), equals(<int>{2}));
    expect(await SceneSolvedStore.solvedIndices('5'), equals(<int>{2}));
  });

  test('seen observations are per-scene namespaced (5級 ≠ 4級)', () async {
    await SceneSolvedStore.markObservationSeen('5', 7);
    expect(await SceneSolvedStore.seenObservationIndices('4'), isEmpty);
  });

  // ── Unlocked hint tiers (#155: paid hints must survive a cold restart) ──────

  test('markHintTier persists and hintTiers reads it back', () async {
    expect(await SceneSolvedStore.hintTiers('5'), isEmpty);
    await SceneSolvedStore.markHintTier('5', 2, 1);
    expect(await SceneSolvedStore.hintTiers('5'), equals({2: 1}));
  });

  test('markHintTier keeps the HIGHEST tier per hotspot (one entry per idx)',
      () async {
    await SceneSolvedStore.markHintTier('5', 3, 1);
    await SceneSolvedStore.markHintTier('5', 3, 3); // upgrade
    await SceneSolvedStore.markHintTier('5', 3, 2); // lower
    final got = await SceneSolvedStore.hintTiers('5');
    expect(got[3], equals(3),
        reason: 'must not regress a paid-for higher tier');
  });

  test('markHintTier with tier <= 0 is a no-op', () async {
    await SceneSolvedStore.markHintTier('5', 4, 0);
    expect(await SceneSolvedStore.hintTiers('5'), isEmpty);
  });

  test('hint tiers are per-scene namespaced (5級 ≠ 4級)', () async {
    await SceneSolvedStore.markHintTier('5', 1, 2);
    expect(await SceneSolvedStore.hintTiers('4'), isEmpty);
  });

  test('hint-state is independent of solve/coin/observation namespaces',
      () async {
    await SceneSolvedStore.markHintTier('5', 6, 2);
    expect(await SceneSolvedStore.solvedIndices('5'), isEmpty);
    expect(await SceneSolvedStore.collectedCoinIndices('5'), isEmpty);
    expect(await SceneSolvedStore.seenObservationIndices('5'), isEmpty);
  });

  // ── ミノス mastery record ───────────────────────────────────────────────────

  test('saveMinos persists and loadMinos reads it back', () async {
    expect(await SceneSolvedStore.loadMinos('5'), 0);
    await SceneSolvedStore.saveMinos('5', 42);
    expect(await SceneSolvedStore.loadMinos('5'), 42);
  });

  test('saveMinos keeps the HIGHEST value (best-run mastery record)', () async {
    await SceneSolvedStore.saveMinos('5', 30);
    await SceneSolvedStore.saveMinos('5', 50); // higher → replaces
    await SceneSolvedStore.saveMinos('5', 20); // lower → ignored
    expect(await SceneSolvedStore.loadMinos('5'), 50,
        reason: 'a re-play with fewer ミノス must never lower the record');
  });

  test('saveMinos with 0 is a no-op (nothing to record yet)', () async {
    await SceneSolvedStore.saveMinos('5', 0);
    expect(await SceneSolvedStore.loadMinos('5'), 0);
  });

  test('ミノス records are per-grade namespaced (5級 ≠ 4級)', () async {
    await SceneSolvedStore.saveMinos('5', 25);
    expect(await SceneSolvedStore.loadMinos('4'), 0);
  });

  test('minos-state is independent of solve/coin/observation namespaces',
      () async {
    await SceneSolvedStore.saveMinos('5', 15);
    expect(await SceneSolvedStore.solvedIndices('5'), isEmpty);
    expect(await SceneSolvedStore.collectedCoinIndices('5'), isEmpty);
    expect(await SceneSolvedStore.seenObservationIndices('5'), isEmpty);
  });
}

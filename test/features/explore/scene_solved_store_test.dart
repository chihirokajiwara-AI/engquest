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
}

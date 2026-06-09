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
}

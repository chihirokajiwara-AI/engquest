// #168 — in-scene 探偵メモ (detective-memo) drawer: re-read collected lore/clues
// without leaving the scene. Locks the core contract: the memo FAB appears only
// when something has been collected (solved-NPC fragments + read observations),
// and opening it surfaces the collected lore. (Replacement for the test lost in
// worktree integration; uses the SceneView.previewAllSolved seam.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/explore/scene_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The 探偵メモ FAB is suppressed on a FRESH scene (nothing collected yet) — no
  // dead button on first entry.
  testWidgets('memo FAB hidden when nothing collected yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel(RegExp('たんていメモ')), findsNothing,
        reason: 'no collected memos on fresh entry → no FAB');
    // No timers left dangling for the framework to complain about.
    await tester.pump(const Duration(seconds: 1));
  });

  // With every NPC ナゾ solved (preview seam), their mysteryFragmentJa are
  // collected → the FAB appears so the child can re-read them.
  testWidgets('memo FAB appears once lore is collected (previewAllSolved)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SceneView(
            scene: kTown5Scene, eikenLevel: '5', previewAllSolved: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel(RegExp('たんていメモ')), findsWidgets,
        reason: 'solved-NPC fragments collected → memo FAB visible');
    await tester.pump(const Duration(seconds: 1));
  });
}

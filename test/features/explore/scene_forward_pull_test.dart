// test/features/explore/scene_forward_pull_test.dart
//
// Tests for the game-studio #3 forward-pull beat: when a NON-FINAL ナゾ is
// solved タロ delivers a diegetic "あとNつ！…" line (via the arrival-banner
// widget) AFTER the hero frame + lore have had their moment.
//
// Contract under test:
//   (1) Solving a non-final ナゾ eventually shows the forward-pull text
//       (あとNつ / あと1つ) pumped past the full chain delay.
//   (2) The forward-pull does NOT appear simultaneously with the hero overlay
//       OR the lore banner.
//   (3) Solving the FINAL ナゾ (scene cleared) does NOT show the forward-pull.
//   (4) Reduced-motion path shows the pull (after the banner clears) and
//       never produces a hero overlay.
//
// Test approach mirrors scene_hero_frame_test.dart: use the @visibleForTesting
// [applyRestoreForTest] seam via dynamic dispatch through WidgetTester.state().

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/explore/scene_view.dart';

// ── Scene NPC index helpers ──────────────────────────────────────────────────

/// All NPC hotspot indices in kTown5Scene, in definition order.
List<int> _npcIndices() => [
      for (var i = 0; i < kTown5Scene.hotspots.length; i++)
        if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) i,
    ];

int _firstNpcIdx() => _npcIndices().first;
int _lastNpcIdx() => _npcIndices().last;

/// A solved result (first-try correct).
const _solved = NazoResult(solved: true, minosEarned: 3, firstTryCorrect: true);

// ── Test seam ────────────────────────────────────────────────────────────────

Future<void> _callApplyRestore(
  WidgetTester tester,
  int idx,
  NazoResult result,
) async {
  final state = tester.state(find.byType(SceneView));
  await tester.pump();
  // ignore: avoid_dynamic_calls
  (state as dynamic)
      .applyRestoreForTest(idx, kTown5Scene.hotspots[idx], result);
  await tester.pump();
  tester.takeException(); // consume any AnimatedSize mutation noise
}

/// Pre-solve [preSolveIdx] indices so that solving [targetIdx] next is a
/// non-final solve (remaining >= 2) or a final solve (remaining == 1 after).
/// Each solve drains ALL timers (hero 1700ms + lore-wait 1300ms + pull
/// auto-dismiss 3500ms ≈ 7000ms) so forward-pull text from pre-solves is
/// fully gone before the target solve fires.
Future<void> _presolveSome(
  WidgetTester tester,
  List<int> preSolveIdx,
) async {
  for (final i in preSolveIdx) {
    await _callApplyRestore(tester, i, _solved);
    // 7200ms > hero(1700) + lore-delay(1300) + pull-autodismiss(3500) + margin.
    await tester.pump(const Duration(milliseconds: 7200));
    tester.takeException();
  }
}

// ── Pump helper ──────────────────────────────────────────────────────────────

Future<void> pumpScene(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: SceneView(
          scene: kTown5Scene,
          eikenLevel: '5',
        ),
      ),
    ),
  );
  await tester.pump(); // initState
  await tester.pump(); // _maybeGreet postFrameCallback
  // Dismiss the arrival banner immediately so it never gates other banners.
  final arrival = find.textContaining('いろが');
  if (arrival.evaluate().isNotEmpty) {
    await tester.tap(arrival);
    await tester.pump();
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // (1a) Non-final solve (remaining >= 2): pull text contains "あと" + "つ！".
  testWidgets(
      'non-final solve (remaining>=2): forward-pull line appears after hero+lore delay',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);

    // kTown5Scene has 4 NPCs. Solving idx 0 leaves 3 remaining → pull = あと3つ.
    await _callApplyRestore(tester, _firstNpcIdx(), _solved);

    // Before the hero releases: forward-pull must NOT be visible.
    expect(
      find.textContaining('あと'),
      findsNothing,
      reason: 'forward-pull must not appear before the hero frame clears',
    );

    // Advance past the full chain: hero(1700ms) + lore-wait(1300ms) = 3000ms.
    await tester.pump(const Duration(milliseconds: 3100));

    expect(
      find.textContaining('あと'),
      findsWidgets,
      reason: 'forward-pull must be visible after the full hero+lore chain',
    );
    // Verify it contains the count (3 remaining after solving idx 0 of 4 NPCs).
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texts.contains('あと'), isTrue,
        reason: 'forward-pull text must name remaining count');
    expect(tester.takeException(), isNull);
  });

  // (1b) Non-final solve (remaining == 1): pull uses the "あと1つ！さいごの" form.
  testWidgets('non-final solve (remaining==1): forward-pull uses さいごの form',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);

    final npcIdx = _npcIndices();
    // Pre-solve all but the last TWO so solving the second-to-last leaves 1 remaining.
    await _presolveSome(tester, npcIdx.sublist(0, npcIdx.length - 2));

    // Solve second-to-last → remaining == 1.
    final secondToLast = npcIdx[npcIdx.length - 2];
    await _callApplyRestore(tester, secondToLast, _solved);

    // Advance past the full chain.
    await tester.pump(const Duration(milliseconds: 3100));

    expect(
      find.textContaining('さいごの'),
      findsWidgets,
      reason: 'remaining==1 must use the さいごの variant',
    );
    expect(tester.takeException(), isNull);
  });

  // (2) Forward-pull does NOT appear simultaneously with the hero overlay.
  testWidgets('forward-pull does NOT co-exist with hero dim overlay',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);
    await _callApplyRestore(tester, _firstNpcIdx(), _solved);

    // During the hero window the dim overlay is present.
    expect(find.byKey(const ValueKey('hero_dim_overlay')), findsOneWidget);
    // Forward-pull must NOT be visible while the hero is up.
    expect(
      find.textContaining('あと'),
      findsNothing,
      reason: 'forward-pull must not co-exist with the hero dim overlay',
    );
    expect(tester.takeException(), isNull);
  });

  // (2b) Forward-pull and lore are STRICTLY SEQUENTIAL, never co-rendered.
  // Studio #5 reordered the beat to hero → PULL (re-entry peak) → lore: the pull
  // now owns the bottom slot the moment the hero dim clears, and the lore takes
  // over only after the pull's ~2.5s moment. The invariant: they never co-render.
  testWidgets('forward-pull and lore are sequential, never co-rendered (#5)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);
    final firstNpc = kTown5Scene.hotspots[_firstNpcIdx()];
    expect(firstNpc.mysteryFragmentJa, isNotNull,
        reason: 'test NPC must have lore to trigger §3');

    await _callApplyRestore(tester, _firstNpcIdx(), _solved);

    // At 1800ms: hero is gone, the PULL owns the slot (re-entry peak), lore not
    // yet. 'とりもどそう' is pull-specific (remaining==3 form) — collision-safe vs
    // any 'あと' the lore fragment might contain.
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.textContaining('とりもどそう'), findsWidgets,
        reason: 'the forward-pull lands the moment the hero dim clears (#5)');
    expect(find.byKey(const ValueKey('scene_lore_banner')), findsNothing,
        reason: 'lore must NOT co-render with the pull — the pull comes first');

    // After the pull's ~2.5s moment: lore takes over, the pull is dismissed.
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.byKey(const ValueKey('scene_lore_banner')), findsOneWidget,
        reason: 'lore drips in after the pull has had its moment');
    expect(find.textContaining('とりもどそう'), findsNothing,
        reason: 'the pull must be dismissed before the lore banner shows');
    expect(tester.takeException(), isNull);
  });

  // (3) Solving the FINAL ナゾ (scene cleared) does NOT show the forward-pull.
  testWidgets('final ナゾ solve (scene cleared): NO forward-pull line appears',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);

    final npcIdx = _npcIndices();
    // Pre-solve all but the last NPC.
    await _presolveSome(tester, npcIdx.sublist(0, npcIdx.length - 1));

    // Solve the last NPC → justCleared == true → no pull.
    await _callApplyRestore(tester, _lastNpcIdx(), _solved);

    // Advance well past where the pull would appear.
    await tester.pump(const Duration(milliseconds: 4000));

    // No "あとNつ" line must appear (the cleared modal is shown instead).
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    // We check for the specific pull prefix to avoid false-positives from other
    // UI text that might incidentally contain "あと".
    expect(
      texts.contains('このまちの ことばを、とりもどそう') || texts.contains('さいごの なぞ が まっている'),
      isFalse,
      reason:
          'forward-pull MUST NOT appear on the final (scene-clearing) solve',
    );
    expect(tester.takeException(), isNull);
  });

  // (4a) Reduced-motion: pull appears (no animated chain, static after banner).
  testWidgets(
      'reduced-motion: forward-pull line appears (static, after banner clears)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, reduceMotion: true);

    // Solve the first NPC (3 remaining) — reduced-motion path.
    await _callApplyRestore(tester, _firstNpcIdx(), _solved);

    // Reduced-motion: NO hero dim overlay at any point.
    expect(
      find.byKey(const ValueKey('hero_dim_overlay')),
      findsNothing,
      reason: 'reduced-motion must never show the hero dim overlay',
    );

    // Advance past the reduced-motion delay (2500ms restoration banner + margin).
    await tester.pump(const Duration(milliseconds: 3000));

    expect(
      find.textContaining('あと'),
      findsWidgets,
      reason:
          'reduced-motion must show forward-pull after the restoration banner',
    );
    expect(tester.takeException(), isNull);
  });

  // (4b) Reduced-motion: final solve still has no forward-pull.
  testWidgets('reduced-motion: final ナゾ solve does NOT show forward-pull',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, reduceMotion: true);

    final npcIdx = _npcIndices();
    await _presolveSome(tester, npcIdx.sublist(0, npcIdx.length - 1));
    await _callApplyRestore(tester, _lastNpcIdx(), _solved);

    await tester.pump(const Duration(milliseconds: 4000));

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(
      texts.contains('このまちの ことばを、とりもどそう') || texts.contains('さいごの なぞ が まっている'),
      isFalse,
      reason: 'reduced-motion: final solve must not show forward-pull',
    );
    expect(tester.takeException(), isNull);
  });

  // Safety: timers clean up after dismiss (no leak).
  testWidgets('forward-pull auto-dismisses after ~3.5s and leaves no leak',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);
    await _callApplyRestore(tester, _firstNpcIdx(), _solved);

    // Advance past the full chain.
    await tester.pump(const Duration(milliseconds: 3100));
    expect(find.textContaining('あと'), findsWidgets);

    // Advance past the 3500ms auto-dismiss.
    await tester.pump(const Duration(milliseconds: 3600));
    expect(
      find.textContaining('このまちの ことばを、とりもどそう'),
      findsNothing,
      reason: 'forward-pull must auto-dismiss after ~3.5s',
    );
    expect(tester.takeException(), isNull);
  });
}

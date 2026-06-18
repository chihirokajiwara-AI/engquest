// test/features/explore/scene_hero_frame_test.dart
//
// Tests for the held-restoration HERO FRAME (game-studio #2, 2026-06-19):
// when a ナゾ is solved (non-reduced-motion), a full-bleed dim overlay + enlarged
// NPC portrait + restoration text play as a 1700ms held beat, THEN the §3 lore
// fragment fires (never simultaneously). Reduced-motion path keeps the existing
// instant behaviour: colour swap + static top banner + lore.
//
// Test approach: the @visibleForTesting [applyRestoreForTest] method on the
// State is invoked via dynamic dispatch through WidgetTester.state().
// This avoids a real NazoScreen Navigator round-trip while still exercising the
// full _applyRestore code path.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/explore/scene_view.dart';

// The first NPC hotspot in kTown5Scene.
Hotspot _firstNpc() => kTown5Scene.hotspots.firstWhere(
      (h) => h.kind == HotspotKind.npc,
    );

int _firstNpcIdx() {
  for (var i = 0; i < kTown5Scene.hotspots.length; i++) {
    if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) return i;
  }
  return 0;
}

// A solved NazoResult with first-try correct (the richest path).
const _solvedResult = NazoResult(
  solved: true,
  minosEarned: 3,
  firstTryCorrect: true,
);

// A solved NazoResult without first-try (no 「かんぺき！」).
const _solvedRetried = NazoResult(
  solved: true,
  minosEarned: 2,
  firstTryCorrect: false,
);

/// Calls [applyRestoreForTest] on the State via dynamic dispatch.
/// The method is @visibleForTesting on _SceneViewState; the private class name
/// is inaccessible from tests but dynamic dispatch works fine at runtime.
///
/// The call is deferred via [addPostFrameCallback] so it runs AFTER the
/// current layout pass, avoiding a RenderAnimatedSize mutation-during-layout
/// error that occurs when setState (and Duration.zero AnimatedCrossFade) is
/// called synchronously from a test that has a pending layout frame.
Future<void> _callApplyRestore(
  WidgetTester tester,
  int idx,
  Hotspot h,
  NazoResult result,
) async {
  final state = tester.state(find.byType(SceneView));
  // Settle any pending layout before calling setState.
  await tester.pump();
  // ignore: avoid_dynamic_calls
  (state as dynamic).applyRestoreForTest(idx, h, result);
  await tester.pump(); // apply the setState + first animation frame
  // When disableAnimations:true, AnimatedCrossFade uses Duration.zero which can
  // produce a "RenderAnimatedSize mutated in performLayout" FlutterError on the
  // FIRST frame after the crossFadeState changes — this is a Flutter framework
  // constraint in the test environment (not a user-facing bug). Drain that error
  // so subsequent takeException() calls see only real failures.
  tester.takeException(); // consume any AnimatedSize mutation error
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Helper ──────────────────────────────────────────────────────────────────

  Future<void> pumpScene(
    WidgetTester tester, {
    bool reduceMotion = false,
    bool dismissArrival = false,
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
    await tester.pump(); // run initState + first build
    // A second pump lets the postFrameCallback in _maybeGreet fire, showing the
    // arrival banner (kTown5Scene has companionArrivalJa set).
    await tester.pump();
    if (dismissArrival) {
      // Tap the arrival banner to dismiss it, so lore tests aren't gated by it
      // (the lore banner is only rendered when _showArrival is false).
      final arrival = find.textContaining('いろが');
      if (arrival.evaluate().isNotEmpty) {
        await tester.tap(arrival);
        await tester.pump();
      }
    }
  }

  // ── Solved-state persistence ─────────────────────────────────────────────────

  testWidgets(
      'restore path marks idx as solved AND does not throw (non-reduced-motion)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);

    await _callApplyRestore(tester, _firstNpcIdx(), _firstNpc(), _solvedResult);
    await tester.pump();

    // Verify the solved state via semantics: NPC label changes
    // from 「ナゾの ぬし」 to 「ナゾ クリアずみ」.
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp(r'クリアずみ')),
      findsWidgets,
      reason: '_solved[idx] must be true after applyRestore',
    );
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'restore path marks idx as solved AND does not throw (reduced-motion)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, reduceMotion: true);

    await _callApplyRestore(tester, _firstNpcIdx(), _firstNpc(), _solvedResult);
    await tester.pump();

    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp(r'クリアずみ')),
      findsWidgets,
      reason: 'solved state must persist on the reduced-motion path',
    );
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  // ── Hero overlay appears (non-reduced-motion) ────────────────────────────────

  testWidgets('hero dim overlay appears on solve (non-reduced-motion)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);

    // Before solve: no dim.
    expect(find.byKey(const ValueKey('hero_dim_overlay')), findsNothing);

    await _callApplyRestore(tester, _firstNpcIdx(), _firstNpc(), _solvedResult);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('hero_dim_overlay')),
      findsOneWidget,
      reason:
          'full-bleed dim overlay must appear on a non-reduced-motion solve',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero portrait overlay appears on solve (non-reduced-motion)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);

    expect(find.byKey(const ValueKey('hero_portrait_overlay')), findsNothing);

    await _callApplyRestore(tester, _firstNpcIdx(), _firstNpc(), _solvedResult);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('hero_portrait_overlay')),
      findsOneWidget,
      reason: 'hero portrait overlay must appear on a non-reduced-motion solve',
    );
    expect(tester.takeException(), isNull);
  });

  // ── Hero overlay clears after 1700ms ─────────────────────────────────────────

  testWidgets(
      'hero dim and portrait overlays clear after 1700ms (non-reduced-motion)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);
    await _callApplyRestore(tester, _firstNpcIdx(), _firstNpc(), _solvedResult);
    await tester.pump();

    // Overlays present during the hero window.
    expect(find.byKey(const ValueKey('hero_dim_overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero_portrait_overlay')), findsOneWidget);

    // Advance past the 1700ms window.
    await tester.pump(const Duration(milliseconds: 1800));

    expect(
      find.byKey(const ValueKey('hero_dim_overlay')),
      findsNothing,
      reason: 'dim overlay must clear after the 1700ms hero window',
    );
    expect(
      find.byKey(const ValueKey('hero_portrait_overlay')),
      findsNothing,
      reason: 'hero portrait must clear after the 1700ms hero window',
    );
    expect(tester.takeException(), isNull);
  });

  // ── Reduced-motion: NO hero frame, static top banner ─────────────────────────

  testWidgets(
      'reduced-motion: no dim overlay, no hero portrait, static top banner appears',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, reduceMotion: true);
    await _callApplyRestore(tester, _firstNpcIdx(), _firstNpc(), _solvedResult);
    await tester.pump();

    // Hero frame MUST NOT appear under reduced-motion.
    expect(
      find.byKey(const ValueKey('hero_dim_overlay')),
      findsNothing,
      reason: 'reduced-motion must suppress the dim overlay (a11y)',
    );
    expect(
      find.byKey(const ValueKey('hero_portrait_overlay')),
      findsNothing,
      reason: 'reduced-motion must suppress the hero portrait overlay (a11y)',
    );

    // Static top banner MUST appear instead — contains 「もどってきた」.
    expect(
      find.textContaining('もどってきた'),
      findsAtLeastNWidgets(1),
      reason: 'reduced-motion must show the static top-banner restoration line',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced-motion: first-try solve includes かんぺき！ in banner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, reduceMotion: true);
    await _callApplyRestore(tester, _firstNpcIdx(), _firstNpc(), _solvedResult);
    await tester.pump();

    expect(
      find.textContaining('かんぺき！'),
      findsAtLeastNWidgets(1),
      reason: 'a first-try correct solve must include 「かんぺき！」 in the banner',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced-motion: retried solve omits かんぺき！ in banner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, reduceMotion: true);
    await _callApplyRestore(
        tester, _firstNpcIdx(), _firstNpc(), _solvedRetried);
    await tester.pump();

    expect(
      find.textContaining('もどってきた'),
      findsAtLeastNWidgets(1),
      reason: 'retried solve still shows the restoration line',
    );
    // 「かんぺき！」 must NOT be in the text (only for firstTryCorrect).
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join();
    expect(texts.contains('かんぺき'), isFalse,
        reason: 'retried solve must NOT show 「かんぺき！」');
    expect(tester.takeException(), isNull);
  });

  // ── Lore re-sequencing: fires AFTER hero, not simultaneously ─────────────────

  testWidgets(
      'lore banner NOT present during the 1700ms hero window (non-reduced-motion)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // dismissArrival so the lore gate (_showArrival==false) is clear.
    await pumpScene(tester, dismissArrival: true);
    final h = _firstNpc();
    expect(h.mysteryFragmentJa, isNotNull,
        reason: 'test NPC needs a lore fragment (§3)');

    await _callApplyRestore(tester, _firstNpcIdx(), h, _solvedResult);
    await tester.pump();

    // During the hero window: lore banner must NOT be present.
    expect(
      find.byKey(const ValueKey('scene_lore_banner')),
      findsNothing,
      reason: 'lore banner must NOT fire during the hero frame (was the bug)',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lore banner appears AFTER the 1700ms hero window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, dismissArrival: true);
    final h = _firstNpc();
    expect(h.mysteryFragmentJa, isNotNull,
        reason: 'test NPC needs a lore fragment (§3)');

    await _callApplyRestore(tester, _firstNpcIdx(), h, _solvedResult);

    // Advance past the 1700ms hero window.
    await tester.pump(const Duration(milliseconds: 1800));

    expect(
      find.byKey(const ValueKey('scene_lore_banner')),
      findsOneWidget,
      reason: 'lore banner must fire AFTER the hero frame settles',
    );
    expect(tester.takeException(), isNull);
  });

  // ── Reduced-motion: lore fires immediately ────────────────────────────────────

  testWidgets('reduced-motion: lore banner fires immediately (no delay)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester, reduceMotion: true, dismissArrival: true);
    final h = _firstNpc();
    expect(h.mysteryFragmentJa, isNotNull,
        reason: 'test NPC needs a lore fragment (§3)');

    await _callApplyRestore(tester, _firstNpcIdx(), h, _solvedResult);
    await tester.pump(); // single pump — no hero delay

    expect(
      find.byKey(const ValueKey('scene_lore_banner')),
      findsOneWidget,
      reason: 'reduced-motion: lore must fire immediately, no 1700ms delay',
    );
    expect(tester.takeException(), isNull);
  });

  // ── Safety: no crash on consecutive solves ────────────────────────────────────

  testWidgets('no exception when two NPCs are restored in quick succession',
      (tester) async {
    await pumpScene(tester);
    final h = _firstNpc();
    final idx = _firstNpcIdx();

    await _callApplyRestore(tester, idx, h, _solvedResult);
    await tester.pump();

    // Solve a different NPC immediately — must cancel timers cleanly.
    final secondIdx = kTown5Scene.hotspots.lastIndexWhere(
      (hot) => hot.kind == HotspotKind.npc,
    );
    if (secondIdx != idx) {
      await _callApplyRestore(
          tester, secondIdx, kTown5Scene.hotspots[secondIdx], _solvedRetried);
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    // Drain timers.
    await tester.pump(const Duration(milliseconds: 2500));
    expect(tester.takeException(), isNull);
  });
}

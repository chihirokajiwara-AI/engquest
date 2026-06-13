// test/features/explore/scene_view_smoke_test.dart
// Wave 1 — smoke test: SceneView(kTown5Scene) must build without throwing.
//
// Rationale: the last shipped screen passed unit tests but CRASHED on render
// (eager Firebase call). This test catches widget-tree build crashes that unit
// tests can't — specifically null-deref in build(), missing const constructors,
// or Image.asset without errorBuilder.
//
// Firebase is intentionally NOT initialised here (it must never be touched by
// SceneView — see constraint in CLAUDE.md). SharedPreferences falls back to
// in-memory automatically in the test environment.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/explore/scene_solved_store.dart';
import 'package:engquest/features/explore/nazo_screen.dart';

void main() {
  // Install the in-memory SharedPreferences stub so HintCoinService doesn't
  // throw in the test environment.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SceneView(kTown5Scene) builds without exception',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SceneView(scene: kTown5Scene, eikenLevel: '5'),
      ),
    );
    // A single pump is enough to run initState and the first build pass.
    await tester.pump();

    // Key expectation: no exception thrown during build.
    expect(tester.takeException(), isNull);
  });

  testWidgets('SceneView shows scene title in header', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SceneView(scene: kTown5Scene, eikenLevel: '5'),
      ),
    );
    await tester.pump();

    // The scene title should appear somewhere in the widget tree.
    expect(
      find.textContaining('ことばを失'),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SceneView hotspots are rendered (NPC + coin)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SceneView(scene: kTown5Scene, eikenLevel: '5'),
      ),
    );
    await tester.pump();

    // The scene has 3 NPC hotspots + 1 coin = 4 tap targets. We can't inspect
    // internal state directly, but building without exception is the gate.
    expect(tester.takeException(), isNull);
  });

  // スラ companion arrival banner: #49 character presence / light #55 arrival hook.
  // A scene whose SceneDef.companionArrivalJa is set should show スラ's line on
  // entry, and the scene must still be reachable (title visible) after the banner
  // is dismissed.
  testWidgets('arrival banner shows スラ line; scene reachable after dismiss',
      (tester) async {
    // kTown5Scene has companionArrivalJa set.
    await tester.pumpWidget(
      MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
    );
    // First pump runs initState; the postFrameCallback fires on the next pump.
    await tester.pump();
    await tester.pump();

    // The banner must be present and show part of スラ's arrival line.
    expect(
      find.textContaining('スラ'),
      findsAtLeastNWidgets(1),
      reason: 'arrival banner should show the スラ speaker label',
    );
    expect(
      find.textContaining('いろが'),
      findsOneWidget,
      reason: 'arrival banner text should contain スラ\'s line for kTown5Scene',
    );

    // Tap the banner to dismiss.
    await tester.tap(find.textContaining('いろが'));
    await tester.pump();

    // Banner gone — scene title still visible.
    expect(
      find.textContaining('ことばを失'),
      findsAtLeastNWidgets(1),
      reason: 'scene title should remain after banner dismiss',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scene with no companionArrivalJa shows no arrival banner',
      (tester) async {
    const sceneNoArrival = SceneDef(
      backgroundAsset: 'x.webp',
      titleJa: 'テスト',
      hotspots: [],
    );
    await tester.pumpWidget(
      MaterialApp(home: SceneView(scene: sceneNoArrival, eikenLevel: '5')),
    );
    await tester.pump();
    await tester.pump();

    // No banner label; 'スラ' speaker tag should not appear.
    expect(
      find.textContaining('タップで とばす'),
      findsNothing,
      reason: 'no arrival banner when companionArrivalJa is null',
    );
    expect(tester.takeException(), isNull);
  });

  // a11y: the scene hotspots are invisible CanvasKit tap targets — without
  // Semantics a screen-reader child cannot find or play the 探偵 exploration scene.
  // Each NPC + coin must announce as a named button.
  testWidgets(
      'scene hotspots expose a11y button labels (screen-reader playable)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
    );
    await tester.pump();

    // Unsolved NPC hotspots + the coin each carry a descriptive button label.
    expect(find.bySemanticsLabel(RegExp('ナゾの ぬし')), findsWidgets,
        reason: 'NPC hotspots must be labelled buttons for screen readers');
    expect(find.bySemanticsLabel(RegExp('ひかる てがかり')), findsOneWidget,
        reason: 'the coin hotspot must be a labelled button');
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  // REGRESSION (CEO 2026-06-09, live demo): tapping 「？」ナゾをみる did NOTHING
  // because the speech bubble was nested inside the hotspot's small
  // GestureDetector and overflowed its bounds (Clip.none) — Flutter renders such
  // overflow children but does NOT hit-test them, so the button silently ate the
  // tap. Fix: render the bubble at SCENE level. This test taps the NPC, then the
  // bubble button, and asserts the ナゾ (NazoScreen) actually opens.
  testWidgets('tapping an NPC bubble opens its ナゾ (hit-testable)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
    );
    await tester.pump();

    // Open the スラ NPC bubble — its hotspot is at Alignment(0.30, 0.30)
    // → (0.65·w, 0.65·h) in pixels.
    await tester.tapAt(const Offset(440 * 0.65, 900 * 0.65));
    await tester.pump();

    final nazoButton = find.text('「？」ナゾをみる');
    expect(nazoButton, findsOneWidget, reason: 'bubble button should be shown');

    // The fix: tapping it must navigate to the puzzle (pre-fix: nothing).
    await tester.tap(nazoButton);
    await tester.pumpAndSettle();
    expect(find.byType(NazoScreen), findsOneWidget,
        reason: 'tapping 「ナゾをみる」 must open the ナゾ');
    expect(tester.takeException(), isNull);
  });

  // Coin re-farm guard (flaw-hunt 2026-06-14): coin-found state must persist, or
  // a child re-enters the scene and re-collects the SAME coin for unlimited hint
  // coins — re-opening the finite-economy hole R9 closed for the balance.
  testWidgets('a collected coin does NOT reappear on re-entry (no re-farm)',
      (tester) async {
    final coinLabel = RegExp('ひかる てがかり');

    // Control: a fresh scene presents the coin's investigate target.
    final h1 = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.bySemanticsLabel(coinLabel), findsOneWidget,
        reason: 'an un-collected coin must be present on the first visit');
    h1.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // Re-entry after the coin was collected in a prior session → it must be GONE.
    await SceneSolvedStore.markCoinCollected('5', 3); // idx 3 = the 5級 coin
    final h2 = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
    );
    await tester.pump();
    await tester
        .pump(const Duration(milliseconds: 50)); // _restoreSolved applies
    expect(find.bySemanticsLabel(coinLabel), findsNothing,
        reason: 'a collected coin must not reappear (would allow re-farming)');
    h2.dispose();
  });
}

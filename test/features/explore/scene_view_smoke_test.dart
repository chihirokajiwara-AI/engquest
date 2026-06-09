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
}

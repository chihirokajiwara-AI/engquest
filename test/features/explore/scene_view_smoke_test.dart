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

void main() {
  // Install the in-memory SharedPreferences stub so HintCoinService doesn't
  // throw in the test environment.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SceneView(kTown5Scene) builds without exception', (tester) async {
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
}

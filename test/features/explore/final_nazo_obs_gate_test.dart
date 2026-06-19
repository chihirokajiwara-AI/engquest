// test/features/explore/final_nazo_obs_gate_test.dart
//
// Guards the evidence-gate mechanic (studio rank #6): the final ナゾ (対決) must
// be locked until the child has read at least [kFinalNazoObsRequired] observation
// notes, turning hotspots from independent quiz booths into cross-hotspot
// evidence that unlocks the confrontation.
//
// Two scenarios proven:
//   A. seenObs < kFinalNazoObsRequired with obsCount >= threshold → gate fires
//      (NazoScreen NOT pushed; gate-message banner shown).
//   B. seenObs >= kFinalNazoObsRequired → the same tap DOES open the ナゾ.
//
// Setup mirrors scene_restoration_test.dart (isFinalNazoIndex group): solve
// all but the last NPC so the final-ナゾ predicate is true for it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/explore/hotspot.dart'
    show HotspotKind, Hotspot, SceneDef;
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/explore/scene_solved_store.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Indices of NPC hotspots in kTown5Scene (order-stable).
List<int> _npcIndices() => [
      for (var i = 0; i < kTown5Scene.hotspots.length; i++)
        if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) i,
    ];

/// Indices of observation hotspots in kTown5Scene.
List<int> _obsIndices() => [
      for (var i = 0; i < kTown5Scene.hotspots.length; i++)
        if (kTown5Scene.hotspots[i].kind == HotspotKind.observation) i,
    ];

/// Pump the scene past the entry cinematic (bounded — a coin twinkle is
/// perpetual and [pumpAndSettle] would timeout).
///
/// Also advances past the タロ arrival-banner auto-dismiss timer
/// (_kArrivalAutoDismissMs = 4500ms), so the lore slot is clear for the
/// gate message when [dismissArrival] is true (default).
Future<void> _pumpScene(WidgetTester tester,
    {bool dismissArrival = true}) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  if (dismissArrival) {
    // Advance past the arrival-banner auto-dismiss (4500ms) so _showArrival
    // becomes false and the lore slot is free for the gate message.
    await tester.pump(const Duration(milliseconds: 4000));
  }
}

/// Mark all but the last NPC solved so [isFinalNazoIndex] returns true for it.
Future<void> _solveAllButLast(List<int> npcIdx) async {
  for (final i in npcIdx.sublist(0, npcIdx.length - 1)) {
    await SceneSolvedStore.markSolved('5', i);
  }
}

/// Semantics label of an unsolved NPC hotspot (as defined in _hotspotSemanticLabel).
const _unsolvedNpcLabel = 'ナゾの ぬし';

/// CTA label inside the bubble for the FINAL unsolved ナゾ.
/// When isFinalNazoIndex is true the CTA changes to the 対決 label
/// (see _bubbleOverlay: ctaLabel: isFinal ? '⚔️ 対決（たいけつ）する' : '「？」ナゾをみる').
const _finalBubbleCta = '⚔️ 対決（たいけつ）する';

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // kTown5Scene must have >= kFinalNazoObsRequired observation hotspots for the
  // gate to be active in tests A/B. Assert at load time to catch model drift.
  setUpAll(() {
    final obs = _obsIndices();
    assert(
      obs.length >= kFinalNazoObsRequired,
      'kTown5Scene must have >= $kFinalNazoObsRequired observation hotspots '
      'for the evidence gate to be exercisable; found ${obs.length}.',
    );
    assert(
      _npcIndices().length >= 2,
      'kTown5Scene must have >= 2 NPC hotspots.',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('evidence gate — final ナゾ gated on observation count', () {
    // Scenario A: child has not read any observations → gate fires.
    testWidgets(
        'A: seenObs=0 (< $kFinalNazoObsRequired) → gate fires, NazoScreen not pushed',
        (tester) async {
      // ensureSemantics() BEFORE pumpWidget so the semantics tree is built.
      final handle = tester.ensureSemantics();

      // Solve all but the last NPC → it becomes the 対決 peak.
      await _solveAllButLast(_npcIndices());
      // NO observations marked → seenObs = 0.

      await tester.pumpWidget(
        MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
      );
      await _pumpScene(tester);

      // Exactly one NPC remains unsolved; its semantics label contains ナゾの ぬし.
      final npcFinder = find.bySemanticsLabel(RegExp(_unsolvedNpcLabel));
      expect(npcFinder, findsOneWidget,
          reason: 'exactly one unsolved NPC must remain');

      // Tap the NPC through the semantics tree (position-independent).
      await tester.tap(npcFinder);
      await tester.pump();

      // The bubble must appear with the 対決 CTA (isFinal == true).
      expect(
        find.text(_finalBubbleCta),
        findsOneWidget,
        reason: 'final NPC bubble must show the 対決 CTA',
      );

      // Tap the CTA — the evidence gate must intercept.
      await tester.tap(find.text(_finalBubbleCta));
      await tester.pump();

      // Gate fires: NazoScreen must NOT be pushed.
      expect(
        find.byType(NazoScreen),
        findsNothing,
        reason:
            'NazoScreen must NOT be pushed when seenObs < kFinalNazoObsRequired',
      );

      // Gate message shown via _loreBanner (which already has liveRegion: true).
      expect(
        find.textContaining('てがかり'),
        findsAtLeastNWidgets(1),
        reason: 'gate must show the てがかり count message via the lore banner',
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    // Scenario B: child has read >= kFinalNazoObsRequired observations → gate passes.
    testWidgets(
        'B: seenObs=$kFinalNazoObsRequired (>= threshold) → ナゾ opens normally',
        (tester) async {
      final handle = tester.ensureSemantics();

      final npcIdx = _npcIndices();
      final obsIdx = _obsIndices();

      // Solve all but the last NPC.
      await _solveAllButLast(npcIdx);
      // Persist exactly kFinalNazoObsRequired observations as seen.
      // _restoreSolved() reads these back into _observed → seenObs >= 2.
      for (var i = 0; i < kFinalNazoObsRequired; i++) {
        await SceneSolvedStore.markObservationSeen('5', obsIdx[i]);
      }

      await tester.pumpWidget(
        MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
      );
      await _pumpScene(tester);

      // Tap the one remaining unsolved NPC.
      final npcFinder = find.bySemanticsLabel(RegExp(_unsolvedNpcLabel));
      expect(npcFinder, findsOneWidget,
          reason: 'exactly one unsolved NPC must remain');
      await tester.tap(npcFinder);
      await tester.pump();

      expect(
        find.text(_finalBubbleCta),
        findsOneWidget,
        reason: 'final NPC bubble must show the 対決 CTA',
      );

      // Tap the CTA — gate passes (seenObs >= kFinalNazoObsRequired), ナゾ opens.
      await tester.tap(find.text(_finalBubbleCta));
      await tester.pumpAndSettle();

      expect(
        find.byType(NazoScreen),
        findsOneWidget,
        reason: 'NazoScreen must open when seenObs >= kFinalNazoObsRequired',
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  group(
      'evidence gate — safety: scenes with < $kFinalNazoObsRequired '
      'observations are never soft-locked', () {
    testWidgets('0-observation scene: final ナゾ always accessible',
        (tester) async {
      final handle = tester.ensureSemantics();

      // Minimal scene: 2 NPCs, 0 observations.
      // obsCount(0) < kFinalNazoObsRequired(2) → gate is never applied.
      final minimalScene = SceneDef(
        backgroundAsset: 'assets/test_bg.webp',
        titleJa: 'テスト',
        hotspots: [
          // NPC 1 at left (index 0) — will be solved.
          Hotspot.npc(
            pos: const Alignment(-0.3, 0.0),
            size: 0.18,
            step: kTown5Scene.hotspots
                .firstWhere((h) => h.kind == HotspotKind.npc)
                .step!,
            clueLineJa: 'テスト NPC 1',
          ),
          // NPC 2 at right (index 1) — becomes the final ナゾ.
          Hotspot.npc(
            pos: const Alignment(0.3, 0.0),
            size: 0.18,
            step: kTown5Scene.hotspots
                .lastWhere((h) => h.kind == HotspotKind.npc)
                .step!,
            clueLineJa: 'テスト NPC 2',
          ),
        ],
      );

      // Solve NPC 1 (idx 0) → NPC 2 (idx 1) is the final ナゾ.
      await SceneSolvedStore.markSolved('5', 0);

      await tester.pumpWidget(
        MaterialApp(home: SceneView(scene: minimalScene, eikenLevel: '5')),
      );
      await _pumpScene(tester);

      // Tap the only remaining (final) NPC via semantics.
      final npcFinder = find.bySemanticsLabel(RegExp(_unsolvedNpcLabel));
      expect(npcFinder, findsOneWidget);
      await tester.tap(npcFinder);
      await tester.pump();

      // The CTA appears (対決 because isFinal is true).
      expect(find.text(_finalBubbleCta), findsOneWidget,
          reason: 'final NPC bubble must appear on 0-obs scene');

      // Tap — must go straight to NazoScreen with no gate.
      await tester.tap(find.text(_finalBubbleCta));
      await tester.pumpAndSettle();

      expect(
        find.byType(NazoScreen),
        findsOneWidget,
        reason:
            'NazoScreen must open immediately when obsCount < kFinalNazoObsRequired',
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  // Constant export sanity check.
  test('kFinalNazoObsRequired equals 2', () {
    expect(kFinalNazoObsRequired, equals(2));
  });
}

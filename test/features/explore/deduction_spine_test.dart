// test/features/explore/deduction_spine_test.dart
//
// Guards the case-loop deduction spine (studio run-2 #5): when the final ナゾ
// (対決) opens after ≥2 observations are read, NazoScreen receives a non-null
// [gatheredCluesJa] and renders the 探偵メモ block; a NON-final ナゾ receives
// null (block absent).
//
// Test structure mirrors final_nazo_obs_gate_test.dart: uses kTown5Scene,
// pre-solves all but the last NPC, marks observations via SceneSolvedStore so
// _restoreSolved() seeds _observed, then taps through to NazoScreen and
// inspects what is rendered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/explore/hotspot.dart'
    show HotspotKind, Hotspot;
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/explore/scene_solved_store.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

List<int> _npcIndices() => [
      for (var i = 0; i < kTown5Scene.hotspots.length; i++)
        if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) i,
    ];

List<int> _obsIndices() => [
      for (var i = 0; i < kTown5Scene.hotspots.length; i++)
        if (kTown5Scene.hotspots[i].kind == HotspotKind.observation) i,
    ];

/// Pump the scene past the entry cinematic and arrival-banner auto-dismiss.
Future<void> _pumpScene(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  // Advance past the arrival-banner auto-dismiss (4500ms).
  await tester.pump(const Duration(milliseconds: 4000));
}

Future<void> _solveAllButLast(List<int> npcIdx) async {
  for (final i in npcIdx.sublist(0, npcIdx.length - 1)) {
    await SceneSolvedStore.markSolved('5', i);
  }
}

const _unsolvedNpcLabel = 'ナゾの ぬし';
const _finalBubbleCta = '⚔️ 対決（たいけつ）する';

// Header text rendered inside the 探偵メモ DqPanel.
const _memoHeaderText = 'たんていメモを よみかえす';

// Label on the teach-phase CTA that advances to recall → quiz.
const _teachCtaLabel = 'おぼえた！ ナゾへ ▶';

/// Advance NazoScreen from teach phase (if present) through recall → quiz.
///
/// Scrolls the teach CTA into view before tapping (the teach card can push it
/// below the 600px test-viewport). Then taps 'スキップ ▶' to jump straight to
/// quiz (council verdict 2026-06-21: countdown timer removed, child advances
/// per-cue via '「つぎ ▶」' or skips entire recall in one tap via スキップ ▶).
/// If already on quiz (no teach CTA found), does nothing extra.
Future<void> _advanceToQuizPhase(WidgetTester tester) async {
  final teachCta = find.text(_teachCtaLabel);
  if (teachCta.evaluate().isNotEmpty) {
    // Scroll the CTA into the 600px test viewport before tapping.
    await tester.ensureVisible(teachCta);
    await tester.pump();
    await tester.tap(teachCta);
    await tester.pump();
    // Skip the recall phase (スキップ ▶ cancels recall timers and goes to quiz).
    final skipBtn = find.text('スキップ ▶');
    if (skipBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(skipBtn);
      await tester.pump();
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();
    }
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('deduction spine — final ナゾ injects gathered clues', () {
    // Scenario A: ≥ kFinalNazoObsRequired observations read → NazoScreen gets
    // gatheredCluesJa and renders the 探偵メモ block.
    testWidgets(
        'A: final ナゾ after $kFinalNazoObsRequired read observations → '
        '探偵メモ block visible in NazoScreen', (tester) async {
      final npcIdx = _npcIndices();
      final obsIdx = _obsIndices();

      // Solve all but the last NPC so it becomes the 対決 peak.
      await _solveAllButLast(npcIdx);

      // Mark exactly kFinalNazoObsRequired observations as seen.
      for (var i = 0; i < kFinalNazoObsRequired; i++) {
        await SceneSolvedStore.markObservationSeen('5', obsIdx[i]);
      }

      await tester.pumpWidget(
        MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
      );
      await _pumpScene(tester);

      // Tap the single remaining NPC.
      final npcFinder = find.bySemanticsLabel(RegExp(_unsolvedNpcLabel));
      expect(npcFinder, findsOneWidget,
          reason: 'exactly one unsolved NPC must remain');
      await tester.tap(npcFinder);
      await tester.pump();

      // Confirm the 対決 bubble CTA appears.
      expect(find.text(_finalBubbleCta), findsOneWidget,
          reason: 'final NPC bubble must show the 対決 CTA');

      // Tap the CTA — gate passes (seenObs >= kFinalNazoObsRequired).
      await tester.tap(find.text(_finalBubbleCta));
      await tester.pumpAndSettle();

      // NazoScreen must have opened (teach phase or quiz phase).
      expect(find.byType(NazoScreen), findsOneWidget,
          reason: 'NazoScreen must open when gate passes');

      // Advance through teach → recall → quiz phases.
      await _advanceToQuizPhase(tester);

      // The 探偵メモ block must be rendered (header text visible).
      expect(
        find.textContaining(_memoHeaderText),
        findsAtLeastNWidgets(1),
        reason:
            'NazoScreen must show the 探偵メモ block header when gatheredCluesJa is non-null',
      );

      // At least one clue bullet must appear from the read observations.
      expect(
        find.textContaining('・'),
        findsAtLeastNWidgets(1),
        reason:
            'gathered clue bullet lines (・...) must appear in the 探偵メモ block',
      );

      expect(tester.takeException(), isNull);
    });

    // Scenario B: opening a NON-final ナゾ (there are still other NPCs unsolved)
    // → gatheredCluesJa is null → 探偵メモ block must NOT appear.
    testWidgets('B: non-final ナゾ → 探偵メモ block absent', (tester) async {
      final npcIdx = _npcIndices();
      final obsIdx = _obsIndices();

      // Mark observations so the gate is not an issue.
      for (var i = 0; i < kFinalNazoObsRequired; i++) {
        await SceneSolvedStore.markObservationSeen('5', obsIdx[i]);
      }

      // Solve all but the last TWO NPCs: the one we tap will still have another
      // unsolved NPC → isFinalNazoIndex == false for it.
      final solveUpTo = npcIdx.length - 2;
      for (var i = 0; i < solveUpTo; i++) {
        await SceneSolvedStore.markSolved('5', npcIdx[i]);
      }

      await tester.pumpWidget(
        MaterialApp(home: SceneView(scene: kTown5Scene, eikenLevel: '5')),
      );
      await _pumpScene(tester);

      // There are now 2 unsolved NPCs — tap the first one found.
      final npcFinder = find.bySemanticsLabel(RegExp(_unsolvedNpcLabel));
      expect(npcFinder, findsAtLeastNWidgets(2),
          reason: 'at least 2 unsolved NPCs must remain for the non-final tap');
      await tester.tap(npcFinder.first);
      await tester.pump();

      // The CTA for a non-final ナゾ is different from 対決.
      const nonFinalCta = '「？」ナゾをみる';
      expect(find.text(nonFinalCta), findsOneWidget,
          reason: 'non-final NPC bubble must show the 「？」ナゾをみる CTA');
      await tester.tap(find.text(nonFinalCta));
      await tester.pumpAndSettle();

      expect(find.byType(NazoScreen), findsOneWidget,
          reason: 'NazoScreen must open for a non-final ナゾ');

      // Advance through teach → recall → quiz phases.
      await _advanceToQuizPhase(tester);

      // The 探偵メモ block must NOT be present.
      expect(
        find.textContaining(_memoHeaderText),
        findsNothing,
        reason: 'NazoScreen must NOT show the 探偵メモ block for a non-final ナゾ '
            '(gatheredCluesJa should be null)',
      );

      expect(tester.takeException(), isNull);
    });
  });

  // Unit-level: NazoScreen renders the memo block when gatheredCluesJa is set,
  // and does NOT render it when null. Uses a minimal Hotspot.npc without a
  // teachCard so the screen starts directly in quiz phase.
  group('NazoScreen — gatheredCluesJa rendering unit', () {
    // Build a no-teachCard NPC hotspot by wrapping the step from the first
    // scene NPC — strips the teachCard so phase starts at quiz.
    Hotspot noTeachHotspot() {
      final src = kTown5Scene.hotspots.firstWhere(
        (h) => h.kind == HotspotKind.npc && h.step != null,
      );
      return Hotspot.npc(
        pos: src.pos,
        step: src.step!,
        clueLineJa: src.clueLineJa,
        // teachCard intentionally omitted → starts in quiz phase immediately
      );
    }

    testWidgets('gatheredCluesJa non-null → 探偵メモ block rendered',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const testClues = '・まどの むこうで ひかりが。\n・いしだたみに ちいさな くつのあと。';

      await tester.pumpWidget(
        MaterialApp(
          home: NazoScreen(
            hotspot: noTeachHotspot(),
            eikenLevel: '5',
            gatheredCluesJa: testClues,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining(_memoHeaderText),
        findsAtLeastNWidgets(1),
        reason: 'DqPanel header must appear when gatheredCluesJa is non-null',
      );
      expect(
        find.textContaining('まどの むこうで'),
        findsAtLeastNWidgets(1),
        reason: 'first clue bullet must appear',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('gatheredCluesJa null → 探偵メモ block absent', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: NazoScreen(
            hotspot: noTeachHotspot(),
            eikenLevel: '5',
            // gatheredCluesJa defaults to null
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining(_memoHeaderText),
        findsNothing,
        reason: 'DqPanel header must NOT appear when gatheredCluesJa is null',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

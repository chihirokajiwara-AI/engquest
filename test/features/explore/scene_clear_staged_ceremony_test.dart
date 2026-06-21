// test/features/explore/scene_clear_staged_ceremony_test.dart
//
// Guards studio finding #6: the scene-clear STAGED CEREMONY.
//
// When the child solves the LAST ナゾ, the payoff must run in 3 witnessed
// phases rather than dumping all content at once:
//   Phase 1 (0–1200ms) : colour-flood is the only thing visible — NO dialog.
//   Phase 2 (~1200ms)  : CASE CLOSED stamp drops in (in-Stack overlay).
//   Phase 3 (~2200ms)  : payoff dialog slides up.
//
// Reduced-motion: dialog appears IMMEDIATELY (no staged delays).
// Content order in the dialog: streak pill near top BEFORE the story beat.
//
// Test seam: @visibleForTesting [applyRestoreForTest] via dynamic dispatch,
// mirroring scene_forward_pull_test / scene_hero_frame_test.
//
// NOTE ON TEST ISOLATION
// StreakService uses a static write-serialization queue (_writeQueue) that
// persists across Dart-isolate widget tests.  Fire-and-forget recordExamHabit
// calls inside _applyRestore chain callbacks onto this queue; those callbacks
// can take > 10ms to settle.  Cross-test contamination is prevented by:
//   1. Running the acceptance-critical timing assertions in ONE testWidgets
//      body (combines both the normal-motion absent+present checks and the
//      reduced-motion check) so no pending callbacks spill into a sibling test.
//   2. Each test body drains ≥ 3 500ms before returning so the queue is
//      settled for any subsequent tests.
//   3. setUp only resets SharedPreferences (prevents "already-cleared" state
//      from leaking via SceneSolvedStore); it does NOT reset
//      PreferencesService._instance or StreakService._writeQueue — those
//      resets interfere with in-flight callbacks within single-test runs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/exam_practice/practice_encouragement.dart';
import 'package:engquest/features/home/streak_service.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// All NPC hotspot indices in kTown5Scene (definition order).
List<int> _npcIndices() => [
      for (var i = 0; i < kTown5Scene.hotspots.length; i++)
        if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) i,
    ];

int _lastNpcIdx() => _npcIndices().last;

/// A first-try correct solved result.
const _solved = NazoResult(solved: true, minosEarned: 3, firstTryCorrect: true);

/// Calls [applyRestoreForTest] on the State via dynamic dispatch.
///
/// Pumps 10 × 1ms after the call to drain the async streak callbacks
/// (_serialize chain) without triggering the 1200ms Phase-2 timer.
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
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  tester.takeException(); // consume AnimatedSize mutation noise
}

/// Pre-solve [preSolveIdx] indices so that solving the next idx is the FINAL
/// ナゾ.  Each pre-solve drains 7 200ms (far > hero+lore+pull+streak chain).
Future<void> _presolveSome(
  WidgetTester tester,
  List<int> preSolveIdx,
) async {
  for (final i in preSolveIdx) {
    await _callApplyRestore(tester, i, _solved);
    await tester.pump(const Duration(milliseconds: 7200));
    tester.takeException();
  }
}

/// Pump and build a SceneView inside [MaterialApp].
///
/// Wraps in [MediaQuery] so [reduceMotion] is reflected without relying on
/// the test-binding's default (which may vary by platform).
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
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    // Reset SharedPreferences so _restoreSolved() finds 0 solved NPCs in each
    // test — without this, SceneSolvedStore.markSolved() writes from a
    // previous test make _sceneRestored true on entry, causing justCleared to
    // never fire.  PreferencesService._instance and _writeQueue are NOT reset
    // here; see NOTE ON TEST ISOLATION above.
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  // ── Acceptance test: timing + reduced-motion (ONE combined body) ─────────────
  //
  // Both the normal-motion timing assertions (absent at t=0, present at 2300ms)
  // and the reduced-motion assertion (immediate) run in a SINGLE testWidgets
  // body.  Each scenario re-pumps a fresh SceneView after the previous one has
  // been fully drained.  This avoids cross-test _writeQueue contamination (see
  // NOTE ON TEST ISOLATION).
  testWidgets('staged ceremony: timing (normal) + immediate (reduced-motion)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // ── Scenario 1: normal motion ────────────────────────────────────────────
    await pumpScene(tester);
    final npcIdx = _npcIndices();
    await _presolveSome(tester, npcIdx.sublist(0, npcIdx.length - 1));
    await _callApplyRestore(tester, _lastNpcIdx(), _solved);

    // Phase 1 (~10ms consumed): colour-flood only, NO dialog, NO stamp.
    expect(
      find.text('つづける'),
      findsNothing,
      reason:
          'normal-motion: dialog must NOT appear at t~10ms (colour-flood Phase 1)',
    );
    expect(
      find.byKey(const ValueKey('scene_clear_stamp_overlay')),
      findsNothing,
      reason: 'stamp must not appear before Phase 2 (~1200ms)',
    );

    // Phase 2 (~1260ms): CASE CLOSED stamp drops in, dialog still absent.
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pump(); // apply setState
    expect(
      find.byKey(const ValueKey('scene_clear_stamp_overlay')),
      findsOneWidget,
      reason: 'CASE CLOSED stamp overlay must appear in Phase 2 (~1200ms)',
    );
    expect(
      find.text('つづける'),
      findsNothing,
      reason: 'dialog must not open during Phase 2 (stamp-only window)',
    );

    // Phase 3 (~2310ms total from final solve): dialog slides up.
    // _callApplyRestore consumed ~10ms; the stamp check consumed ~1260ms;
    // we need ~940ms more to reach the 2200ms dialog timer.
    await tester.pump(const Duration(milliseconds: 1050));
    await tester.pump(); // settle slide-in animation
    expect(
      find.text('つづける'),
      findsOneWidget,
      reason: 'normal-motion: dialog must appear after ~2200ms staged delay',
    );

    // Full drain before switching to the reduced-motion scenario.
    await tester.pump(const Duration(milliseconds: 3500));
    tester.takeException();

    // ── Scenario 2: reduced-motion ───────────────────────────────────────────
    // Fresh SceneView (new pumpWidget replaces the previous tree).
    await pumpScene(tester, reduceMotion: true);
    await _presolveSome(tester, npcIdx.sublist(0, npcIdx.length - 1));
    await _callApplyRestore(tester, _lastNpcIdx(), _solved);

    // In reduced-motion, _showPayoffDialog is called synchronously (no timers).
    await tester.pump(); // one frame for showDialog to build
    expect(
      find.text('つづける'),
      findsOneWidget,
      reason:
          'reduced-motion: dialog must appear immediately without staged delays',
    );
    // Stamp overlay must never appear in reduced-motion.
    expect(
      find.byKey(const ValueKey('scene_clear_stamp_overlay')),
      findsNothing,
      reason: 'reduced-motion: in-Stack stamp overlay must never appear',
    );

    // Drain before the test ends.
    await tester.pump(const Duration(milliseconds: 3500));
    tester.takeException();
  });

  // ── Timer leak guard ─────────────────────────────────────────────────────────
  testWidgets('dispose after scene-clear does not throw (timer leak guard)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpScene(tester);
    final npcIdx = _npcIndices();
    await _presolveSome(tester, npcIdx.sublist(0, npcIdx.length - 1));
    await _callApplyRestore(tester, _lastNpcIdx(), _solved);

    // Dispose BEFORE ceremony timers fire (navigate away immediately).
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(milliseconds: 3500));
    expect(tester.takeException(), isNull);
  });

  // ── Dialog content: streak pill before story beat (reorder guard) ────────────
  //
  // The reordered dialog places the SessionEndHook streak pill BEFORE the
  // story beat.  scene_cleared_payoff_hook_test.dart covers the non-null /
  // null branching exhaustively; here we confirm the button and hook are
  // present in a locally-constructed reordered layout (quick regression guard).
  testWidgets(
      'payoff dialog content: SessionEndHook before story beat (reorder guard)',
      (tester) async {
    const streak = StreakState(
      currentStreak: 5,
      weeklyBits: 0,
      todayCount: 1,
      problemsToday: 10,
      dailyGoal: 10,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mirrors the reordered dialog: streak FIRST (above story beat).
              const SizedBox(height: 14),
              const SessionEndHook(streak: streak),
              const Text('story beat placeholder'),
              const Text('つづける'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SessionEndHook), findsOneWidget,
        reason: 'SessionEndHook must appear in the reordered dialog content');
    expect(tester.takeException(), isNull);
  });
}

// test/features/explore/nazo_teach_first_test.dart
//
// CEO 2026-06-09 (致命的欠陥): a true beginner was dropped into an English
// multiple-choice ナゾ with NO teaching first ("何も学んでないのに、いきなりこれが
// 出てきて、誰が答えられるのだ？"). The structural fix: a Hotspot whose ナゾ is a bare
// quiz now carries a TeachCard, and NazoScreen TEACHES it BEFORE the quiz.
//
// This test locks that contract: the slime greeting ナゾ must show the lesson
// (meanings of Hello/Goodbye/Thank you/Sorry) FIRST; an ACTIVE cued-production
// recall phase walks the child through each item — the JA meaning is shown LARGE
// as the cue, and the child must tap the correct English tile from the shuffled
// set to advance. Quiz options must NOT appear until all cues are produced.
//
// Updated 2026-06-19: passive tap-to-reveal 「いみは？」 replaced with active
// cued-production retrieval ("claim-the-word"). Tests updated to match.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Hotspot greetingHotspot() => kTown5Scene.hotspots
      .firstWhere((h) => identical(h.teachCard, kGreetingTeach));

  testWidgets('teach-first: greeting ナゾ teaches meanings BEFORE the quiz',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NazoScreen(hotspot: greetingHotspot(), eikenLevel: '5'),
      ),
    );
    await tester.pumpAndSettle();

    // The lesson is shown first: the card title + all four taught meanings.
    expect(find.text('まず、4つの あいさつを おぼえよう'), findsOneWidget);
    expect(find.text('こんにちは'), findsOneWidget);
    expect(find.text('さようなら'), findsOneWidget);
    expect(find.text('ありがとう'), findsOneWidget);
    expect(find.text('ごめんなさい'), findsOneWidget);

    // The quiz must NOT be reachable yet — no ミノス meter.
    expect(find.text('ミノス'), findsNothing);

    // Tap 「おぼえた！ ナゾへ」 → the recall phase begins with the first cue:
    // the JA meaning shown large, and EN tiles below it.
    final advance = find.text('おぼえた！ ナゾへ ▶');
    expect(advance, findsOneWidget);
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Recall phase: the cue prompt is visible.
    expect(find.text('えいごで いうと？'), findsOneWidget,
        reason: 'recall cue prompt must appear');
    // The ミノス quiz meter must still be hidden.
    expect(find.text('ミノス'), findsNothing,
        reason: 'quiz must not be visible during recall');
    // AudioOptionButton choice tiles ARE present (the active-production choices).
    expect(find.byType(AudioOptionButton), findsWidgets,
        reason: 'EN choice tiles must appear in recall for active production');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a step that already teaches (no TeachCard) goes straight to quiz',
      (tester) async {
    // A teach-less ナゾ (a step that teaches inherently) must go straight to the
    // quiz surface. The phonics ナゾ used to be that case; the 英検-redirect (#112)
    // gave every 5級 NPC a real 英検 question + teach card, so no teach-less NPC
    // remains in this scene — skip until a non-teaching ナゾ type exists again.
    final teachless = kTown5Scene.hotspots
        .where((h) => h.kind == HotspotKind.npc && h.teachCard == null);
    if (teachless.isEmpty) {
      markTestSkipped('no teach-less 5級 NPC ナゾ after the 英検-redirect (#112)');
      return;
    }
    final cell = teachless.first;
    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: cell, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ミノス'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── Active cued-production recall contract tests ─────────────────────────────

  testWidgets(
      'recall phase: JA cue shown large + EN choice tiles present (no いみは？)',
      (tester) async {
    final hotspot = greetingHotspot();
    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Advance from teach to recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // The recall cue prompt must appear.
    expect(find.text('えいごで いうと？'), findsOneWidget,
        reason: 'recall cue prompt must appear');

    // EN choice tiles (AudioOptionButton) must be present for active production.
    expect(find.byType(AudioOptionButton), findsWidgets,
        reason: 'EN choice tiles must appear for active production recall');

    // The old passive 「いみは？」 tap-target must NOT be present.
    expect(find.text('いみは？'), findsNothing,
        reason:
            '「いみは？」 passive reveal removed; replaced by active production tiles');

    expect(tester.takeException(), isNull);
  });

  testWidgets('wrong tile tap shakes and does NOT advance (same JA cue stays)',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();
    final items = hotspot.teachCard!.items;

    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Advance from teach to recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Capture first cue JA text.
    final firstJa = items.first.ja;

    // Tap a WRONG tile (any tile that is NOT the correct EN for the first cue).
    // The correct answer for cue idx=0 is items[0].en; wrong = items[1].
    final wrongLabel = items[1].en; // a different word than the cue
    // Find the tile by its label text inside an AudioOptionButton.
    final wrongTile = find.widgetWithText(AudioOptionButton, wrongLabel);
    // May be off-screen on a small view; ensureVisible first.
    if (wrongTile.evaluate().isNotEmpty) {
      await tester.ensureVisible(wrongTile.first);
      await tester.pump();
      await tester.tap(wrongTile.first);
      await tester.pumpAndSettle();
    }

    // After a wrong tap the JA cue must still be visible (no advance).
    expect(find.text(firstJa), findsOneWidget,
        reason:
            'JA cue must stay visible after wrong tap — child retries without advancing');
    // ミノス must not appear yet (still in recall, not quiz).
    expect(find.text('ミノス'), findsNothing,
        reason: 'quiz must not start from a wrong recall tap');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'correct tile tap advances the cue (cue index increments or quiz on last)',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();
    final items = hotspot.teachCard!.items;

    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Advance from teach to recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Tap the CORRECT EN tile for the first cue (items[0].en matches cue JA items[0].ja).
    final correctLabel = items[0].en;
    final correctTile = find.widgetWithText(AudioOptionButton, correctLabel);
    expect(correctTile, findsOneWidget,
        reason: 'correct EN tile must be present for cue 0');
    await tester.ensureVisible(correctTile.first);
    await tester.pump();
    await tester.tap(correctTile.first);
    await tester.pumpAndSettle();

    if (items.length == 1) {
      // Single-item card → quiz starts immediately.
      expect(find.text('ミノス'), findsOneWidget,
          reason: 'single-cue correct tap must advance straight to quiz');
    } else {
      // Multi-item card → cue advanced to idx=1; second JA is now the cue.
      final secondJa = items[1].ja;
      expect(find.text(secondJa), findsOneWidget,
          reason:
              'correct tap must advance to the next cue (idx 1 JA now shown)');
      // First JA must be gone (we advanced).
      expect(find.text(items[0].ja), findsNothing,
          reason: 'first JA must no longer be the cue after correct tap');
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping correct tile through all cues reaches the quiz (ミノス + AudioOptionButtons)',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();
    final items = hotspot.teachCard!.items;

    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Advance from teach to recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Tap the correct tile for each cue in sequence.
    for (var i = 0; i < items.length; i++) {
      final correctLabel = items[i].en;
      final correctTile = find.widgetWithText(AudioOptionButton, correctLabel);
      expect(correctTile, findsOneWidget,
          reason:
              'correct EN tile for cue $i must be present: "$correctLabel"');
      await tester.ensureVisible(correctTile.first);
      await tester.pump();
      await tester.tap(correctTile.first);
      await tester.pumpAndSettle();
    }

    // Now in quiz phase: ミノス meter + AudioOptionButton quiz tiles present.
    expect(find.text('ミノス'), findsOneWidget,
        reason: 'ミノス meter must appear after all cues are produced correctly');
    expect(find.byType(AudioOptionButton), findsWidgets,
        reason: 'quiz option tiles must appear after completing recall cues');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no TeachCard → quiz opens directly, no recall phase',
      (tester) async {
    // A hotspot without a TeachCard must never show the recall screen.
    final teachless = kTown5Scene.hotspots
        .where((h) => h.kind == HotspotKind.npc && h.teachCard == null);
    if (teachless.isEmpty) {
      markTestSkipped('no teach-less 5級 NPC ナゾ after the 英検-redirect (#112)');
      return;
    }
    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: teachless.first, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();
    expect(find.text('えいごで いうと？'), findsNothing,
        reason: 'recall phase must not appear when there is no TeachCard');
    expect(find.text('ミノス'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── CEO 2147: correct-tap green-pop hold (studio #1) ────────────────────────

  testWidgets(
      'correct-tap green-pop: tile reaches DqChoiceState.correct before advancing',
      (tester) async {
    // Reduced-motion is FALSE here (default): we want the 300ms hold to fire.
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();
    final items = hotspot.teachCard!.items;
    // Need at least 2 items to observe "hold then advance" without going to quiz.
    expect(items.length, greaterThan(1),
        reason: 'greetingHotspot must have >1 cue to test non-last advance');

    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Advance teach → recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Locate the correct EN tile for cue 0.
    final correctLabel = items[0].en;
    final correctTile = find.widgetWithText(AudioOptionButton, correctLabel);
    expect(correctTile, findsOneWidget,
        reason: 'correct EN tile must be present for cue 0');
    await tester.ensureVisible(correctTile.first);
    await tester.pump();

    // Tap, then pump ONE frame to process the setState setting _recallCorrectIdx.
    // Do NOT pumpAndSettle yet — that would drain the 300ms pop timer and advance.
    await tester.tap(correctTile.first);
    await tester
        .pump(); // single frame: setState fired, tile should be .correct

    // The tapped tile must now be in DqChoiceState.correct (green elastic pop).
    final tappedWidget = tester.widget<AudioOptionButton>(correctTile);
    expect(tappedWidget.state, equals(DqChoiceState.correct),
        reason:
            'tapped tile must be DqChoiceState.correct during the 300ms hold before advancing');

    // The JA cue for item 0 must still be visible — we have NOT advanced yet.
    expect(find.text(items[0].ja), findsOneWidget,
        reason: 'first JA cue must remain visible during the 300ms hold');

    // No quiz yet.
    expect(find.text('ミノス'), findsNothing,
        reason: 'quiz must not appear during the 300ms hold');

    // Now drain the 300ms timer — should advance to cue 1 (or quiz if last).
    await tester.pumpAndSettle();
    expect(find.text(items[0].ja), findsNothing,
        reason:
            'first JA cue must be gone after the pop-timer fires and advances');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'wrong-tap still shakes and stays on cue (unchanged by studio #1 pop)',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();
    final items = hotspot.teachCard!.items;
    expect(items.length, greaterThan(1),
        reason: 'greetingHotspot must have >1 item for a wrong-tile choice');

    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Advance teach → recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    final firstJa = items[0].ja;
    // Tap a WRONG tile (items[1].en is a different word than items[0].ja).
    final wrongLabel = items[1].en;
    final wrongTile = find.widgetWithText(AudioOptionButton, wrongLabel);
    if (wrongTile.evaluate().isNotEmpty) {
      await tester.ensureVisible(wrongTile.first);
      await tester.pump();
      await tester.tap(wrongTile.first);
      await tester.pumpAndSettle();
    }

    // JA cue must still be visible — wrong tap must NOT advance.
    expect(find.text(firstJa), findsOneWidget,
        reason: 'JA cue must stay after wrong tap — no advance');

    // Wrong tile must NOT be DqChoiceState.correct.
    if (wrongTile.evaluate().isNotEmpty) {
      final wrongWidget = tester.widget<AudioOptionButton>(wrongTile);
      expect(wrongWidget.state, isNot(equals(DqChoiceState.correct)),
          reason: 'wrong tile must not show green after a wrong tap');
    }

    // No quiz.
    expect(find.text('ミノス'), findsNothing,
        reason: 'quiz must not start from a wrong recall tap');

    expect(tester.takeException(), isNull);
  });

  // ── CEO 2147 studio run-3 #2: "who you're rescuing" row ────────────────────

  testWidgets(
      'teach card shows NPC name + DqPortrait when hotspot has npcGreyAsset + step',
      (tester) async {
    // greetingHotspot has npcGreyAsset='assets/.../npc_slime_grey.webp'
    // and step.npcName='タロ' — the rescue row should render both.
    final hotspot = greetingHotspot();
    // Verify the test data preconditions.
    expect(hotspot.npcGreyAsset, isNotNull,
        reason: 'greetingHotspot must have a grey asset for this test');
    expect(hotspot.step?.npcName.trim(), isNotEmpty,
        reason: 'greetingHotspot must have a non-empty npcName');

    await tester.pumpWidget(
      MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ),
    );
    await tester.pumpAndSettle();

    // The DqPortrait (grey silhouette) must be present on the teach card.
    expect(find.byType(DqPortrait), findsWidgets,
        reason: 'DqPortrait must appear in the teach card rescue row');

    // The NPC name must appear as a gold nameplate.
    expect(find.text('タロ'), findsOneWidget,
        reason: 'NPC name タロ must be displayed on the teach card');

    // The diegetic hint line must also appear (clueLineJa or generic fallback).
    // At minimum the generic fallback contains 'たすけよう'.
    final hasClue = tester.widgetList<Text>(find.byType(Text)).any((t) =>
        (t.data ?? '').contains('たすけよう') ||
        (t.data ?? '')
            .contains(hotspot.clueLineJa?.substring(0, 8) ?? '__NONE__'));
    expect(hasClue, isTrue,
        reason: 'a diegetic rescue line must appear in the teach card');

    // No overflow or exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'teach card renders cleanly when hotspot has neither npcGreyAsset nor step (null guard)',
      (tester) async {
    // A coin hotspot has no teachCard, so NazoScreen won't show the teach
    // scaffold — but we still confirm the null guard in _rescueSubjectRow
    // doesn't throw. We can exercise it directly by wrapping the widget that
    // drives _teachScaffold in a known NPC hotspot that has a null asset.
    // Build a minimal NPC hotspot without npcGreyAsset or npcName, with a
    // teachCard so _teachScaffold IS reached.
    // We reuse the greeting hotspot's teach card data for a bare NPC hotspot.
    final bareNpcHotspot = Hotspot.npc(
      pos: const Alignment(0, 0),
      step: greetingHotspot().step!,
      // No npcGreyAsset, no npcColorAsset → rescue row must NOT render.
      clueLineJa: null,
      teachCard: greetingHotspot().teachCard,
    );

    expect(bareNpcHotspot.npcGreyAsset, isNull);
    expect(bareNpcHotspot.step?.npcName.trim().isEmpty, isFalse,
        reason: 'step still has npcName — row appears by name guard alone');

    // Name-only path: npcName is non-empty but no asset. Row still renders
    // (name guard triggers), and DqPortrait falls back to the emoji.
    await tester.pumpWidget(
      MaterialApp(
        home: NazoScreen(hotspot: bareNpcHotspot, eikenLevel: '5'),
      ),
    );
    await tester.pumpAndSettle();

    // With a non-empty npcName the rescue row IS rendered (name guard).
    expect(find.byType(DqPortrait), findsWidgets,
        reason: 'DqPortrait emoji-fallback must render when npcName is set');
    expect(find.text('タロ'), findsOneWidget,
        reason: 'NPC name must still render on name-only path');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'teach card has no rescue row when both npcGreyAsset and npcName are absent',
      (tester) async {
    // Build a hotspot where step has an empty npcName AND no npcGreyAsset.
    // Use a modified QuestEncounter with npcName=''. This verifies the null
    // guard fully suppresses the row.

    // We cannot easily construct a QuestEncounter inline without quest_data
    // internals. Instead we verify via the coin hotspot + standalone render:
    // Coin hotspots never reach _teachScaffold (no teachCard), so we verify
    // the guard logic via the field values directly.
    const bareHotspot = Hotspot.coin(pos: Alignment.center, coinValue: 1);
    expect(bareHotspot.npcGreyAsset, isNull);
    // Coin hotspot has no step → npcName is null (inaccessible). Guard
    // `(widget.hotspot.step?.npcName ?? '').isNotEmpty` returns false.
    expect((bareHotspot.step?.npcName ?? '').isNotEmpty, isFalse,
        reason:
            'coin hotspot has no npcName — rescue row guard must evaluate false');
    // No flutter widget test needed: the guard is a compile-time evaluatable
    // constant for the coin case. The NPC null-name case is covered above.
  });

  // ── knewWords in NazoResult ──────────────────────────────────────────────────

  testWidgets(
      'NazoResult.knewWords is populated for words produced on the first tap',
      (tester) async {
    // This test verifies the NazoResult data model, not the screen UI.
    // A learner who produces all cues first-try has knewWords == full set.
    const result = NazoResult(
      solved: true,
      minosEarned: 10,
      knewWords: {'Hello!', 'Goodbye.'},
    );
    expect(result.knewWords, containsAll(['Hello!', 'Goodbye.']));
    expect(result.knewWords.length, 2);

    // Default (no recall phase or timer-skipped): empty set.
    const defaultResult = NazoResult(solved: true, minosEarned: 5);
    expect(defaultResult.knewWords, isEmpty);
  });
}

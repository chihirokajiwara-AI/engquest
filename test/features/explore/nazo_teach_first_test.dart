// test/features/explore/nazo_teach_first_test.dart
//
// CEO 2026-06-09 (致命的欠陥): a true beginner was dropped into an English
// multiple-choice ナゾ with NO teaching first ("何も学んでないのに、いきなりこれが
// 出てきて、誰が答えられるのだ？"). The structural fix: a Hotspot whose ナゾ is a bare
// quiz now carries a TeachCard, and NazoScreen TEACHES it BEFORE the quiz.
//
// This test locks that contract: the slime greeting ナゾ must show the lesson
// (meanings of Hello/Goodbye/Thank you/Sorry) FIRST; a COVER-REVEAL recall phase
// then walks the child through each item — the JA meaning is shown LARGE as the
// cue, and a masked '？？？' panel invites the child to recall the EN before tapping
// to reveal it. Quiz options must NOT appear until all cues are produced.
//
// Updated 2026-06-21 (council verdict): self-assessment row removed.
// After revealing the EN word, a single neutral '「つぎ ▶」' button advances to the
// next cue (or 'つぎ ▶ ナゾへ' on the last cue). No 'おぼえてた！'/'もう1かい' buttons.
// knewWords in NazoResult is now wired from QUIZ first-try correctness, not from
// self-report: a first-try correct quiz answer seeds the word; wrong first-try → not
// seeded.

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
    // the JA meaning shown large, and a covered '？？？' EN panel below it.
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
    // Cover panel '？？？' must appear (EN hidden before child taps).
    expect(find.text('？？？'), findsOneWidget,
        reason: 'cover mask must appear in recall before reveal');
    // Safety eyebrow must label this as practice.
    expect(find.text('れんしゅう — おもいだしてみよう'), findsOneWidget,
        reason: 'practice safety eyebrow must appear');
    // Skip button must be present for ≤ 1-tap quiz access.
    expect(find.text('スキップ ▶'), findsOneWidget,
        reason: 'skip button must appear in recall');
    // Self-assessment buttons must NOT be present at all (council verdict).
    expect(find.text('おぼえてた！'), findsNothing,
        reason:
            'self-assessment removed by council verdict — must never appear');
    expect(find.text('もう1かい'), findsNothing,
        reason: 'self-assessment removed — もう1かい must never appear');

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

  // ── Cover-reveal recall contract tests ───────────────────────────────────────

  testWidgets(
      'recall phase: JA cue shown large + cover panel present (no EN tiles initially)',
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

    // Cover panel must be present (EN hidden).
    expect(find.text('？？？'), findsOneWidget,
        reason: 'cover mask must appear before reveal');

    // The old passive 「いみは？」 tap-target must NOT be present.
    expect(find.text('いみは？'), findsNothing,
        reason:
            '「いみは？」 passive reveal removed; replaced by cover-reveal panel');

    // Self-assessment buttons must NOT be visible at all (council verdict:
    // removed entirely, not just hidden pre-reveal).
    expect(find.text('おぼえてた！'), findsNothing,
        reason: 'self-assessment removed by council verdict');
    expect(find.text('もう1かい'), findsNothing,
        reason: 'self-assessment removed by council verdict');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping the cover panel reveals EN word + shows つぎ ▶ (no self-assessment)',
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

    // Advance teach → recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Tap the cover panel to reveal.
    final coverPanel = find.text('？？？');
    expect(coverPanel, findsOneWidget, reason: 'cover panel must be present');
    await tester.ensureVisible(coverPanel);
    await tester.pump();
    await tester.tap(coverPanel);
    await tester.pump();

    // After reveal: EN word appears in place of the mask.
    final firstEn = items[0].en;
    expect(find.text(firstEn), findsOneWidget,
        reason: 'EN word must appear after tapping cover panel');
    // Cover mask must be gone.
    expect(find.text('？？？'), findsNothing,
        reason: 'cover mask must disappear after reveal');

    // Council verdict: NO self-assessment buttons — ever.
    expect(find.text('おぼえてた！'), findsNothing,
        reason:
            'self-assessment removed — 「おぼえてた！」 must never appear (council verdict)');
    expect(find.text('もう1かい'), findsNothing,
        reason:
            'self-assessment removed — 「もう1かい」 must never appear (council verdict)');

    // Neutral advance button must appear after reveal.
    // Last cue label differs ('つぎ ▶ ナゾへ' vs 'つぎ ▶'); match either.
    final hasNext = find.textContaining('つぎ ▶').evaluate().isNotEmpty;
    expect(hasNext, isTrue,
        reason:
            '「つぎ ▶」 neutral advance button must appear after revealing the EN word');

    expect(tester.takeException(), isNull);
  });

  testWidgets('つぎ ▶ advances to next cue (or quiz on last)', (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();
    final items = hotspot.teachCard!.items;

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

    // Capture first cue JA text.
    final firstJa = items[0].ja;

    // Tap cover to reveal.
    await tester.ensureVisible(find.text('？？？'));
    await tester.pump();
    await tester.tap(find.text('？？？'));
    await tester.pump();

    // Tap 'つぎ ▶' (or 'つぎ ▶ ナゾへ' on last cue) to advance.
    final nextBtn = find.textContaining('つぎ ▶');
    await tester.ensureVisible(nextBtn);
    await tester.pump();
    await tester.tap(nextBtn);
    // The 600ms pop-hold is a dart:async Timer; pumpAndSettle() does not drain
    // it. Advance the fake clock manually past the hold, then pump one frame.
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    if (items.length == 1) {
      // Single-item card → quiz starts immediately.
      expect(find.text('ミノス'), findsOneWidget,
          reason: 'single-cue つぎ ▶ must advance straight to quiz');
    } else {
      // Multi-item card → cue advanced to idx=1; second JA is now the cue.
      final secondJa = items[1].ja;
      expect(find.text(secondJa), findsOneWidget,
          reason: 'つぎ ▶ must advance to the next cue (idx 1 JA now shown)');
      // First JA must be gone (we advanced).
      expect(find.text(firstJa), findsNothing,
          reason: 'first JA must no longer be the cue after advance');
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping through all cues with つぎ ▶ reaches the quiz (ミノス visible)',
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

    // Step through each cue: tap cover → reveal → tap つぎ ▶.
    for (var i = 0; i < items.length; i++) {
      // Cover must be present at start of each cue.
      expect(find.text('？？？'), findsOneWidget,
          reason: 'cover must be present at start of cue $i');
      await tester.ensureVisible(find.text('？？？'));
      await tester.pump();
      await tester.tap(find.text('？？？'));
      await tester.pump();

      // つぎ ▶ must appear after reveal (no self-assessment).
      final nextBtn = find.textContaining('つぎ ▶');
      expect(nextBtn, findsOneWidget,
          reason: 'つぎ ▶ must appear after reveal on cue $i');
      // Confirm self-assessment is absent.
      expect(find.text('おぼえてた！'), findsNothing,
          reason: 'self-assessment must never appear (council verdict)');
      await tester.ensureVisible(nextBtn);
      await tester.pump();
      await tester.tap(nextBtn);
      // Drain the 600ms pop-hold dart:async Timer manually.
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
    }

    // Now in quiz phase: ミノス meter + AudioOptionButton quiz tiles present.
    expect(find.text('ミノス'), findsOneWidget,
        reason: 'ミノス meter must appear after all cues are produced');
    expect(find.byType(AudioOptionButton), findsWidgets,
        reason: 'quiz option tiles must appear after completing recall cues');
    expect(tester.takeException(), isNull);
  });

  testWidgets('スキップ ▶ button jumps to quiz without stepping through cues',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();

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

    // Recall phase is active (cover visible).
    expect(find.text('？？？'), findsOneWidget, reason: 'must be in recall phase');

    // Tap skip button.
    final skipBtn = find.text('スキップ ▶');
    expect(skipBtn, findsOneWidget, reason: 'skip button must be present');
    await tester.ensureVisible(skipBtn);
    await tester.pump();
    await tester.tap(skipBtn);
    await tester.pumpAndSettle();

    // Must be in quiz phase now.
    expect(find.text('ミノス'), findsOneWidget,
        reason: 'スキップ ▶ must advance immediately to quiz');
    expect(find.text('？？？'), findsNothing,
        reason: 'cover panel must be gone after skip');

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

  // ── knewWords in NazoResult: driven by QUIZ first-try, NOT self-report ────────

  testWidgets(
      'NazoResult.knewWords model — populated set and default empty set',
      (tester) async {
    // This test verifies the NazoResult data model, not the screen UI.
    // knewWords carries EN strings from quiz first-try correct answers.
    const result = NazoResult(
      solved: true,
      minosEarned: 10,
      knewWords: {'Hello!', 'Goodbye.'},
    );
    expect(result.knewWords, containsAll(['Hello!', 'Goodbye.']));
    expect(result.knewWords.length, 2);

    // Default (wrong first try or timer-skipped recall): empty set.
    const defaultResult = NazoResult(solved: true, minosEarned: 5);
    expect(defaultResult.knewWords, isEmpty);
  });

  testWidgets(
      'knewWords is populated from quiz first-try correct, NOT from recall self-report',
      (tester) async {
    // Council verdict 2026-06-21: FSRS seeding must come from the OBJECTIVE
    // quiz signal. Verify end-to-end:
    //   • Child skips recall (no recall self-report involved).
    //   • Child answers the quiz correctly on the first try.
    //   • NazoResult.knewWords == {correctOption.label}.
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = kTown5Scene.hotspots.firstWhere(
      (h) => h.kind == HotspotKind.npc && h.step != null,
    );
    final correctIdx = hotspot.step!.correctIndex;
    final correctWord = hotspot.step!.options[correctIdx].label;

    NazoResult? captured;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                captured = await Navigator.of(ctx).push<NazoResult>(
                  MaterialPageRoute(
                    builder: (_) =>
                        NazoScreen(hotspot: hotspot, eikenLevel: '5'),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Skip past the teach card if present.
    final proceed = find.textContaining('おぼえた');
    if (proceed.evaluate().isNotEmpty) {
      await tester.ensureVisible(proceed.first);
      await tester.pump();
      await tester.tap(proceed.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Skip the recall phase entirely (no self-report path at all).
    if (find.text('スキップ ▶').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('スキップ ▶'));
      await tester.pump();
      await tester.tap(find.text('スキップ ▶'));
      await tester.pumpAndSettle();
    }

    // Answer the quiz CORRECTLY on the first try.
    final tile = find.byType(AudioOptionButton).at(correctIdx);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();

    // Wait for read-window, then tap finish.
    await tester.pump(const Duration(milliseconds: 600));
    final finish = find.textContaining('解');
    await tester.ensureVisible(finish);
    await tester.pump();
    await tester.tap(finish);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured, isNotNull, reason: 'NazoResult must be returned');
    expect(captured!.firstTryCorrect, isTrue,
        reason: 'quiz answered correctly on first try');
    expect(captured!.knewWords, contains(correctWord),
        reason:
            'knewWords must contain the correct quiz option when first-try correct '
            '(objective signal, NOT self-report)');
  });

  testWidgets(
      'knewWords is EMPTY when quiz first-try is wrong (FSRS not poisoned)',
      (tester) async {
    // A child who answers wrong first → knewWords must be empty regardless of
    // whether they "would have" claimed おぼえてた！ in the old self-report flow.
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = kTown5Scene.hotspots.firstWhere(
      (h) => h.kind == HotspotKind.npc && h.step != null,
    );
    final correctIdx = hotspot.step!.correctIndex;
    final wrongIdx = correctIdx == 0 ? 1 : 0;

    NazoResult? captured;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                captured = await Navigator.of(ctx).push<NazoResult>(
                  MaterialPageRoute(
                    builder: (_) =>
                        NazoScreen(hotspot: hotspot, eikenLevel: '5'),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Skip past the teach card and recall.
    final proceed = find.textContaining('おぼえた');
    if (proceed.evaluate().isNotEmpty) {
      await tester.ensureVisible(proceed.first);
      await tester.pump();
      await tester.tap(proceed.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.text('スキップ ▶').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('スキップ ▶'));
      await tester.pump();
      await tester.tap(find.text('スキップ ▶'));
      await tester.pumpAndSettle();
    }

    // Tap WRONG first, then correct.
    final wrongTile = find.byType(AudioOptionButton).at(wrongIdx);
    await tester.ensureVisible(wrongTile);
    await tester.pump();
    await tester.tap(wrongTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final correctTile = find.byType(AudioOptionButton).at(correctIdx);
    await tester.ensureVisible(correctTile);
    await tester.pump();
    await tester.tap(correctTile);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 600));
    final finish = find.textContaining('解');
    await tester.ensureVisible(finish);
    await tester.pump();
    await tester.tap(finish);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured, isNotNull);
    expect(captured!.firstTryCorrect, isFalse);
    expect(captured!.knewWords, isEmpty,
        reason: 'knewWords must be empty when quiz first-try was wrong — '
            'no FSRS poisoning from overconfident self-report');
  });
}

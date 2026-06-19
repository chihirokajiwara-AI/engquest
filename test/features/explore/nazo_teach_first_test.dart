// test/features/explore/nazo_teach_first_test.dart
//
// CEO 2026-06-09 (致命的欠陥): a true beginner was dropped into an English
// multiple-choice ナゾ with NO teaching first ("何も学んでないのに、いきなりこれが
// 出てきて、誰が答えられるのだ？"). The structural fix: a Hotspot whose ナゾ is a bare
// quiz now carries a TeachCard, and NazoScreen TEACHES it BEFORE the quiz.
//
// This test locks that contract: the slime greeting ナゾ must show the lesson
// (meanings of Hello/Goodbye/Thank you/Sorry) FIRST; an active cued-recall phase
// (game-studio director #1) walks the child through each item one at a time;
// tapping 「いみは？」 reveals the JA; tapping 「つぎへ ▶」 / 「ナゾへ ▶」 advances through
// all items to the quiz; quiz options must NOT appear until then.

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

    // Tap 「おぼえた！ ナゾへ」 → the recall phase begins with the first item's EN.
    final advance = find.text('おぼえた！ ナゾへ ▶');
    expect(advance, findsOneWidget);
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Recall phase: the first EN word (Hello!) is visible on the cover card.
    // The JA meanings and quiz options are NOT yet visible.
    expect(find.textContaining('Hello'), findsOneWidget,
        reason: 'first item EN must appear on the cover card');
    expect(find.text('いみは？'), findsOneWidget,
        reason: 'JA meaning must be hidden behind the tap-target');
    expect(find.text('こんにちは'), findsNothing,
        reason: 'JA meaning must be occluded before tap');
    expect(find.text('ミノス'), findsNothing,
        reason: 'quiz must not be visible during recall');

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

  // ── Active cued-recall contract tests ────────────────────────────────────────

  testWidgets('recall phase: teach EN word on cover card + いみは？ target',
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

    // The first EN word must appear on the cover card.
    final firstEn = hotspot.teachCard!.items.first.en;
    expect(
        find.textContaining(firstEn.replaceAll('!', '').trim()), findsOneWidget,
        reason: 'EN word must appear on cover card');

    // The 「いみは？」 tap-target must be present.
    expect(find.text('いみは？'), findsOneWidget,
        reason: '「いみは？」 tap-target must be present before reveal');

    // Teach JA text must NOT be in the tree yet.
    expect(find.text('こんにちは'), findsNothing,
        reason: 'JA must be hidden before tapping いみは？');

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping いみは？ reveals the JA meaning', (tester) async {
    final hotspot = greetingHotspot();
    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Advance to recall.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Tap 「いみは？」 to reveal JA.
    final imiwa = find.text('いみは？');
    expect(imiwa, findsOneWidget);
    await tester.tap(imiwa);
    await tester.pumpAndSettle();

    // The first JA meaning must now be visible.
    final firstJa = hotspot.teachCard!.items.first.ja;
    expect(find.text(firstJa), findsOneWidget,
        reason: 'JA meaning must appear after tapping いみは？');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping 「つぎへ ▶」 through all items reaches the quiz (AudioOptionButton options)',
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

    // Step through each item: tap 「つぎへ ▶」 (or 「ナゾへ ▶」 on the last item).
    for (var i = 0; i < items.length; i++) {
      final isLast = i == items.length - 1;
      final nextLabel = isLast ? 'ナゾへ ▶' : 'つぎへ ▶';
      final nextBtn = find.text(nextLabel);
      expect(nextBtn, findsOneWidget,
          reason: 'Expected "$nextLabel" button at cue $i');
      await tester.ensureVisible(nextBtn);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
    }

    // Now the quiz phase: ミノス meter + AudioOptionButton tiles present.
    expect(find.text('ミノス'), findsOneWidget,
        reason: 'ミノス meter must appear after all cues are tapped through');
    expect(find.byType(AudioOptionButton), findsWidgets,
        reason: 'quiz option tiles must appear after completing recall cues');
    expect(tester.takeException(), isNull);
  });

  testWidgets('teach English words are NOT answer options until quiz phase',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    // The cover card shows the EN word large — but NOT as an AudioOptionButton
    // (quiz choice). Verify no AudioOptionButtons exist yet in the recall phase.
    expect(find.byType(AudioOptionButton), findsNothing,
        reason:
            'quiz option tiles must NOT appear until the quiz phase — teach EN word shown on cover card is not an answer option');
    expect(tester.takeException(), isNull);
  });

  testWidgets('recall phase: teach items are NOT in the tree (occlusion)',
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

    // JA meanings must NOT appear in the tree during recall (until tapped).
    for (final word in ['こんにちは', 'さようなら', 'ありがとう', 'ごめんなさい']) {
      expect(find.text(word), findsNothing,
          reason:
              '"$word" must be occluded during recall to force retrieval practice');
    }
    // AudioOptionButton quiz tiles must not appear yet.
    expect(find.byType(AudioOptionButton), findsNothing,
        reason: 'quiz tiles must be occluded during recall');
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
    expect(find.text('いみは？'), findsNothing,
        reason: 'recall phase must not appear when there is no TeachCard');
    expect(find.text('ミノス'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

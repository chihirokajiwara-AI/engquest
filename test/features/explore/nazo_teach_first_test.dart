// test/features/explore/nazo_teach_first_test.dart
//
// CEO 2026-06-09 (致命的欠陥): a true beginner was dropped into an English
// multiple-choice ナゾ with NO teaching first ("何も学んでないのに、いきなりこれが
// 出てきて、誰が答えられるのだ？"). The structural fix: a Hotspot whose ナゾ is a bare
// quiz now carries a TeachCard, and NazoScreen TEACHES it BEFORE the quiz.
//
// This test locks that contract: the slime greeting ナゾ must show the lesson
// (meanings of Hello/Goodbye/Thank you/Sorry) FIRST; a retrieval gap (recall
// phase) occludes the teach content before the quiz appears; and quiz options
// must NOT be reachable until the child has tapped through both phases.

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

    // Tap 「おぼえた！ ナゾへ」 → the recall phase occludes the teach content.
    final advance = find.text('おぼえた！ ナゾへ ▶');
    expect(advance, findsOneWidget);
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Recall phase: teach content is gone; the recall instruction appears;
    // the skip button is present; the quiz is not shown yet.
    expect(find.text('あたまの なかで、ことばを おもいだそう。'), findsOneWidget,
        reason: 'recall phase must show the instruction');
    expect(find.text('こんにちは'), findsNothing,
        reason: 'teach content must be occluded during recall');
    expect(find.text('さようなら'), findsNothing);
    expect(find.text('ミノス'), findsNothing,
        reason: 'quiz must not be visible during recall');

    // Tap 「もう だいじょうぶ ▶」 (skip) → quiz appears.
    final skip = find.textContaining('もう だいじょうぶ');
    expect(skip, findsOneWidget);
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();

    // Now the quiz is shown (ミノス meter + the greeting choices).
    expect(find.text('ミノス'), findsOneWidget);
    expect(
        find.text('Hello!'), findsWidgets); // the correct reply is selectable
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

  // ── Retrieval-gap (recall phase) contract tests ───────────────────────────

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

    // Teach English words must NOT appear in the tree during recall.
    for (final word in ['Hello', 'Goodbye', 'Thank you', 'Sorry']) {
      expect(find.textContaining(word), findsNothing,
          reason: '"$word" must be occluded during recall to force retrieval');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('recall skip button advances directly to quiz with options',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final hotspot = greetingHotspot();
    await tester.pumpWidget(
      MaterialApp(home: NazoScreen(hotspot: hotspot, eikenLevel: '5')),
    );
    await tester.pumpAndSettle();

    // Tap through teach.
    final advance = find.textContaining('おぼえた');
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pumpAndSettle();

    // Tap recall skip.
    final skip = find.textContaining('もう だいじょうぶ');
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();

    // Now on quiz: ミノス + option tiles present.
    expect(find.text('ミノス'), findsOneWidget);
    expect(find.byType(AudioOptionButton), findsWidgets);
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
    expect(find.textContaining('ことばを おもいだそう'), findsNothing,
        reason: 'recall phase must not appear when there is no TeachCard');
    expect(find.text('ミノス'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

// test/features/explore/nazo_teach_first_test.dart
//
// CEO 2026-06-09 (致命的欠陥): a true beginner was dropped into an English
// multiple-choice ナゾ with NO teaching first ("何も学んでないのに、いきなりこれが
// 出てきて、誰が答えられるのだ？"). The structural fix: a Hotspot whose ナゾ is a bare
// quiz now carries a TeachCard, and NazoScreen TEACHES it BEFORE the quiz.
//
// This test locks that contract: the slime greeting ナゾ must show the lesson
// (meanings of Hello/Goodbye/Thank you/Sorry) FIRST, and the quiz options must
// NOT be reachable until the child taps 「わかった！ こたえてみる」.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';

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

    // The quiz must NOT be reachable yet — no ミノス meter, no advance to it.
    expect(find.text('ミノス'), findsNothing);

    // Tap 「わかった！」 → the quiz appears.
    final advance = find.text('わかった！ こたえてみる ▶');
    expect(advance, findsOneWidget);
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    await tester.tap(advance);
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
}

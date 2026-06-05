// Verifies the 英検5級 blend step's c→a→t letter-highlight sweep: tapping the
// blend card's replay button drives BlendWordCard.activeLetter 0→1→2 then clears.
// Coordinate-clicking CanvasKit headlessly is unreliable, so this asserts the
// behaviour deterministically (and guards against the highlight regressing to
// the old always-static -1).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/quest_data.dart';
import 'package:engquest/features/quest/quest_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  testWidgets('blend step sweeps the letters on replay tap', (tester) async {
    // previewEncounterIndex: 3 = the s-a-t BlendWord step in town_eiken5.
    await tester.pumpWidget(MaterialApp(
      home: QuestScreen(town: kQuestTowns[0], previewEncounterIndex: 3),
    ));
    await tester.pump();

    BlendWordCard card() => tester.widget<BlendWordCard>(find.byType(BlendWordCard));

    expect(find.byType(BlendWordCard), findsOneWidget,
        reason: 'index 3 should render a blend card');
    expect(card().letters, ['s', 'a', 't']);
    expect(card().activeLetter, -1, reason: 'no highlight before the tap');

    // Tap the blend card's replay button (🔁 おとを つなげて きく).
    await tester.tap(find.byType(DqReplayButton));
    await tester.pump(); // sweep starts on the first letter
    expect(card().activeLetter, 0, reason: 'first tile lights immediately');

    await tester.pump(const Duration(milliseconds: 470));
    expect(card().activeLetter, 1, reason: 'sweep advances to the second tile');

    await tester.pump(const Duration(milliseconds: 470));
    expect(card().activeLetter, 2, reason: 'sweep advances to the third tile');

    // After the whole word holds briefly, the highlight clears back to -1.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(card().activeLetter, -1, reason: 'highlight clears after the word');
  });
}

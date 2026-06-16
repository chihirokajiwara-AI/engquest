import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/chapter.dart';
import 'package:engquest/features/explore/chapter_map_screen.dart';

Chapter _twoLocationChapter() {
  final s = sceneForGrade('5')!;
  return Chapter(
    grade: '5',
    titleJa: 'ことばを失った村',
    locations: [
      Location(scene: s, gate: const MasteryGate(requiredFirstTryNazo: 3)),
      Location(scene: s, gate: const MasteryGate(requiredFirstTryNazo: 3)),
    ],
    map: const ChapterMap(nodes: [
      MapNode(locationIndex: 0, x: 0.30, y: 0.64),
      MapNode(locationIndex: 1, x: 0.72, y: 0.34),
    ]),
    beats: const [],
  );
}

void main() {
  testWidgets('ChapterMapScreen renders both location nodes + title',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: ChapterMapScreen(
        chapter: _twoLocationChapter(),
        firstTryCorrectPerLocation: const [3, 1], // cleared, current
      ),
    ));
    await t.pump();
    expect(find.text('ことばを失った村'), findsOneWidget);
    expect(find.text('あんないず'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('reveal-1-ahead: a locked node is NOT a button, current IS',
      (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(
      home: ChapterMapScreen(
        chapter: _twoLocationChapter(),
        firstTryCorrectPerLocation: const [0, 0], // loc0 current, loc1 locked
      ),
    ));
    await t.pump();
    // The current (reachable) node announces as a tappable button…
    expect(find.bySemanticsLabel(RegExp('いま ここ')), findsOneWidget);
    // …and the locked node announces "can't go yet" (and is not tappable).
    expect(find.bySemanticsLabel(RegExp('まだ いけません')), findsOneWidget);
    handle.dispose();
    expect(t.takeException(), isNull);
  });

  testWidgets('cleared node exposes a re-enter button', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(
      home: ChapterMapScreen(
        chapter: _twoLocationChapter(),
        firstTryCorrectPerLocation: const [3, 1],
      ),
    ));
    await t.pump();
    expect(find.bySemanticsLabel(RegExp('クリアずみ')), findsOneWidget);
    handle.dispose();
  });
}

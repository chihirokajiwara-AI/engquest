// Smoke test: the battle WIDGET must actually build (the controller unit tests
// passed but the rendered screen crashed with a runtime type error on web —
// nothing pumped the widget). This surfaces the real (unminified) exception.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/quest_data.dart';
import 'package:engquest/features/quest/battle/quest_town_battle_flow.dart';
import 'package:engquest/features/quest/battle/silent_battle_controller.dart';
import 'package:engquest/features/quest/battle/silent_battle_screen.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';

void main() {
  testWidgets('QuestTownBattleFlow opens straight into battle without crashing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: QuestTownBattleFlow(
        town: kQuestTowns[0],
        previewStraightToBattle: true,
        repository: InMemoryFsrsCardRepository(),
        uid: 'test-uid',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  // R3: pump SilentBattleScreen directly (the prior test pumped the flow
  // wrapper, so the screen class itself had no named smoke coverage).
  testWidgets('SilentBattleScreen pumps directly without exception',
      (tester) async {
    final slices = sliceBattles(kQuestTowns[0].encounters, sliceSize: 4);
    final controller = SilentBattleController(
      townId: kQuestTowns[0].id,
      steps: slices.first.steps,
      stepOffsets: slices.first.offsets,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: SilentBattleScreen(
        controller: controller,
        repository: InMemoryFsrsCardRepository(),
        uid: 'test-uid',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SilentBattleScreen), findsOneWidget);
    // silent-blank guard: a screen that degrades to an empty Scaffold fails.
    expect(find.byType(Text), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

// test/features/quest/quest_map_overworld_test.dart
//
// Guards the painted serpentine overworld (task #22): it must render every town
// node WITHOUT a layout overflow even on a narrow 320 px phone — the width the
// adversarial child-UX audit (2026-06-07) flagged as the truncation risk for the
// long furigana town names. Seeds a chosen level so the MAP (not the level
// picker) renders, exercising start / cleared / unlocked / locked states.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/quest/quest_map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('overworld renders at 320 px with no overflow / crash',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 3000); // 320 logical @ 2x
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Seed a started journey: level 5級, two towns cleared → exercises start,
    // cleared, current-unlocked, and locked node states in one render.
    SharedPreferences.setMockInitialValues({
      'quest_start_level': '5',
      'quest_unlocked_index_5':
          2, // grade-scoped key (was global 'quest_unlocked_index')
    });

    await tester.pumpWidget(const MaterialApp(home: QuestMapScreen()));
    await tester.pump(); // let _load() resolve prefs
    await tester.pump(const Duration(milliseconds: 50));

    // No RenderFlex overflow or other layout/paint exception on the first frame.
    expect(tester.takeException(), isNull);

    // The painted map (not the picker) is showing: the start town is present.
    expect(find.textContaining('ことばを失'), findsOneWidget);
    // A later, still-locked town also lays out (name visible, just greyed).
    expect(find.textContaining('Grey Square'), findsOneWidget);
  });

  testWidgets(
      'unlock cursor is grade-scoped — a 5級 unlock does not bleed into 3級',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The child unlocked town 4 in 5級, then switched to 3級. The 3級 map must
    // start from 3級's own (absent) progress, NOT inherit the 5級 cursor — else
    // it pre-unlocks 準2/2級 towns the child never cleared.
    SharedPreferences.setMockInitialValues({
      'quest_start_level': '3',
      'quest_unlocked_index_5': 4,
    });

    await tester.pumpWidget(const MaterialApp(home: QuestMapScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final state = tester.state(find.byType(QuestMapScreen)) as dynamic;
    expect(state.debugUnlocked, isNot(4),
        reason: '3級 must not inherit the 5級 unlock cursor (cross-grade bleed)');
    expect(tester.takeException(), isNull);
  });
}

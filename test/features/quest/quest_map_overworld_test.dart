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
      'quest_unlocked_index': 2,
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
}

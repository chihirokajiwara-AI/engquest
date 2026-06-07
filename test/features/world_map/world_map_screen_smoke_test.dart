// test/features/world_map/world_map_screen_smoke_test.dart
// R3 smoke test: pump WorldMapScreen and assert no render exception.
// This screen was part of the #24 P0 "crash to blank grey" cluster — a render
// smoke test guards against that regression class.
// R4: initState only sets up AnimationControllers + staggered Future.delayed
// forwards; no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/world_map/world_map_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WorldMapScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception (staggered entrance settles)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WorldMapScreen()));
      // Let the staggered card entrance animations run + settle.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(WorldMapScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders zone labels (not an empty grey Scaffold)',
        (tester) async {
      await tester
          .pumpWidget(const MaterialApp(home: WorldMapScreen(childAge: 6)));
      // The #24 regression rendered a blank screen — assert real text content.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
      // Flush the staggered entrance timers before the tree is disposed.
      await tester.pump(const Duration(seconds: 3));
    });
  });
}

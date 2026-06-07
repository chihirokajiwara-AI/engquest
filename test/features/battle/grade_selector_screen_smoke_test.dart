// test/features/battle/grade_selector_screen_smoke_test.dart
// R3 smoke test: pump GradeSelectorScreen and assert no render exception.
// R4: StatelessWidget reading FlavorConfig.instance — no Firebase / network.
// FlavorConfig must be initialised (setFlavor) before instance access.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/features/battle/grade_selector_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlavorConfig.setFlavor(Flavor.aken);
  });

  group('GradeSelectorScreen — smoke tests (R3)', () {
    testWidgets('aken flavor — pumps without exception', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GradeSelectorScreen()));
      await tester.pump();
      expect(find.byType(GradeSelectorScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('edilab flavor — pumps without exception', (tester) async {
      FlavorConfig.setFlavor(Flavor.edilab);
      addTearDown(() => FlavorConfig.setFlavor(Flavor.aken));
      await tester.pumpWidget(
          const MaterialApp(home: GradeSelectorScreen(childAge: 10)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

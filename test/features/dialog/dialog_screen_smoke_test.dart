// test/features/dialog/dialog_screen_smoke_test.dart
// R3 smoke tests: pump DialogScenariosScreen (the scenario picker) and
// DialogScreen (the live NPC conversation shell) and assert no render exception.
// R4: DialogScreen's initial greeting makes a network call, so the test renders
// it with autoGreet:false — the chat shell builds with zero network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:engquest/features/dialog/dialog_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('DialogScenariosScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DialogScenariosScreen()));
      await tester.pump();
      expect(find.byType(DialogScenariosScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('DialogScreen — smoke tests (R3)', () {
    testWidgets('chat shell pumps without exception (autoGreet off)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DialogScreen(autoGreet: false),
      ));
      await tester.pump();
      expect(find.byType(DialogScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// test/features/paywall/grade_gate_screen_smoke_test.dart
// R3 smoke test: pump the GradeGateScreen paywall and assert no render
// exception. R4: reads FlavorConfig.instance — no Firebase / network in build.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/features/paywall/grade_gate_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlavorConfig.setFlavor(Flavor.aken);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GradeGateScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GradeGateScreen(eikenGrade: '2', onSubscribe: () {}),
      ));
      await tester.pump();
      expect(find.byType(GradeGateScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

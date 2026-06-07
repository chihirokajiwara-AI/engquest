// test/features/legal/terms_of_service_screen_smoke_test.dart
// R3 smoke test: pump TermsOfServiceScreen and assert no render exception.
// R4: pure StatelessWidget rendering static legal text — no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:engquest/features/legal/terms_of_service_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('TermsOfServiceScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));
      await tester.pump();
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with close button variant pumps without exception',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TermsOfServiceScreen(showCloseButton: true),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

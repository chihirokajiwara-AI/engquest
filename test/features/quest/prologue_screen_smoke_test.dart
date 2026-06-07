// test/features/quest/prologue_screen_smoke_test.dart
// R3 smoke test: pump PrologueScreen (the opening cutscene) and assert no render
// exception. R4: AudioCueService is test-safe (no native playback on the
// flutter_test host); no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/quest/prologue_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PrologueScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(onDone: () {}),
      ));
      await tester.pump();
      expect(find.byType(PrologueScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('startIndex offset pumps without exception', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(onDone: () {}, startIndex: 1),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

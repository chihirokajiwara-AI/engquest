// test/features/achievements/achievements_screen_smoke_test.dart
// R3 smoke test: pump AchievementsScreen and assert no render exception.
// This screen was part of the #24 P0 "crash to blank grey" cluster.
// R4: AuthService resolves FirebaseAuth lazily/safely (null when Firebase is
// uninitialised) and _load() is wrapped in try/catch → the screen degrades to
// its loaded/empty state rather than throwing. No network in build.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/achievements/achievements_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AchievementsScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception (Firebase absent)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AchievementsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AchievementsScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

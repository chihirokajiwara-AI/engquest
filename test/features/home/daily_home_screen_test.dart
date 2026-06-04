// test/features/home/daily_home_screen_test.dart
// Widget tests for DailyHomeScreen.
//
// Tests verify:
//   1. Screen renders without crash (basic smoke test)
//   2. Greeting text "おかえり！" is visible after loading
//   3. Quick action buttons are present (単語バトル, 会話練習, 発音チェック)
//   4. ワールドマップ link is visible
//   5. Streak section is visible (日連続 text)
//   6. Today's goal section is present
//
// SharedPreferences is mocked with setMockInitialValues so _loadData completes.
// Firebase (XpService/AuthService) is not initialized — DailyHomeScreen falls
// back gracefully to XpProfile.zero('offline') via the try/catch in _loadData.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/home/daily_home_screen.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

Widget _wrap({int childAge = 8}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF4FC3F7),
        secondary: const Color(0xFFFFB74D),
        surface: Colors.white,
        error: const Color(0xFFEF5350),
        onPrimary: Colors.white,
        onSecondary: Colors.black87,
        onSurface: const Color(0xFF263238),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      useMaterial3: true,
      textTheme: GoogleFonts.notoSansJpTextTheme(),
    ),
    home: DailyHomeScreen(childAge: childAge),
  );
}

/// Pumps enough frames for all async work to complete.
///
/// We use explicit Duration steps instead of pumpAndSettle to avoid timeouts
/// caused by AnimatedContainer in the streak dots (continuously animating).
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    // Mock SharedPreferences so PreferencesService.getInstance() resolves.
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();

    // Suppress Firebase-not-initialized errors: DailyHomeScreen catches them
    // and falls back to XpProfile.zero('offline').
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('Firebase') || msg.contains('No Firebase App')) return;
      FlutterError.presentError(details);
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
  });

  testWidgets('DailyHomeScreen renders without crash', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(find.byType(DailyHomeScreen), findsOneWidget);
  });

  testWidgets('DailyHomeScreen shows greeting after loading', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);
    expect(find.textContaining('おかえり'), findsWidgets);
  });

  testWidgets('DailyHomeScreen shows quick action labels', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);
    expect(find.text('単語バトル'), findsOneWidget);
    expect(find.text('会話練習'), findsOneWidget);
    expect(find.text('発音チェック'), findsOneWidget);
  });

  testWidgets('DailyHomeScreen shows world map link', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);
    expect(find.textContaining('ワールドマップ'), findsWidgets);
  });

  testWidgets('DailyHomeScreen shows streak section', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);
    expect(find.textContaining('日連続'), findsOneWidget);
  });

  testWidgets('DailyHomeScreen shows today goal section', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);
    expect(find.textContaining('もくひょう'), findsWidgets);
  });

  testWidgets('DailyHomeScreen shows level badge', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settle(tester);
    // Level badge shows "Lv.N" text.
    expect(find.textContaining('Lv.'), findsOneWidget);
  });
}

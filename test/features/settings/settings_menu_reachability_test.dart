// Reachability guard (#41): the parent progress dashboard and achievements screen
// were built but unreachable from the live home. They are now surfaced via the
// (already-reachable) Settings gear. This test fails if those affordances vanish.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/settings/settings_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings surfaces For-Parents + Achievements (reachability)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('For Parents'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('保護者（ほごしゃ）の方（かた）へ'), findsOneWidget);
    expect(find.text('じっせき'), findsOneWidget);
  });
}

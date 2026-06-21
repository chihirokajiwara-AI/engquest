// test/features/explore/nazo_phase_crossfade_test.dart
//
// Studio finding #5: teach → recall → quiz phase transitions crossfade via
// AnimatedSwitcher (cognitive-load research: the transition IS the beat).
// Reduced-motion: AnimatedSwitcher is ABSENT; keyed child is returned directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Helper: the greeting hotspot (has a TeachCard, so it starts in teach phase).
  Hotspot greetingHotspot() => kTown5Scene.hotspots
      .firstWhere((h) => identical(h.teachCard, kGreetingTeach));

  testWidgets('normal motion: AnimatedSwitcher is present in the widget tree',
      (tester) async {
    // Default MediaQuery has disableAnimations = false → normal motion path.
    await tester.pumpWidget(
      MaterialApp(
        home: NazoScreen(hotspot: greetingHotspot(), eikenLevel: '5'),
      ),
    );
    await tester.pump();

    // AnimatedSwitcher must wrap the phase child under normal motion.
    expect(
      find.byType(AnimatedSwitcher),
      findsOneWidget,
      reason: 'AnimatedSwitcher must be present so phases crossfade',
    );
  });

  testWidgets(
      'reduced motion (disableAnimations: true): AnimatedSwitcher is ABSENT',
      (tester) async {
    // Simulate the OS "reduce motion" accessibility setting.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: NazoScreen(hotspot: greetingHotspot(), eikenLevel: '5'),
        ),
      ),
    );
    await tester.pump();

    // Under reduced motion the keyed child is returned directly — no animation.
    expect(
      find.byType(AnimatedSwitcher),
      findsNothing,
      reason: 'AnimatedSwitcher must be absent under disableAnimations=true '
          '(instant phase change for vestibular/seizure-sensitive users)',
    );
  });
}

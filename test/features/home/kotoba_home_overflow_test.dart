// test/features/home/kotoba_home_overflow_test.dart
// #65 — the home hub (the child's landing screen on every launch) must lay out
// without a horizontal RenderFlex overflow across the phone widths the app
// targets. The three CTA Rows previously overflowed at ~360px logical width (a
// very common Android width) because their labels were not flex-wrapped — in a
// release build that clips the label rather than painting the debug stripe.
// FittedBox(scaleDown) now shrinks each label to fit. This test pins it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';

void main() {
  // Narrow-to-typical phone widths (logical px). 320 = iPhone SE (1st gen),
  // 360 = common Android, 390 = iPhone 14.
  for (final width in <double>[320, 360, 390]) {
    testWidgets('home hub lays out without overflow at ${width}px wide',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: KotobaHomeScreen(
          cardRepository: InMemoryFsrsCardRepository(),
          initialEikenLevel: '5',
        ),
      ));
      await tester.pump(); // post-frame _loadData
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'home hub overflowed at ${width}px (#65)');
    });
  }
}

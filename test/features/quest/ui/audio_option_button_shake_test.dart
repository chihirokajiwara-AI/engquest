// test/features/quest/ui/audio_option_button_shake_test.dart
// Game-feel (#59): a WRONG option tap must produce a kinetic response. Before
// this, the wrong tap was visually dead (and in the no-penalize branch the tap
// was swallowed with NO feedback at all). triggerShake() shudders the tile —
// gated off when "reduce motion" is on (vestibular/seizure a11y).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  double dxOf(WidgetTester tester) {
    final t = tester.widget<Transform>(find.descendant(
      of: find.byType(AudioOptionButton),
      matching: find.byType(Transform),
    ));
    return t.transform.getTranslation().x;
  }

  testWidgets('triggerShake displaces the tile, then settles back to 0',
      (tester) async {
    final key = GlobalKey<AudioOptionButtonState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AudioOptionButton(key: key, label: 'apple', onChoose: () {}),
      ),
    ));

    // At rest → no offset.
    expect(dxOf(tester), 0);

    key.currentState!.triggerShake();
    // Sample across the 320ms shudder; the tile must displace at some frame.
    var maxAbs = 0.0;
    for (var ms = 0; ms < 320; ms += 40) {
      await tester.pump(const Duration(milliseconds: 40));
      maxAbs = maxAbs > dxOf(tester).abs() ? maxAbs : dxOf(tester).abs();
    }
    expect(maxAbs, greaterThan(2.0), reason: 'tile must visibly shake');

    // After the animation completes → settles back to exactly 0 (no drift).
    await tester.pumpAndSettle();
    expect(dxOf(tester), 0);
  });

  testWidgets('reduce-motion: triggerShake is a no-op (no displacement)',
      (tester) async {
    final key = GlobalKey<AudioOptionButtonState>();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: AudioOptionButton(key: key, label: 'apple', onChoose: () {}),
        ),
      ),
    ));

    key.currentState!.triggerShake();
    await tester.pump(const Duration(milliseconds: 80));
    // Reduce-motion → the tile never moves.
    expect(dxOf(tester), 0);
  });
}

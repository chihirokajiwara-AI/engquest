// The 英検-progress tint must be GREY at 0 readiness and FULL COLOUR at 1, so the
// character honestly "comes to life" only as the child genuinely nears 合格 (CEO
// 3758 ① mechanism). Tests the saturation matrix maths directly.

import 'package:engquest/features/character/progress_tinted_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;

  test('readiness 0 → greyscale: every RGB row collapses to the luma weights', () {
    final m = progressSaturationMatrix(0);
    // Rows R, G, B must all be [lr, lg, lb] → output channel = input luminance.
    for (final rowStart in [0, 5, 10]) {
      expect(m[rowStart + 0], closeTo(lr, 1e-9));
      expect(m[rowStart + 1], closeTo(lg, 1e-9));
      expect(m[rowStart + 2], closeTo(lb, 1e-9));
    }
  });

  test('readiness 1 → identity (full colour, no tint)', () {
    final m = progressSaturationMatrix(1);
    expect(m[0], closeTo(1, 1e-9)); // R←R
    expect(m[1], closeTo(0, 1e-9));
    expect(m[6], closeTo(1, 1e-9)); // G←G
    expect(m[12], closeTo(1, 1e-9)); // B←B
  });

  test('partial readiness is between grey and colour (monotonic toward colour)', () {
    // The R←R diagonal grows from lr (grey) toward 1 (colour) as readiness rises.
    final r0 = progressSaturationMatrix(0.0)[0];
    final rHalf = progressSaturationMatrix(0.5)[0];
    final r1 = progressSaturationMatrix(1.0)[0];
    expect(r0, lessThan(rHalf));
    expect(rHalf, lessThan(r1));
  });

  test('out-of-range readiness is clamped (no crash / no NaN)', () {
    expect(progressSaturationMatrix(-1)[0], closeTo(lr, 1e-9)); // → grey
    expect(progressSaturationMatrix(2)[0], closeTo(1, 1e-9)); // → colour
  });

  testWidgets('widget renders without crash and tolerates a missing asset',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProgressTintedCharacter(
        asset: 'assets/art/does_not_exist.webp',
        readiness: 0.5,
        size: 80,
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ProgressTintedCharacter), findsOneWidget);
  });
}

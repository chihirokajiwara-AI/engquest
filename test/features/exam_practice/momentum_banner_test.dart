// The momentum banner celebrates a correct streak (positive mirror of the
// cold-streak encouragement) — engagement spine (CEO 951), COPPA-safe own-progress.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/practice_encouragement.dart';

void main() {
  testWidgets('momentum banner shows the streak count + 🔥', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PracticeMomentumBanner(streak: 5)),
    ));
    expect(find.byKey(const ValueKey('practice_momentum_banner')), findsOneWidget);
    expect(find.textContaining('5問'), findsOneWidget);
    expect(find.textContaining('れんぞく 正解'), findsOneWidget);
    expect(find.textContaining('🔥'), findsOneWidget);
  });

  test('momentum threshold is a sane small streak', () {
    expect(kMomentumThreshold, greaterThanOrEqualTo(3));
  });
}

// test/features/exam_practice/practice_result_stars_test.dart
//
// The reward-moment stars (#51) are purely cosmetic, so the contract worth
// locking is the TIERING: how many stars + which praise line each accuracy
// earns, and that the widget renders the right number of filled stars. The
// thresholds are deliberately gentle (a ~60% 英検-pass run earns 2 stars).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/practice_result_stars.dart';

void main() {
  group('PracticeResultStars tiering', () {
    int starsFor(int c, int t) =>
        PracticeResultStars(correct: c, total: t).stars;
    String praiseFor(int c, int t) =>
        PracticeResultStars(correct: c, total: t).praise;

    test('perfect → 3 stars + ぜんもん せいかい', () {
      expect(starsFor(10, 10), 3);
      expect(praiseFor(10, 10), 'ぜんもん せいかい！');
    });

    test('85%+ (not perfect) → 3 stars + すばらしい', () {
      expect(starsFor(9, 10), 3);
      expect(praiseFor(9, 10), 'すばらしい！');
    });

    test('60% (英検 pass line) → 2 stars + よく できました', () {
      expect(starsFor(6, 10), 2);
      expect(praiseFor(6, 10), 'よく できました！');
    });

    test('35-59% → 1 star + いい ちょうし', () {
      expect(starsFor(5, 10), 1);
      expect(praiseFor(5, 10), 'いい ちょうし！');
    });

    test('below 35% → 0 stars + encouragement (never a scold)', () {
      expect(starsFor(3, 10), 0);
      expect(praiseFor(3, 10), 'つぎは もっと いけるよ！');
    });

    test('empty session is safe (no divide-by-zero)', () {
      expect(starsFor(0, 0), 0);
      expect(PracticeResultStars(correct: 0, total: 0).pct, 0);
    });
  });

  testWidgets('renders the right number of filled stars + praise',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: PracticeResultStars(correct: 9, total: 10)),
      ),
    ));
    // 3 filled stars (90% → 3), 0 outline; praise line present.
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    expect(find.text('すばらしい！'), findsOneWidget);
  });
}

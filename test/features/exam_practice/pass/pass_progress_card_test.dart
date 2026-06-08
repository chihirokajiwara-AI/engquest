// test/features/exam_practice/pass/pass_progress_card_test.dart
// Verifies the session-end 合格率 progress card: honest thin-data state, the
// +delta "you went up" moment, and the 合格圏 state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/pass_gauge.dart';
import 'package:engquest/features/exam_practice/pass/pass_progress_card.dart';

CseEstimate _est({
  required double readinessPct,
  required int totalItems,
  int pointsNeeded = 120,
  Set<EikenSkill> unmeasured = const {},
}) {
  return CseEstimate(
    grade: '3',
    skillScores: const {EikenSkill.reading: 300},
    totalScore: 300,
    passingScore: 419,
    maxScore: 850,
    readinessPct: readinessPct,
    limitingSkill: EikenSkill.reading,
    pointsNeeded: pointsNeeded,
    unmeasuredSkills: unmeasured,
    // Spread items across reading so totalItemsAttempted == totalItems.
    itemsAttempted: {EikenSkill.reading: totalItems},
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('thin sample → "しんだんちゅう", no confident gauge', (tester) async {
    await tester.pumpWidget(_wrap(PassProgressCard(
      post: _est(readinessPct: 70, totalItems: 6),
    )));
    expect(find.textContaining('しんだんちゅう'), findsOneWidget);
    expect(find.textContaining('あと 14問'), findsOneWidget); // 20 - 6
    // No gauge on thin data — would read as fabricated.
    expect(find.byType(PassGauge), findsNothing);
  });

  testWidgets('confident + gain → shows the +delta up-badge and the gauge',
      (tester) async {
    await tester.pumpWidget(_wrap(PassProgressCard(
      pre: _est(readinessPct: 60, totalItems: 40),
      post: _est(readinessPct: 66, totalItems: 50),
    )));
    expect(find.byType(PassGauge), findsOneWidget);
    expect(find.textContaining('＋6'), findsOneWidget); // +6% up
    expect(find.textContaining('アップ'), findsOneWidget);
    expect(find.textContaining('あと'), findsWidgets); // 合格まで あと Nポイント
  });

  testWidgets('no prior data → gauge but NO delta badge', (tester) async {
    await tester.pumpWidget(_wrap(PassProgressCard(
      post: _est(readinessPct: 55, totalItems: 30),
    )));
    expect(find.byType(PassGauge), findsOneWidget);
    expect(find.textContaining('アップ'), findsNothing);
  });

  testWidgets('predicted pass (all skills measured) → 合格圏 headline',
      (tester) async {
    await tester.pumpWidget(_wrap(PassProgressCard(
      post: _est(readinessPct: 100, totalItems: 40), // unmeasured = {}
    )));
    expect(find.textContaining('合格圏'), findsOneWidget);
  });

  testWidgets(
      'high % but writing+listening UNMEASURED → NOT 合格圏, discloses basis',
      (tester) async {
    // The honesty boundary: a reading-only Battle for 3級+ can push readiness
    // high, but must NOT claim 合格圏 while skills are untested, and MUST disclose
    // which skills are not yet measured.
    await tester.pumpWidget(_wrap(PassProgressCard(
      post: _est(
        readinessPct: 100,
        totalItems: 40,
        unmeasured: const {EikenSkill.writing, EikenSkill.listening},
      ),
    )));
    expect(find.textContaining('合格圏'), findsNothing);
    expect(find.textContaining('ライティング'), findsOneWidget);
    expect(find.textContaining('リスニング'), findsOneWidget);
    expect(find.textContaining('これから'), findsOneWidget);
  });
}

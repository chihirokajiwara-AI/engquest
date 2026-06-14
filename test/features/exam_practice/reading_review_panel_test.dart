// 大問4 読解 session-end "review these" list. ReadingReviewPanel is a pure widget
// over (question, why) records, so this asserts the real behaviour without
// driving the whole passage screen: one row per missed question, and the 解説
// (passage evidence) shows only when the question has one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:engquest/features/exam_practice/reading_practice_screen.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ReadingReviewPanel', () {
    testWidgets('renders one row per missed question', (tester) async {
      await _pump(
        tester,
        const ReadingReviewPanel(
          missed: [
            (question: 'Why did the boy run?', why: 'He was late.'),
            (question: 'What did she buy?', why: 'A blue hat.'),
          ],
        ),
      );
      expect(
          find.byKey(const ValueKey('reading_review_panel')), findsOneWidget);
      expect(find.textContaining('Why did the boy run?'), findsOneWidget);
      expect(find.textContaining('What did she buy?'), findsOneWidget);
    });

    testWidgets('shows 解説 when present, omits it when null', (tester) async {
      await _pump(
        tester,
        const ReadingReviewPanel(
          missed: [
            (question: 'Q with reason', why: 'evidence in the passage line 3'),
            (question: 'Q without reason', why: null),
          ],
        ),
      );
      expect(find.text('evidence in the passage line 3'), findsOneWidget);
      // The reason-less question still renders (graceful, no crash).
      expect(find.textContaining('Q without reason'), findsOneWidget);
    });

    testWidgets('empty why string is treated as absent (no blank 解説 row)',
        (tester) async {
      await _pump(
        tester,
        const ReadingReviewPanel(
          missed: [(question: 'Only question', why: '')],
        ),
      );
      expect(find.textContaining('Only question'), findsOneWidget);
      // Just the question text — no empty second Text node for the 解説.
      expect(find.byType(Text), findsNWidgets(2)); // header + the one question
    });
  });
}

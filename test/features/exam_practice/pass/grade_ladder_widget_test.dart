// test/features/exam_practice/pass/grade_ladder_widget_test.dart
//
// GradeLadderWidget unit/widget tests.
//
// Covers:
//   1. All 7 grade stops render (smoke).
//   2. Passed grades show a ✓ icon.
//   3. Current grade is highlighted (star icon).
//   4. Next grade shows goal label.
//   5. readinessPct badge appears when provided.
//   6. No crash on an unknown grade (graceful fallback).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/pass/grade_ladder_widget.dart';
import 'package:engquest/features/exam_practice/pass/mastery_advisor.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders all 7 grade stops (smoke)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GradeLadderWidget(currentGrade: '3'),
      ),
    );
    // All ladder grades should produce their Japanese short label.
    expect(find.textContaining('5きゅう'), findsOneWidget);
    expect(find.textContaining('4きゅう'), findsOneWidget);
    expect(find.textContaining('3きゅう'), findsOneWidget);
    expect(find.textContaining('じゅん2きゅう'), findsWidgets); // pre2 + pre2plus
    // '2きゅう' (exact, not substring) — use text() not textContaining to avoid
    // matching じゅん2きゅう and じゅん2きゅう＋.
    expect(find.text('2きゅう'), findsOneWidget);
    expect(find.textContaining('じゅん1きゅう'), findsOneWidget);
  });

  testWidgets('current grade shows star icon; passed grades show check icon',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GradeLadderWidget(
          currentGrade: '3',
          passedGrades: {'5', '4'},
        ),
      ),
    );
    // Star for current.
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    // Check for each passed grade (5 + 4).
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('next grade after current shows もくひょう label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GradeLadderWidget(currentGrade: '4'),
      ),
    );
    expect(find.textContaining('もくひょう'), findsOneWidget);
  });

  testWidgets('readinessPct badge shows the % on current grade',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GradeLadderWidget(
          currentGrade: '3',
          readinessPct: 72,
        ),
      ),
    );
    expect(find.textContaining('72%'), findsOneWidget);
  });

  testWidgets(
      'unknown grade does not throw — renders without current highlight',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GradeLadderWidget(currentGrade: 'unknown_grade'),
      ),
    );
    // No star (no current stop highlighted).
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    // 7 stops still render. When grade is unknown currentIdx==-1 so the
    // isNext check resolves to i==0 (the first stop becomes the implied next),
    // giving 1 arrow + 6 locks (not 7 locks).
    expect(find.byIcon(Icons.lock_outline_rounded),
        findsNWidgets(kGradeLadder.length - 1));
  });

  testWidgets('compact mode (showLabels: false) renders without grade text',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GradeLadderWidget(
          currentGrade: '2',
          showLabels: false,
        ),
      ),
    );
    // No Japanese grade labels in compact mode.
    expect(find.textContaining('きゅう'), findsNothing);
    // Icons still render.
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('auto-passes grades before current when passedGrades is null',
      (tester) async {
    // Current = pre2 (index 3). Grades 5, 4, 3 (indexes 0,1,2) auto-marked passed.
    await tester.pumpWidget(
      _wrap(
        const GradeLadderWidget(currentGrade: 'pre2'),
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}

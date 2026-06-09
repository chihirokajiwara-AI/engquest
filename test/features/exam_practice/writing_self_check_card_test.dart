// Honesty test for the 見直しチェック self-check card (#100 follow-through).
// Decided by the 3-lens expert panel (validity + pedagogy + product, 2026):
// the card is a REVISION checklist that NEVER feeds the 合格率 and whose closure
// must name what was NOT checked (語彙・文法 quality) so it can't read as a grade.

import 'package:engquest/features/exam_practice/writing_practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('closure appears only after ALL objective items are confirmed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WritingSelfCheckCard(taskType: WritingTaskType.opinion),
        ),
      ),
    ));
    await tester.pump();

    // No closure before the learner confirms the items.
    expect(find.textContaining('提出準備 OK'), findsNothing);

    // Tap every unchecked box.
    final n =
        tester.widgetList(find.byIcon(Icons.check_box_outline_blank)).length;
    expect(n, greaterThan(0));
    for (var i = 0; i < n; i++) {
      await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
      await tester.pump();
    }

    // Closure now shows...
    expect(find.textContaining('提出準備 OK'), findsOneWidget);
    // ...and HONESTLY names that quality (語彙・文法) is AI-graded, not certified
    // here — the anti-overconfidence inoculation.
    expect(find.textContaining('AI先生が 採点'), findsOneWidget);
    // ...and explicitly states it does NOT feed the pass gauge.
    expect(find.textContaining('合格率には まだ 反映しません'), findsOneWidget);
  });

  testWidgets('the card never emits a numeric/quality score', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WritingSelfCheckCard(taskType: WritingTaskType.email),
        ),
      ),
    ));
    await tester.pump();
    for (var i = 0;
        i <
            tester
                .widgetList(find.byIcon(Icons.check_box_outline_blank))
                .length;
        i++) {
      await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
      await tester.pump();
    }
    // No "/4", no "点", no "%" anywhere — it is a checklist, not a grade.
    expect(find.textContaining('/4'), findsNothing);
    expect(find.textContaining('点'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}

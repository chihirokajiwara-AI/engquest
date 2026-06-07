// test/features/exam_practice/conversation_practice_test.dart
//
// Content invariant for 英検 大問2 会話文の文空所補充 (task #31). Guards the
// grade-differentiated banks: 5/4/3/準2 each must have real, well-formed items
// (4 distinct non-empty choices, a valid in-range correctIdx). 大問2 会話文空所
// exists ONLY at these grades — 2級/準1級 大問2 is 長文空所, so they are not
// asserted here.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';

void main() {
  for (final grade in ['5', '4', '3', 'pre2']) {
    test('英検$grade級 会話 items are well-formed 大問2 (4 choices, valid key)', () {
      final items = conversationItemsForTest(grade);
      expect(items.length, greaterThanOrEqualTo(5),
          reason: 'grade $grade has too few conversation items');

      for (final item in items) {
        // Exactly four options, exam-standard.
        expect(item.choices.length, 4, reason: 'grade $grade: ${item.choices}');
        // Correct index points at a real choice.
        expect(item.correctIdx, inInclusiveRange(0, 3),
            reason: 'grade $grade bad correctIdx ${item.correctIdx}');
        // No duplicate or empty options (a dup could create two right answers).
        expect(item.choices.toSet().length, item.choices.length,
            reason: 'duplicate choice in grade $grade: ${item.choices}');
        for (final c in item.choices) {
          expect(c.trim(), isNotEmpty, reason: 'empty choice in ${item.choices}');
        }
      }
    });
  }

  test('3級 and 準2級 have DIFFERENT conversation banks (not the old shared set)',
      () {
    // Regression guard for the defect fixed 2026-06-08: both upper grades used
    // to return the identical generic (too-hard-for-3級) bank.
    final g3 = conversationItemsForTest('3').map((i) => i.choices.first).toList();
    final gpre2 =
        conversationItemsForTest('pre2').map((i) => i.choices.first).toList();
    expect(g3, isNot(equals(gpre2)));
  });
}

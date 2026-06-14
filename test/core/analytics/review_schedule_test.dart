// Locks the parent-dashboard review-schedule bucketing (previously untested
// buyer-facing logic, wired live in a7ede38). Verifies the today/tomorrow/week
// day boundaries, the "new/learning/relearning = always due today" rule, and
// overdue handling. `now` is injected for determinism.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/analytics/progress_service.dart';

// A fixed reference "now": midday, so day boundaries are unambiguous.
final _now = DateTime(2026, 6, 14, 12, 0, 0);

Map<String, dynamic> _review(DateTime due) =>
    {'state': 'review', 'dueDate': due};

void main() {
  group('buildReviewSchedule', () {
    test('empty → all zeros', () {
      final s = buildReviewSchedule([], _now);
      expect(s.todayDue, 0);
      expect(s.tomorrowDue, 0);
      expect(s.weekDue, 0);
    });

    test('new / learning / relearning are always due today (+ this week)', () {
      final cards = [
        {'state': 'new'},
        {'state': 'learning'},
        {'state': 'relearning'},
      ];
      final s = buildReviewSchedule(cards, _now);
      expect(s.todayDue, 3);
      expect(s.tomorrowDue, 0); // they are NOT counted as tomorrow
      expect(s.weekDue, 3);
    });

    test('a review card with no dueDate is overdue → today', () {
      final s = buildReviewSchedule([
        {'state': 'review'} // null dueDate
      ], _now);
      expect(s.todayDue, 1);
      expect(s.weekDue, 1);
    });

    test('an overdue review (past dueDate) counts as today', () {
      final s = buildReviewSchedule(
          [_review(_now.subtract(const Duration(days: 3)))], _now);
      expect(s.todayDue, 1);
      expect(s.weekDue, 1);
      expect(s.tomorrowDue, 0);
    });

    test('buckets review cards by day boundary', () {
      final cards = [
        _review(DateTime(2026, 6, 14, 20)), // later today → today
        _review(DateTime(2026, 6, 15, 9)), // tomorrow → tomorrow
        _review(DateTime(2026, 6, 18, 9)), // +4 days → week only
        _review(DateTime(2026, 6, 25, 9)), // +11 days → none
      ];
      final s = buildReviewSchedule(cards, _now);
      expect(s.todayDue, 1);
      expect(s.tomorrowDue, 1);
      // today(1) + tomorrow(1) + day-4(1) are all within the 7-day window;
      // the +11-day card is excluded.
      expect(s.weekDue, 3);
    });

    test('week window is 7 days inclusive of today (today+6 23:59 is in)', () {
      final s = buildReviewSchedule([
        _review(DateTime(2026, 6, 20, 23, 0)), // today+6 → still this week
        _review(DateTime(2026, 6, 21, 0, 1)), // today+7 → out
      ], _now);
      expect(s.weekDue, 1);
    });

    test('todayDue ⊆ weekDue and tomorrowDue ⊆ weekDue (monotone buckets)', () {
      final cards = [
        {'state': 'new'},
        _review(_now.subtract(const Duration(days: 1))), // today
        _review(DateTime(2026, 6, 15, 10)), // tomorrow
        _review(DateTime(2026, 6, 17, 10)), // week
      ];
      final s = buildReviewSchedule(cards, _now);
      expect(s.weekDue, greaterThanOrEqualTo(s.todayDue));
      expect(s.weekDue, greaterThanOrEqualTo(s.tomorrowDue));
      expect(s.weekDue, 4); // all four fall within the week
    });
  });
}

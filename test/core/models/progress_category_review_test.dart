// Locks the display contract the parent dashboard now depends on after wiring
// REAL data (flaw-hunt 2026-06-14): the Progress tab + Schedule tab used to show
// hardcoded mock percentages / review counts to a paying parent. They now render
// progress.categoryMastery (CategoryMastery.ratio) and progress.reviewSchedule.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/models/progress_data.dart';

void main() {
  group('CategoryMastery.ratio (the % shown to parents)', () {
    test('ratio = mastered / total', () {
      const c =
          CategoryMastery(name: 'Animals', masteredCount: 9, totalCount: 12);
      expect(c.ratio, closeTo(0.75, 1e-9));
    });

    test('a category with no cards is 0, never a divide-by-zero', () {
      const c = CategoryMastery(name: 'Food', masteredCount: 0, totalCount: 0);
      expect(c.ratio, 0.0);
    });

    test('fully mastered = 1.0', () {
      const c =
          CategoryMastery(name: 'Colors', masteredCount: 5, totalCount: 5);
      expect(c.ratio, 1.0);
    });
  });

  group('ReviewSchedule (the counts shown to parents)', () {
    test('empty schedule is all zeros — honest "no reviews" before any study',
        () {
      const s = ReviewSchedule.empty();
      expect(s.todayDue, 0);
      expect(s.tomorrowDue, 0);
      expect(s.weekDue, 0);
    });

    test('carries the real due counts', () {
      const s = ReviewSchedule(todayDue: 4, tomorrowDue: 2, weekDue: 11);
      expect(s.todayDue, 4);
      expect(s.tomorrowDue, 2);
      expect(s.weekDue, 11);
    });
  });

  group('LearningProgress defaults are honest-empty (no fabricated data)', () {
    test('a freshly-constructed progress has empty category + zero schedule',
        () {
      const p = LearningProgress(
        uid: 'u',
        currentStreak: 0,
        totalWordsMastered: 0,
        totalWordsPracticed: 0,
        masteryPercent: 0,
        last7Days: [],
      );
      expect(p.categoryMastery, isEmpty);
      expect(p.reviewSchedule.todayDue, 0);
      expect(p.reviewSchedule.weekDue, 0);
    });
  });
}

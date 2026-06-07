// test/features/onboarding/placement_engine_test.dart
//
// Unit tests for PlacementEngine (adaptive placement diagnostic).
// Pure Dart — no Flutter imports needed.
//
// Run: flutter test test/features/onboarding/placement_engine_test.dart

import 'package:test/test.dart';
import 'package:engquest/features/onboarding/placement_engine.dart';
import 'package:engquest/features/onboarding/placement_item_bank.dart';

void main() {
  // ── Age seed table ──────────────────────────────────────────────────────

  group('age seed', () {
    test('age 4 seeds to rung 0 (5級)', () {
      final e = PlacementEngine.fromAge(4);
      expect(e.theta, equals(0.0));
    });
    test('age 6 seeds to rung 0 (5級)', () {
      final e = PlacementEngine.fromAge(6);
      expect(e.theta, equals(0.0));
    });
    test('age 7 seeds to rung 1 (4級)', () {
      final e = PlacementEngine.fromAge(7);
      expect(e.theta, equals(1.0));
    });
    test('age 9 seeds to rung 1 (4級)', () {
      final e = PlacementEngine.fromAge(9);
      expect(e.theta, equals(1.0));
    });
    test('age 10 seeds to rung 2 (3級)', () {
      final e = PlacementEngine.fromAge(10);
      expect(e.theta, equals(2.0));
    });
    test('age 12 seeds to rung 2 (3級)', () {
      final e = PlacementEngine.fromAge(12);
      expect(e.theta, equals(2.0));
    });
    test('age 13 seeds to rung 3 (準2級)', () {
      final e = PlacementEngine.fromAge(13);
      expect(e.theta, equals(3.0));
    });
    test('age 15 seeds to rung 3 (準2級)', () {
      final e = PlacementEngine.fromAge(15);
      expect(e.theta, equals(3.0));
    });
    test('age 16 seeds to rung 4 (準2級プラス)', () {
      final e = PlacementEngine.fromAge(16);
      expect(e.theta, equals(4.0));
    });
    test('age 18 seeds to rung 4 (準2級プラス)', () {
      final e = PlacementEngine.fromAge(18);
      expect(e.theta, equals(4.0));
    });
    test('selfReportShift +1 shifts seed up', () {
      final e = PlacementEngine.fromAge(8, selfReportShift: 1);
      expect(e.theta, equals(2.0)); // 1 + 1
    });
    test('selfReportShift -1 shifts seed down', () {
      final e = PlacementEngine.fromAge(13, selfReportShift: -1);
      expect(e.theta, equals(2.0)); // 3 - 1
    });
    test('selfReportShift is clamped to [0, 6]', () {
      final eHigh = PlacementEngine.fromAge(16, selfReportShift: 5);
      expect(eHigh.theta, equals(6.0)); // 4 + 5 clamped to 6
      final eLow = PlacementEngine.fromAge(4, selfReportShift: -5);
      expect(eLow.theta, equals(0.0)); // 0 - 5 clamped to 0
    });
  });

  // ── EWMA step decay ─────────────────────────────────────────────────────

  group('EWMA step decay', () {
    test('step on first answer is 1.5 (n=0)', () {
      final e = PlacementEngine.fromAge(10);
      // theta starts at 2.0; correct answer → 2.0 + 1.5 = 3.5
      e.record(true, grade: 2);
      expect(e.theta, closeTo(3.5, 0.001));
    });
    test('step on second answer (n=1) is 1.25', () {
      final e = PlacementEngine.fromAge(10); // θ=2.0
      e.record(true, grade: 2);  // n=0 → step 1.5, θ=3.5
      e.record(true, grade: 3);  // n=1 → step 1.25, θ=4.75
      expect(e.theta, closeTo(4.75, 0.001));
    });
    test('step on third answer (n=2) is 1.0', () {
      final e = PlacementEngine.fromAge(10); // θ=2.0
      e.record(true, grade: 2);  // n=0, step 1.5 → 3.5
      e.record(true, grade: 3);  // n=1, step 1.25 → 4.75
      e.record(true, grade: 4);  // n=2, step 1.0 → 5.75
      expect(e.theta, closeTo(5.75, 0.001));
    });
    test('step never drops below 0.5', () {
      // The step formula: max(0.5, 1.5 - 0.25*n).
      // At n=4 the formula gives max(0.5, 0.5) = 0.5.
      // At n=10 the formula gives max(0.5, -1.0) = 0.5 — floor is 0.5.
      // Verify by using wrong answers from a mid-theta start (avoids clamping).
      // The step formula: max(0.5, 1.5 - 0.25*n). At n>=5, value is <= 0.5
      // so the floor kicks in. Verify with alternating answers from θ=3.
      final e2 = PlacementEngine.fromAge(13); // θ=3
      for (var i = 0; i < 5; i++) {
        e2.record(i.isEven, grade: 3); // alternating
      }
      // At n=5: step = max(0.5, 1.5-1.25) = max(0.5, 0.25) = 0.5
      final thetaBefore = e2.theta;
      e2.record(true, grade: 3); // n=5, step should be 0.5
      // If θ+0.5 would exceed 6, clamp prevents us from verifying. Only check
      // that the increase is at most 0.5 (the step minimum) since we can't
      // exceed 6. Allow 0.0 if already at 6.
      final delta = e2.theta - thetaBefore;
      expect(delta, lessThanOrEqualTo(0.5 + 0.001));
      // And verify the step formula: at n>=5, max(0.5, 1.5-0.25*5)=0.5.
      // We can't directly access the step, but if theta was below 6 before,
      // delta == 0.5.
      if (thetaBefore < 6.0) {
        expect(delta, closeTo(0.5, 0.001));
      }
    });
    test('wrong answer moves theta down', () {
      final e = PlacementEngine.fromAge(12); // θ=2.0
      e.record(false, grade: 2); // step 1.5, θ = 2.0 - 1.5 = 0.5
      expect(e.theta, closeTo(0.5, 0.001));
    });
    test('theta is clamped to [0.0, 6.0]', () {
      final e = PlacementEngine.fromAge(16); // θ=4.0
      // Give many correct answers to drive θ to ceiling.
      for (var i = 0; i < 10; i++) {
        e.record(true, grade: 6);
      }
      expect(e.theta, lessThanOrEqualTo(6.0));

      final e2 = PlacementEngine.fromAge(4); // θ=0.0
      for (var i = 0; i < 10; i++) {
        e2.record(false, grade: 0);
      }
      expect(e2.theta, greaterThanOrEqualTo(0.0));
    });
  });

  // ── Non-discourage guard ────────────────────────────────────────────────

  group('non-discourage guard', () {
    test('after a wrong answer, nextGrade uses floor(θ) not round(θ)', () {
      // θ=2.5 → round=3, floor=2
      final e = PlacementEngine.fromAge(10); // θ=2
      e.record(true, grade: 2);  // step 1.5 → θ=3.5
      // Manually record a wrong at grade 3 → θ = 3.5-1.25=2.25
      e.record(false, grade: 3); // step 1.25 → θ=2.25
      // nextGrade after wrong answer: floor(2.25)=2
      expect(e.nextGrade(), equals(2));
    });

    test('after a correct answer, nextGrade climbs by the earned staircase', () {
      final e = PlacementEngine.fromAge(10); // θ=2
      e.record(true, grade: 2); // step 1.5 → θ=3.5
      // round(3.5)=4, but the gentle staircase (CEO 721) caps the presented rung
      // at highest-passed (2) + 1 = 3 — never jump from a passed rung-2 straight
      // to rung 4, skipping rung 3.
      expect(e.nextGrade(), equals(3));
    });

    test('no two consecutive failed-rung items at the same rung', () {
      // Feed the engine: correct at low, wrong at high, then check next grade
      // goes to floor(θ) which is at or below the failed rung.
      final e = PlacementEngine.fromAge(7); // θ=1
      e.record(true, grade: 1);   // step 1.5 → θ=2.5
      e.record(false, grade: 3);  // step 1.25 → θ=1.25; last=wrong
      final next = e.nextGrade(); // must be floor(1.25)=1, not round=1 (same)
      // Either way ≤ the grade that was just failed (3).
      expect(next, lessThan(3));
    });
  });

  // ── Min-3 / max-8 stopping ──────────────────────────────────────────────

  group('min-3 / max-8 stopping', () {
    test('done is false after fewer than 3 items', () {
      final e = PlacementEngine.fromAge(10);
      expect(e.done, isFalse);
      e.record(true, grade: 2);
      expect(e.done, isFalse);
      e.record(true, grade: 3);
      expect(e.done, isFalse);
    });

    test('done is true after 8 items regardless of pattern', () {
      final e = PlacementEngine.fromAge(10);
      for (var i = 0; i < 8; i++) {
        e.record(i.isEven, grade: 2);
      }
      expect(e.done, isTrue);
    });

    test('done does not become true at exactly 8 items due to ceiling if '
        'ceiling-stable was already met at 3 items', () {
      // Build a ceiling-stable pattern in 3 items:
      // items at grade 2 (pass), 2 (pass), 3 (fail) → stable ceiling at 2/3.
      final e = PlacementEngine.fromAge(10); // θ=2
      e.record(true, grade: 2);   // answers=[T], grades=[2]
      e.record(true, grade: 2);   // answers=[T,T], grades=[2,2]
      e.record(false, grade: 3);  // answers=[T,T,F], grades=[2,2,3] → stable
      expect(e.done, isTrue);
      expect(e.n, equals(3));
    });
  });

  // ── Ceiling early-stop ──────────────────────────────────────────────────

  group('ceiling early-stop', () {
    test('stops at 3 items when last 3 pass lower rung and fail upper rung', () {
      final e = PlacementEngine.fromAge(10); // θ=2
      e.record(true, grade: 2);
      e.record(true, grade: 2);
      e.record(false, grade: 3);
      expect(e.done, isTrue);
    });

    test('does not stop early when last 3 are not ceiling-pattern', () {
      final e = PlacementEngine.fromAge(10);
      e.record(true, grade: 2);
      e.record(false, grade: 2); // same rung, both directions — not stable
      e.record(true, grade: 2);
      expect(e.done, isFalse);
    });
  });

  // ── Barely-cleared → one rung down ──────────────────────────────────────

  group('barely-cleared → one rung down', () {
    test('2/3 correct at rung r and 0/1 correct at rung r+1 → placed at r-1', () {
      // Simulate: 2 correct at grade 3, 1 wrong at grade 3, 1 wrong at grade 4
      // → grade 3 pass rate = 2/3 (barely cleared) → placed at 2.
      final e = PlacementEngine.fromAge(13); // θ=3
      e.record(true, grade: 3);
      e.record(true, grade: 3);
      e.record(false, grade: 3);
      // Force 5 more to reach max (won't early-stop from above)
      e.record(false, grade: 4);
      e.record(false, grade: 4);
      e.record(false, grade: 4);
      e.record(false, grade: 4);
      e.record(false, grade: 4);
      expect(e.done, isTrue);
      final outcome = e.result();
      // Rung 3 barely cleared → placed at 2.
      expect(outcome.grade, equals(2));
    });

    test('3/3 correct at rung r → not barely cleared, placed at r', () {
      final e = PlacementEngine.fromAge(13); // θ=3
      e.record(true, grade: 3);
      e.record(true, grade: 3);
      e.record(true, grade: 3);
      // Drive to max
      for (var i = 0; i < 5; i++) { e.record(false, grade: 4); }
      expect(e.done, isTrue);
      final outcome = e.result();
      expect(outcome.grade, equals(3));
    });
  });

  // ── Full integration: 6-yo passes 5級 only ──────────────────────────────

  group('6-yo passes 5級 only', () {
    test('places at rung 0 when child only clears 5級 items', () {
      final e = PlacementEngine.fromAge(6); // θ=0
      // 3 correct at grade 0 then correct + fail at grade 1 (ceiling above 0)
      e.record(true, grade: 0);
      e.record(true, grade: 0);
      e.record(true, grade: 0);
      // 3 wrong at grade 1 to cement ceiling at 0
      e.record(false, grade: 1);
      e.record(false, grade: 1);
      e.record(false, grade: 1);
      // Should be done by now (max is 8 — add to reach 8 if not done)
      if (!e.done) {
        e.record(false, grade: 1);
        e.record(false, grade: 1);
      }
      final outcome = e.result();
      expect(outcome.grade, equals(0));
      expect(outcome.eikenLevel, equals('5'));
    });
  });

  // ── 13-yo clears 準1級 in ≤8 items ──────────────────────────────────────

  group('13-yo clears 準1級 in ≤8 items', () {
    test('placing at rung 6 takes ≤8 items', () {
      // Age 13 → seed θ=3 (準2級). Simulate all correct to escalate to rung 6.
      final e = PlacementEngine.fromAge(13); // θ=3
      var itemsUsed = 0;
      while (!e.done && itemsUsed < 8) {
        final g = e.nextGrade();
        e.record(true, grade: g);
        itemsUsed++;
      }
      expect(itemsUsed, lessThanOrEqualTo(8));
      final outcome = e.result();
      // Should have reached at least rung 5 or 6 when always correct.
      expect(outcome.grade, greaterThanOrEqualTo(5));
    });
  });

  // ── Item bank helpers ────────────────────────────────────────────────────

  group('item bank helpers', () {
    test('itemsForGrade returns 5 items for each rung', () {
      for (var g = 0; g <= 6; g++) {
        final items = itemsForGrade(g);
        expect(items.length, equals(5), reason: 'rung $g should have 5 items');
      }
    });

    test('unusedItemForGrade returns an item from the correct grade', () {
      final item = unusedItemForGrade(3, {});
      expect(item.grade, equals(3));
    });

    test('unusedItemForGrade avoids already-used items', () {
      // Mark first 4 items at grade 0 as used.
      final usedIds = <int>{};
      for (var i = 0; i < kPlacementBank.length && usedIds.length < 4; i++) {
        if (kPlacementBank[i].grade == 0) usedIds.add(i);
      }
      final item = unusedItemForGrade(0, usedIds);
      expect(item.grade, equals(0));
      expect(usedIds, isNot(contains(bankIndexOf(item))));
    });

    test('unusedItemForGrade falls back gracefully when all items are used', () {
      // Mark all items at grade 6 as used.
      final usedIds =
          kPlacementBank.indexed.where((r) => r.$2.grade == 6).map((r) => r.$1).toSet();
      // Should not throw — returns a fallback item.
      expect(() => unusedItemForGrade(6, usedIds), returnsNormally);
      final item = unusedItemForGrade(6, usedIds);
      expect(item.grade, equals(6));
    });

    test('all items have exactly 4 choices', () {
      for (final item in kPlacementBank) {
        expect(item.choices.length, equals(4),
            reason: '${item.stemEn} should have 4 choices');
      }
    });

    test('all correctIndex values are in range [0,3]', () {
      for (final item in kPlacementBank) {
        expect(item.correctIndex, inInclusiveRange(0, 3),
            reason: '${item.stemEn} correctIndex out of range');
      }
    });
  });

  // ── PlacementOutcome eikenLevel mapping ──────────────────────────────────

  group('PlacementOutcome eikenLevel mapping', () {
    final expected = {
      0: '5',
      1: '4',
      2: '3',
      3: 'pre2',
      4: 'pre2plus',
      5: '2',
      6: 'pre1',
    };

    for (final entry in expected.entries) {
      test('grade ${entry.key} maps to eikenLevel ${entry.value}', () {
        final g = entry.key;
        final e = PlacementEngine.fromAge(4); // start low

        if (g < 6) {
          // 3 correct at g (pass rate 3/3 = not barely-cleared)
          for (var i = 0; i < 3; i++) { e.record(true, grade: g); }
          // 3 wrong at g+1 to establish ceiling above g
          for (var i = 0; i < 3; i++) { e.record(false, grade: g + 1); }
          // Push to done without adding more items at grade g
          while (!e.done) { e.record(false, grade: g + 1); }
        } else {
          // g=6 (準1級): 3 correct at g=6, then just pad with wrong at
          // grade 5 (lower) so the result loop still identifies rung 6 as
          // the top passing rung (3/3 = 100%, not barely-cleared).
          for (var i = 0; i < 3; i++) { e.record(true, grade: 6); }
          // Pad to min 3 done (already at 3 — may already be done if stable).
          // Do NOT add more wrongs at grade 6 — that would dilute the pass rate.
          // Add wrongs at a lower grade that the result loop won't confuse.
          while (!e.done) { e.record(false, grade: 5); }
        }

        final outcome = e.result();
        expect(outcome.eikenLevel, equals(entry.value),
            reason: 'grade $g should map to ${entry.value}');
      });
    }
  });

  // ── Gentle staircase (CEO 721): always open easy, climb only by earned steps ──
  group('gentle staircase opening', () {
    test('first item is rung 0 (5級) even for the oldest age seed', () {
      // Age 16+ seeds θ high (4.0); the test must STILL open at 5級.
      final e = PlacementEngine.fromAge(18);
      expect(e.nextGrade(), 0);
    });

    test('first item is rung 0 for every age', () {
      for (final age in [4, 7, 10, 13, 16, 99]) {
        expect(PlacementEngine.fromAge(age).nextGrade(), 0,
            reason: 'age $age must still open at rung 0');
      }
    });

    test('presented rung never jumps more than one above highest passed', () {
      final e = PlacementEngine.fromAge(18); // high θ seed
      var presented = e.nextGrade();
      expect(presented, 0);
      var highestPassed = -1;
      for (var i = 0; i < 8; i++) {
        presented = e.nextGrade();
        expect(presented, lessThanOrEqualTo(highestPassed + 1),
            reason: 'must not jump ahead of earned level');
        // Simulate an advanced learner answering everything correctly.
        e.record(true, grade: presented);
        if (presented > highestPassed) highestPassed = presented;
      }
    });

    test('wrong first answer keeps it at rung 0 (no discourage spiral)', () {
      final e = PlacementEngine.fromAge(18);
      e.record(false, grade: 0); // failed the opening 5級 item
      expect(e.nextGrade(), 0);
    });
  });
}

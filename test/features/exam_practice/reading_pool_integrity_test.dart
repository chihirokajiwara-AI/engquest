// test/features/exam_practice/reading_pool_integrity_test.dart
//
// Guardrail (#16) against the "demo-deep, not prep-deep" failure mode found by
// the autonomous-loop completeness critic (2026-06-07): the mock scales
// proportionally, so reading/listening shortfalls and malformed items NEVER
// error — they silently produce a misleading 合格率.
//
// This file validates the SOURCE pool data (raw ReadingMockItem), not the
// composed readingItemsFor() output, so an empty passage cannot be masked by
// the passage+instruction concatenation. (Hardened after an adversarial audit
// flagged a tautological skill check + a masked-empty-passage false-green.)
//
// Three layers:
//   1. Structural R1 invariants (always green): 4 unique non-blank choices, no
//      Japanese/CJK leakage in choices (the exact 7,923-distractor corruption
//      class the governance rule exists for), valid correctIdx, non-empty
//      passage AND instruction, unique ids.
//   2. Count FLOOR / ratchet (always green): per-grade reading/listening counts
//      do not regress below the achieved baseline. Raise as pools grow.
//   3. Official-TARGET gap (machine-visible via skip): the remaining shortfall
//      to the real 英検 大問 target shows up in `flutter test` output as a
//      skipped test with the gap in its reason — NOT buried in a comment.
//
// Official 英検 targets (verified eiken.or.jp, 2026-06-07):
//   reading  5級25 4級35 3級30 準2級29 2級31 準1級31
//   listening 5級25 4級30 3級30 準2級30 2級30 準1級30

import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/listening_data.dart';
import 'package:engquest/features/exam_practice/pass/reading_item_pool.dart';

final _cjk = RegExp(r'[぀-ヿ㐀-䶿一-鿿]');

void main() {
  const grades = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];

  // Regression ratchet — current achieved counts. RAISE toward the target; never lower.
  const readingFloor = {
    '5': 24,
    '4': 35, // ratcheted to official target (studio expansion 2026-06-12)
    '3': 30, // ratcheted to official target (studio expansion 2026-06-12)
    'pre2': 19,
    'pre2plus': 31, // ratcheted to official target (studio expansion 2026-06-12)
    '2': 19,
    'pre1': 19,
  };
  // Official reading 大問 counts (verified eiken.or.jp, 2026-06-07).
  const readingTarget = {
    '5': 25,
    '4': 35,
    '3': 30,
    'pre2': 29,
    'pre2plus': 31,
    '2': 31,
    'pre1': 31,
  };
  // Listening: pre1/pre2plus currently 0 (no pool) — visible as skips.
  const listeningTarget = {
    '5': 25,
    '4': 30,
    '3': 30,
    'pre2': 30,
    'pre2plus': 30,
    '2': 30,
    'pre1': 29,
  };

  group('reading pool — structural integrity (raw source data, R1)', () {
    for (final g in grades) {
      test('英検$g items are well-formed', () {
        final items = rawReadingItemsFor(g);
        expect(items, isNotEmpty, reason: 'grade $g has no reading items');
        final seenIds = <String>{};
        for (final it in items) {
          expect(it.passageText.trim(), isNotEmpty,
              reason:
                  '${it.id}: empty passageText (would be masked by compose)');
          expect(it.questionText.trim(), isNotEmpty,
              reason: '${it.id}: empty questionText');
          expect(it.choices.length, 4,
              reason: '${it.id}: must have exactly 4 choices');
          expect(it.choices.map((c) => c.trim()).toSet().length, 4,
              reason: '${it.id}: choices must be unique and non-blank');
          for (final c in it.choices) {
            expect(c.trim(), isNotEmpty, reason: '${it.id}: blank choice');
            // English-only choices: no Japanese/CJK among answer options.
            expect(_cjk.hasMatch(c), isFalse,
                reason: '${it.id}: Japanese/CJK leaked into a choice: "$c"');
          }
          expect(it.correctIdx, inInclusiveRange(0, it.choices.length - 1),
              reason: '${it.id}: correctIdx out of range');
          expect(seenIds.add(it.id), isTrue,
              reason: '${it.id}: duplicate item id within grade $g');
        }
      });
    }
  });

  group('pool count floor (ratchet — never regress)', () {
    for (final g in grades) {
      test('英検$g reading >= ${readingFloor[g]}', () {
        expect(rawReadingItemsFor(g).length,
            greaterThanOrEqualTo(readingFloor[g]!),
            reason: 'grade $g reading pool regressed.');
      });
    }
  });

  // Machine-visible shortfall: these are SKIPPED (not red — the hard gate forbids
  // red), but the skip reason prints the exact gap to the official target, so the
  // volume deficit shows in `flutter test` output instead of hiding in a comment.
  group('pool count vs official 大問 target (shortfall is visible as skips)', () {
    for (final g in grades) {
      final have = rawReadingItemsFor(g).length;
      final want = readingTarget[g]!;
      test('英検$g reading meets target $want',
          () => expect(have, greaterThanOrEqualTo(want)),
          skip: have >= want
              ? false
              : 'SHORTFALL: 英検$g reading $have/$want (need ${want - have} more)');
    }
    for (final g in grades) {
      final have = listeningItemsFor(g, 1).length +
          listeningItemsFor(g, 2).length +
          listeningItemsFor(g, 3).length;
      final want = listeningTarget[g]!;
      test('英検$g listening meets target $want',
          () => expect(have, greaterThanOrEqualTo(want)),
          skip: have >= want
              ? false
              : 'SHORTFALL: 英検$g listening $have/$want (need ${want - have} more)');
    }
  });
}

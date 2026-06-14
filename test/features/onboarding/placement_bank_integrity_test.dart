// Structural integrity gate for the onboarding placement-item bank.
//
// These 35 英検 items decide a child's STARTING GRADE on first launch, so a
// malformed item (out-of-range correctIndex → crash/wrong key, duplicate choice
// → two right answers, a missing rung → a grade that can never be placed) is
// high-stakes. The ANSWER KEYS were content-qa verified clean (2026-06-14); this
// locks the STRUCTURE so a future item can't ship broken. Mirrors the
// reading/listening pool-integrity gates.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/onboarding/placement_item_bank.dart';

void main() {
  // A Japanese glyph among the English answer options = a corrupted item (the
  // child picks from English words). Same guard as the listening bank.
  final cjk = RegExp(r'[぀-ヿ㐀-鿿]');

  group('placement bank integrity', () {
    test('every rung 0..6 has at least one item (all grades placeable)', () {
      final rungs = kPlacementBank.map((i) => i.grade).toSet();
      for (var r = 0; r <= 6; r++) {
        expect(rungs.contains(r), isTrue,
            reason: 'rung $r has no placement item — that grade can never be '
                'tested or placed');
      }
    });

    test('every item is a well-formed 4-choice MCQ with an in-range key', () {
      for (final item in kPlacementBank) {
        final id = '${item.grade}/${item.skill}/${item.stemEn}';
        expect(item.grade, inInclusiveRange(0, 6), reason: '$id: bad grade');
        expect(item.stemEn.trim(), isNotEmpty, reason: '$id: blank stem');
        expect(item.choices.length, 4, reason: '$id: choices=${item.choices}');
        for (final c in item.choices) {
          expect(c.trim(), isNotEmpty, reason: '$id: blank choice');
          expect(cjk.hasMatch(c), isFalse,
              reason: '$id: CJK in an English answer option ("$c")');
        }
        // 4 distinct choices → a single unambiguous answer slot.
        expect(item.choices.map((c) => c.trim()).toSet().length, 4,
            reason:
                '$id: duplicate choice → two right answers: ${item.choices}');
        // correctIndex must point at a real choice.
        expect(item.correctIndex, inInclusiveRange(0, item.choices.length - 1),
            reason: '$id: correctIndex ${item.correctIndex} out of range');
      }
    });

    test('the bank is the expected size (5 items per rung × 7 rungs)', () {
      expect(kPlacementBank.length, 35);
      for (var r = 0; r <= 6; r++) {
        expect(kPlacementBank.where((i) => i.grade == r).length, 5,
            reason: 'rung $r should have 5 items');
      }
    });
  });
}

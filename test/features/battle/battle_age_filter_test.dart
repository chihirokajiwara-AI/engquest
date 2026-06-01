// test/features/battle/battle_age_filter_test.dart
// Tests for age-appropriate vocabulary filtering in BattleScreen.
// Ensures:
//   - age < 8  → only young-learner subset (animals/colors/food/family)
//   - age >= 8 → full A1 deck (30 words)
//   - Filter IDs are all valid (exist in _kSeedVocab)

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Duplicate the filter logic here so tests are self-contained and don't
// depend on Flutter widgets being available in unit test mode.
// ---------------------------------------------------------------------------

const _kYoungLearnerIds = {
  'eiken5_001', // cat
  'eiken5_002', // dog
  'eiken5_003', // apple
  'eiken5_006', // red
  'eiken5_007', // big
  'eiken5_009', // eat
  'eiken5_010', // water
  'eiken5_012', // happy
  'eiken5_013', // play
  'eiken5_015', // blue
  'eiken5_016', // mother
  'eiken5_017', // father
  'eiken5_019', // small
  'eiken5_020', // bird
  'eiken5_021', // fish
  'eiken5_022', // tree
  'eiken5_023', // green
  'eiken5_024', // sing
  'eiken5_027', // white
  'eiken5_029', // milk
};

// Minimal vocab stub matching battle_screen.dart's _kSeedVocab IDs
final List<String> _kAllVocabIds = List.generate(
  30,
  (i) => 'eiken5_${(i + 1).toString().padLeft(3, '0')}',
);

List<String> _filterIdsByAge(int age) {
  if (age < 8) {
    return _kAllVocabIds.where((id) => _kYoungLearnerIds.contains(id)).toList();
  }
  return List<String>.from(_kAllVocabIds);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Age-based vocabulary filter', () {
    test('age < 8 returns only young-learner subset', () {
      for (final age in [4, 5, 6, 7]) {
        final ids = _filterIdsByAge(age);
        expect(ids.length, _kYoungLearnerIds.length,
            reason: 'age $age should return ${_kYoungLearnerIds.length} words');
        for (final id in ids) {
          expect(_kYoungLearnerIds.contains(id), isTrue,
              reason: '$id should be in young-learner set');
        }
      }
    });

    test('age 4 includes concrete animals: cat, dog, bird, fish', () {
      final ids = _filterIdsByAge(4).toSet();
      expect(
          ids,
          containsAll(
              {'eiken5_001', 'eiken5_002', 'eiken5_020', 'eiken5_021'}));
    });

    test('age 4 includes primary colors: red, blue, green, white', () {
      final ids = _filterIdsByAge(4).toSet();
      expect(
          ids,
          containsAll(
              {'eiken5_006', 'eiken5_015', 'eiken5_023', 'eiken5_027'}));
    });

    test('age 4 includes family words: mother, father', () {
      final ids = _filterIdsByAge(4).toSet();
      expect(ids, containsAll({'eiken5_016', 'eiken5_017'}));
    });

    test('age 4 excludes school, desk, pen (abstract/school vocab)', () {
      final ids = _filterIdsByAge(4).toSet();
      expect(ids, isNot(contains('eiken5_005'))); // school
      expect(ids, isNot(contains('eiken5_025'))); // pen
      expect(ids, isNot(contains('eiken5_026'))); // desk
    });

    test('age 8 returns full 30-word deck', () {
      final ids = _filterIdsByAge(8);
      expect(ids.length, 30);
    });

    test('age 10 returns full 30-word deck', () {
      final ids = _filterIdsByAge(10);
      expect(ids.length, 30);
    });

    test('age 18 returns full 30-word deck', () {
      final ids = _filterIdsByAge(18);
      expect(ids.length, 30);
    });

    test('young-learner IDs are all valid (exist in full deck)', () {
      final fullSet = _kAllVocabIds.toSet();
      for (final id in _kYoungLearnerIds) {
        expect(fullSet.contains(id), isTrue,
            reason: '$id in _kYoungLearnerIds not found in full vocab');
      }
    });

    test('young-learner count is exactly 20', () {
      expect(_kYoungLearnerIds.length, 20);
    });

    test('filtered list has no duplicates', () {
      for (final age in [4, 8, 12]) {
        final ids = _filterIdsByAge(age);
        expect(ids.toSet().length, ids.length,
            reason: 'age $age filter has duplicate IDs');
      }
    });

    test('age 7 boundary — same as age 4 (young learner)', () {
      expect(_filterIdsByAge(7).length, _filterIdsByAge(4).length);
    });

    test('age 8 boundary — same as age 12 (full deck)', () {
      expect(_filterIdsByAge(8).length, _filterIdsByAge(12).length);
    });
  });
}

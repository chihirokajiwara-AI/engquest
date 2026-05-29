// test/core/content/vocab_age_filter_test.dart
// ENG Quest — P1.6: Age-appropriate vocabulary filter wiring tests
//
// Verifies the Onboarding → Battle age-filter contract:
//   - age < 8  → restricted young-learner deck (concrete nouns + simple verbs)
//   - age >= 8 → full A1 deck
//   - the age chosen at onboarding maps to the correct deck size
//
// Run: dart test test/core/content/vocab_age_filter_test.dart

import 'package:test/test.dart';
import 'package:engquest/core/content/vocab_age_filter.dart';
import 'package:engquest/data/models/vocab_item.dart';

// Mirror of the BattleScreen seed deck shape (ids only matter for filtering).
List<VocabItem> _buildSeed() => List.generate(
      30,
      (i) {
        final n = (i + 1).toString().padLeft(3, '0');
        return VocabItem(
          id: 'eiken5_$n',
          word: 'w$n',
          reading: 'r$n',
          jpTranslation: 'j$n',
          cefrLevel: 'A1',
          eikenLevel: '5',
          pos: const ['noun'],
          exampleSentences: const ['example.'],
        );
      },
    );

void main() {
  group('filterVocabByAge — young learners (age < 8)', () {
    for (final age in [3, 4, 5, 6, 7]) {
      test('age $age → restricted young-learner deck', () {
        final result = filterVocabByAge(_buildSeed(), age);
        expect(result.length, equals(kYoungLearnerVocabIds.length));
        // Every returned word must be in the young-learner allowlist.
        for (final v in result) {
          expect(kYoungLearnerVocabIds.contains(v.id), isTrue,
              reason: '${v.id} should not appear for age $age');
        }
        // Restricted deck must be strictly smaller than the full deck.
        expect(result.length, lessThan(_buildSeed().length));
      });
    }

    test('isYoungLearner true for age 7, false for age 8', () {
      expect(isYoungLearner(7), isTrue);
      expect(isYoungLearner(8), isFalse);
    });
  });

  group('filterVocabByAge — older learners (age >= 8)', () {
    for (final age in [8, 9, 10, 12, 15]) {
      test('age $age → full deck', () {
        final seed = _buildSeed();
        final result = filterVocabByAge(seed, age);
        expect(result.length, equals(seed.length));
      });
    }
  });

  group('boundary + safety', () {
    test('threshold is exactly 8', () {
      expect(kYoungLearnerAgeThreshold, equals(8));
    });

    test('age 7 deck is a strict subset of age 8 deck', () {
      final young = filterVocabByAge(_buildSeed(), 7).map((v) => v.id).toSet();
      final full = filterVocabByAge(_buildSeed(), 8).map((v) => v.id).toSet();
      expect(young.difference(full), isEmpty);
      expect(full.length, greaterThan(young.length));
    });

    test('returns a fresh list (mutating result does not touch source)', () {
      final seed = _buildSeed();
      final result = filterVocabByAge(seed, 10);
      result.clear();
      expect(seed.length, equals(30));
    });

    test('empty source yields empty deck for any age', () {
      expect(filterVocabByAge(<VocabItem>[], 5), isEmpty);
      expect(filterVocabByAge(<VocabItem>[], 10), isEmpty);
    });
  });

  group('onboarding age → deck mapping (wiring contract)', () {
    // Simulates the value that flows: OnboardingResult.ageYears → childAge →
    // BattleScreen._filterVocabByAge. We assert the chosen age selects the
    // right deck, which is the property the P1.6 fix guarantees on first run.
    test('age picked at onboarding selects matching deck size', () {
      final cases = <int, int>{
        5: kYoungLearnerVocabIds.length, // young learner
        8: 30, // full deck (boundary)
        11: 30, // full deck
      };
      cases.forEach((age, expectedSize) {
        final deck = filterVocabByAge(_buildSeed(), age);
        expect(deck.length, equals(expectedSize),
            reason: 'onboarding age $age should yield $expectedSize words');
      });
    });
  });
}

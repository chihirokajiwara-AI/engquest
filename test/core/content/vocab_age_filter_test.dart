// test/core/content/vocab_age_filter_test.dart
// ENG Quest — Age-appropriate vocabulary filter tests
//
// Verifies the category-based age-filter contract:
//   - age < 8  → only young-learner categories (Animals, Food & Drink, etc.)
//   - age >= 8 → full deck
//
// Run: dart test test/core/content/vocab_age_filter_test.dart

import 'package:test/test.dart';
import 'package:engquest/core/content/vocab_age_filter.dart';
import 'package:engquest/core/models/vocab_item.dart';

// Build a seed with mixed categories: some young-learner, some not.
List<VocabItem> _buildSeed() {
  final youngCategories = ['Animals', 'Food & Drink', 'Family & People', 'Colors & Shapes'];
  final olderCategories = ['School', 'Nature', 'Actions', 'Numbers'];
  final items = <VocabItem>[];

  // 12 young-learner items (3 per category)
  for (var c = 0; c < youngCategories.length; c++) {
    for (var i = 0; i < 3; i++) {
      final idx = c * 3 + i + 1;
      final n = idx.toString().padLeft(3, '0');
      items.add(VocabItem(
        id: 'eiken5_$n',
        word: 'w$n',
        reading: 'r$n',
        jpTranslation: 'j$n',
        cefrLevel: CefrLevel.a1,
        eikenLevel: '5',
        pos: [PartOfSpeech.noun],
        exampleSentences: const ['example.'],
        category: youngCategories[c],
      ));
    }
  }

  // 18 older items (not in young-learner categories)
  for (var c = 0; c < olderCategories.length; c++) {
    for (var i = 0; i < 4; i++) {
      final idx = 13 + c * 4 + i;
      final n = idx.toString().padLeft(3, '0');
      items.add(VocabItem(
        id: 'eiken5_$n',
        word: 'w$n',
        reading: 'r$n',
        jpTranslation: 'j$n',
        cefrLevel: CefrLevel.a1,
        eikenLevel: '5',
        pos: [PartOfSpeech.noun],
        exampleSentences: const ['example.'],
        category: olderCategories[c],
      ));
    }
  }

  // Add remaining to reach 30
  for (var i = items.length; i < 30; i++) {
    final n = (i + 1).toString().padLeft(3, '0');
    items.add(VocabItem(
      id: 'eiken5_$n',
      word: 'w$n',
      reading: 'r$n',
      jpTranslation: 'j$n',
      cefrLevel: CefrLevel.a1,
      eikenLevel: '5',
      pos: [PartOfSpeech.noun],
      exampleSentences: const ['example.'],
      category: 'Numbers',
    ));
  }

  return items;
}

void main() {
  group('filterVocabByAge — young learners (age < 8)', () {
    for (final age in [3, 4, 5, 6, 7]) {
      test('age $age → restricted young-learner deck', () {
        final result = filterVocabByAge(_buildSeed(), age);
        // Should only contain items from young-learner categories
        expect(result.length, equals(12));
        for (final v in result) {
          expect(kYoungLearnerCategories.contains(v.category), isTrue,
              reason: '${v.id} (${v.category}) should not appear for age $age');
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
    test('age picked at onboarding selects matching deck size', () {
      final cases = <int, int>{
        5: 12, // young learner (4 categories × 3 items)
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

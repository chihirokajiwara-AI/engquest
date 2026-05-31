// test/data/content/vocab_a2_test.dart
// Tests for A2 vocabulary data integrity and level selection logic.

import 'package:test/test.dart';
import 'package:engquest/data/content/vocab_a1.dart';
import 'package:engquest/data/content/vocab_a2.dart';


void main() {
  group('A2 vocabulary data integrity', () {
    test('contains exactly 300 words', () {
      expect(kSeedVocabA2.length, 300);
    });

    test('all IDs are unique', () {
      final ids = kSeedVocabA2.map((v) => v.id).toSet();
      expect(ids.length, 300);
    });

    test('all words are unique', () {
      final words = kSeedVocabA2.map((v) => v.word.toLowerCase()).toSet();
      expect(words.length, 300);
    });

    test('all IDs follow eiken4_NNN format', () {
      for (final v in kSeedVocabA2) {
        expect(v.id, matches(RegExp(r'^eiken4_\d{3}$')),
            reason: '${v.id} does not match eiken4_NNN format');
      }
    });

    test('IDs are sequential from 001 to 300', () {
      for (var i = 0; i < 300; i++) {
        final expected = 'eiken4_${(i + 1).toString().padLeft(3, '0')}';
        expect(kSeedVocabA2[i].id, expected);
      }
    });

    test('all entries have cefrLevel A2', () {
      for (final v in kSeedVocabA2) {
        expect(v.cefrLevel, 'A2', reason: '${v.word} has wrong cefrLevel');
      }
    });

    test('all entries have eikenLevel 4', () {
      for (final v in kSeedVocabA2) {
        expect(v.eikenLevel, '4', reason: '${v.word} has wrong eikenLevel');
      }
    });

    test('all entries have non-empty fields', () {
      for (final v in kSeedVocabA2) {
        expect(v.word.isNotEmpty, isTrue, reason: '${v.id} has empty word');
        expect(v.reading.isNotEmpty, isTrue, reason: '${v.id} has empty reading');
        expect(v.jpTranslation.isNotEmpty, isTrue,
            reason: '${v.id} has empty jpTranslation');
        expect(v.pos.isNotEmpty, isTrue, reason: '${v.id} has empty pos');
        expect(v.exampleSentences.isNotEmpty, isTrue,
            reason: '${v.id} has empty exampleSentences');
      }
    });

    test('all pos values are valid', () {
      const validPos = {
        'noun', 'verb', 'adjective', 'adverb', 'preposition',
        'conjunction', 'pronoun', 'interjection', 'phrase',
      };
      for (final v in kSeedVocabA2) {
        for (final p in v.pos) {
          expect(validPos.contains(p), isTrue,
              reason: '${v.word} has invalid pos: $p');
        }
      }
    });

    test('no overlap with A1 word IDs', () {
      final a1Ids = kSeedVocabA1.map((v) => v.id).toSet();
      final a2Ids = kSeedVocabA2.map((v) => v.id).toSet();
      expect(a1Ids.intersection(a2Ids), isEmpty);
    });

    test('no overlap with A1 words', () {
      final a1Words = kSeedVocabA1.map((v) => v.word.toLowerCase()).toSet();
      final a2Words = kSeedVocabA2.map((v) => v.word.toLowerCase()).toSet();
      final overlap = a1Words.intersection(a2Words);
      expect(overlap, isEmpty,
          reason: 'Words appearing in both A1 and A2: $overlap');
    });
  });

  group('A1 vocabulary data integrity', () {
    test('contains exactly 30 words', () {
      expect(kSeedVocabA1.length, 30);
    });

    test('all entries have cefrLevel A1', () {
      for (final v in kSeedVocabA1) {
        expect(v.cefrLevel, 'A1');
      }
    });

    test('all entries have eikenLevel 5', () {
      for (final v in kSeedVocabA1) {
        expect(v.eikenLevel, '5');
      }
    });
  });
}

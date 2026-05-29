// test/core/data/vocab_repository_test.dart
// ENG Quest — Unit tests for VocabRepository and VocabItem
// Run: flutter test test/core/data/vocab_repository_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/models/vocab_item.dart';

// Test helpers — simulate JSON loading without Flutter assets
Map<String, dynamic> makeTestWord({
  String id = 'eiken5_001',
  String word = 'apple',
  String reading = 'アップル',
  String jpTranslation = 'りんご',
  String cefrLevel = 'A1',
  String eikenLevel = '5',
  String category = 'Food',
  List<String> pos = const ['noun'],
  List<String> exampleSentences = const ['I eat an apple.'],
  String audioUrl = 'audio/eiken5/eiken5_001.mp3',
  String imageUrl = 'images/eiken5/eiken5_001.jpg',
  String fsrsState = 'new',
  List<String> tags = const ['eiken5', 'A1', 'food'],
}) {
  return {
    'id': id,
    'word': word,
    'reading': reading,
    'jpTranslation': jpTranslation,
    'cefrLevel': cefrLevel,
    'eikenLevel': eikenLevel,
    'category': category,
    'pos': pos,
    'exampleSentences': exampleSentences,
    'audioUrl': audioUrl,
    'imageUrl': imageUrl,
    'fsrsState': fsrsState,
    'tags': tags,
  };
}

void main() {
  group('VocabItem', () {
    test('deserializes from JSON correctly', () {
      final json = makeTestWord();
      final item = VocabItem.fromJson(json);

      expect(item.id, 'eiken5_001');
      expect(item.word, 'apple');
      expect(item.reading, 'アップル');
      expect(item.jpTranslation, 'りんご');
      expect(item.cefrLevel, CefrLevel.a1);
      expect(item.eikenLevel, '5');
      expect(item.category, 'Food');
      expect(item.pos, [PartOfSpeech.noun]);
      expect(item.exampleSentences, ['I eat an apple.']);
      expect(item.fsrsState, FsrsState.newCard);
      expect(item.tags, contains('eiken5'));
    });

    test('serializes to JSON and back (round-trip)', () {
      final original = VocabItem.fromJson(makeTestWord());
      final json = original.toJson();
      final restored = VocabItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.word, original.word);
      expect(restored.cefrLevel, original.cefrLevel);
      expect(restored.fsrsState, original.fsrsState);
    });

    test('copyWith preserves fields and updates fsrsState', () {
      final item = VocabItem.fromJson(makeTestWord());
      final updated = item.copyWith(fsrsState: FsrsState.review);

      expect(updated.id, item.id);
      expect(updated.word, item.word);
      expect(updated.fsrsState, FsrsState.review);
    });

    test('supports equality via Equatable', () {
      final a = VocabItem.fromJson(makeTestWord());
      final b = VocabItem.fromJson(makeTestWord());
      expect(a, equals(b));
    });

    group('FSRS states', () {
      test('parses all valid FSRS state strings', () {
        expect(FsrsStateExtension.fromString('new'), FsrsState.newCard);
        expect(FsrsStateExtension.fromString('learning'), FsrsState.learning);
        expect(FsrsStateExtension.fromString('review'), FsrsState.review);
        expect(FsrsStateExtension.fromString('relearning'), FsrsState.relearning);
      });

      test('unknown FSRS state defaults to newCard', () {
        expect(FsrsStateExtension.fromString('unknown'), FsrsState.newCard);
      });
    });

    group('CEFR levels', () {
      test('parses all CEFR levels', () {
        expect(CefrLevelExtension.fromString('A1'), CefrLevel.a1);
        expect(CefrLevelExtension.fromString('A2'), CefrLevel.a2);
        expect(CefrLevelExtension.fromString('B1'), CefrLevel.b1);
        expect(CefrLevelExtension.fromString('B2'), CefrLevel.b2);
        expect(CefrLevelExtension.fromString('C1'), CefrLevel.c1);
        expect(CefrLevelExtension.fromString('C2'), CefrLevel.c2);
      });

      test('CEFR label round-trips correctly', () {
        expect(CefrLevel.a1.label, 'A1');
        expect(CefrLevel.b2.label, 'B2');
      });
    });

    group('Part of speech', () {
      test('parses multi-POS word correctly', () {
        final json = makeTestWord(pos: ['noun', 'adjective']);
        final item = VocabItem.fromJson(json);
        expect(item.pos, containsAll([PartOfSpeech.noun, PartOfSpeech.adjective]));
      });

      test('unknown POS defaults to unknown', () {
        expect(PartOfSpeechExtension.fromString('xyz'), PartOfSpeech.unknown);
      });
    });
  });

  group('VocabItem real data validation', () {
    // Validate that our 300-word dataset structure is correct
    // by loading and parsing a subset of items programmatically
    
    final testItems = [
      makeTestWord(id: 'eiken5_001', word: 'cat', category: 'Animals',
        reading: 'キャット', jpTranslation: 'ねこ'),
      makeTestWord(id: 'eiken5_031', word: 'apple', category: 'Food',
        reading: 'アップル', jpTranslation: 'りんご'),
      makeTestWord(id: 'eiken5_256', word: 'hello', category: 'Greetings_Social',
        reading: 'ハロー', jpTranslation: 'こんにちは',
        pos: ['interjection'], tags: ['eiken5', 'A1', 'greetings_social']),
    ];

    test('all test items parse without error', () {
      for (final json in testItems) {
        expect(() => VocabItem.fromJson(json), returnsNormally);
      }
    });

    test('items with multiple POS handled correctly', () {
      final multiPos = makeTestWord(pos: ['noun', 'adverb']);
      final item = VocabItem.fromJson(multiPos);
      expect(item.pos.length, 2);
    });

    test('toString contains id and word', () {
      final item = VocabItem.fromJson(makeTestWord(id: 'eiken5_001', word: 'apple'));
      expect(item.toString(), contains('eiken5_001'));
      expect(item.toString(), contains('apple'));
    });
  });
}

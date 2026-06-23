// test/features/exam_practice/distractor_generator_test.dart
// Locks the #76 anti-leak guarantees: the generated distractors can never make
// the answer the trivial first-letter odd-one-out, never inject a phrase, never
// repeat a synonym, and never echo a word from the sentence.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/models/vocab_item.dart';
import 'package:engquest/features/exam_practice/distractor_generator.dart';

VocabItem w(
  String word, {
  PartOfSpeech pos = PartOfSpeech.noun,
  String jp = '',
  String category = 'general',
}) =>
    VocabItem(
      id: 'id_$word',
      word: word,
      reading: '',
      jpTranslation: jp.isEmpty ? 'JP_$word' : jp,
      cefrLevel: CefrLevel.a1,
      eikenLevel: '5',
      category: category,
      pos: [pos],
      exampleSentences: const [],
    );

void main() {
  final rng = Random(42);

  group('buildAntiLeakDistractors (#76)', () {
    test('all distractors share the answer first letter (no odd-one-out leak)',
        () {
      final answer = w('borrow', pos: PartOfSpeech.verb);
      final bank = [
        answer,
        w('bring', pos: PartOfSpeech.verb),
        w('build', pos: PartOfSpeech.verb),
        w('break', pos: PartOfSpeech.verb),
        w('buy', pos: PartOfSpeech.verb),
        // wrong-initial decoys that must NEVER be chosen
        w('catch', pos: PartOfSpeech.verb),
        w('drive', pos: PartOfSpeech.verb),
      ];
      final d = buildAntiLeakDistractors(answer, 'Can I ___ a pen?', bank, rng);
      expect(d, isNotNull);
      expect(d!.length, 3);
      for (final x in d) {
        expect(x[0].toLowerCase(), 'b',
            reason: 'distractor "$x" must share the answer initial');
      }
    });

    test('never returns the answer itself, a phrase, or a same-initial synonym',
        () {
      final answer = w('big', pos: PartOfSpeech.adjective, jp: '大きい');
      final bank = [
        answer,
        w('big', pos: PartOfSpeech.adjective, jp: '大きい'), // dup of answer
        w('bright', pos: PartOfSpeech.adjective, jp: '明るい'),
        w('busy', pos: PartOfSpeech.adjective, jp: '忙しい'),
        w('brave', pos: PartOfSpeech.adjective, jp: '勇敢な'),
        w('large',
            pos: PartOfSpeech.adjective,
            jp: '大きい'), // synonym (wrong init anyway)
        w('big city', pos: PartOfSpeech.adjective, jp: '大都市'), // phrase
      ];
      final d = buildAntiLeakDistractors(answer, 'The dog is ___.', bank, rng);
      expect(d, isNotNull);
      expect(d!, isNot(contains('big')));
      expect(d.any((x) => x.contains(' ')), isFalse,
          reason: 'no multi-word phrase distractors');
      // jpTranslation overlap with the answer is excluded as a synonym risk.
      expect(d, isNot(contains('large')));
    });

    test('never echoes a word already visible in the sentence', () {
      final answer = w('apple', jp: 'りんご');
      final bank = [
        answer,
        w('arm', jp: '腕'),
        w('animal', jp: '動物'),
        w('answer', jp: '答え'),
        w('autumn', jp: '秋'),
      ];
      // "arm" appears in the sentence → must be filtered out.
      final d = buildAntiLeakDistractors(
          answer, 'She has an apple in her arm.', bank, rng);
      expect(d, isNotNull);
      expect(d!, isNot(contains('arm')));
    });

    test('requires the same part of speech', () {
      final answer = w('run', pos: PartOfSpeech.verb);
      final bank = [
        answer,
        w('rabbit', pos: PartOfSpeech.noun),
        w('river', pos: PartOfSpeech.noun),
        w('red', pos: PartOfSpeech.adjective),
        w('reach', pos: PartOfSpeech.verb),
        w('rise', pos: PartOfSpeech.verb),
        w('relax', pos: PartOfSpeech.verb),
      ];
      final d = buildAntiLeakDistractors(answer, 'I ___ fast.', bank, rng);
      expect(d, isNotNull);
      for (final x in d!) {
        final match = bank.firstWhere((v) => v.word == x);
        expect(match.pos.contains(PartOfSpeech.verb), isTrue);
      }
    });

    test('rejects underscore-joined multiword keys as distractors', () {
      final answer = w('parrot', jp: 'オウム');
      final bank = [
        answer,
        w('physical_education', jp: '体育'), // underscore key → must be excluded
        w('pencil', jp: '鉛筆'),
        w('picture', jp: '絵'),
        w('plant', jp: '植物'),
      ];
      final d = buildAntiLeakDistractors(
          answer, 'The ___ repeated the word.', bank, rng);
      expect(d, isNotNull);
      expect(d!.any((x) => x.contains('_')), isFalse);
    });

    test(
        'excludes ultra-generic confusables (standard/today/there) as distractors',
        () {
      final answer = w('sequential', pos: PartOfSpeech.adjective, jp: '順序立てた');
      final bank = [
        answer,
        w('standard',
            pos: PartOfSpeech.adjective, jp: '標準的な'), // generic → excluded
        w('suburban', pos: PartOfSpeech.adjective, jp: '郊外の'),
        w('symbolic', pos: PartOfSpeech.adjective, jp: '象徴的な'),
        w('synthetic', pos: PartOfSpeech.adjective, jp: '合成の'),
      ];
      final d = buildAntiLeakDistractors(
          answer, 'Tasks appear in ___ order here.', bank, rng);
      expect(d, isNotNull);
      expect(d!, isNot(contains('standard')));
    });

    test('a generic word is still allowed AS the answer (kept practiceable)',
        () {
      // The stoplist only blocks generic words as DISTRACTORS, never the answer.
      final answer = w('standard', pos: PartOfSpeech.noun, jp: '基準');
      final bank = [
        answer,
        w('signal', pos: PartOfSpeech.noun, jp: '信号'),
        w('subject', pos: PartOfSpeech.noun, jp: '科目'),
        w('surface', pos: PartOfSpeech.noun, jp: '表面'),
        w('symbol', pos: PartOfSpeech.noun, jp: '記号'),
      ];
      final d =
          buildAntiLeakDistractors(answer, 'It sets a high ___.', bank, rng);
      expect(d, isNotNull);
      expect(d!.length, 3);
    });

    test('returns null when fewer than three clean candidates exist', () {
      final answer = w('zebra');
      final bank = [
        answer,
        w('zone'), // only one same-initial peer
        w('apple'),
        w('cat'),
      ];
      final d = buildAntiLeakDistractors(answer, 'A ___ runs.', bank, rng);
      expect(d, isNull);
    });

    // Word-boundary (not raw-substring) sentence filter:
    test('a distractor that is only a SUBSTRING of a sentence word is kept',
        () {
      // Old raw .contains() rejected "add" for being inside "ladder", silently
      // draining a valid distractor → the item got skipped. \b-matching keeps it.
      final answer = w('act', pos: PartOfSpeech.verb);
      final bank = [
        answer,
        w('add', pos: PartOfSpeech.verb),
        w('aim', pos: PartOfSpeech.verb),
        w('ask', pos: PartOfSpeech.verb),
      ];
      final d = buildAntiLeakDistractors(
          answer, 'We had a ladder here.', bank, Random(1));
      expect(d, isNotNull,
          reason:
              '"add" is a substring of "ladder", not a whole word — keep it');
      expect(d!, contains('add'));
      expect(d, hasLength(3));
    });

    test('a WHOLE-WORD match in the sentence is still rejected', () {
      // The primary rule holds: a word literally present in the sentence is out.
      final answer = w('act', pos: PartOfSpeech.verb);
      final bank = [
        answer,
        w('add', pos: PartOfSpeech.verb),
        w('aim', pos: PartOfSpeech.verb),
        w('ask', pos: PartOfSpeech.verb),
      ];
      final d = buildAntiLeakDistractors(
          answer, 'Please add the numbers.', bank, Random(1));
      expect(d, isNull,
          reason: '"add" is a whole word here → excluded → <3 left → null');
    });

    test('an answer with an unknown POS is skipped (no cross-POS distractors)',
        () {
      final answer = w('alpha', pos: PartOfSpeech.unknown);
      final bank = [
        answer,
        w('apple', pos: PartOfSpeech.unknown),
        w('arrow', pos: PartOfSpeech.unknown),
        w('angle', pos: PartOfSpeech.unknown),
      ];
      final d =
          buildAntiLeakDistractors(answer, 'An ___ value.', bank, Random(1));
      expect(d, isNull,
          reason: 'unknown answer POS would match any unknown-tagged word');
    });
  });
}

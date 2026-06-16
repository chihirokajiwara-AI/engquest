// #85: the battle card front frames each review as rescuing a word from the
// サイレント (the world's premise), varied by part-of-speech so it never reads as
// one repeated stock line. Pure function — locked here.
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/core/models/vocab_item.dart';

void main() {
  test('every POS line names the サイレント premise', () {
    for (final pos in PartOfSpeech.values) {
      final line = silentRescueLineJa(pos);
      expect(line, contains('サイレント'),
          reason: '$pos must tie the review to the world premise');
      expect(line, contains('うばわれた'));
    }
  });

  test('POS varies the framing (not one stock line)', () {
    expect(silentRescueLineJa(PartOfSpeech.verb), contains('うごき'));
    expect(silentRescueLineJa(PartOfSpeech.adjective), contains('ようす'));
    expect(silentRescueLineJa(PartOfSpeech.number), contains('かず'));
    expect(silentRescueLineJa(PartOfSpeech.noun), contains('なまえ'));
    // At least 3 distinct lines across the common POS set.
    final distinct = {
      for (final p in [
        PartOfSpeech.verb,
        PartOfSpeech.adjective,
        PartOfSpeech.number,
        PartOfSpeech.noun,
        PartOfSpeech.pronoun,
      ])
        silentRescueLineJa(p)
    };
    expect(distinct.length, greaterThanOrEqualTo(3));
  });
}

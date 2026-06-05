// Quiz line/option audio slugging: keys must be deterministic and match what
// tool/dump_quiz_audio.dart names the files; cloze blanks must NOT leak into the
// spoken text's word content, and non-speakable lines must resolve to null
// (stay silent) rather than voicing a stage direction.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/quest_data.dart';
import 'package:engquest/features/quest/quest_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  group('quizAudioKey', () {
    test('complete question → stable slug', () {
      expect(quizAudioKey('How are you?'), 'how_are_you');
      expect(quizAudioKey("I'm fine, thank you."), 'i_m_fine_thank_you');
    });

    test('cloze blank is dropped from the slug (audio renders it as a gap)', () {
      expect(quizAudioKey('You ___ a traveller. Welcome.'), 'you_a_traveller_welcome');
    });

    test('stage directions in (parens) are stripped', () {
      expect(quizAudioKey('(pointing far away) What is that on the hill?'),
          'what_is_that_on_the_hill');
    });

    test('non-speakable lines resolve to null (stay silent)', () {
      expect(quizAudioKey('... ... (A small slime opens its mouth, but no word comes out.)'),
          isNull);
      expect(quizAudioKey('   '), isNull);
    });

    test('asset path wraps the slug under audio/quiz/', () {
      expect(quizAudioAsset('Hello!'), 'audio/quiz/hello.mp3');
      expect(quizAudioAsset('...'), isNull);
    });
  });

  testWidgets('grammar quiz renders self-voicing option buttons + question replay',
      (tester) async {
    // The first voiced 応答型 quiz ("How are you?") in town_eiken5.
    final idx = kQuestTowns[0]
        .encounters
        .indexWhere((s) => s is QuestEncounter && s.autoPlayAudio != null);
    expect(idx, greaterThan(0));
    await tester.pumpWidget(MaterialApp(
      home: QuestScreen(town: kQuestTowns[0], previewEncounterIndex: idx),
    ));
    await tester.pump();

    // Every answer option is an AudioOptionButton (tap to hear), not a plain
    // DqChoice — so a child can audition each English reply.
    expect(find.byType(AudioOptionButton), findsNWidgets(4));
    // The English question has a 🔊 replay button.
    expect(find.byType(DqReplayButton), findsOneWidget);
  });
}

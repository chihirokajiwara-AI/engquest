// Emits the quiz-audio manifest for scripts/generate_quiz_audio.py.
//
// For each QuestEncounter in a town it lists the spoken English line and every
// answer option, keyed by the SAME slug the runtime uses (quizAudioKey) so the
// generated assets/audio/quiz/<key>.mp3 always resolve. The line keeps its `___`
// cloze blank so the generator can render it as an audible gap (no answer leak).
//
// Usage:
//   dart run tool/dump_quiz_audio.dart            # 英検5級 (town 0)
//   dart run tool/dump_quiz_audio.dart --all      # every town
//
// Output: a JSON array of {key, text} on stdout. dart:io is fine here — this is
// a build-time tool, NOT web app code.

import 'dart:convert';
import 'dart:io';

import 'package:engquest/features/quest/quest_data.dart';

void main(List<String> args) {
  final all = args.contains('--all');
  final towns = all ? kQuestTowns : [kQuestTowns.first];

  final byKey = <String, String>{};
  void add(String text) {
    final key = quizAudioKey(text);
    if (key == null) return;
    byKey[key] = quizSpeakableText(text); // keeps `___` for the gap
  }

  for (final town in towns) {
    for (final step in town.encounters) {
      if (step is QuestEncounter) {
        add(step.npcLine);
        for (final c in step.choices) {
          add(c);
        }
      }
    }
  }

  final list = byKey.entries.map((e) => {'key': e.key, 'text': e.value}).toList();
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(list));
  stderr.writeln('[dump_quiz_audio] ${list.length} clips for '
      '${towns.length} town(s)${all ? " (all)" : " (英検5級)"}');
}

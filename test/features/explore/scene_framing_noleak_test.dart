// Durable guard against pre-quiz answer leaks in scene framing/clue text.
//
// A scene hotspot shows `framingJa` (scene-setting) and `clueLineJa` (NPC line)
// BEFORE its ナゾ quiz. If either names the correct answer, the child can pick it
// without reasoning — the retrieval practice is defeated. This was a real bug:
// the 準1 (resilience/carry-out) and 4級/3級 (will/yet/for) framings literally
// named the answer ("現在完了の for", "= resilience を えらべ"). After fixing each,
// this test locks the invariant scene-wide so the leak class cannot return.
//
// Scope: English single-token answers (where the leaks were) checked with word
// boundaries to avoid false positives (e.g. "for" inside "before"); slash-choice
// answers ("carry / out") are normalised to "carry out". The quiz SENTENCE quoted
// in framing carries a blank ("___"), not the answer, so it never trips this.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/quest/quest_data.dart';

void main() {
  test('no scene framing/clue text leaks its quiz answer (word-boundary)', () {
    var checked = 0;
    final leaks = <String>[];

    kScenesByGrade.forEach((grade, scene) {
      for (final hs in scene.hotspots) {
        final step = hs.step;
        if (step is! QuestEncounter) continue;
        final answerRaw = step.choices[step.correctIndex];
        // Normalise slash choices ("carry / out" -> "carry out").
        final answer = answerRaw.replaceAll(RegExp(r'\s*/\s*'), ' ').trim();
        if (answer.isEmpty) continue;

        for (final field in [hs.framingJa, hs.clueLineJa]) {
          if (field == null) continue;
          checked++;
          // ASCII word-boundary, case-insensitive. Only meaningful for answers
          // that contain ASCII letters (the English target words).
          if (!RegExp(r'[a-zA-Z]').hasMatch(answer)) continue;
          final pattern = RegExp(
            r'\b' + RegExp.escape(answer) + r'\b',
            caseSensitive: false,
          );
          if (pattern.hasMatch(field)) {
            leaks.add('grade $grade: "$answer" appears in framing/clue:\n'
                '    ${field.replaceAll("\n", " ").trim()}');
          }
        }
      }
    });

    expect(checked, greaterThan(0),
        reason: 'guard must exercise real scene framing/clue text');
    expect(leaks, isEmpty,
        reason: 'pre-quiz framing/clue must NEVER name the answer:\n'
            '${leaks.join("\n")}');
  });
}

// Gate: every 英検 listening item must be a well-formed 4-choice MCQ.
//
// The listening bank is the largest hand-authored content set (204 items across
// 7 grades). It had a 解説-coverage gate (listening_explanation_coverage_test)
// but NO structural-integrity gate — so a corrupted answer key (correctIndex out
// of range), a blank choice, or a DUPLICATE choice (which silently creates two
// "correct" answers once the runtime shuffles them) would ship undetected. That
// is exactly the bug class that once corrupted thousands of vocab distractors.
// This locks the invariants the screen relies on; a scan of the live bank passes
// it today, so this is a regression guard, not a fix.
//
// Choice count is asserted at 4: every listening part (第1部/第2部/第3部) across
// every grade currently uses 4 options (verified empirically). If a future part
// legitimately needs 3, relax this per-part — do not silently widen it.
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';

void main() {
  // CJK = listening answer options are spoken English; a Japanese glyph among
  // them signals a content-pipeline corruption (gloss leaked into an option).
  final cjk = RegExp(r'[぀-ヿ㐀-䶿一-鿿ｦ-ﾟ]');

  // A question that refers to a speaker's gender ("the woman / 女性", "the man /
  // 男性") is only answerable from audio if the clip actually has two distinct-
  // gender speakers — the pipeline voices Speaker-A female / Speaker-B male, so a
  // single-voice clip conveys no gender. Guards the authoring contract documented
  // in listening_data.dart's header against a future single-speaker gender item.
  final genderRef =
      RegExp(r'女性|女の人|男性|男の人|woman|\bman\b', caseSensitive: false);

  // Iterate the live map so a newly-added grade is covered automatically.
  for (final entry in kListeningItems.entries) {
    final grade = entry.key;
    final items = entry.value;

    test('英検$grade listening items are well-formed 4-choice MCQs', () {
      expect(items, isNotEmpty, reason: 'grade $grade has no listening items');
      final seenKeys = <String>{};
      for (final it in items) {
        final id = '$grade/${it.audioKey}';

        expect(it.question.trim(), isNotEmpty, reason: '$id: blank question');

        // Exactly 4 distinct, non-empty, English choices.
        expect(it.choices.length, 4, reason: '$id: choices=${it.choices}');
        for (final c in it.choices) {
          expect(c.trim(), isNotEmpty, reason: '$id: blank choice');
          expect(cjk.hasMatch(c), isFalse,
              reason: '$id: CJK in an answer option ("$c")');
        }
        expect(it.choices.map((c) => c.trim()).toSet().length, 4,
            reason: '$id: duplicate choice (would create two right answers) '
                '-> ${it.choices}');

        // Answer key must point at a real choice.
        expect(it.correctIndex, inInclusiveRange(0, it.choices.length - 1),
            reason: '$id: correctIndex ${it.correctIndex} out of range');

        // The screen plays this audio — it must be present.
        expect(it.audioKey.trim(), isNotEmpty, reason: '$id: blank audioKey');
        expect(seenKeys.add(it.audioKey), isTrue,
            reason: '$id: duplicate audioKey within grade $grade');

        // Transcript is what the (TTS) audio is generated from — non-empty.
        final liveLines =
            it.transcripts.where((t) => t.trim().isNotEmpty).toList();
        expect(liveLines, isNotEmpty, reason: '$id: no transcript lines');

        // A gender-referencing question must be a ≥2-speaker dialogue, or the
        // audio cannot convey which speaker is meant (single voice = no gender).
        if (genderRef.hasMatch(it.question)) {
          expect(liveLines.length, greaterThanOrEqualTo(2),
              reason: '$id: question references a speaker gender '
                  '("${it.question}") but the clip has only ${liveLines.length} '
                  'transcript line(s) — gender is not conveyable by a single voice');
        }
      }
    });
  }
}

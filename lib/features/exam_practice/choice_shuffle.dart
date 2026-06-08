// lib/features/exam_practice/choice_shuffle.dart
// Randomise an MCQ's answer position to kill positional answer-key bias.
//
// Several authored 大問 pools cluster the correct answer at one slot (conversation
// = 92% choice 1; reading = 93% choice 2/3). A child could then score high by
// always tapping the same position, inflating the 合格率 readiness meter with no
// real comprehension. Shuffling each item's choices at load time removes the tell.

import 'dart:math';

/// Returns [choices] in a random order plus the new index of the answer that was
/// at [correctIdx]. The answer string is preserved — only its position moves.
({List<String> choices, int correctIdx}) shuffledChoiceSet(
    List<String> choices, int correctIdx, Random rng) {
  final order = List<int>.generate(choices.length, (i) => i)..shuffle(rng);
  return (
    choices: [for (final i in order) choices[i]],
    correctIdx: order.indexOf(correctIdx),
  );
}

// Locks the formative StubPronunciationScorer tiers (二次 speaking practice).
// The score is an HONEST practice guide (not the real human-scored interview),
// but it must still REWARD a child who reads clearly more than one who reads
// half — a flat ceiling gives no encouragement for excellence (the engagement
// spine). Added the 0.9 "excellent" tier (flaw-hunt 2026-06-14).

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/speaking/pronunciation_scorer.dart';

void main() {
  const scorer = StubPronunciationScorer();

  SpeakingScore run(String reference, String transcript) => scorer.score(
        referenceText: reference,
        transcript: transcript,
        eikenGrade: '3',
      );

  const reference = 'I like to play soccer with my friends after school';

  test('empty transcript → 0.0 + attitude coach', () {
    final s = run(reference, '   ');
    expect(s.score, 0.0);
    expect(s.showAttitudeCoach, isTrue);
  });

  test('very short (< 3 words) → 0.35', () {
    final s = run(reference, 'I like');
    expect(s.score, 0.35);
  });

  test('a near-complete read earns the excellent tier (0.9)', () {
    // Says essentially all the reference words → should be celebrated, not
    // capped at the same 0.75 as a half-read.
    final s =
        run(reference, 'I like to play soccer with my friends after school');
    expect(s.score, 0.9, reason: 'a clear, complete read must be rewarded');
    expect(s.feedbackEn.toLowerCase(), contains('excellent'));
  });

  test('half coverage → 0.75', () {
    // ~50% of the 10 reference words.
    final s = run(reference, 'I like play soccer my');
    expect(s.score, 0.75);
  });

  test('low coverage → 0.5', () {
    final s = run(reference, 'um maybe something different entirely here');
    expect(s.score, 0.5);
  });

  test('MONOTONIC: a fuller read never scores lower than a partial one', () {
    final full = run(reference, reference).score;
    final half = run(reference, 'I like play soccer my').score;
    final low =
        run(reference, 'um maybe something different entirely here').score;
    expect(full, greaterThan(half));
    expect(half, greaterThan(low));
  });
}

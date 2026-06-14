// lib/features/speaking/pronunciation_scorer.dart
// A-KEN Quest — 英検 二次 Pronunciation Scorer interface + stub implementation.
//
// Architecture:
//   PronunciationScorer  — pure Dart interface; the real Azure Pronunciation
//                          Assessment implementation drops in here without any
//                          UI changes (strategy pattern).
//   StubPronunciationScorer — formative-feedback stub used until the Azure
//                             backend /v1/pronounce endpoint is wired (TODO).
//
// IMPORTANT:  Scores must NEVER be used as hard pass/fail verdicts.
// See ASR-SPEAKING-RESEARCH.json §biggestRisk: no published WER benchmark
// exists for Japanese children speaking L2 English; treat all output as
// FORMATIVE coaching only — encourage first, correct second.
//
// To wire Azure later:
//   1. Implement AzurePronunciationScorer : PronunciationScorer
//      — POST /v1/pronounce on the existing VPS proxy (Stripe+Claude server)
//      — pass audioBytes (16 kHz mono WAV) + referenceText + grade
//      — receive Azure structured JSON → Haiku rubric mapping.
//   2. Inject AzurePronunciationScorer into SpeakingScreen in exam_practice_screen.dart.

/// A single scored item: the child spoke [referenceText] and got back
/// [feedback] with a [score] in [0.0, 1.0].
class SpeakingScore {
  /// The text the child was asked to read or respond to.
  final String referenceText;

  /// The transcript captured (may be empty if the child was silent).
  final String transcript;

  /// Formative quality band in [0.0, 1.0].
  /// 0.0 = no speech detected, 1.0 = excellent.
  /// MUST be treated as coaching guidance, not a pass/fail threshold.
  final double score;

  /// Child-friendly Japanese feedback sentence shown in the UI.
  final String feedbackJa;

  /// Optional English coaching note (shown smaller, for older learners).
  final String feedbackEn;

  /// Whether the アティチュード coach should be shown (silence detected).
  final bool showAttitudeCoach;

  const SpeakingScore({
    required this.referenceText,
    required this.transcript,
    required this.score,
    required this.feedbackJa,
    required this.feedbackEn,
    this.showAttitudeCoach = false,
  });
}

/// Interface for pronunciation/speaking scoring.
///
/// Implementations:
///   StubPronunciationScorer  — formative stub (current, no network)
///   AzurePronunciationScorer — TODO: real Azure via /v1/pronounce proxy
abstract class PronunciationScorer {
  /// Score the child's [transcript] against [referenceText] for [eikenGrade].
  ///
  /// [eikenGrade] is one of '3', 'pre2', '2', 'pre1' — used to adjust the
  /// scoring leniency (lower grades = more encouragement per Azure guidance).
  ///
  /// Returns a [SpeakingScore] with formative feedback.
  SpeakingScore score({
    required String referenceText,
    required String transcript,
    required String eikenGrade,
  });
}

// ── Stub implementation ───────────────────────────────────────────────────────

/// Formative stub scorer.
///
/// STUB BEHAVIOUR (no network, no Azure):
///   - Empty transcript → score 0.0, アティチュード coach triggered.
///   - Very short transcript (< 3 words) → score 0.35, gentle retry.
///   - Transcript covers ≥ 85 % of reference words → score 0.9, excellent praise.
///   - Transcript covers ≥ 50 % of reference words → score 0.75, encouragement.
///   - Otherwise → score 0.5, coaching.
///
/// All messages are intentionally positive/formative — the research finding is
/// that no JP-child benchmark exists, so we must bias lenient and never scold.
///
/// TODO: Replace with AzurePronunciationScorer once the Azure account and the
///       backend /v1/pronounce endpoint are set up.  The UI (SpeakingScreen)
///       calls only the interface and needs no changes.
class StubPronunciationScorer implements PronunciationScorer {
  const StubPronunciationScorer();

  @override
  SpeakingScore score({
    required String referenceText,
    required String transcript,
    required String eikenGrade,
  }) {
    final trimmed = transcript.trim();

    // ── Silence / empty ────────────────────────────────────────────────────────
    if (trimmed.isEmpty) {
      return SpeakingScore(
        referenceText: referenceText,
        transcript: trimmed,
        score: 0.0,
        feedbackJa: 'もう少し、ゆっくり言ってみよう！',
        feedbackEn: 'Give it a try — any words are great!',
        showAttitudeCoach: true,
      );
    }

    final transcriptWords = trimmed
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final referenceWords = referenceText
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // ── Very short response ────────────────────────────────────────────────────
    if (transcriptWords.length < 3) {
      return SpeakingScore(
        referenceText: referenceText,
        transcript: trimmed,
        score: 0.35,
        feedbackJa: 'いいね！もう少し続けて言ってみよう。',
        feedbackEn: 'Good start! Try to say a bit more.',
        showAttitudeCoach: false,
      );
    }

    // ── Coverage heuristic ─────────────────────────────────────────────────────
    // Count how many distinct reference words appear in the transcript.
    final refSet = referenceWords.toSet();
    final transcriptSet = transcriptWords.toSet();
    final overlap = refSet.intersection(transcriptSet).length;
    final coverage =
        referenceWords.isEmpty ? 0.0 : overlap / referenceWords.length;

    // ── Near-complete coverage → reward the excellence ─────────────────────────
    // A child who says ALL the words clearly should SEE a higher score + warmer
    // praise than one who covered half — capping a perfect read at the same 0.75
    // as a 50% read gives no encouragement for doing great (the engagement spine
    // runs on celebrating effort that earns it, honestly).
    if (coverage >= 0.85) {
      return SpeakingScore(
        referenceText: referenceText,
        transcript: trimmed,
        score: 0.9,
        feedbackJa: 'すばらしい！はっきり 言（い）えたね！',
        feedbackEn: 'Excellent! You said it clearly!',
        showAttitudeCoach: false,
      );
    }

    if (coverage >= 0.5) {
      return SpeakingScore(
        referenceText: referenceText,
        transcript: trimmed,
        score: 0.75,
        feedbackJa: 'よくできました！自信を持って話せているね。',
        feedbackEn: 'Well done! You covered the key words.',
        showAttitudeCoach: false,
      );
    }

    // ── Partial coverage ───────────────────────────────────────────────────────
    return SpeakingScore(
      referenceText: referenceText,
      transcript: trimmed,
      score: 0.5,
      feedbackJa: 'がんばった！もう少し練習するともっとうまくなるよ。',
      feedbackEn: 'Good effort! Practice makes perfect.',
      showAttitudeCoach: false,
    );
  }
}

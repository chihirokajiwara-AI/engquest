// lib/core/voice/voice_service.dart
// ENG Quest — C06 Voice Module
//
// Orchestrates microphone recording → Whisper transcription → pronunciation
// evaluation.  The transcription layer is a platform-channel stub; the
// evaluation logic (Levenshtein-based matching) is fully implemented.

import 'dart:math' as math;
import 'dart:typed_data';

import 'platform_voice_channel.dart';

// ── Result types ──────────────────────────────────────────────────────────────

/// Outcome of a single pronunciation attempt.
enum VoiceResult {
  /// Recognised text matches the target word exactly (case-insensitive).
  correct,

  /// Recognised text is close (Levenshtein distance ≤ 3).
  close,

  /// Recognised text is too different from the target.
  incorrect,

  /// Recording / evaluation did not complete within the allowed time window.
  timeout,

  /// Unexpected error in recording or transcription pipeline.
  error,
}

/// Full result of evaluating a single pronunciation attempt.
class PronunciationResult {
  /// The text returned by Whisper (or the mock pipeline in demo mode).
  final String transcribed;

  /// The target word the learner was asked to pronounce.
  final String target;

  /// Pronunciation quality verdict.
  final VoiceResult result;

  /// Confidence score in [0.0, 1.0].
  /// 1.0 → correct, 0.7 → close, 0.0 → incorrect / timeout / error.
  final double confidence;

  /// Wall-clock milliseconds from start of recording to result ready.
  final int latencyMs;

  const PronunciationResult({
    required this.transcribed,
    required this.target,
    required this.result,
    required this.confidence,
    required this.latencyMs,
  });

  @override
  String toString() =>
      'PronunciationResult(target=$target, transcribed=$transcribed, '
      'result=$result, confidence=$confidence, latencyMs=$latencyMs)';
}

// ── VoiceService ──────────────────────────────────────────────────────────────

/// High-level voice service: record → transcribe → evaluate.
///
/// ### Demo mode
/// When [PlatformVoiceChannel.demoMode] is true (or the native channel is
/// unavailable), [recordAudio] returns empty bytes and [transcribeAudio]
/// returns a mock word chosen from a fixed pool.  The demo intentionally
/// produces a mix of correct / close / incorrect results so the UI can be
/// exercised without a real microphone.
///
/// ### Production architecture (Spike S01)
/// whisper_ggml_plus v1.5.2 + base.en model.
/// Falls back to OpenAI Cloud Whisper API when on-device inference fails.
class VoiceService {
  VoiceService({PlatformVoiceChannel? channel})
      : _channel = channel ?? PlatformVoiceChannel();

  final PlatformVoiceChannel _channel;

  // Pool of mock words cycled during demo to produce varied results.
  static const List<String> _mockWords = [
    'cat', 'kat', 'dog', 'apple', 'aple', 'xyz', 'book', 'buk', 'school',
  ];
  int _mockIdx = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Records audio, transcribes it, and evaluates pronunciation of
  /// [targetWord].
  ///
  /// [recordingDuration] is typically 2–4 seconds for single-word targets.
  Future<PronunciationResult> evaluatePronunciation({
    required String targetWord,
    required Duration recordingDuration,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. Record
      final audio = await recordAudio(recordingDuration);

      // 2. Transcribe
      final recognised = await transcribeAudio(audio);

      // 3. Evaluate
      final result = evaluateMatch(recognised, targetWord);
      final confidence = _confidenceFor(result);

      sw.stop();
      return PronunciationResult(
        transcribed: recognised,
        target: targetWord,
        result: result,
        confidence: confidence,
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (_) {
      sw.stop();
      return PronunciationResult(
        transcribed: '',
        target: targetWord,
        result: VoiceResult.error,
        confidence: 0.0,
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }

  /// Records audio for [duration] using the device microphone.
  ///
  /// Returns raw PCM-16 bytes, or an empty [Uint8List] in demo mode.
  Future<Uint8List> recordAudio(Duration duration) async {
    // Add a small real delay so callers can show a recording UI.
    final durationMs = duration.inMilliseconds;
    final audio = await _channel.recordForDuration(durationMs);
    return audio ?? Uint8List(0); // empty bytes → demo / fallback
  }

  /// Transcribes [audioData] via the Whisper platform channel.
  ///
  /// Falls back to a deterministic mock sequence in demo mode so the full UI
  /// flow can be exercised without hardware.
  Future<String> transcribeAudio(Uint8List audioData) async {
    // In demo mode audioData is empty; skip the channel call.
    if (audioData.isEmpty || PlatformVoiceChannel.demoMode) {
      return _nextMockWord();
    }

    final result = await _channel.transcribeWithWhisper(audioData);
    if (result == null || result.trim().isEmpty) {
      return _nextMockWord();
    }
    return result.trim().toLowerCase();
  }

  /// Evaluates how closely [recognized] matches [target].
  ///
  /// Rules:
  /// - Exact match (case-insensitive): [VoiceResult.correct]
  /// - Levenshtein distance ≤ 3:       [VoiceResult.close]
  /// - Otherwise:                      [VoiceResult.incorrect]
  VoiceResult evaluateMatch(String recognized, String target) {
    final r = recognized.trim().toLowerCase();
    final t = target.trim().toLowerCase();

    if (r == t) return VoiceResult.correct;

    final dist = _levenshtein(r, t);
    if (dist <= 3) return VoiceResult.close;

    return VoiceResult.incorrect;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _confidenceFor(VoiceResult result) {
    switch (result) {
      case VoiceResult.correct:
        return 1.0;
      case VoiceResult.close:
        return 0.7;
      case VoiceResult.incorrect:
      case VoiceResult.timeout:
      case VoiceResult.error:
        return 0.0;
    }
  }

  String _nextMockWord() {
    final word = _mockWords[_mockIdx % _mockWords.length];
    _mockIdx++;
    return word;
  }

  /// Standard Wagner–Fischer Levenshtein distance.
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    // Use two rows for O(min(m,n)) space.
    final sLen = s.length;
    final tLen = t.length;

    List<int> prev = List<int>.generate(tLen + 1, (i) => i);
    List<int> curr = List<int>.filled(tLen + 1, 0);

    for (int i = 1; i <= sLen; i++) {
      curr[0] = i;
      for (int j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[tLen];
  }
}

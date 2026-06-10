// lib/core/voice/voice_service.dart
// ENG Quest — C06 Voice Module
//
// Orchestrates speech recognition → pronunciation evaluation.
//
// Two modes:
//   Real mode  — SpeechRecognitionService available → uses platform speech
//                recognition (Web Speech API / Apple Speech / Google Speech).
//   Demo mode  — no SpeechRecognitionService → cycles through mock words
//                producing a realistic mix of correct / close / incorrect
//                results so the UI can be exercised without a microphone.

import 'dart:math' as math;
import 'dart:typed_data';

import 'platform_voice_channel.dart';
import 'speech_recognition_service.dart';

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
  /// The text returned by speech recognition (or the mock pipeline in demo
  /// mode).
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

/// High-level voice service: listen → evaluate.
///
/// ### Real mode
/// When a [SpeechRecognitionService] is provided and available, the service
/// uses platform speech recognition to transcribe the learner's speech in
/// real time during the recording window.
///
/// ### Demo mode
/// When no [SpeechRecognitionService] is available (or it reports unavailable),
/// the service simulates recording with a delay matching [recordingDuration]
/// and returns a mock word from a fixed pool, producing varied results.
class VoiceService {
  VoiceService({
    PlatformVoiceChannel? channel,
    SpeechRecognitionService? speechRecognition,
  })  : _channel = channel ?? PlatformVoiceChannel(),
        _speechRecognition = speechRecognition;

  final PlatformVoiceChannel _channel;
  final SpeechRecognitionService? _speechRecognition;

  // Pool of mock words cycled during demo to produce varied results.
  static const List<String> _mockWords = [
    'cat',
    'kat',
    'dog',
    'apple',
    'aple',
    'xyz',
    'book',
    'buk',
    'school',
  ];
  int _mockIdx = 0;

  /// Whether real speech recognition is available.
  bool get isRealRecognitionAvailable =>
      _speechRecognition?.isAvailable ?? false;

  /// Whether we are running in demo mode (no real recognition).
  bool get isDemoMode => !isRealRecognitionAvailable;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Records audio, transcribes it, and evaluates pronunciation of
  /// [targetWord].
  ///
  /// In real mode, speech recognition listens for [recordingDuration].
  /// In demo mode, a simulated delay of [recordingDuration] occurs before
  /// returning a mock result.
  Future<PronunciationResult> evaluatePronunciation({
    required String targetWord,
    required Duration recordingDuration,
  }) async {
    final sw = Stopwatch()..start();
    try {
      String recognised;

      if (isRealRecognitionAvailable) {
        // ── Real speech recognition ──
        final result = await _speechRecognition!.listenForWord(
          duration: recordingDuration,
        );
        recognised = result?.trim().toLowerCase() ?? '';

        if (recognised.isEmpty) {
          sw.stop();
          return PronunciationResult(
            transcribed: '',
            target: targetWord,
            result: VoiceResult.timeout,
            confidence: 0.0,
            latencyMs: sw.elapsedMilliseconds,
          );
        }
      } else {
        // ── Demo mode (no real speech recognition) ──
        // We do NOT score in demo (the caller branches to honest shadowing
        // practice — #124), so there is nothing to "recognise". Use a brief
        // pause only (CAPPED, not the full ~60s recordingDuration) so tapping
        // Done is never stuck waiting, and never feed a mock word into a fake
        // score. Cap keeps tests (Duration.zero) instant.
        const cap = Duration(milliseconds: 1200);
        await Future<void>.delayed(
            recordingDuration < cap ? recordingDuration : cap);
        recognised = '';
      }

      // Evaluate match
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
  /// Retained for backward compatibility; prefer [evaluatePronunciation].
  Future<Uint8List> recordAudio(Duration duration) async {
    final durationMs = duration.inMilliseconds;
    final audio = await _channel.recordForDuration(durationMs);
    return audio ?? Uint8List(0);
  }

  /// Transcribes [audioData] via the Whisper platform channel.
  ///
  /// Falls back to a deterministic mock sequence in demo mode.
  /// Retained for backward compatibility; prefer [evaluatePronunciation].
  Future<String> transcribeAudio(Uint8List audioData) async {
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

    // No speech captured → "no speech", never "close". Levenshtein('', short
    // word) is ≤ 3, so without this guard silence would flatter a child with
    // "Almost there!" (the demo path feeds an empty string). Honest: nothing
    // was heard. (R9; same honesty principle as #124's no-score demo.)
    if (r.isEmpty) return VoiceResult.timeout;

    if (r == t) return VoiceResult.correct;

    final dist = _levenshtein(r, t);
    if (dist <= 3) return VoiceResult.close;

    return VoiceResult.incorrect;
  }

  /// Stop any active speech recognition session.
  Future<void> stopListening() async {
    await _speechRecognition?.stop();
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

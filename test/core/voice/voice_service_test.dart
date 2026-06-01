// test/core/voice/voice_service_test.dart

import 'package:engquest/core/voice/speech_recognition_service.dart';
import 'package:engquest/core/voice/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

// ── Fake SpeechRecognitionService for testing ────────────────────────────────

class FakeSpeechRecognitionService extends SpeechRecognitionService {
  FakeSpeechRecognitionService({this.available = true, this.recognizedWord})
      : super(speechToText: SpeechToText());

  final bool available;
  final String? recognizedWord;

  bool _initialized = false;

  @override
  bool get isAvailable => _initialized && available;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<bool> initialize() async {
    _initialized = true;
    return available;
  }

  @override
  Future<String?> listenForWord({required Duration duration}) async {
    if (!isAvailable) return null;
    // No real delay in tests.
    return recognizedWord;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('VoiceService - evaluateMatch', () {
    late VoiceService service;

    setUp(() {
      service = VoiceService();
    });

    test('exact match returns correct', () {
      expect(service.evaluateMatch('cat', 'cat'), VoiceResult.correct);
    });

    test('case-insensitive match returns correct', () {
      expect(service.evaluateMatch('Cat', 'cat'), VoiceResult.correct);
      expect(service.evaluateMatch('CAT', 'cat'), VoiceResult.correct);
    });

    test('whitespace-trimmed match returns correct', () {
      expect(service.evaluateMatch(' cat ', 'cat'), VoiceResult.correct);
    });

    test('close match (distance <= 3) returns close', () {
      // 'kat' vs 'cat' → distance 1
      expect(service.evaluateMatch('kat', 'cat'), VoiceResult.close);
      // 'buk' vs 'book' → distance 2
      expect(service.evaluateMatch('buk', 'book'), VoiceResult.close);
      // 'aple' vs 'apple' → distance 1
      expect(service.evaluateMatch('aple', 'apple'), VoiceResult.close);
    });

    test('distant match returns incorrect', () {
      expect(service.evaluateMatch('helicopter', 'cat'), VoiceResult.incorrect);
      expect(service.evaluateMatch('xyzabc', 'cat'), VoiceResult.incorrect);
    });

    test('borderline match (distance == 3) returns close', () {
      // 'xyz' vs 'cat' → distance 3 → still "close"
      expect(service.evaluateMatch('xyz', 'cat'), VoiceResult.close);
      // '' vs 'cat' → distance 3 → still "close"
      expect(service.evaluateMatch('', 'cat'), VoiceResult.close);
    });
  });

  group('VoiceService - demo mode', () {
    test('isDemoMode is true when no speech service provided', () {
      final service = VoiceService();
      expect(service.isDemoMode, isTrue);
      expect(service.isRealRecognitionAvailable, isFalse);
    });

    test('isDemoMode is true when speech service is unavailable', () {
      final fakeSrs = FakeSpeechRecognitionService(available: false);
      fakeSrs.initialize();
      final service = VoiceService(speechRecognition: fakeSrs);
      expect(service.isDemoMode, isTrue);
    });

    test('evaluatePronunciation returns mock results in demo mode', () async {
      final service = VoiceService();
      final result = await service.evaluatePronunciation(
        targetWord: 'cat',
        recordingDuration: Duration.zero, // no delay in tests
      );
      // First mock word is 'cat' → correct
      expect(result.result, VoiceResult.correct);
      expect(result.transcribed, 'cat');
      expect(result.target, 'cat');
      expect(result.confidence, 1.0);
    });

    test('demo mode cycles through mock words', () async {
      final service = VoiceService();
      final results = <String>[];
      for (int i = 0; i < 3; i++) {
        final r = await service.evaluatePronunciation(
          targetWord: 'cat',
          recordingDuration: Duration.zero,
        );
        results.add(r.transcribed);
      }
      // Should cycle: cat, kat, dog
      expect(results, ['cat', 'kat', 'dog']);
    });
  });

  group('VoiceService - real recognition mode', () {
    test('isRealRecognitionAvailable is true when service available', () async {
      final fakeSrs = FakeSpeechRecognitionService(
        available: true,
        recognizedWord: 'cat',
      );
      await fakeSrs.initialize();
      final service = VoiceService(speechRecognition: fakeSrs);
      expect(service.isRealRecognitionAvailable, isTrue);
      expect(service.isDemoMode, isFalse);
    });

    test('evaluatePronunciation uses real recognition when available',
        () async {
      final fakeSrs = FakeSpeechRecognitionService(
        available: true,
        recognizedWord: 'apple',
      );
      await fakeSrs.initialize();
      final service = VoiceService(speechRecognition: fakeSrs);

      final result = await service.evaluatePronunciation(
        targetWord: 'apple',
        recordingDuration: const Duration(seconds: 1),
      );
      expect(result.result, VoiceResult.correct);
      expect(result.transcribed, 'apple');
      expect(result.confidence, 1.0);
    });

    test('returns timeout when recognition returns null', () async {
      final fakeSrs = FakeSpeechRecognitionService(
        available: true,
        recognizedWord: null,
      );
      await fakeSrs.initialize();
      final service = VoiceService(speechRecognition: fakeSrs);

      final result = await service.evaluatePronunciation(
        targetWord: 'cat',
        recordingDuration: const Duration(seconds: 1),
      );
      expect(result.result, VoiceResult.timeout);
      expect(result.transcribed, '');
    });

    test('returns timeout when recognition returns empty string', () async {
      final fakeSrs = FakeSpeechRecognitionService(
        available: true,
        recognizedWord: '   ',
      );
      await fakeSrs.initialize();
      final service = VoiceService(speechRecognition: fakeSrs);

      final result = await service.evaluatePronunciation(
        targetWord: 'cat',
        recordingDuration: const Duration(seconds: 1),
      );
      expect(result.result, VoiceResult.timeout);
    });

    test('returns close for near-miss recognition', () async {
      final fakeSrs = FakeSpeechRecognitionService(
        available: true,
        recognizedWord: 'kat',
      );
      await fakeSrs.initialize();
      final service = VoiceService(speechRecognition: fakeSrs);

      final result = await service.evaluatePronunciation(
        targetWord: 'cat',
        recordingDuration: const Duration(seconds: 1),
      );
      expect(result.result, VoiceResult.close);
      expect(result.confidence, 0.7);
    });

    test('returns incorrect for distant recognition', () async {
      final fakeSrs = FakeSpeechRecognitionService(
        available: true,
        recognizedWord: 'helicopter',
      );
      await fakeSrs.initialize();
      final service = VoiceService(speechRecognition: fakeSrs);

      final result = await service.evaluatePronunciation(
        targetWord: 'cat',
        recordingDuration: const Duration(seconds: 1),
      );
      expect(result.result, VoiceResult.incorrect);
      expect(result.confidence, 0.0);
    });
  });

  group('PronunciationResult', () {
    test('toString includes all fields', () {
      const result = PronunciationResult(
        transcribed: 'cat',
        target: 'cat',
        result: VoiceResult.correct,
        confidence: 1.0,
        latencyMs: 100,
      );
      final s = result.toString();
      expect(s, contains('target=cat'));
      expect(s, contains('transcribed=cat'));
      expect(s, contains('correct'));
    });
  });
}

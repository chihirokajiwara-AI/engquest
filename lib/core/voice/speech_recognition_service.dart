// lib/core/voice/speech_recognition_service.dart
// ENG Quest — Cross-platform speech recognition
//
// Wraps the speech_to_text package to provide a simple API for the voice
// module.  Platform backends:
//   Web:     Web Speech API (Chrome, Edge, Safari)
//   iOS:     Apple Speech framework (on-device, COPPA compliant)
//   Android: Google Speech Services
//
// Falls back gracefully when speech recognition is unavailable — callers
// should check [isAvailable] and degrade to demo mode.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Cross-platform speech recognition service.
///
/// Usage:
/// ```dart
/// final srs = SpeechRecognitionService();
/// await srs.initialize();
/// if (srs.isAvailable) {
///   final text = await srs.listenForWord(duration: Duration(seconds: 3));
/// }
/// ```
class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speechToText})
      : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _available = false;

  /// Whether speech recognition has been initialised and is available.
  bool get isAvailable => _initialized && _available;

  /// Whether [initialize] has been called (regardless of availability).
  bool get isInitialized => _initialized;

  /// Initialise the speech recognition engine and request microphone
  /// permission.  Returns true if speech recognition is available.
  Future<bool> initialize() async {
    if (_initialized) return _available;
    try {
      _available = await _speech.initialize(
        onError: (error) {
          if (kDebugMode) {
            debugPrint('SpeechRecognition error: ${error.errorMsg}');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SpeechRecognition init failed: $e');
      }
      _available = false;
    }
    _initialized = true;
    return _available;
  }

  /// Listen for speech for [duration] and return the recognised text.
  ///
  /// Returns null if speech recognition is unavailable, the user said nothing,
  /// or an error occurred.  The caller should treat null as "no input" and
  /// fall back to demo mode or show a timeout result.
  Future<String?> listenForWord({required Duration duration}) async {
    if (!isAvailable) return null;

    String? recognised;
    final completer = Completer<String?>();

    try {
      await _speech.listen(
        onResult: (result) {
          recognised = result.recognizedWords;
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: duration + const Duration(seconds: 2),
          pauseFor: duration,
          localeId: 'en_US',
        ),
      );

      // Wait for the listen duration then collect whatever we have.
      await Future<void>.delayed(duration);

      if (!completer.isCompleted) {
        await _speech.stop();
        completer.complete(recognised);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SpeechRecognition listen error: $e');
      }
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future;
  }

  /// Stop any active listening session.
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Swallow — stop is best-effort.
    }
  }

  /// Cancel any active listening session without waiting for results.
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // Swallow — cancel is best-effort.
    }
  }
}

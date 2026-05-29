// lib/core/voice/platform_voice_channel.dart
// ENG Quest — C06 Voice Module
//
// Flutter MethodChannel stub for native voice I/O.
// Current: returns mock data in demo mode.
// Future:  swapped for real iOS (AVAudioRecorder) / Android (MediaRecorder)
//          + whisper_ggml_plus v1.5.2 + base.en model implementation.

import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Platform channel stub for voice recording and Whisper transcription.
///
/// All methods gracefully return null / empty data when the native side is not
/// yet implemented, allowing the app to fall back to demo mode.
class PlatformVoiceChannel {
  static const MethodChannel _channel = MethodChannel('engquest/voice');

  /// Whether we are running in demo mode (no native implementation available).
  ///
  /// In demo mode, [recordForDuration] returns empty bytes and
  /// [transcribeWithWhisper] returns null, triggering the mock pipeline in
  /// [VoiceService].
  static bool demoMode = true;

  // ── Recording ──────────────────────────────────────────────────────────────

  /// Records audio for [durationMs] milliseconds using the device microphone.
  ///
  /// iOS: AVAudioRecorder (PCM-16 / 16 kHz mono)
  /// Android: MediaRecorder (AAC-LC → PCM-16 remux)
  ///
  /// Returns raw audio bytes, or null if the native side is unavailable.
  Future<Uint8List?> recordForDuration(int durationMs) async {
    if (demoMode) return null;
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'recordForDuration',
        {'durationMs': durationMs},
      );
      return result;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  // ── Transcription ─────────────────────────────────────────────────────────

  /// Transcribes [audioData] using the on-device whisper_ggml_plus engine
  /// (base.en model).
  ///
  /// Falls back to the OpenAI Cloud Whisper API when on-device inference is
  /// unavailable (hybrid architecture defined in Spike S01).
  ///
  /// Returns the recognised text, or null if transcription failed / native
  /// side is not yet wired up.
  Future<String?> transcribeWithWhisper(Uint8List audioData) async {
    if (demoMode) return null;
    try {
      final result = await _channel.invokeMethod<String>(
        'transcribeWithWhisper',
        {'audioData': audioData},
      );
      return result;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

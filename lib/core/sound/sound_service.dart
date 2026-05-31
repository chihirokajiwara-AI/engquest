// lib/core/sound/sound_service.dart
// ENG Quest — Sound Effect Service
//
// Plays short UI feedback sounds during Battle sessions.
// Sounds are synthesized as WAV bytes (no external asset files needed).
// Uses audioplayers ^5.2.1 BytesSource for web-compatible playback.

import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../storage/preferences_service.dart';

class SoundService {
  // Singleton
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  AudioPlayer? _playerInstance;
  AudioPlayer get _player => _playerInstance ??= AudioPlayer();
  bool _muted = false;

  bool get muted => _muted;
  set muted(bool value) {
    _muted = value;
    // Persist asynchronously (fire-and-forget)
    PreferencesService.getInstance().then((prefs) {
      prefs.setBool(PrefKeys.soundMuted, value);
    }).catchError((_) {});
  }

  /// Load persisted mute state. Call once at app startup.
  Future<void> loadPreferences() async {
    try {
      final prefs = await PreferencesService.getInstance();
      _muted = prefs.getBool(PrefKeys.soundMuted);
    } catch (_) {
      // Non-fatal: default to unmuted
    }
  }

  // Lazy-cached WAV bytes for each sound effect
  Uint8List? _flipWav;
  Uint8List? _correctWav;
  Uint8List? _wrongWav;
  Uint8List? _levelUpWav;
  Uint8List? _achievementWav;
  Uint8List? _sessionCompleteWav;
  Uint8List? _xpGainWav;

  /// Called when the flashcard is flipped (face -> back).
  void playFlip() {
    if (muted) return;
    _flipWav ??= generateFlipSound();
    _playBytes(_flipWav!);
  }

  /// Called when the user grades a card Good or Easy (correct recall).
  void playCorrect() {
    if (muted) return;
    _correctWav ??= generateCorrectSound();
    _playBytes(_correctWav!);
  }

  /// Called when the user grades a card Again (incorrect recall).
  void playWrong() {
    if (muted) return;
    _wrongWav ??= generateWrongSound();
    _playBytes(_wrongWav!);
  }

  /// Called when the player gains enough XP to level up.
  void playLevelUp() {
    if (muted) return;
    _levelUpWav ??= generateLevelUpSound();
    _playBytes(_levelUpWav!);
  }

  /// Called when the player unlocks an achievement/badge.
  void playAchievement() {
    if (muted) return;
    _achievementWav ??= generateAchievementSound();
    _playBytes(_achievementWav!);
  }

  /// Called when a practice session is completed.
  void playSessionComplete() {
    if (muted) return;
    _sessionCompleteWav ??= generateSessionCompleteSound();
    _playBytes(_sessionCompleteWav!);
  }

  /// Called when XP is awarded (short tick).
  void playXpGain() {
    if (muted) return;
    _xpGainWav ??= generateXpGainSound();
    _playBytes(_xpGainWav!);
  }

  void dispose() {
    _playerInstance?.dispose();
  }

  // ── Playback ────────────────────────────────────────────────────────────────

  void _playBytes(Uint8List wav) {
    // Fire-and-forget: sound effects are non-blocking UI enhancements
    _player.play(BytesSource(wav)).catchError((e) {
      if (kDebugMode) debugPrint('[SoundService] playback error: $e');
    });
  }

  // ── Sound synthesis ─────────────────────────────────────────────────────────

  static const int _sampleRate = 44100;

  /// Short click/tick for card flip (~60ms, 880 Hz with fast decay)
  @visibleForTesting
  static Uint8List generateFlipSound() {
    const durationMs = 60;
    final samples = _sampleRate * durationMs ~/ 1000;
    final pcm = Float64List(samples);

    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      // Quick exponential decay envelope
      final envelope = math.exp(-t * 80);
      pcm[i] = math.sin(2 * math.pi * 880 * t) * envelope * 0.5;
    }

    return encodeWav(pcm);
  }

  /// Pleasant ascending two-tone chime for correct answer (~250ms)
  /// C5 (523 Hz) -> E5 (659 Hz)
  @visibleForTesting
  static Uint8List generateCorrectSound() {
    const durationMs = 250;
    final samples = _sampleRate * durationMs ~/ 1000;
    final pcm = Float64List(samples);
    final half = samples ~/ 2;

    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final freq = i < half ? 523.25 : 659.25;
      // Per-note envelope: attack 5ms, sustain, decay at end
      final noteStart = i < half ? 0 : half;
      final notePos = i - noteStart;
      final noteLen = i < half ? half : samples - half;
      final attack = (notePos / (_sampleRate * 0.005)).clamp(0.0, 1.0);
      final release =
          ((noteLen - notePos) / (_sampleRate * 0.03)).clamp(0.0, 1.0);
      final envelope = attack * release;
      pcm[i] = math.sin(2 * math.pi * freq * t) * envelope * 0.4;
    }

    return encodeWav(pcm);
  }

  /// Low descending tone for wrong answer (~200ms)
  /// E4 (330 Hz) -> C4 (262 Hz) with slight buzz
  @visibleForTesting
  static Uint8List generateWrongSound() {
    const durationMs = 200;
    final samples = _sampleRate * durationMs ~/ 1000;
    final pcm = Float64List(samples);

    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = i / samples;
      // Descending frequency sweep
      final freq = 330.0 - (330.0 - 262.0) * progress;
      final envelope = (1.0 - progress) * 0.4;
      // Add slight harmonic for "buzzy" feel
      pcm[i] = (math.sin(2 * math.pi * freq * t) * 0.7 +
              math.sin(2 * math.pi * freq * 2 * t) * 0.3) *
          envelope;
    }

    return encodeWav(pcm);
  }

  /// Triumphant ascending arpeggio for level-up (~600ms)
  /// C5 -> E5 -> G5 -> C6
  @visibleForTesting
  static Uint8List generateLevelUpSound() {
    const durationMs = 600;
    final samples = _sampleRate * durationMs ~/ 1000;
    final pcm = Float64List(samples);
    const freqs = [523.25, 659.25, 783.99, 1046.50]; // C5 E5 G5 C6
    final noteLen = samples ~/ freqs.length;

    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final noteIdx = (i ~/ noteLen).clamp(0, freqs.length - 1);
      final freq = freqs[noteIdx];
      // Per-note envelope
      final notePos = i - noteIdx * noteLen;
      final attack = (notePos / (_sampleRate * 0.005)).clamp(0.0, 1.0);
      final release =
          ((noteLen - notePos) / (_sampleRate * 0.05)).clamp(0.0, 1.0);
      final envelope = attack * release;
      // Add octave harmonic for richness on final note
      final harmonic = noteIdx == freqs.length - 1 ? 0.2 : 0.0;
      pcm[i] = (math.sin(2 * math.pi * freq * t) * (1.0 - harmonic) +
              math.sin(2 * math.pi * freq * 2 * t) * harmonic) *
          envelope *
          0.4;
    }

    return encodeWav(pcm);
  }

  /// Bright celebratory chime for achievement unlock (~400ms)
  /// G5 -> B5 -> D6 -> G6 (G major arpeggio, higher register)
  @visibleForTesting
  static Uint8List generateAchievementSound() {
    const durationMs = 400;
    final samples = _sampleRate * durationMs ~/ 1000;
    final pcm = Float64List(samples);
    const freqs = [783.99, 987.77, 1174.66, 1567.98]; // G5 B5 D6 G6
    final noteLen = samples ~/ freqs.length;

    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final noteIdx = (i ~/ noteLen).clamp(0, freqs.length - 1);
      final freq = freqs[noteIdx];
      final notePos = i - noteIdx * noteLen;
      final attack = (notePos / (_sampleRate * 0.005)).clamp(0.0, 1.0);
      final release =
          ((noteLen - notePos) / (_sampleRate * 0.04)).clamp(0.0, 1.0);
      final envelope = attack * release;
      // Add shimmer with octave harmonic
      pcm[i] = (math.sin(2 * math.pi * freq * t) * 0.7 +
              math.sin(2 * math.pi * freq * 2 * t) * 0.3) *
          envelope *
          0.35;
    }

    return encodeWav(pcm);
  }

  /// Triumphant fanfare for session completion (~500ms)
  /// C5 -> E5 -> G5 (hold) — major triad with sustained final note
  @visibleForTesting
  static Uint8List generateSessionCompleteSound() {
    const durationMs = 500;
    final samples = _sampleRate * durationMs ~/ 1000;
    final pcm = Float64List(samples);
    // 3 notes: first two quick, last one held
    const freqs = [523.25, 659.25, 783.99]; // C5 E5 G5
    final quickNote = samples ~/ 5; // 100ms each
    final holdNote = samples - quickNote * 2; // 300ms

    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      int noteIdx;
      int noteStart;
      int noteLength;
      if (i < quickNote) {
        noteIdx = 0;
        noteStart = 0;
        noteLength = quickNote;
      } else if (i < quickNote * 2) {
        noteIdx = 1;
        noteStart = quickNote;
        noteLength = quickNote;
      } else {
        noteIdx = 2;
        noteStart = quickNote * 2;
        noteLength = holdNote;
      }
      final freq = freqs[noteIdx];
      final notePos = i - noteStart;
      final attack = (notePos / (_sampleRate * 0.005)).clamp(0.0, 1.0);
      final release =
          ((noteLength - notePos) / (_sampleRate * 0.06)).clamp(0.0, 1.0);
      final envelope = attack * release;
      // Rich tone with harmonic for final note
      final harmonic = noteIdx == 2 ? 0.15 : 0.0;
      pcm[i] = (math.sin(2 * math.pi * freq * t) * (1.0 - harmonic) +
              math.sin(2 * math.pi * freq * 2 * t) * harmonic) *
          envelope *
          0.4;
    }

    return encodeWav(pcm);
  }

  /// Quick bright tick for XP gain (~80ms, high-pitched ping)
  @visibleForTesting
  static Uint8List generateXpGainSound() {
    const durationMs = 80;
    final samples = _sampleRate * durationMs ~/ 1000;
    final pcm = Float64List(samples);

    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final envelope = math.exp(-t * 50);
      // Bright high ping at 1318 Hz (E6)
      pcm[i] = math.sin(2 * math.pi * 1318.51 * t) * envelope * 0.3;
    }

    return encodeWav(pcm);
  }

  // ── WAV encoder ─────────────────────────────────────────────────────────────

  /// Encode normalized PCM samples (-1.0..1.0) as a 16-bit mono WAV file.
  @visibleForTesting
  static Uint8List encodeWav(Float64List samples) {
    const bitsPerSample = 16;
    const numChannels = 1;
    const byteRate = _sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = samples.length * blockAlign;
    final fileSize = 36 + dataSize; // 36 = header size minus 8

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt sub-chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // ' '
    buffer.setUint32(offset, 16, Endian.little); // sub-chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data sub-chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // PCM samples (16-bit signed, little-endian)
    for (var i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final intSample = (clamped * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}

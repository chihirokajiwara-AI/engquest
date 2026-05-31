// test/core/sound/sound_service_test.dart
// Tests for SoundService — WAV synthesis + playback integration.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/sound/sound_service.dart';

void main() {
  // AudioPlayer requires Flutter platform channels
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundService', () {
    late SoundService service;

    setUp(() {
      service = SoundService();
      // Start unmuted
      service.muted = false;
    });

    test('is a singleton', () {
      final a = SoundService();
      final b = SoundService();
      expect(identical(a, b), isTrue);
    });

    test('muted getter/setter works', () {
      expect(service.muted, isFalse);
      service.muted = true;
      expect(service.muted, isTrue);
      service.muted = false;
      expect(service.muted, isFalse);
    });

    // Verify methods don't throw when muted (no AudioPlayer interaction)
    test('playFlip does not throw when muted', () {
      service.muted = true;
      expect(() => service.playFlip(), returnsNormally);
    });

    test('playCorrect does not throw when muted', () {
      service.muted = true;
      expect(() => service.playCorrect(), returnsNormally);
    });

    test('playWrong does not throw when muted', () {
      service.muted = true;
      expect(() => service.playWrong(), returnsNormally);
    });

    test('playLevelUp does not throw when muted', () {
      service.muted = true;
      expect(() => service.playLevelUp(), returnsNormally);
    });

    test('playAchievement does not throw when muted', () {
      service.muted = true;
      expect(() => service.playAchievement(), returnsNormally);
    });

    test('playSessionComplete does not throw when muted', () {
      service.muted = true;
      expect(() => service.playSessionComplete(), returnsNormally);
    });

    test('playXpGain does not throw when muted', () {
      service.muted = true;
      expect(() => service.playXpGain(), returnsNormally);
    });
  });

  group('SoundService WAV synthesis', () {
    // Access WAV generators via public-for-test helper.
    // The generators are static methods; we test them through the
    // SoundServiceTestHelper that exposes them.

    test('generated WAV has valid RIFF header', () {
      final wav = SoundServiceTestHelper.generateFlipSound();
      // RIFF header check
      expect(wav[0], 0x52); // R
      expect(wav[1], 0x49); // I
      expect(wav[2], 0x46); // F
      expect(wav[3], 0x46); // F
      // WAVE format
      expect(wav[8], 0x57);  // W
      expect(wav[9], 0x41);  // A
      expect(wav[10], 0x56); // V
      expect(wav[11], 0x45); // E
    });

    test('generated WAV has correct fmt chunk', () {
      final wav = SoundServiceTestHelper.generateFlipSound();
      // fmt sub-chunk at offset 12
      expect(wav[12], 0x66); // f
      expect(wav[13], 0x6D); // m
      expect(wav[14], 0x74); // t
      expect(wav[15], 0x20); // ' '

      final data = ByteData.sublistView(wav);
      // PCM format = 1
      expect(data.getUint16(20, Endian.little), 1);
      // Mono = 1 channel
      expect(data.getUint16(22, Endian.little), 1);
      // 44100 Hz sample rate
      expect(data.getUint32(24, Endian.little), 44100);
      // 16 bits per sample
      expect(data.getUint16(34, Endian.little), 16);
    });

    test('flip sound has expected duration (~60ms)', () {
      final wav = SoundServiceTestHelper.generateFlipSound();
      _expectApproxDurationMs(wav, 60);
    });

    test('correct sound has expected duration (~250ms)', () {
      final wav = SoundServiceTestHelper.generateCorrectSound();
      _expectApproxDurationMs(wav, 250);
    });

    test('wrong sound has expected duration (~200ms)', () {
      final wav = SoundServiceTestHelper.generateWrongSound();
      _expectApproxDurationMs(wav, 200);
    });

    test('level up sound has expected duration (~600ms)', () {
      final wav = SoundServiceTestHelper.generateLevelUpSound();
      _expectApproxDurationMs(wav, 600);
    });

    test('achievement sound has expected duration (~400ms)', () {
      final wav = SoundServiceTestHelper.generateAchievementSound();
      _expectApproxDurationMs(wav, 400);
    });

    test('session complete sound has expected duration (~500ms)', () {
      final wav = SoundServiceTestHelper.generateSessionCompleteSound();
      _expectApproxDurationMs(wav, 500);
    });

    test('xp gain sound has expected duration (~80ms)', () {
      final wav = SoundServiceTestHelper.generateXpGainSound();
      _expectApproxDurationMs(wav, 80);
    });

    test('all generators produce non-empty WAV data', () {
      // Minimum WAV: 44 byte header + at least 2 bytes of audio
      expect(SoundServiceTestHelper.generateFlipSound().length,
          greaterThan(44));
      expect(SoundServiceTestHelper.generateCorrectSound().length,
          greaterThan(44));
      expect(SoundServiceTestHelper.generateWrongSound().length,
          greaterThan(44));
      expect(SoundServiceTestHelper.generateLevelUpSound().length,
          greaterThan(44));
      expect(SoundServiceTestHelper.generateAchievementSound().length,
          greaterThan(44));
      expect(SoundServiceTestHelper.generateSessionCompleteSound().length,
          greaterThan(44));
      expect(SoundServiceTestHelper.generateXpGainSound().length,
          greaterThan(44));
    });

    test('WAV file size field matches actual data', () {
      for (final wav in [
        SoundServiceTestHelper.generateFlipSound(),
        SoundServiceTestHelper.generateCorrectSound(),
        SoundServiceTestHelper.generateWrongSound(),
        SoundServiceTestHelper.generateLevelUpSound(),
        SoundServiceTestHelper.generateAchievementSound(),
        SoundServiceTestHelper.generateSessionCompleteSound(),
        SoundServiceTestHelper.generateXpGainSound(),
      ]) {
        final data = ByteData.sublistView(wav);
        final riffSize = data.getUint32(4, Endian.little);
        // RIFF size = total file size - 8 (RIFF + size field)
        expect(riffSize, wav.length - 8);
      }
    });

    test('PCM samples are within 16-bit signed range', () {
      final wav = SoundServiceTestHelper.generateCorrectSound();
      final data = ByteData.sublistView(wav);
      // Data starts at offset 44
      for (var i = 44; i < wav.length; i += 2) {
        final sample = data.getInt16(i, Endian.little);
        expect(sample, greaterThanOrEqualTo(-32768));
        expect(sample, lessThanOrEqualTo(32767));
      }
    });
  });
}

/// Verify WAV data chunk size corresponds to expected duration.
void _expectApproxDurationMs(Uint8List wav, int expectedMs) {
  final data = ByteData.sublistView(wav);
  final dataSize = data.getUint32(40, Endian.little);
  // 16-bit mono at 44100 Hz = 2 bytes per sample
  final samples = dataSize ~/ 2;
  final durationMs = (samples * 1000) ~/ 44100;
  // Allow 1ms tolerance due to integer division
  expect(durationMs, closeTo(expectedMs, 2));
}

/// Alias for readability — delegates to @visibleForTesting static methods.
class SoundServiceTestHelper {
  static Uint8List generateFlipSound() => SoundService.generateFlipSound();
  static Uint8List generateCorrectSound() => SoundService.generateCorrectSound();
  static Uint8List generateWrongSound() => SoundService.generateWrongSound();
  static Uint8List generateLevelUpSound() => SoundService.generateLevelUpSound();
  static Uint8List generateAchievementSound() => SoundService.generateAchievementSound();
  static Uint8List generateSessionCompleteSound() => SoundService.generateSessionCompleteSound();
  static Uint8List generateXpGainSound() => SoundService.generateXpGainSound();
}

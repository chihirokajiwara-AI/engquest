// lib/core/sound/sound_service.dart
// ENG Quest — Sound Effect Service
//
// Currently all methods are NO-OP stubs.
// TODO: integrate audioplayers ^5.2.1 in next sprint
//
// Usage:
//   final _sound = SoundService();
//   _sound.playFlip();
//   _sound.playCorrect();

import 'package:flutter/foundation.dart';

class SoundService {
  // Singleton
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  /// Called when the flashcard is flipped (face → back).
  void playFlip() {
    if (kDebugMode) debugPrint('[SoundService] playFlip — stub');
    // TODO: await _player.play(AssetSource('audio/flip.mp3'));
  }

  /// Called when the user grades a card Good or Easy (correct recall).
  void playCorrect() {
    if (kDebugMode) debugPrint('[SoundService] playCorrect — stub');
    // TODO: await _player.play(AssetSource('audio/correct.mp3'));
  }

  /// Called when the user grades a card Again (incorrect recall).
  void playWrong() {
    if (kDebugMode) debugPrint('[SoundService] playWrong — stub');
    // TODO: await _player.play(AssetSource('audio/wrong.mp3'));
  }

  /// Called when the player gains enough XP to level up.
  void playLevelUp() {
    if (kDebugMode) debugPrint('[SoundService] playLevelUp — stub');
    // TODO: await _player.play(AssetSource('audio/level_up.mp3'));
  }
}

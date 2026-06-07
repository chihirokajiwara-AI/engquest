// lib/core/audio/audio_mute.dart
//
// Single source of truth for the "Voice" audio channel (spoken word /
// pronunciation playback). Honoured by BOTH voice playback services —
// WordAudioPlayerService (Battle flashcards) and AudioCueService (quest /
// scene / nazo / listening / mock / prologue word audio) — so the Settings
// toggle and "すべて消音 / mute everything" silence ALL voice audio, not just
// one screen. (SFX is a separate channel owned by SoundService.)

import '../storage/preferences_service.dart';

class AudioMute {
  AudioMute._();

  /// When true, no voice/pronunciation audio is fetched or played anywhere.
  static bool voiceMuted = false;

  /// Load the persisted Voice-channel mute. Call once at app bootstrap so the
  /// setting is live from the very first screen (prologue, deep-links, Battle).
  static Future<void> loadVoicePreference() async {
    try {
      final prefs = await PreferencesService.getInstance();
      voiceMuted = prefs.getBool(PrefKeys.voiceMuted);
    } catch (_) {
      // Non-fatal: default to unmuted.
    }
  }

  /// Set + persist the Voice-channel mute (used by the Settings screen).
  static Future<void> setVoiceMuted(bool value) async {
    voiceMuted = value;
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.setBool(PrefKeys.voiceMuted, value);
    } catch (_) {
      // Non-fatal.
    }
  }
}

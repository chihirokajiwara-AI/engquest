// lib/core/audio/audio_cue_service.dart
// A-KEN Quest — Audio Cue Service
//
// Plays bundled phonics / blend / word / phrase clips by asset KEY for the
// 英検5級『言葉を失った村』stage. Sources from assets/audio/phonics/ (and may be
// pointed at assets/audio/eiken5/ for whole-word clips).
//
// WEB AUTOPLAY CONTRACT (hardened C3): browsers block audio that is not started
// from a user gesture. NEVER call [play] from initState/build — only from tap
// handlers (the 🔊 button, an option tap, or the user-gesture chain that already
// drives _start/_next/_choose in QuestScreen). Autoplay-on-step-enter is
// best-effort; the always-visible 🔊 button is the real contract.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a single bundled audio asset by key (relative to `assets/`, e.g.
/// 'audio/phonics/phoneme_s.mp3'). Fire-and-forget; errors are swallowed so a
/// missing/unrecorded clip (founder records phonemes later) never crashes the UI.
class AudioCueService {
  AudioCueService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Play the asset at [assetKey]. Restarts cleanly if a clip is already playing
  /// (e.g. the child taps 🔊 repeatedly to imitate). Must be invoked from a
  /// user-gesture chain on web.
  Future<void> play(String? assetKey) async {
    if (assetKey == null || assetKey.isEmpty) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(assetKey));
    } catch (e) {
      if (kDebugMode) debugPrint('[AudioCue] playback error for $assetKey: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {/* ignore */}
  }

  void dispose() => _player.dispose();
}

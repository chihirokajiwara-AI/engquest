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

import 'audio_mute.dart';

/// Plays a single bundled audio asset by key (relative to `assets/`, e.g.
/// 'audio/phonics/phoneme_s.mp3'). Fire-and-forget; errors are swallowed so a
/// missing/unrecorded clip (founder records phonemes later) never crashes the UI.
class AudioCueService {
  AudioCueService({AudioPlayer? player}) : _injectedPlayer = player;

  // Lazily created so the player is never built when voice is muted (or in
  // tests that only exercise the mute gate).
  final AudioPlayer? _injectedPlayer;
  AudioPlayer? _playerInstance;
  bool _disposed = false;
  AudioPlayer get _player =>
      _playerInstance ??= (_injectedPlayer ?? AudioPlayer());

  /// Test-only: true once a real player has been constructed. Lets a CI test
  /// prove the mute gate prevents playback (player never built → nothing
  /// played) without relying on the platform throwing.
  @visibleForTesting
  bool get debugPlayerCreated => _playerInstance != null;

  /// Play the asset at [assetKey]. Restarts cleanly if a clip is already playing
  /// (e.g. the child taps 🔊 repeatedly to imitate). Must be invoked from a
  /// user-gesture chain on web.
  Future<void> play(String? assetKey) async {
    // Guard against a tap landing after dispose() (e.g. a 🔊 replay in the #168
    // memo drawer tapped during the scene-pop animation) — calling play()/stop()
    // on a disposed AudioPlayer would otherwise hit the catch and silently no-op.
    if (_disposed) return;
    // Voice channel muted in Settings → silence ALL word/pronunciation audio.
    if (AudioMute.voiceMuted) return;
    if (assetKey == null || assetKey.isEmpty) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(assetKey));
    } catch (e) {
      if (kDebugMode) debugPrint('[AudioCue] playback error for $assetKey: $e');
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _playerInstance?.stop();
    } catch (_) {/* ignore */}
  }

  void dispose() {
    _disposed = true;
    _playerInstance?.dispose();
  }
}

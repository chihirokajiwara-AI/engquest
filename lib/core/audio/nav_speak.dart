// #133 pre-literacy "tap-to-speak": a non-reading 4–7yo can tap a small speaker on
// any key nav element and HEAR its Japanese label, so the 英検 front door is usable
// before the child can read. Plays a pre-generated ja_JP clip
// (assets/audio/ui_ja/`key`.mp3, made offline by macOS `say -v Kyoko` via
// scripts/generate_nav_audio_say.sh — ¥0, no cloud, COPPA-safe) through the SHARED
// mute-gated AudioCueService. Decided by the CEO-1197 expert panel (file-based clips
// chosen over flutter_tts/browser SpeechSynthesis, which fail the honesty bar with
// silent/English/mechanical fallbacks across Chrome-Android/Safari/ChromeOS in 2026).
//
// HONESTY: these are NAVIGATION labels, never 英検 learning content — they never feed
// 合格率. NAVIGATION NEVER DEPENDS ON AUDIO: a missing clip or muted voice is just
// silence; every element stays fully usable by tap.

import 'package:flutter/material.dart';

import 'audio_cue_service.dart';

/// Speaks short Japanese nav labels. Keys map 1:1 to assets/audio/ui_ja/`key`.mp3.
class NavSpeak {
  NavSpeak._();

  static final AudioCueService _cue = AudioCueService();

  /// Keys with a backing clip. A SpeakerButton for an unknown key is a no-op.
  static const Set<String> keys = {
    'exam',
    'passrate',
    'map',
    'settings',
    'hint',
    'back',
  };

  /// Fire-and-forget; muting / a missing clip degrades to silence (errors are
  /// swallowed inside AudioCueService). MUST be called from a tap gesture.
  static void speak(String key) {
    if (!keys.contains(key)) return;
    _cue.play('audio/ui_ja/$key.mp3');
  }
}

/// An always-visible small speaker that reads [navKey]'s label aloud on tap.
/// Additive: place it beside (not instead of) the real, tappable nav element.
class SpeakerButton extends StatelessWidget {
  const SpeakerButton(
    this.navKey, {
    super.key,
    this.color,
    this.size = 20,
    this.semanticLabel = 'よみあげ',
  });

  final String navKey;
  final Color? color;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.volume_up_rounded, size: size, color: color),
      tooltip: semanticLabel,
      iconSize: size,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      splashRadius: size,
      onPressed: () => NavSpeak.speak(navKey),
    );
  }
}

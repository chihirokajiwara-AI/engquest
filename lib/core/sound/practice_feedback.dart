// lib/core/sound/practice_feedback.dart
//
// Shared answer-feedback "juice" for the 英検 practice screens (#51 game-feel,
// CEO 1320). The FSRS Battle already pairs a haptic tick + correct/wrong chime
// with every grade, but the actual 英検 exam-practice modes (vocab/reading/
// listening/conversation/word-ordering) gave only a flat green/red colour
// change — the core "passing" loop felt dead. A responsive answer is what makes
// a child want to do "one more problem".
//
// One shared SoundService instance (SFX synthesised on-demand, mute-aware) so
// the five screens don't each duplicate the field + preference load. Haptics are
// no-ops on web/desktop, which is fine — the chime carries the feedback there.

import 'package:flutter/services.dart';

import 'sound_service.dart';

class PracticeFeedback {
  PracticeFeedback._();

  static final SoundService _sound = SoundService();
  static bool _prefsRequested = false;

  static void _ensurePrefs() {
    if (_prefsRequested) return;
    _prefsRequested = true;
    // Fire-and-forget: loads the SFX-mute preference. The WAV data itself is
    // synthesised lazily inside SoundService, so playback never waits on this.
    _sound.loadPreferences();
  }

  /// Call once per answered question. Correct → light haptic + rising chime;
  /// wrong → a soft selection tick + the gentle "wrong" tone (never harsh —
  /// the screens already avoid shaming a child).
  static void answered({required bool correct}) {
    _ensurePrefs();
    if (correct) {
      HapticFeedback.lightImpact();
      _sound.playCorrect();
    } else {
      HapticFeedback.selectionClick();
      _sound.playWrong();
    }
  }

  /// Call when a practice session finishes (results screen) — a short fanfare.
  static void sessionComplete() {
    _ensurePrefs();
    _sound.playSessionComplete();
  }
}

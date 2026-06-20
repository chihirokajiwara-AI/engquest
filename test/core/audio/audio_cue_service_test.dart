// #183 — AudioCueService must not touch a disposed AudioPlayer. A 🔊 replay tap
// landing after dispose() (e.g. the #168 memo drawer tapped during scene-pop)
// must be a safe no-op, never build/play on the disposed player.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/audio/audio_cue_service.dart';

void main() {
  test('play() after dispose() is a guarded no-op (never builds a player)',
      () async {
    final cue = AudioCueService();
    cue.dispose();
    // Must not throw, and must NOT lazily construct/play on a disposed player.
    await cue.play('audio/phonics/phoneme_s.mp3');
    await cue.stop();
    expect(cue.debugPlayerCreated, isFalse,
        reason:
            'play()/stop() after dispose must early-return before touching the player');
  });
}

// #133 pre-literacy gate (flaw-hunt 2026-06-13): the tap-to-speak feature lets a
// non-reading 4–7yo hear a nav element's Japanese label. NavSpeak.speak(key)
// plays assets/audio/ui_ja/<key>.mp3 through the mute-gated AudioCueService, and
// a missing clip degrades SILENTLY to no sound. So every key in NavSpeak.keys
// MUST have a bundled clip — otherwise a future key added without its audio ships
// a speaker button that does nothing when a pre-reader taps it (a silent-failure
// regression). This locks the keys ↔ assets/audio/ui_ja/*.mp3 invariant.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/audio/nav_speak.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NavSpeak exposes the expected nav keys', () {
    expect(NavSpeak.keys, isNotEmpty);
  });

  for (final key in NavSpeak.keys) {
    test('NavSpeak key "$key" has a non-empty bundled ui_ja clip', () async {
      final data = await rootBundle.load('assets/audio/ui_ja/$key.mp3');
      expect(data.lengthInBytes, greaterThan(0),
          reason: 'assets/audio/ui_ja/$key.mp3 is missing or empty — '
              'tap-to-speak would be silent for this nav element');
    });
  }
}

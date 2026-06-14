// #133 pre-literacy gate (flaw-hunt 2026-06-13): the tap-to-speak feature lets a
// non-reading 4–7yo hear a nav element's Japanese label. NavSpeak.speak(key)
// plays assets/audio/ui_ja/<key>.mp3 through the mute-gated AudioCueService, and
// a missing clip degrades SILENTLY to no sound. So every key in NavSpeak.keys
// MUST have a bundled clip — otherwise a future key added without its audio ships
// a speaker button that does nothing when a pre-reader taps it (a silent-failure
// regression). This locks the keys ↔ assets/audio/ui_ja/*.mp3 invariant.

import 'package:flutter/material.dart';
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

  // Child-a11y (flaw-hunt 2026-06-14): the SpeakerButton is a non-reading 5yo's
  // primary affordance — its visual icon is small (~20px) but the TAP area must
  // be finger-sized (>=44, the Apple-HIG/Material child minimum). It used to
  // strip IconButton's min constraints down to ~32px.
  testWidgets('SpeakerButton has a >=44px tap target (small hands)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SpeakerButton('exam'))),
    ));
    final size = tester.getSize(find.byType(SpeakerButton));
    expect(size.width, greaterThanOrEqualTo(44),
        reason: 'tap target too narrow for a small child: ${size.width}');
    expect(size.height, greaterThanOrEqualTo(44),
        reason: 'tap target too short for a small child: ${size.height}');
  });
}

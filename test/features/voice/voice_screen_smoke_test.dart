// test/features/voice/voice_screen_smoke_test.dart
// R3 smoke test: pump VoiceScreen and assert no render exception.
// R4: initState forces PlatformVoiceChannel.demoMode = true (no native speech
// plugin) and sets up animation controllers only — no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/voice/voice_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VoiceScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception (demo mode)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VoiceScreen()));
      await tester.pump();
      // A pulse animation repeats — advance a couple frames, do not settle.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(VoiceScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

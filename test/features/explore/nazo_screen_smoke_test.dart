// test/features/explore/nazo_screen_smoke_test.dart
// R3 smoke test: pump NazoScreen (the explore puzzle / コトバ探偵 mini-mystery)
// with a real hotspot from kTown5Scene and assert no render exception.
// R4: HintCoinService + AudioCueService are test-safe (prefs mocked, no native
// playback); no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NazoScreen — smoke tests (R3)', () {
    testWidgets('first 5級 NPC hotspot — pumps without exception',
        (tester) async {
      final hotspot = kTown5Scene.hotspots.firstWhere(
        (h) => h.kind == HotspotKind.npc,
      );
      await tester.pumpWidget(MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NazoScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

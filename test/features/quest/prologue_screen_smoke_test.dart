// test/features/quest/prologue_screen_smoke_test.dart
// R3 smoke test: pump PrologueScreen (the opening cutscene) and assert no render
// exception. R4: AudioCueService is test-safe (no native playback on the
// flutter_test host); no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/quest/prologue_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PrologueScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception', (tester) async {
      // Dispose the screen before teardown so the S3 idle Timer is cancelled
      // (a pending Timer fails the test otherwise).
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(onDone: () {}),
      ));
      await tester.pump();
      expect(find.byType(PrologueScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('startIndex offset pumps without exception', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(onDone: () {}, startIndex: 1),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'opens on the 5級 town plate, NOT the 準1級 finale (council S2 canon)',
        (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      // WORLD-BIBLE §2 inward spiral: the OPENING is the 5級 misty edge, the 準1級
      // grey centre is the FINALE. The background must be the 5級 plate; opening on
      // town_pre1_grey_square (the palette-stripped 準1 finale) is the canon defect
      // the art-director caught. Lock it via the rendered Image asset path.
      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(onDone: () {}),
      ));
      await tester.pump();
      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image)
          .whereType<AssetImage>()
          .map((a) => a.assetName)
          .toList();
      expect(assets.any((a) => a.contains('town5')), isTrue,
          reason: 'prologue background must be the 5級 town plate');
      expect(assets.any((a) => a.contains('town_pre1')), isFalse,
          reason:
              'must NOT open on the 準1級 finale plate (inward-spiral canon)');
    });

    testWidgets(
        'S3: idle ~4s pulses the advance cue without breaking the screen',
        (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(MaterialApp(
        home: PrologueScreen(onDone: () {}),
      ));
      await tester.pump();
      // Sit idle past the 4s threshold → the non-reader pulse cue fires. On the
      // first (起) panel the agency control is 🔊「きいてみよう」 (#110: the child
      // sounds the keeper's broken す… before advancing); it must stay present
      // under the pulse and the screen must not throw.
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('きいてみよう'), findsOneWidget,
          reason:
              'the 起 tap-to-hear agency control stays usable under the pulse');
      expect(tester.takeException(), isNull);
      // Tapping it satisfies the agency gate → 'つぎの てがかりへ' appears.
      await tester.tap(find.textContaining('きいてみよう'));
      await tester.pump();
      expect(find.textContaining('てがかりへ'), findsOneWidget,
          reason: 'after hearing す…, the advance control appears');
    });
  });
}

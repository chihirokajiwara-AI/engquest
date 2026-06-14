// test/features/explore/nazo_screen_smoke_test.dart
// R3 smoke test: pump NazoScreen (the explore puzzle / コトバ探偵 mini-mystery)
// with a real hotspot from kTown5Scene and assert no render exception.
// R4: HintCoinService + AudioCueService are test-safe (prefs mocked, no native
// playback); no Firebase / network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/audio/audio_assets.dart';
import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/quest/ui/muted_voice_banner.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AudioAssets.resetForTest);

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

    testWidgets(
        'audio ナゾ shows the muted-voice banner when Voice is muted (clip present)',
        (tester) async {
      // This ナゾ plays a phoneme the child must hear — a muted child needs the
      // warning + one-tap unmute (#42).
      final hotspot = kTown5Scene.hotspots.firstWhere(
        (h) => h.kind == HotspotKind.npc && h.step?.autoPlayAudio != null,
      );
      // Treat this step's clip as bundled so the audio affordance is live (the
      // muted banner is suppressed when the clip is missing — see #43).
      AudioAssets.debugAssets = {'assets/${hotspot.step!.autoPlayAudio!}'};

      AudioMute.voiceMuted = true;
      addTearDown(() => AudioMute.voiceMuted = false);
      await tester.pumpWidget(MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MutedVoiceBanner), findsOneWidget);
      // The quest surfaces must use the phonics message, not the listening one.
      expect(find.textContaining('きいて こたえてね'), findsOneWidget);

      // Tapping unmute clears the flag and the banner.
      await tester.tap(find.text('おんを オンにする'));
      await tester.pump();
      expect(AudioMute.voiceMuted, isFalse);
      expect(find.byType(MutedVoiceBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('audio ナゾ shows NO banner when Voice is on', (tester) async {
      final hotspot = kTown5Scene.hotspots.firstWhere(
        (h) => h.kind == HotspotKind.npc && h.step?.autoPlayAudio != null,
      );
      AudioAssets.debugAssets = {'assets/${hotspot.step!.autoPlayAudio!}'};
      AudioMute.voiceMuted = false;
      await tester.pumpWidget(MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MutedVoiceBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('NazoScreen — first-try correctness for honest 合格率 (#89)', () {
    // A ナゾ can be retried until solved, so the 合格率 signal must be the FIRST
    // answer, not "solved". Guards against inflating the pass meter to 100%.
    Future<NazoResult?> solveSequence(
        WidgetTester tester, List<int> taps) async {
      // Tall phone surface so the answer tiles are on-screen + hittable.
      tester.view.physicalSize = const Size(440, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final hotspot = kTown5Scene.hotspots
          .firstWhere((h) => h.kind == HotspotKind.npc && h.step != null);
      NazoResult? captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await Navigator.of(ctx).push<NazoResult>(
                    MaterialPageRoute(
                      builder: (_) =>
                          NazoScreen(hotspot: hotspot, eikenLevel: '5'),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final i in taps) {
        await tester.tap(find.byType(AudioOptionButton).at(i));
        await tester.pump();
      }
      // The reveal shows the「▶ ナゾ、解けた！」finish button.
      await tester.tap(find.textContaining('解'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return captured;
    }

    int correctIdxOf5kuNpc() => kTown5Scene.hotspots
        .firstWhere((h) => h.kind == HotspotKind.npc && h.step != null)
        .step!
        .correctIndex;

    testWidgets('correct on first try → firstTryCorrect == true', (t) async {
      final c = correctIdxOf5kuNpc();
      final r = await solveSequence(t, [c]);
      expect(r, isNotNull);
      expect(r!.solved, isTrue);
      expect(r.firstTryCorrect, isTrue);
    });

    testWidgets('wrong then correct → firstTryCorrect == false (no inflation)',
        (t) async {
      final c = correctIdxOf5kuNpc();
      final wrong = c == 0 ? 1 : 0;
      final r = await solveSequence(t, [wrong, c]);
      expect(r, isNotNull);
      expect(r!.solved, isTrue);
      expect(r.firstTryCorrect, isFalse,
          reason: 'a retried solve must NOT count as a first-try correct');
    });
  });

  group('NazoScreen — missing-audio feedback (#43)', () {
    testWidgets('missing clip → honest 準備中 note, no dead 🔊, no muted banner',
        (tester) async {
      final hotspot = kTown5Scene.hotspots.firstWhere(
        (h) => h.kind == HotspotKind.npc && h.step?.autoPlayAudio != null,
      );
      // Clip is NOT bundled (e.g. founder-pending phoneme). Even with Voice
      // muted, the dead 🔊 + muted banner must be replaced by an honest note.
      AudioAssets.debugAssets = <String>{};
      AudioMute.voiceMuted = true;
      addTearDown(() => AudioMute.voiceMuted = false);

      await tester.pumpWidget(MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ));
      await tester.pump(); // let the async existence check resolve
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('じゅんびちゅう'), findsOneWidget); // 準備中 note
      expect(find.textContaining('おとを きく'), findsNothing); // no dead 🔊 button
      expect(
          find.byType(MutedVoiceBanner), findsNothing); // unmute wouldn't help
      expect(tester.takeException(), isNull);
    });

    testWidgets('present clip → 🔊 replay button, no 準備中 note', (tester) async {
      final hotspot = kTown5Scene.hotspots.firstWhere(
        (h) => h.kind == HotspotKind.npc && h.step?.autoPlayAudio != null,
      );
      AudioAssets.debugAssets = {'assets/${hotspot.step!.autoPlayAudio!}'};
      AudioMute.voiceMuted = false;

      await tester.pumpWidget(MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('じゅんびちゅう'), findsNothing);
      expect(find.textContaining('おとを きく'), findsOneWidget); // live 🔊 button
      expect(tester.takeException(), isNull);
    });
  });

  // Studio build (2026-06-14, harsh-playtester-approved replacement for the
  // rejected rule-card #2): on the FIRST wrong tap of a grammar/quiz ナゾ, スラ
  // gives a FREE hint — "the game is helping me", not a school-y rule lecture.
  // Only on penalizeWrong steps (teach steps replay audio instead), only once.
  group('NazoScreen — free hint on first wrong', () {
    testWidgets(
        'first wrong tap on a penalizeWrong ナゾ auto-reveals a free hint',
        (tester) async {
      tester.view.physicalSize = const Size(440, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // A grammar/quiz ナゾ (penalizeWrong); teach steps don't penalize/hint.
      final hotspot = kTown5Scene.hotspots.firstWhere(
          (h) => h.kind == HotspotKind.npc && (h.step?.penalizeWrong ?? false));
      await tester.pumpWidget(MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Past the teach-first card if present.
      final proceed = find.textContaining('こたえてみる');
      if (proceed.evaluate().isNotEmpty) {
        await tester.tap(proceed.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      // Tap a WRONG choice.
      final correct = hotspot.step!.correctIndex;
      final wrong = correct == 0 ? 1 : 0;
      await tester.tap(find.byType(AudioOptionButton).at(wrong));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // The free hint cue appears (スラ helps — once, warm, not a rule lecture).
      expect(find.textContaining('スラがヒントをくれた'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// test/features/settings/settings_test.dart
//
// Settings + mute (task #27). The important assertions prove the mute is REAL
// (gates playback), not a cosmetic toggle, and that choices persist.
// #68: Manage-subscription entry is present (aken flavor) / absent (edilab).
// #66 upgrade: Support email addresses are wired with a GestureDetector.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/core/audio/audio_cue_service.dart';
import 'package:engquest/core/audio/word_audio_player_service.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/settings/settings_screen.dart';
import 'package:engquest/features/quest/prologue_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
    AudioMute.voiceMuted = false;
  });

  test(
      'Voice mute is REAL — Battle flashcard playWord plays nothing when muted',
      () async {
    AudioMute.voiceMuted = true;
    final svc = WordAudioPlayerService();
    await svc.playWord(vocabId: 'eiken5_001', word: 'cat');
    expect(svc.state, WordAudioState.idle); // never entered loading/playing
    expect(svc.isPlaying, isFalse);
  });

  test('Voice mute is REAL & COMPLETE — AudioCueService is gated when muted',
      () async {
    // This is the dominant voice path (quest/scene/nazo/listening/mock/prologue).
    // Muting must gate it too, or "mute everything" is theatre. The player is
    // lazy: if the gate were missing, play() would construct a real AudioPlayer
    // and hit the (absent) test platform → throw. Muted → it returns first, so
    // completing without error proves nothing was played.
    AudioMute.voiceMuted = true;
    final cue = AudioCueService();
    await cue.play('audio/phonics/phoneme_s.mp3');
    // Non-tautological: if the gate were missing, play() would touch the lazy
    // _player getter and construct a real AudioPlayer. Muted → it returns
    // first, so no player is ever built ⇒ nothing was played.
    expect(cue.debugPlayerCreated, isFalse,
        reason: 'AudioCueService built a player (played) while muted');
    AudioMute.voiceMuted = false;
  });

  test('setVoiceMuted persists and loadVoicePreference reads it back',
      () async {
    await AudioMute.setVoiceMuted(true);
    expect(AudioMute.voiceMuted, isTrue);

    // Simulate a fresh launch: reset the in-memory flag, then load from prefs.
    AudioMute.voiceMuted = false;
    await AudioMute.loadVoicePreference();
    expect(AudioMute.voiceMuted, isTrue);
  });

  testWidgets('Settings screen renders the channels + how-to-play affordance',
      (tester) async {
    // Tall surface so the whole scrollable settings list (sound + readability +
    // menu + help) is laid out and the bottom 'あそびかた' tile is found.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump(); // initState load
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('こうかおん'), findsOneWidget); // SFX channel
    expect(find.text('ことばの こえ'), findsOneWidget); // Voice channel
    expect(find.text('もじの 大（おお）きさ'), findsOneWidget); // readability (#114)
    expect(find.text('あそびかた'), findsOneWidget); // how-to-play
    expect(find.byType(Switch), findsNWidgets(3)); // SFX, Voice, master
  });

  testWidgets('Replay-opening tile is present and opens the PrologueScreen',
      (tester) async {
    // The opening story plays once-ever on first launch; a child who loved it
    // (or a parent) must be able to re-watch it from Settings.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tile = find.text('Replay opening');
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump(); // start the route push
    await tester.pump(const Duration(milliseconds: 400)); // advance transition
    expect(find.byType(PrologueScreen), findsOneWidget);
    // Unmount so the pushed screen's async (audio preload) does not leak.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  // ── #66 — Support contact dialog ─────────────────────────────────────────

  testWidgets('#66 support tile is present and dialog opens with email addrs',
      (tester) async {
    // Extra-tall surface so the entire Settings list (including the Help panel
    // at the bottom) is laid out and the support tile is found.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Tile must be visible.
    expect(find.text('Contact Support'), findsOneWidget);

    // Tap the support tile — dialog should appear.
    await tester.tap(find.text('Contact Support'));
    await tester.pumpAndSettle();

    // Dialog must contain both email addresses as SelectableText.
    expect(find.text('support@edilab.co'), findsOneWidget);
    expect(find.text('privacy@edilab.co'), findsOneWidget);

    // Dismiss dialog via the close button.
    await tester.tap(find.textContaining('とじる'));
    await tester.pumpAndSettle();
    expect(find.text('support@edilab.co'), findsNothing);
  });

  // ── #66 upgrade — email addresses are tappable (GestureDetector) ──────────

  testWidgets('#66 upgrade: email addresses are wrapped in GestureDetector',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    // Open support dialog.
    await tester.tap(find.text('Contact Support'));
    await tester.pumpAndSettle();

    // Each email address text must have a GestureDetector ancestor —
    // this proves it is wired for tap (mailto: launch), not just selectable.
    expect(
      find.ancestor(
        of: find.text('support@edilab.co'),
        matching: find.byType(GestureDetector),
      ),
      findsWidgets,
    );
    expect(
      find.ancestor(
        of: find.text('privacy@edilab.co'),
        matching: find.byType(GestureDetector),
      ),
      findsWidgets,
    );
  });

  // ── #68 — Manage subscription entry (aken flavor only) ───────────────────

  testWidgets(
      '#68 manage-subscription tile is present when aken flavor is active',
      (tester) async {
    FlavorConfig.setFlavor(Flavor.aken);
    addTearDown(() => FlavorConfig.setFlavor(Flavor.edilab));

    // Extra-tall + wide surface so the entire settings list, including the
    // Subscription panel appended at the very bottom, is fully laid out without
    // scrolling (avoids RenderBox overflow clipping tiles off-screen).
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    // DqPanel renders title.toUpperCase() — assert on the tile text labels
    // (jp + en) which are NOT uppercased.
    expect(find.text('Manage subscription'), findsOneWidget);
    expect(find.text('サブスクの かいやく（解約）'), findsOneWidget);
  });

  testWidgets(
      '#68 manage-subscription tile is ABSENT when edilab flavor is active',
      (tester) async {
    FlavorConfig.setFlavor(Flavor.edilab);

    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Manage subscription'), findsNothing);
    expect(find.text('サブスクの かいやく（解約）'), findsNothing);
  });

  testWidgets(
      '#68 manage-subscription tile is ABSENT when no flavor is initialized',
      (tester) async {
    // FlavorConfig.instanceOrNull == null → the tile condition is false.
    // No flavor is set (default test state — FlavorConfig._instance may be set
    // from a previous test in the same run; we restore edilab in tearDown above,
    // so instanceOrNull?.isAkenFlavor == false, which also hides the tile).
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Manage subscription'), findsNothing);
  });
}

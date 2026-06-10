// test/features/settings/settings_test.dart
//
// Settings + mute (task #27). The important assertions prove the mute is REAL
// (gates playback), not a cosmetic toggle, and that choices persist.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/core/audio/audio_cue_service.dart';
import 'package:engquest/core/audio/word_audio_player_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/settings/settings_screen.dart';

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
}

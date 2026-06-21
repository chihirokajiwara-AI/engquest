// test/features/battle/proactive_audio_affordance_test.dart
//
// #175 diverse-values council binding verdict: a non-reader must never be
// presented with a live-looking 🔊 speaker that is silently dead.
//
// These tests verify the PROACTIVE (before first tap) audio-availability
// treatment on the battle card front face:
//   - A word KNOWN to lack a bundled clip → speaker absent/dimmed (no live
//     volume_up_rounded icon; tooltip = 'おとは じゅんびちゅう'; onPressed = null).
//   - A word KNOWN to have a bundled clip → speaker live (volume_up_rounded,
//     tooltip = '発音を聞く', tappable).
//
// The test seam: WordAudioPlayerService.seedCacheForTest() pre-populates the
// session prefetch cache so hasAudioSync() can answer synchronously without any
// rootBundle / TTS / audioplayers I/O.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/core/audio/word_audio_player_service.dart';
import 'package:engquest/core/data/vocab_repository.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/models/vocab_item.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

VocabItem _word(String id, String word) => VocabItem(
      id: id,
      word: word,
      reading: 'リーディング',
      jpTranslation: 'いみ',
      cefrLevel: CefrLevel.a1,
      eikenLevel: '5',
      pos: const [PartOfSpeech.noun],
      exampleSentences: ['I see a $word here.'],
    );

VocabRepository _seeded(List<VocabItem> words) =>
    VocabRepository()..seedForTest(words, grade: '5');

Future<void> _pumpLoad(WidgetTester t) async {
  for (var i = 0; i < 15; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'word WITHOUT bundled audio → speaker is absent/dimmed before any tap',
      (t) async {
    // eiken5_500 is beyond the 300-word manifest → no bundled clip.
    // We seed the cache explicitly so hasAudioSync() answers synchronously.
    final audioSvc = WordAudioPlayerService();
    audioSvc.seedCacheForTest({'eiken5_500': false}); // no audio

    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded([_word('eiken5_500', 'example')]),
        childAge: 10,
        eikenGrade: '5',
        wordAudioService: audioSvc,
      ),
    ));
    await _pumpLoad(t);

    // The live volume_up icon must NOT be present — that would be the "silently
    // dead" live button the council prohibits. onPressed:null disables it; we
    // verify by looking for the live-speaker tooltip vs. the absent one.
    expect(
      find.byTooltip('発音を聞く'),
      findsNothing,
      reason: 'a word with no audio must NOT show a live tap-to-hear button',
    );
    // The dimmed "じゅんびちゅう" affordance IS present so the non-reader sees an
    // honest state (not a completely hidden speaker that might confuse).
    expect(
      find.byTooltip('おとは じゅんびちゅう'),
      findsOneWidget,
      reason:
          'a word with no audio must show the じゅんびちゅう affordance before any tap',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'word WITH bundled audio → live speaker present and tappable before any tap',
      (t) async {
    // eiken5_001 is in the 300-word manifest → bundled clip exists.
    final audioSvc = WordAudioPlayerService();
    audioSvc.seedCacheForTest({'eiken5_001': true}); // has audio

    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded([_word('eiken5_001', 'cat')]),
        childAge: 10,
        eikenGrade: '5',
        wordAudioService: audioSvc,
      ),
    ));
    await _pumpLoad(t);

    // The live speaker must be present for a word that has audio.
    expect(
      find.byTooltip('発音を聞く'),
      findsOneWidget,
      reason: 'a word with audio must show the live tap-to-hear speaker',
    );
    // The absent/dimmed affordance must NOT appear for a word that has audio.
    expect(
      find.byTooltip('おとは じゅんびちゅう'),
      findsNothing,
      reason: 'a word with audio must not show the じゅんびちゅう disabled affordance',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'hasAudioSync returns true by default when word is not in cache '
      '(safe-present assumption → never hides working audio)', (t) async {
    // No cache seeding: word not in cache, manifest not loaded → safe default.
    final audioSvc = WordAudioPlayerService();
    // Do NOT call seedCacheForTest — simulate a cold start where prefetch hasn't
    // completed yet and the manifest hasn't loaded. hasAudioSync → true (safe).

    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded([_word('eiken5_999', 'unknown')]),
        childAge: 10,
        eikenGrade: '5',
        wordAudioService: audioSvc,
      ),
    ));
    await _pumpLoad(t);

    // With no cache entry and no manifest, hasAudioSync returns true (safe
    // default: show the live speaker rather than hiding potentially-real audio).
    expect(
      find.byTooltip('発音を聞く'),
      findsOneWidget,
      reason:
          'unknown-availability words must show a live speaker (safe default)',
    );
    expect(t.takeException(), isNull);
  });

  // Unit test: hasAudioSync logic (no widget required).
  test('hasAudioSync: cache hit controls availability', () {
    final svc = WordAudioPlayerService();
    svc.seedCacheForTest({'eiken5_001': true, 'eiken5_400': false});

    expect(svc.hasAudioSync('eiken5_001'), isTrue,
        reason: 'cache says available → true');
    expect(svc.hasAudioSync('eiken5_400'), isFalse,
        reason: 'cache says unavailable → false');
    expect(svc.hasAudioSync('eiken5_999'), isTrue,
        reason: 'not in cache, no manifest → safe default true');
  });
}

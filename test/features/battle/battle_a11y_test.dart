// Widget tests for the BattleScreen — possible now that the vocab repo is
// injectable (seeded, no rootBundle I/O). The production VocabRepository does
// asset I/O in init that never completes under flutter_test's FakeAsync clock,
// which is why the battle a11y fixes (#45/#46) and the empty-deck guard (#36)
// previously had NO widget test. These lock the screen-reader operability of the
// core review loop + the empty-deck guard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/core/data/vocab_repository.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/models/vocab_item.dart';

VocabItem _w(String id, String word) => VocabItem(
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
  // Past the async deck load (resolveUid offline + seeded vocab + in-memory
  // deck) — no rootBundle I/O now, so FakeAsync advances it.
  for (var i = 0; i < 15; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('flip card is a labelled screen-reader button (#45)', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded([_w('eiken5_001', 'cat'), _w('eiken5_002', 'dog')]),
        childAge: 10,
        eikenGrade: '5',
      ),
    ));
    await _pumpLoad(t);

    // The word is up (session is showing, not the spinner/empty state)…
    expect(find.byType(BattleScreen), findsOneWidget);
    // …and flipping it to reveal the meaning is exposed as a button, so a
    // screen-reader child can play the core review loop.
    expect(find.bySemanticsLabel(RegExp('めくって')), findsWidgets,
        reason: 'the flip card must be an operable button for screen readers');
    h.dispose();
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'after flip, recall is TWO child choices, not four FSRS grades (#84)',
      (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded([_w('eiken5_001', 'cat'), _w('eiken5_002', 'dog')]),
        childAge: 10,
        eikenGrade: '5',
      ),
    ));
    await _pumpLoad(t);

    // Flip the card to reveal the meaning → the recall grade buttons appear.
    await t.tap(find.bySemanticsLabel(RegExp('めくって')).first);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }

    // Two plain child choices — NOT the four FSRS grades a young child can't grade.
    expect(find.textContaining('わかった'), findsOneWidget);
    expect(find.textContaining('わからな'), findsOneWidget);
    expect(find.textContaining('むずかしい'), findsNothing,
        reason: 'the 4-grade FSRS UI (Hard/むずかしい) must be gone — #84');
    h.dispose();
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'the flashcard front exposes a tap-to-hear speaker for non-readers',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded([_w('eiken5_001', 'cat'), _w('eiken5_002', 'dog')]),
        childAge: 10,
        eikenGrade: '5',
      ),
    ));
    await _pumpLoad(t);

    // The core target user is a 4-7yo NON-READER: the learning card MUST let
    // them HEAR the English word — they cannot read it. The card front exposes
    // a tap-to-hear speaker (発音を聞く). Lock it so a refactor cannot silently
    // strip the non-reader's only way into a new word. (Audio uses the bundled
    // 5級 MP3 pronunciation via WordAudioPlayerService, not synthetic TTS.)
    expect(find.byTooltip('発音を聞く'), findsOneWidget,
        reason: 'the flashcard front must expose audio for non-readers');
    expect(t.takeException(), isNull);
  });

  testWidgets('flashcard does not RenderFlex-overflow on a short viewport',
      (t) async {
    // CI (Linux font metrics) hit a 56px bottom overflow when the card was given
    // < its natural content height (~460px) on a short viewport — would clip the
    // recall cue on a small phone. The card now scrolls/centres instead. Pump a
    // deliberately SHORT surface and assert no overflow exception is thrown.
    t.view.physicalSize = const Size(360, 460);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded([_w('eiken5_001', 'cat'), _w('eiken5_002', 'dog')]),
        childAge: 10,
        eikenGrade: '5',
      ),
    ));
    await _pumpLoad(t);
    expect(t.takeException(), isNull,
        reason: 'the flashcard must not overflow when height-constrained');
  });

  testWidgets('an empty deck shows the calm empty-state, not a crash (#36)',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: BattleScreen(
        repository: InMemoryFsrsCardRepository(),
        vocabRepo: _seeded(const []), // no vocab → empty deck
        childAge: 10,
        eikenGrade: '5',
      ),
    ));
    await _pumpLoad(t);
    expect(find.textContaining('じゅんびちゅう'), findsOneWidget,
        reason: 'empty deck must show the calm empty-state, never RangeError');
    expect(t.takeException(), isNull);
  });
}

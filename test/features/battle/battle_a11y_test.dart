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

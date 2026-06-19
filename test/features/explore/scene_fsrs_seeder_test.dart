// test/features/explore/scene_fsrs_seeder_test.dart
// Unit tests for the game⇄learning interconnect:
//   a word rescued in a scene ナゾ is seeded into the FSRS deck.
//
// Uses InMemoryFsrsCardRepository + VocabRepository.seedForTest so no
// rootBundle, no Firebase, no SharedPreferences platform channel needed.
//
// Coverage:
//   A. matched new word → card seeded (saveCards called) + recorded in prefs
//   B. already-in-deck word → NOT re-saved (existing card untouched)
//   C. unmatched word (not in vocab) → skipped
//   D. empty knewWords → no-op

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/data/vocab_repository.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/models/vocab_item.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/explore/scene_fsrs_seeder.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A minimal AuthService that always returns a fixed uid (no Firebase).
class _FakeAuthService extends AuthService {
  final String uid;
  _FakeAuthService({this.uid = 'test_uid'});

  @override
  Future<String> resolveUid() async => uid;
}

/// Tiny set of VocabItems for tests — no rootBundle needed.
List<VocabItem> _testVocab() => [
      _item('eiken5_001', 'cat'),
      _item('eiken5_002', 'apple'),
      _item('eiken5_003', 'dog'),
      _item('eiken5_004', 'ice cream'), // multi-word / stored as ice_cream
    ];

VocabItem _item(String id, String word) => VocabItem(
      id: id,
      word: word.replaceAll(' ', '_'), // vocab stores underscore-joined
      reading: '',
      jpTranslation: '',
      cefrLevel: CefrLevel.a1,
      eikenLevel: '5',
      pos: const [PartOfSpeech.noun],
      exampleSentences: const [],
    );

// Convenience: build a seeded VocabRepository with the test vocab.
VocabRepository _makeVocabRepo([List<VocabItem>? items]) {
  final repo = VocabRepository();
  repo.seedForTest(items ?? _testVocab(), grade: '5');
  return repo;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Set<String> _readOriginIds(SharedPreferences prefs) {
  final raw = prefs.getString(kSceneOriginVocabIdsKey);
  if (raw == null || raw.isEmpty) return {};
  return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    // Reset the PreferencesService singleton so each test gets a fresh prefs.
    PreferencesService.resetInstance();
    // Provide a backing SharedPreferences in-memory for the test.
    SharedPreferences.setMockInitialValues({});
  });

  group('seedSceneWords —', () {
    test('A: matched new word → card is seeded and recorded in prefs',
        () async {
      final cardRepo = InMemoryFsrsCardRepository();
      final vocabRepo = _makeVocabRepo();

      final seeded = await seedSceneWords(
        '5',
        {'cat'},
        vocabRepo: vocabRepo,
        cardRepo: cardRepo,
        auth: _FakeAuthService(),
      );

      expect(seeded, contains('eiken5_001'),
          reason: '"cat" maps to eiken5_001 and should be seeded');

      // Card in deck.
      final deck = await cardRepo.loadDeck('test_uid');
      expect(deck.any((c) => c.vocabId == 'eiken5_001'), isTrue);
      expect(deck.first.state, CardState.newCard,
          reason: 'seeded card must be state=new');

      // Recorded in prefs (scene-origin set).
      final prefs = await SharedPreferences.getInstance();
      expect(_readOriginIds(prefs), contains('eiken5_001'));
    });

    test('B: already-in-deck word → NOT re-saved, existing card untouched',
        () async {
      const uid = 'test_uid';
      final cardRepo = InMemoryFsrsCardRepository();
      // Pre-load a card with non-default state so we can detect mutation.
      final existingCard = FSRSCard(
        vocabId: 'eiken5_002',
        state: CardState.review,
        stability: 5.0,
        reps: 3,
      );
      await cardRepo.saveCard(uid, existingCard);

      final seeded = await seedSceneWords(
        '5',
        {'apple'}, // maps to eiken5_002 which is already in deck
        vocabRepo: _makeVocabRepo(),
        cardRepo: cardRepo,
        auth: _FakeAuthService(uid: uid),
      );

      // Should return empty — nothing new was seeded.
      expect(seeded, isEmpty);

      // Existing card must be UNCHANGED.
      final deck = await cardRepo.loadDeck(uid);
      final card = deck.firstWhere((c) => c.vocabId == 'eiken5_002');
      expect(card.state, CardState.review,
          reason: 'existing card state must not be reset');
      expect(card.stability, 5.0,
          reason: 'existing card stability must not be changed');
      expect(card.reps, 3);
    });

    test('C: unmatched word (not in vocab) → skipped, no card seeded',
        () async {
      final cardRepo = InMemoryFsrsCardRepository();

      final seeded = await seedSceneWords(
        '5',
        {'phonics_token', 'zzz_unknown'},
        vocabRepo: _makeVocabRepo(),
        cardRepo: cardRepo,
        auth: _FakeAuthService(),
      );

      expect(seeded, isEmpty);
      final deck = await cardRepo.loadDeck('test_uid');
      expect(deck, isEmpty);
    });

    test('D: empty knewWords → no-op', () async {
      final cardRepo = InMemoryFsrsCardRepository();
      bool saveCalled = false;

      // We can verify no-op by checking the deck is empty.
      final seeded = await seedSceneWords(
        '5',
        {}, // empty
        vocabRepo: _makeVocabRepo(),
        cardRepo: cardRepo,
        auth: _FakeAuthService(),
      );

      // Should short-circuit immediately.
      expect(seeded, isEmpty);
      final deck = await cardRepo.loadDeck('test_uid');
      expect(deck, isEmpty);
      // saveCalled check is moot since we can't spy on InMemory; deck empty is sufficient.
      expect(saveCalled, isFalse);
    });

    test('E: multi-word vocab (ice_cream) matched via space normalisation',
        () async {
      final cardRepo = InMemoryFsrsCardRepository();

      // ナゾ returns "ice cream" (spaced); vocab stores "ice_cream".
      final seeded = await seedSceneWords(
        '5',
        {'ice cream'},
        vocabRepo: _makeVocabRepo(),
        cardRepo: cardRepo,
        auth: _FakeAuthService(),
      );

      expect(seeded, contains('eiken5_004'));
      final deck = await cardRepo.loadDeck('test_uid');
      expect(deck.any((c) => c.vocabId == 'eiken5_004'), isTrue);
    });

    test('F: mixed set — new words seeded, existing skipped, unknown dropped',
        () async {
      const uid = 'test_uid';
      final cardRepo = InMemoryFsrsCardRepository();
      // Pre-enroll "apple" (eiken5_002).
      await cardRepo.saveCard(uid, FSRSCard(vocabId: 'eiken5_002'));

      final seeded = await seedSceneWords(
        '5',
        {'cat', 'apple', 'unknown_xyz'},
        vocabRepo: _makeVocabRepo(),
        cardRepo: cardRepo,
        auth: _FakeAuthService(uid: uid),
      );

      // Only "cat" is new and in vocab.
      expect(seeded, ['eiken5_001']);
      final deck = await cardRepo.loadDeck(uid);
      // Deck has apple (pre-existing) + cat (new).
      expect(deck.length, 2);
    });
  });

  group('loadSceneOriginVocabIds —', () {
    test('returns empty set when prefs is empty', () async {
      final ids = await loadSceneOriginVocabIds();
      expect(ids, isEmpty);
    });

    test('returns the set written by seedSceneWords', () async {
      final cardRepo = InMemoryFsrsCardRepository();
      await seedSceneWords(
        '5',
        {'cat', 'dog'},
        vocabRepo: _makeVocabRepo(),
        cardRepo: cardRepo,
        auth: _FakeAuthService(),
      );

      final ids = await loadSceneOriginVocabIds();
      expect(ids, containsAll(['eiken5_001', 'eiken5_003']));
    });
  });
}

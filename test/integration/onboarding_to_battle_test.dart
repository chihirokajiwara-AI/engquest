// test/integration/onboarding_to_battle_test.dart
// ENG Quest — Integration: Onboarding → World Map → Battle Entry
//
// Tests the full user registration flow:
//   Complete onboarding → result persisted → world map available → battle launched
//
// This is a logic-layer test (no Flutter widgets) — it exercises:
//   - OnboardingResult construction
//   - OnboardingPreferences persistence (in-memory stub)
//   - Transition decision logic (isOnboarded → route selection)
//   - BattleSession initialisation from world map entry
//
// Run: dart test test/integration/onboarding_to_battle_test.dart

import 'package:test/test.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';
import 'package:engquest/core/fsrs/fsrs_algorithm.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/models/vocab_item.dart';

// ---------------------------------------------------------------------------
// In-memory SharedPreferences stub
// (replaces shared_preferences package for testability)
// ---------------------------------------------------------------------------

class _InMemoryPrefs {
  final Map<String, dynamic> _store = {};

  bool getBool(String key) => (_store[key] as bool?) ?? false;
  String? getString(String key) => _store[key] as String?;
  int getInt(String key) => (_store[key] as int?) ?? 0;

  void setBool(String key, bool value) => _store[key] = value;
  void setString(String key, String value) => _store[key] = value;
  void setInt(String key, int value) => _store[key] = value;

  void clear() => _store.clear();
}

// ---------------------------------------------------------------------------
// OnboardingPreferences — persistence logic extracted from main.dart
// ---------------------------------------------------------------------------

class OnboardingPreferences {
  final _InMemoryPrefs _prefs;
  static const String _keyComplete = 'onboarding_complete';
  static const String _keyAge = 'onboarding_age';
  static const String _keyCefr = 'onboarding_cefr';
  static const String _keyAvatar = 'onboarding_avatar';
  static const String _keyGoal = 'onboarding_goal_minutes';

  // ignore: library_private_types_in_public_api
  OnboardingPreferences(this._prefs);

  bool get isOnboardingComplete => _prefs.getBool(_keyComplete);

  void save(OnboardingResult result) {
    _prefs.setBool(_keyComplete, true);
    _prefs.setInt(_keyAge, result.ageYears);
    _prefs.setString(_keyCefr, result.cefrPlacement.name);
    _prefs.setString(_keyAvatar, result.avatarId);
    _prefs.setInt(_keyGoal, result.dailyGoalMinutes);
  }

  OnboardingResult? load() {
    if (!isOnboardingComplete) return null;
    return OnboardingResult(
      ageYears: _prefs.getInt(_keyAge),
      cefrPlacement: CefrPlacement.values.firstWhere(
        (e) => e.name == _prefs.getString(_keyCefr),
        orElse: () => CefrPlacement.a1,
      ),
      avatarId: _prefs.getString(_keyAvatar) ?? 'knight',
      dailyGoalMinutes: _prefs.getInt(_keyGoal),
    );
  }
}

// ---------------------------------------------------------------------------
// Route decision logic (mirrors app.dart startup behaviour)
// ---------------------------------------------------------------------------

enum AppRoute { onboarding, worldMap }

AppRoute resolveStartRoute(OnboardingPreferences prefs) {
  return prefs.isOnboardingComplete ? AppRoute.worldMap : AppRoute.onboarding;
}

// ---------------------------------------------------------------------------
// Minimal BattleSession for integration verification
// ---------------------------------------------------------------------------

const _seedVocab = [
  VocabItem(
    id: 'eiken5_001', word: 'cat', reading: 'キャット', jpTranslation: 'ねこ',
    cefrLevel: CefrLevel.a1, eikenLevel: '5', pos: [PartOfSpeech.noun],
    exampleSentences: ['I have a cat.'],
  ),
  VocabItem(
    id: 'eiken5_002', word: 'dog', reading: 'ドッグ', jpTranslation: 'いぬ',
    cefrLevel: CefrLevel.a1, eikenLevel: '5', pos: [PartOfSpeech.noun],
    exampleSentences: ['My dog is big.'],
  ),
];

List<FSRSCard> buildDeckFromPlacement(CefrPlacement placement) {
  // In MVP, A1/beginner both use the same A1 word list
  return FSRSAlgorithm.buildDeck(
    _seedVocab.map((v) => v.id).toList(),
  );
}

// ---------------------------------------------------------------------------
// Integration tests
// ---------------------------------------------------------------------------

void main() {
  late _InMemoryPrefs prefs;
  late OnboardingPreferences onboardingPrefs;

  setUp(() {
    prefs = _InMemoryPrefs();
    onboardingPrefs = OnboardingPreferences(prefs);
  });

  group('Onboarding completion', () {
    test('fresh install routes to onboarding', () {
      final route = resolveStartRoute(onboardingPrefs);
      expect(route, equals(AppRoute.onboarding));
    });

    test('OnboardingResult can be constructed with all required fields', () {
      const result = OnboardingResult(
        ageYears: 8,
        cefrPlacement: CefrPlacement.a1,
        avatarId: 'knight',
        dailyGoalMinutes: 10,
      );
      expect(result.ageYears, equals(8));
      expect(result.cefrPlacement, equals(CefrPlacement.a1));
      expect(result.avatarId, equals('knight'));
      expect(result.dailyGoalMinutes, equals(10));
    });

    test('saving OnboardingResult marks onboarding as complete', () {
      expect(onboardingPrefs.isOnboardingComplete, isFalse);
      onboardingPrefs.save(const OnboardingResult(
        ageYears: 10,
        cefrPlacement: CefrPlacement.a1,
        avatarId: 'mage',
        dailyGoalMinutes: 15,
      ));
      expect(onboardingPrefs.isOnboardingComplete, isTrue);
    });

    test('route resolves to worldMap after onboarding saved', () {
      onboardingPrefs.save(const OnboardingResult(
        ageYears: 7,
        cefrPlacement: CefrPlacement.beginner,
        avatarId: 'archer',
        dailyGoalMinutes: 10,
      ));
      final route = resolveStartRoute(onboardingPrefs);
      expect(route, equals(AppRoute.worldMap));
    });
  });

  group('OnboardingResult persistence round-trip', () {
    test('saved result can be loaded back with all fields intact', () {
      const original = OnboardingResult(
        ageYears: 12,
        cefrPlacement: CefrPlacement.a2,
        avatarId: 'healer',
        dailyGoalMinutes: 20,
      );
      onboardingPrefs.save(original);
      final loaded = onboardingPrefs.load();
      expect(loaded, isNotNull);
      expect(loaded!.ageYears, equals(12));
      expect(loaded.cefrPlacement, equals(CefrPlacement.a2));
      expect(loaded.avatarId, equals('healer'));
      expect(loaded.dailyGoalMinutes, equals(20));
    });

    test('load returns null when onboarding not complete', () {
      expect(onboardingPrefs.load(), isNull);
    });

    test('all CefrPlacement values survive round-trip', () {
      for (final placement in CefrPlacement.values) {
        prefs.clear();
        final fresh = OnboardingPreferences(prefs);
        fresh.save(OnboardingResult(
          ageYears: 8,
          cefrPlacement: placement,
          avatarId: 'knight',
          dailyGoalMinutes: 10,
        ));
        expect(fresh.load()!.cefrPlacement, equals(placement));
      }
    });

    test('all avatar IDs survive round-trip', () {
      const avatarIds = ['knight', 'mage', 'archer', 'healer', 'rogue'];
      for (final id in avatarIds) {
        prefs.clear();
        final fresh = OnboardingPreferences(prefs);
        fresh.save(OnboardingResult(
          ageYears: 8,
          cefrPlacement: CefrPlacement.a1,
          avatarId: id,
          dailyGoalMinutes: 10,
        ));
        expect(fresh.load()!.avatarId, equals(id));
      }
    });
  });

  group('World map → Battle entry', () {
    test('A1 placement builds a non-empty battle deck', () {
      const result = OnboardingResult(
        ageYears: 8,
        cefrPlacement: CefrPlacement.a1,
        avatarId: 'knight',
        dailyGoalMinutes: 10,
      );
      final deck = buildDeckFromPlacement(result.cefrPlacement);
      expect(deck, isNotEmpty);
      expect(deck.length, equals(_seedVocab.length));
    });

    test('beginner placement also produces A1 deck', () {
      final deckBeginner = buildDeckFromPlacement(CefrPlacement.beginner);
      final deckA1 = buildDeckFromPlacement(CefrPlacement.a1);
      expect(deckBeginner.length, equals(deckA1.length));
    });

    test('all deck cards start as newCard state', () {
      final deck = buildDeckFromPlacement(CefrPlacement.a1);
      for (final card in deck) {
        expect(card.state, equals(CardState.newCard));
      }
    });

    test('all deck cards are due immediately on first session', () {
      final deck = buildDeckFromPlacement(CefrPlacement.a1);
      final fsrs = FSRSAlgorithm();
      final due = fsrs.getDueCards(deck, DateTime.now());
      expect(due.length, equals(deck.length));
    });

    test('complete flow: fresh install → onboard → world map → battle ready', () {
      // 1. Fresh install → onboarding route
      expect(resolveStartRoute(onboardingPrefs), equals(AppRoute.onboarding));

      // 2. Complete onboarding
      const result = OnboardingResult(
        ageYears: 9,
        cefrPlacement: CefrPlacement.a1,
        avatarId: 'mage',
        dailyGoalMinutes: 15,
      );
      onboardingPrefs.save(result);

      // 3. Next launch → world map
      expect(resolveStartRoute(onboardingPrefs), equals(AppRoute.worldMap));

      // 4. Load persisted profile
      final profile = onboardingPrefs.load()!;
      expect(profile.avatarId, equals('mage'));

      // 5. Enter battle from world map
      final deck = buildDeckFromPlacement(profile.cefrPlacement);
      expect(deck, isNotEmpty);

      // 6. All cards due → session can start
      final fsrs = FSRSAlgorithm();
      final dueCards = fsrs.getDueCards(deck, DateTime.now());
      expect(dueCards.length, equals(deck.length));
    });
  });
}

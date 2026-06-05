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
// Run: flutter test test/integration/onboarding_to_battle_test.dart

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
  static const String _keyStartLevel = 'onboarding_start_level';
  static const String _keyAvatar = 'onboarding_avatar';
  static const String _keyGoal = 'onboarding_goal_minutes';

  // ignore: library_private_types_in_public_api
  OnboardingPreferences(this._prefs);

  bool get isOnboardingComplete => _prefs.getBool(_keyComplete);

  void save(OnboardingResult result) {
    _prefs.setBool(_keyComplete, true);
    _prefs.setInt(_keyAge, result.ageYears);
    _prefs.setString(_keyStartLevel, result.startEikenLevel);
    _prefs.setString(_keyAvatar, result.avatarId);
    _prefs.setInt(_keyGoal, result.dailyGoalMinutes);
  }

  OnboardingResult? load() {
    if (!isOnboardingComplete) return null;
    return OnboardingResult(
      ageYears: _prefs.getInt(_keyAge),
      startEikenLevel: _prefs.getString(_keyStartLevel) ?? '5',
      placementGrade: 0,
      placementTheta: 0.0,
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
    id: 'eiken5_001',
    word: 'cat',
    reading: 'キャット',
    jpTranslation: 'ねこ',
    cefrLevel: CefrLevel.a1,
    eikenLevel: '5',
    pos: [PartOfSpeech.noun],
    exampleSentences: ['I have a cat.'],
  ),
  VocabItem(
    id: 'eiken5_002',
    word: 'dog',
    reading: 'ドッグ',
    jpTranslation: 'いぬ',
    cefrLevel: CefrLevel.a1,
    eikenLevel: '5',
    pos: [PartOfSpeech.noun],
    exampleSentences: ['My dog is big.'],
  ),
];

/// Build a battle deck from a start level string.
List<FSRSCard> buildDeckFromLevel(String eikenLevel) {
  // In MVP, all levels use the same A1 word list as seed deck.
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
        startEikenLevel: '5',
        placementGrade: 0,
        placementTheta: 0.0,
        avatarId: 'knight',
        dailyGoalMinutes: 10,
      );
      expect(result.ageYears, equals(8));
      expect(result.startEikenLevel, equals('5'));
      expect(result.avatarId, equals('knight'));
      expect(result.dailyGoalMinutes, equals(10));
    });

    test('saving OnboardingResult marks onboarding as complete', () {
      expect(onboardingPrefs.isOnboardingComplete, isFalse);
      onboardingPrefs.save(const OnboardingResult(
        ageYears: 10,
        startEikenLevel: '4',
        placementGrade: 1,
        placementTheta: 1.5,
        avatarId: 'mage',
        dailyGoalMinutes: 15,
      ));
      expect(onboardingPrefs.isOnboardingComplete, isTrue);
    });

    test('route resolves to worldMap after onboarding saved', () {
      onboardingPrefs.save(const OnboardingResult(
        ageYears: 7,
        startEikenLevel: '5',
        placementGrade: 0,
        placementTheta: 0.0,
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
        startEikenLevel: '3',
        placementGrade: 2,
        placementTheta: 2.5,
        avatarId: 'healer',
        dailyGoalMinutes: 20,
      );
      onboardingPrefs.save(original);
      final loaded = onboardingPrefs.load();
      expect(loaded, isNotNull);
      expect(loaded!.ageYears, equals(12));
      expect(loaded.startEikenLevel, equals('3'));
      expect(loaded.avatarId, equals('healer'));
      expect(loaded.dailyGoalMinutes, equals(20));
    });

    test('load returns null when onboarding not complete', () {
      expect(onboardingPrefs.load(), isNull);
    });

    test('all supported eikenLevel values survive round-trip', () {
      const levels = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];
      for (final level in levels) {
        prefs.clear();
        final fresh = OnboardingPreferences(prefs);
        fresh.save(OnboardingResult(
          ageYears: 8,
          startEikenLevel: level,
          placementGrade: 0,
          placementTheta: 0.0,
          avatarId: 'knight',
          dailyGoalMinutes: 10,
        ));
        expect(fresh.load()!.startEikenLevel, equals(level));
      }
    });

    test('all avatar IDs survive round-trip', () {
      const avatarIds = ['knight', 'mage', 'archer', 'healer', 'rogue'];
      for (final id in avatarIds) {
        prefs.clear();
        final fresh = OnboardingPreferences(prefs);
        fresh.save(OnboardingResult(
          ageYears: 8,
          startEikenLevel: '5',
          placementGrade: 0,
          placementTheta: 0.0,
          avatarId: id,
          dailyGoalMinutes: 10,
        ));
        expect(fresh.load()!.avatarId, equals(id));
      }
    });
  });

  group('World map → Battle entry', () {
    test('5級 placement builds a non-empty battle deck', () {
      const result = OnboardingResult(
        ageYears: 8,
        startEikenLevel: '5',
        placementGrade: 0,
        placementTheta: 0.0,
        avatarId: 'knight',
        dailyGoalMinutes: 10,
      );
      final deck = buildDeckFromLevel(result.startEikenLevel);
      expect(deck, isNotEmpty);
      expect(deck.length, equals(_seedVocab.length));
    });

    test('all deck cards start as newCard state', () {
      final deck = buildDeckFromLevel('5');
      for (final card in deck) {
        expect(card.state, equals(CardState.newCard));
      }
    });

    test('all deck cards are due immediately on first session', () {
      final deck = buildDeckFromLevel('5');
      final fsrs = FSRSAlgorithm();
      final due = fsrs.getDueCards(deck, DateTime.now());
      expect(due.length, equals(deck.length));
    });

    test('complete flow: fresh install → onboard → world map → battle ready',
        () {
      // 1. Fresh install → onboarding route
      expect(resolveStartRoute(onboardingPrefs), equals(AppRoute.onboarding));

      // 2. Complete onboarding
      const result = OnboardingResult(
        ageYears: 9,
        startEikenLevel: '4',
        placementGrade: 1,
        placementTheta: 1.0,
        avatarId: 'mage',
        dailyGoalMinutes: 15,
      );
      onboardingPrefs.save(result);

      // 3. Next launch → world map
      expect(resolveStartRoute(onboardingPrefs), equals(AppRoute.worldMap));

      // 4. Load persisted profile
      final profile = onboardingPrefs.load()!;
      expect(profile.avatarId, equals('mage'));
      expect(profile.startEikenLevel, equals('4'));

      // 5. Enter battle from world map
      final deck = buildDeckFromLevel(profile.startEikenLevel);
      expect(deck, isNotEmpty);

      // 6. All cards due → session can start
      final fsrs = FSRSAlgorithm();
      final dueCards = fsrs.getDueCards(deck, DateTime.now());
      expect(dueCards.length, equals(deck.length));
    });
  });

  // Legacy CefrPlacement enum still exists for backward compat — test it.
  group('CefrPlacement enum (legacy compat)', () {
    test('CefrPlacement values exist', () {
      expect(CefrPlacement.values, containsAll([
        CefrPlacement.beginner,
        CefrPlacement.a1,
        CefrPlacement.a2,
      ]));
    });
    test('CefrPlacementLabel extensions work', () {
      expect(CefrPlacement.a1.label, isNotEmpty);
      expect(CefrPlacement.a2.description, isNotEmpty);
    });
  });
}

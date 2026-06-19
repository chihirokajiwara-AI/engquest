// lib/features/explore/scene_fsrs_seeder.dart
// Game⇄learning interconnect (#2 studio roadmap): a word a child RESCUES in a
// scene ナゾ enters their FSRS spaced-review deck so it surfaces in Battle with
// the "まちで であった" tag — closing the world→review loop.
//
// SAFE SCOPE: SEED only (insert new FSRSCard for words not yet in the deck).
// Never modify an existing card. Never touch intervals. Touches:
//   - FsrsCardRepository.loadDeck / saveCards (batch insert)
//   - PreferencesService (scene_origin_vocab_ids JSON set)
//   - VocabRepository.getAll() for the word→vocabId lookup map
// Fire-and-forget from _applyRestore; non-fatal (never breaks UI flow).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/data/vocab_repository.dart';
import '../../core/firebase/auth_service.dart';
import '../../core/fsrs/fsrs_card.dart';
import '../../core/fsrs/fsrs_card_repository.dart';
import '../../core/storage/preferences_service.dart';

// ---------------------------------------------------------------------------
// Shared preferences key for the "scene-origin" vocab id set.
// Read by BattleScreen to show the "まちで であった" tag on the card front.
// ---------------------------------------------------------------------------

/// SharedPreferences key that holds a JSON-encoded list of vocabIds that were
/// seeded from ナゾ rescues.  BattleScreen loads this once and uses it to show
/// the "まちで であった ことば" tag on matching cards.
const String kSceneOriginVocabIdsKey = 'scene_origin_vocab_ids';

// ---------------------------------------------------------------------------
// Seeder — pure-Dart, no Flutter widget dependency
// ---------------------------------------------------------------------------

/// Seeds [englishWords] (first-try-correct words from a ナゾ solve) into the
/// FSRS deck for the current user.
///
/// • Only words that (a) map to a vocabId in [grade]'s vocab AND (b) are NOT
///   already present in the user's deck are seeded.
/// • Existing cards are NEVER modified.
/// • Newly seeded vocabIds are recorded in SharedPreferences under
///   [kSceneOriginVocabIdsKey] so BattleScreen can show the world-tag.
/// • Returns the list of newly seeded vocabIds (empty if nothing new).
/// • All errors are caught and logged in debug mode; never rethrows so callers
///   can fire-and-forget safely.
///
/// [vocabRepo] and [cardRepo] are injectable for testing; the production call
/// passes [null] to use the defaults (rootBundle + Prefs-backed FSRS store).
Future<List<String>> seedSceneWords(
  String grade,
  Set<String> englishWords, {
  VocabRepository? vocabRepo,
  FsrsCardRepository? cardRepo,
  AuthService? auth,
}) async {
  if (englishWords.isEmpty) return const [];
  try {
    // 1. Resolve uid (stable, COPPA-anonymous).
    final authService = auth ?? AuthService();
    final uid = await authService.resolveUid();

    // 2. Build lowercased-trimmed word → vocabId map from grade vocab.
    final repo = vocabRepo ?? VocabRepository();
    if (!repo.isInitialized) {
      await repo.initialize(eikenGrade: grade);
    }
    final wordToId = <String, String>{};
    for (final item in repo.getAll()) {
      // item.word may be underscore-joined ("ice_cream") — normalise for match.
      final key = item.word.toLowerCase().trim().replaceAll('_', ' ');
      wordToId[key] = item.id;
    }

    // 3. Load existing deck to build the "already enrolled" Set<vocabId>.
    final fsrsRepo = cardRepo ?? PrefsFsrsCardRepository();
    final existingDeck = await fsrsRepo.loadDeck(uid);
    final existingIds = {for (final c in existingDeck) c.vocabId};

    // 4. Match englishWords → vocabIds; filter to new-only.
    final newCards = <FSRSCard>[];
    for (final w in englishWords) {
      final key = w.toLowerCase().trim().replaceAll('_', ' ');
      final id = wordToId[key];
      if (id == null) continue; // not in vocab — phonics token or unknown
      if (existingIds.contains(id)) continue; // already enrolled — skip
      newCards.add(FSRSCard(vocabId: id));
    }

    if (newCards.isEmpty) return const [];

    // 5. Persist the new cards (batch, no interval math).
    await fsrsRepo.saveCards(uid, newCards);

    // 6. Record vocabIds in the scene-origin prefs set so Battle can tag them.
    final seededIds = newCards.map((c) => c.vocabId).toList();
    await _appendSceneOriginIds(seededIds);

    if (kDebugMode) {
      debugPrint(
          '[SceneFsrsSeeder] seeded ${seededIds.length} cards: $seededIds');
    }
    return seededIds;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[SceneFsrsSeeder] non-fatal error: $e\n$st');
    }
    return const [];
  }
}

/// Appends [newIds] to the persistent scene-origin vocab id set in prefs.
Future<void> _appendSceneOriginIds(List<String> newIds) async {
  if (newIds.isEmpty) return;
  final prefs = await PreferencesService.getInstance();
  final existing = _readSceneOriginIds(prefs);
  final merged = {...existing, ...newIds};
  await prefs.setString(kSceneOriginVocabIdsKey, jsonEncode(merged.toList()));
}

/// Reads the scene-origin vocab id set from [prefs].
/// Returns an empty set on any parse error.
Set<String> _readSceneOriginIds(PreferencesService prefs) {
  final raw = prefs.getString(kSceneOriginVocabIdsKey);
  if (raw == null || raw.isEmpty) return {};
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<String>().toSet();
  } catch (_) {
    return {};
  }
}

// ---------------------------------------------------------------------------
// Public helper for BattleScreen: load the scene-origin set once.
// ---------------------------------------------------------------------------

/// Returns the Set of vocabIds that have been seeded from world ナゾ rescues.
/// BattleScreen calls this once in [_initDeckAsync] (or on mount) to determine
/// which cards earn the "まちで であった ことば" tag.
Future<Set<String>> loadSceneOriginVocabIds() async {
  try {
    final prefs = await PreferencesService.getInstance();
    return _readSceneOriginIds(prefs);
  } catch (_) {
    return {};
  }
}

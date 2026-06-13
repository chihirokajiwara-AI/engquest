// lib/core/fsrs/fsrs_card_repository.dart
// ENG Quest — FSRS Card Repository (C-FSRS-PERSIST)
//
// Provides a persistence layer for FSRSCard state.
//
// Strategy:
//   - Interface: FsrsCardRepository (abstract)
//   - Production impl: SqliteFsrsCardRepository (sqflite-backed, for Flutter)
//   - Test/offline impl: InMemoryFsrsCardRepository (Map + JSON, no native deps)
//
// The InMemory impl is the only one activated in this sprint so that:
//   (a) tests run on plain Dart without Flutter / sqflite native libraries
//   (b) the app can launch and schedule cards without a DB bootstrap step
//
// Migration path: swap InMemoryFsrsCardRepository for SqliteFsrsCardRepository
//   once Flutter integration tests are set up.

import 'dart:convert';
import 'fsrs_card.dart';
import '../storage/preferences_service.dart';

// ---------------------------------------------------------------------------
// Repository interface
// ---------------------------------------------------------------------------

/// Abstract repository for FSRS card state.
///
/// Implementations must be safe to call concurrently (futures-based).
abstract class FsrsCardRepository {
  /// Load all cards for [userId].
  /// Returns an empty list if the user has no cards yet.
  Future<List<FSRSCard>> loadDeck(String userId);

  /// Persist [card] state (insert or replace by vocabId + userId).
  Future<void> saveCard(String userId, FSRSCard card);

  /// Save multiple cards in a single batch.
  Future<void> saveCards(String userId, List<FSRSCard> cards);

  /// Return cards whose [FSRSCard.dueDate] is on or before [now].
  Future<List<FSRSCard>> getDueCards(String userId, DateTime now);

  /// Delete all cards for [userId] (useful for testing / account reset).
  Future<void> clearDeck(String userId);
}

// ---------------------------------------------------------------------------
// In-memory implementation (Map + JSON round-trip)
// ---------------------------------------------------------------------------

/// Pure-Dart, no-native-dep implementation.
/// All data lives in a nested Map keyed by [userId] → [vocabId].
///
/// Cards are serialized to/from JSON on each write/read so the
/// serialization layer is exercised even in unit tests.
class InMemoryFsrsCardRepository implements FsrsCardRepository {
  // userId → vocabId → serialized JSON string
  final Map<String, Map<String, String>> _store = {};

  Map<String, String> _userStore(String userId) =>
      _store.putIfAbsent(userId, () => {});

  @override
  Future<List<FSRSCard>> loadDeck(String userId) async {
    final store = _userStore(userId);
    return store.values
        .map((json) => _fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveCard(String userId, FSRSCard card) async {
    _userStore(userId)[card.vocabId] = jsonEncode(_toJson(card));
  }

  @override
  Future<void> saveCards(String userId, List<FSRSCard> cards) async {
    final store = _userStore(userId);
    for (final card in cards) {
      store[card.vocabId] = jsonEncode(_toJson(card));
    }
  }

  @override
  Future<List<FSRSCard>> getDueCards(String userId, DateTime now) async {
    final all = await loadDeck(userId);
    // FSRSCard.isDue uses DateTime.now() internally; we compare dueDate directly
    return all
        .where((c) => c.dueDate == null || !now.isBefore(c.dueDate!))
        .toList();
  }

  @override
  Future<void> clearDeck(String userId) async {
    _store.remove(userId);
  }

  // ── JSON codec ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _toJson(FSRSCard c) => {
        'vocabId': c.vocabId,
        'state': c.state.value,
        'stability': c.stability,
        'difficulty': c.difficulty,
        'reps': c.reps,
        'lapses': c.lapses,
        'dueDate': c.dueDate?.toIso8601String(),
        'lastReview': c.lastReview?.toIso8601String(),
      };

  FSRSCard _fromJson(Map<String, dynamic> m) => FSRSCard(
        vocabId: m['vocabId'] as String,
        state: CardStateExtension.fromString(m['state'] as String),
        stability: (m['stability'] as num).toDouble(),
        difficulty: (m['difficulty'] as num).toDouble(),
        reps: m['reps'] as int,
        lapses: m['lapses'] as int,
        dueDate: m['dueDate'] != null
            ? DateTime.parse(m['dueDate'] as String)
            : null,
        lastReview: m['lastReview'] != null
            ? DateTime.parse(m['lastReview'] as String)
            : null,
      );
}

// ---------------------------------------------------------------------------
// Schema documentation (for future SqliteFsrsCardRepository)
// ---------------------------------------------------------------------------
//
// CREATE TABLE IF NOT EXISTS fsrs_cards (
//   user_id     TEXT NOT NULL,
//   vocab_id    TEXT NOT NULL,
//   state       TEXT NOT NULL DEFAULT 'new',
//   stability   REAL NOT NULL DEFAULT 0.0,
//   difficulty  REAL NOT NULL DEFAULT 0.0,
//   reps        INTEGER NOT NULL DEFAULT 0,
//   lapses      INTEGER NOT NULL DEFAULT 0,
//   due_date    TEXT,          -- ISO-8601 UTC
//   last_review TEXT,          -- ISO-8601 UTC
//   PRIMARY KEY (user_id, vocab_id)
// );
//
// CREATE INDEX IF NOT EXISTS idx_due_date ON fsrs_cards(user_id, due_date);
//
// SqliteFsrsCardRepository will:
//   - Open DB at getDatabasesPath()/engquest.db
//   - Run migrations in onCreate/onUpgrade
//   - Use batch() for saveCards()
//   - Map Dart DateTime ↔ ISO-8601 string

// ---------------------------------------------------------------------------
// SharedPreferences-backed implementation (durable, web-safe, no native dep)
// ---------------------------------------------------------------------------

/// Persists each user's FSRS deck to SharedPreferences (= localStorage on web)
/// as one JSON map per user, so a child's spaced-repetition memory SURVIVES a
/// page reload — including OFFLINE, where Firestore is unreachable and the deck
/// would otherwise live only in a wiped-on-reload in-memory Map (flaw-hunt
/// 2026-06-13). Mirrors VocabReviewStore's prefs pattern. The other progress
/// stores (streak / 合格率 / scene-solved / review) already persist this way;
/// this gives the FSRS deck — the spaced-repetition core — the same durability.
class PrefsFsrsCardRepository implements FsrsCardRepository {
  static String _key(String userId) => 'fsrs_deck_$userId';

  Future<Map<String, dynamic>> _read(String userId) async {
    final prefs = await PreferencesService.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {}; // corrupt entry → start fresh rather than crash
    }
  }

  Future<void> _write(String userId, Map<String, dynamic> map) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setString(_key(userId), jsonEncode(map));
  }

  @override
  Future<List<FSRSCard>> loadDeck(String userId) async {
    final map = await _read(userId);
    return map.values
        .map((j) => FSRSCard.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveCard(String userId, FSRSCard card) async {
    final map = await _read(userId);
    map[card.vocabId] = card.toJson();
    await _write(userId, map);
  }

  @override
  Future<void> saveCards(String userId, List<FSRSCard> cards) async {
    if (cards.isEmpty) return;
    final map = await _read(userId);
    for (final c in cards) {
      map[c.vocabId] = c.toJson();
    }
    await _write(userId, map);
  }

  @override
  Future<List<FSRSCard>> getDueCards(String userId, DateTime now) async {
    final all = await loadDeck(userId);
    return all
        .where((c) => c.dueDate == null || !now.isBefore(c.dueDate!))
        .toList();
  }

  @override
  Future<void> clearDeck(String userId) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.remove(_key(userId));
  }
}

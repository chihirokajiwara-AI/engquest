// lib/core/fsrs/firestore_card_repository.dart
// ENG Quest — Firestore-backed FSRS Card Repository (P0.1)
//
// Production implementation of FsrsCardRepository that persists card state
// to Cloud Firestore under users/{uid}/cards/{vocabId}.
//
// Features:
//   - Offline persistence enabled (FirebaseFirestore.Settings.persistenceEnabled)
//   - Graceful fallback to InMemoryFsrsCardRepository on Firestore errors
//   - Batch writes via WriteBatch for saveCards()
//   - getDueCards uses compound query: state != 'review' OR dueDate <= now
//     (new/learning/relearning cards are always due; review cards checked by dueDate)
//
// Firestore schema:
//   Collection: users/{uid}/cards
//   Document ID: vocabId (e.g. "eiken5_001")
//   Fields:
//     stability   : double
//     difficulty  : double
//     state       : string ('new'|'learning'|'review'|'relearning')
//     dueDate     : Timestamp (null for brand-new cards)
//     lastReview  : Timestamp (null for unreviewed cards)
//     lapses      : int
//     repetitions : int  (= FSRSCard.reps)
//     updatedAt   : Timestamp (server timestamp, for conflict resolution)

import 'package:cloud_firestore/cloud_firestore.dart';

import 'fsrs_card.dart';
import 'fsrs_card_repository.dart';

/// Firestore-backed repository with offline fallback.
///
/// Usage:
/// ```dart
/// final repo = FirestoreFsrsCardRepository();
/// // or inject instance for testing:
/// final repo = FirestoreFsrsCardRepository(firestore: mockFirestore);
/// ```
class FirestoreFsrsCardRepository implements FsrsCardRepository {
  // Lazily resolved so constructing the repository never touches
  // FirebaseFirestore.instance, which throws when Firebase failed to
  // initialize (offline/placeholder keys). Every _db usage below is inside a
  // try/catch that falls back to [_fallback], so a lazy throw degrades to the
  // in-memory repo rather than blanking the Battle screen at construction.
  final FirebaseFirestore? _injectedDb;
  FirebaseFirestore? _dbCache;
  final FsrsCardRepository _fallback = PrefsFsrsCardRepository();

  FirestoreFsrsCardRepository({FirebaseFirestore? firestore})
      : _injectedDb = firestore;

  /// Resolves (and memoizes) the Firestore instance on first use, configuring
  /// offline persistence once. May throw if Firebase is unavailable — callers
  /// wrap usage in try/catch and fall back to [_fallback].
  FirebaseFirestore get _db {
    final cached = _dbCache;
    if (cached != null) return cached;
    final db = _injectedDb ?? FirebaseFirestore.instance;
    _dbCache = db;
    _configureOfflinePersistence(db);
    return db;
  }

  // ── Offline persistence ───────────────────────────────────────────────────

  void _configureOfflinePersistence(FirebaseFirestore db) {
    try {
      db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {
      // Settings can only be set once per Firestore instance.
      // Silently ignore if already configured (e.g. in tests).
    }
  }

  // ── Collection reference ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _cardsCol(String userId) =>
      _db.collection('users').doc(userId).collection('cards');

  // ── Codec ─────────────────────────────────────────────────────────────────

  /// Serialize FSRSCard to Firestore field map.
  Map<String, dynamic> _toFirestore(FSRSCard card) => {
        'stability': card.stability,
        'difficulty': card.difficulty,
        'state': card.state.value,
        'dueDate':
            card.dueDate != null ? Timestamp.fromDate(card.dueDate!) : null,
        'lastReview': card.lastReview != null
            ? Timestamp.fromDate(card.lastReview!)
            : null,
        'lapses': card.lapses,
        'repetitions': card.reps,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Deserialize a Firestore document snapshot to FSRSCard.
  FSRSCard _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return FSRSCard(
      vocabId: snap.id,
      stability: (d['stability'] as num?)?.toDouble() ?? 0.0,
      difficulty: (d['difficulty'] as num?)?.toDouble() ?? 0.0,
      state: CardStateExtension.fromString(d['state'] as String? ?? 'new'),
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      lastReview: (d['lastReview'] as Timestamp?)?.toDate(),
      lapses: (d['lapses'] as int?) ?? 0,
      reps: (d['repetitions'] as int?) ?? 0,
    );
  }

  // ── Interface implementation ───────────────────────────────────────────────

  @override
  Future<List<FSRSCard>> loadDeck(String userId) async {
    try {
      final snap = await _cardsCol(userId).get();
      final firestoreCards = snap.docs.map((d) => _fromSnapshot(d)).toList();

      // Mirror to fallback so offline reads remain consistent
      await _fallback.saveCards(userId, firestoreCards);
      return firestoreCards;
    } catch (e) {
      // Firestore unavailable — serve from in-memory fallback
      return _fallback.loadDeck(userId);
    }
  }

  @override
  Future<void> saveCard(String userId, FSRSCard card) async {
    // Always update fallback first (instant, offline-safe)
    await _fallback.saveCard(userId, card);
    try {
      await _cardsCol(userId)
          .doc(card.vocabId)
          .set(_toFirestore(card), SetOptions(merge: true));
    } catch (_) {
      // Write buffered by Firestore SDK's offline cache; will sync when online.
      // Fallback already updated — no data loss.
    }
  }

  @override
  Future<void> saveCards(String userId, List<FSRSCard> cards) async {
    if (cards.isEmpty) return;

    // Update fallback first
    await _fallback.saveCards(userId, cards);

    // Firestore WriteBatch — max 500 docs per batch
    const batchLimit = 500;
    for (var offset = 0; offset < cards.length; offset += batchLimit) {
      final chunk = cards.skip(offset).take(batchLimit).toList();
      try {
        final batch = _db.batch();
        for (final card in chunk) {
          batch.set(
            _cardsCol(userId).doc(card.vocabId),
            _toFirestore(card),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      } catch (_) {
        // Firestore unavailable or batch queued offline; the in-memory
        // fallback above already holds the data, so this is non-fatal.
      }
    }
  }

  @override
  Future<List<FSRSCard>> getDueCards(String userId, DateTime now) async {
    // Strategy: fetch full deck (hits local cache when offline) then filter.
    // A compound Firestore query would require a composite index; local
    // filtering is simpler and correct for <=300 card decks.
    final all = await loadDeck(userId);
    return all.where((c) {
      if (c.state == CardState.newCard) return true; // Always show new cards
      if (c.state == CardState.learning) return true; // Show learning cards
      if (c.state == CardState.relearning) return true; // Show relearning cards
      // Review cards: due when dueDate is null or <= now
      return c.dueDate == null || !now.isBefore(c.dueDate!);
    }).toList();
  }

  @override
  Future<void> clearDeck(String userId) async {
    await _fallback.clearDeck(userId);
    try {
      final snap = await _cardsCol(userId).get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // No-op if offline; stale data will be overwritten on next saveCards.
    }
  }
}

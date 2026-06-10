// lib/features/exam_practice/vocab_review_store.dart
//
// Spaced-repetition memory for the 英検 vocab practice flow (flaw-hunt #119).
// The exam vocab screen used to re-shuffle a fresh RANDOM set every session, so
// a word a child got WRONG was never deliberately re-tested — pure one-shot
// recognition, no acquisition. FSRS-4.5 (lib/core/fsrs/) is the project's
// validated spaced-repetition algorithm (also used by Battle); this store wires
// it into the exam flow with simple, offline-safe SharedPreferences persistence
// (the FsrsCardRepository proper is Firestore/userId-oriented and needs the
// backend). One JSON map of {wordKey → FSRSCard} per grade.
//
// On each answered item the word is scheduled via FSRSAlgorithm; on the next
// session, DUE words (previously seen, now forgotten) are surfaced FIRST so the
// child actually re-learns what they missed. Pure-Dart, web-safe, no Firebase.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/fsrs/fsrs_algorithm.dart';
import '../../core/fsrs/fsrs_card.dart';

class VocabReviewStore {
  VocabReviewStore({FSRSAlgorithm? algorithm})
      : _fsrs = algorithm ?? FSRSAlgorithm();

  final FSRSAlgorithm _fsrs;

  static String _prefsKey(String grade) => 'vocab_fsrs_$grade';

  /// Normalise a word to a stable per-grade key.
  static String keyFor(String word) => word.trim().toLowerCase();

  /// Load all review cards for [grade] as {wordKey → FSRSCard}. Empty on any
  /// error so practice always works.
  Future<Map<String, FSRSCard>> _load(String grade) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(grade));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) =>
          MapEntry(k, FSRSCard.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(String grade, Map<String, FSRSCard> cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(cards.map((k, c) => MapEntry(k, c.toJson())));
      await prefs.setString(_prefsKey(grade), encoded);
    } catch (_) {
      // Best-effort: a failed save just means this review isn't remembered.
    }
  }

  /// Record one answer and reschedule the word via FSRS.
  /// correct + unaided → good, correct + hinted → hard (not mastered), wrong →
  /// again (re-surfaces soon). Fire-and-forget from the UI.
  Future<void> recordAnswer({
    required String grade,
    required String word,
    required bool correct,
    bool hinted = false,
  }) async {
    final key = keyFor(word);
    final cards = await _load(grade);
    final card = cards[key] ?? FSRSCard(vocabId: key);
    final grd = !correct
        ? Grade.again
        : (hinted ? Grade.hard : Grade.good);
    cards[key] = _fsrs.schedule(card, grd, DateTime.now());
    await _save(grade, cards);
  }

  /// Word keys the child has SEEN before and that are DUE for review now
  /// (forgotten / scheduled). New, never-seen words are NOT included — those are
  /// the "fill" pool. Used to bias session selection toward spaced recycling.
  Future<Set<String>> dueReviewKeys(String grade) async {
    final cards = await _load(grade);
    final now = DateTime.now();
    return cards.values
        .where((c) => c.reps > 0 && (c.dueDate == null || !now.isBefore(c.dueDate!)))
        .map((c) => c.vocabId)
        .toSet();
  }

  /// Test seam.
  Future<void> clearForTest(String grade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(grade));
  }
}

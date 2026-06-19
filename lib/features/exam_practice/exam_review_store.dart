// lib/features/exam_practice/exam_review_store.dart
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

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/fsrs/fsrs_algorithm.dart';
import '../../core/fsrs/fsrs_card.dart';

/// Per-section FSRS error-corrective review store. Originally vocab-only (大問1);
/// now generic so reading / listening / conversation / word-order / scene ナゾ can
/// each re-test what the child MISSED, not just count it (#118 — the testing
/// effect + spacing is the most-replicated route to actually raising 合格率).
/// One JSON map of {itemKey → FSRSCard} per (section, grade) in SharedPreferences.
/// [section] namespaces the store; the default 'vocab' keeps the original prefs
/// key so existing 大問1 review data is preserved. (Class name kept for now to
/// avoid churning the working vocab path; a rename to ExamReviewStore is queued.)
class ExamReviewStore {
  ExamReviewStore({this.section = 'vocab', FSRSAlgorithm? algorithm})
      : _fsrs = algorithm ?? FSRSAlgorithm();

  final FSRSAlgorithm _fsrs;

  /// Storage namespace (e.g. 'vocab', 'reading', 'listening'). Keeps each
  /// section's review schedule independent so a missed listening item doesn't
  /// collide with a vocab word that happens to share a key.
  final String section;

  String _prefsKey(String grade) => section == 'vocab'
      ? 'vocab_fsrs_$grade'
      : 'fsrs_review_${section}_$grade';

  // Serialise read-modify-write per (section, grade). recordAnswer is called
  // fire-and-forget from the UI, so a child answering quickly issues overlapping
  // load→schedule→save cycles that read the SAME baseline blob and the second
  // save clobbers the first — silently DISCARDING the just-missed word's
  // Grade.again schedule, so it never re-surfaces and 合格率 inflates. This is the
  // same write-race class fixed in PrefsFsrsCardRepository (_writeLocks) and
  // StreakService (_writeQueue); ExamReviewStore was the last unguarded store.
  // Static so all instances of a given (section, grade) share one chain.
  static final Map<String, Future<void>> _writeLocks = {};

  Future<void> _locked(String key, Future<void> Function() op) {
    final prev = _writeLocks[key] ?? Future<void>.value();
    final completer = Completer<void>();
    _writeLocks[key] = completer.future;
    prev.whenComplete(() async {
      try {
        await op();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

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
      return decoded.map(
          (k, v) => MapEntry(k, FSRSCard.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(String grade, Map<String, FSRSCard> cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(cards.map((k, c) => MapEntry(k, c.toJson())));
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
    // Serialised so overlapping fire-and-forget calls can't clobber each other's
    // schedule (see _locked). The whole load→schedule→save cycle is the critical
    // section — loading inside the lock is what guarantees each call sees the
    // previous call's saved blob, not a stale shared baseline.
    await _locked('${section}_$grade', () async {
      final cards = await _load(grade);
      final card = cards[key] ?? FSRSCard(vocabId: key);
      final grd = !correct ? Grade.again : (hinted ? Grade.hard : Grade.good);
      cards[key] = _fsrs.schedule(card, grd, DateTime.now());
      await _save(grade, cards);
    });
  }

  /// Word keys the child has SEEN before and that are DUE for review now
  /// (forgotten / scheduled). New, never-seen words are NOT included — those are
  /// the "fill" pool. Used to bias session selection toward spaced recycling.
  Future<Set<String>> dueReviewKeys(String grade) async {
    final cards = await _load(grade);
    final now = DateTime.now();
    return cards.values
        .where((c) =>
            c.reps > 0 && (c.dueDate == null || !now.isBefore(c.dueDate!)))
        .map((c) => c.vocabId)
        .toSet();
  }

  /// Test seam.
  Future<void> clearForTest(String grade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(grade));
  }
}

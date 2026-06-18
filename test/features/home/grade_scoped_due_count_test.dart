// Honesty invariant for the home 「きょうの ナゾ」 due-count.
//
// The home must count only due FSRS cards the current grade's BattleScreen will
// actually show — due cards whose vocabId belongs to the current grade. A raw
// getDueCards().length over-promises after a grade switch (the FSRS repo still
// holds the previous grade's due cards), telling the child "N reviews are due"
// then opening a deck with fewer. gradeScopedDueCount enforces a grade-prefix
// match; kGradeVocabIdPrefix is locked against the real vocab assets below so a
// data change cannot silently break the scoping.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/fsrs/grade_due.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('gradeScopedDueCount', () {
    test('counts only due cards whose vocabId is in the current grade', () {
      final due = [
        FSRSCard(vocabId: 'eiken5_001'),
        FSRSCard(vocabId: 'eiken5_002'),
        FSRSCard(vocabId: 'eiken3_0044'), // stale: a different grade
      ];
      // On 5級 the 3級 card must NOT be counted.
      expect(gradeScopedDueCount(due, kGradeVocabIdPrefix['5']!), 2);
    });

    test('after a grade switch the old-grade due cards drop to 0', () {
      // Child studied 5級 (built FSRS cards), then switched to 3級 in Settings.
      // The repo still returns the 5級 cards as due, but the 3級 deck excludes
      // them → the home must show 0, matching the Battle the child will open.
      final dueFrom5kyu = [
        FSRSCard(vocabId: 'eiken5_001'),
        FSRSCard(vocabId: 'eiken5_002'),
      ];
      expect(gradeScopedDueCount(dueFrom5kyu, kGradeVocabIdPrefix['3']!), 0);
    });

    test('empty prefix (unknown grade) falls back to the raw count', () {
      // Never show a false 0 for a grade we have no prefix for.
      final due = [FSRSCard(vocabId: 'x_1'), FSRSCard(vocabId: 'y_2')];
      expect(gradeScopedDueCount(due, ''), 2);
    });

    test('empty inputs are safe', () {
      expect(gradeScopedDueCount(const [], 'eiken5_'), 0);
      expect(
          gradeScopedDueCount([FSRSCard(vocabId: 'eiken5_001')], 'eiken5_'), 1);
    });

    test('prefixes are mutually non-overlapping (no double counting)', () {
      final prefixes = kGradeVocabIdPrefix.values.toList();
      for (final a in prefixes) {
        for (final b in prefixes) {
          if (a == b) continue;
          expect(a.startsWith(b), isFalse,
              reason: 'prefix "$a" must not start with another prefix "$b"');
        }
      }
    });
  });

  // ── Lock: each prefix matches the real vocab asset's IDs ───────────────────
  group('kGradeVocabIdPrefix matches real vocab assets', () {
    const assetForGrade = {
      '5': 'assets/data/eiken5_vocab.json',
      '4': 'assets/data/eiken4_vocab.json',
      '3': 'assets/data/eiken3_vocab.json',
      'pre2': 'assets/data/eiken_pre2_vocab.json',
      'pre2plus': 'assets/data/eiken_pre2plus_vocab.json',
      '2': 'assets/data/eiken2_vocab.json',
      'pre1': 'assets/data/eiken_pre1_vocab.json',
    };

    for (final entry in assetForGrade.entries) {
      test('grade ${entry.key} ids start with its mapped prefix', () async {
        final prefix = kGradeVocabIdPrefix[entry.key];
        expect(prefix, isNotNull, reason: 'no prefix mapped for ${entry.key}');
        final raw = await rootBundle.loadString(entry.value);
        final words = (jsonDecode(raw)['words'] as List).cast<Map>();
        expect(words, isNotEmpty);
        // Every id in the real asset must begin with the mapped prefix.
        for (final w in words.take(50)) {
          expect((w['id'] as String).startsWith(prefix!), isTrue,
              reason: '${w['id']} does not start with "$prefix"');
        }
      });
    }
  });
}

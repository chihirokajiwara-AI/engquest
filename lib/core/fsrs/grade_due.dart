// lib/core/fsrs/grade_due.dart
// Grade-scoped FSRS due-count util. Pure + dependency-free (only FSRSCard) so it
// is shared by BOTH the home 「きょうの ナゾ」count and the battle session-end
// "あした N つ" forward hook WITHOUT a circular screen import (home imports
// battle, so these could not live in either screen). Moved out of
// kotoba_home_screen.dart; locked by grade_scoped_due_count_test.dart.

import 'fsrs_card.dart';

/// Each grade's vocab-id prefix. FSRSCard.vocabId is the VocabItem.id, which
/// embeds the grade (e.g. 'eiken5_001', 'eikenpre2_003', 'eiken_pre1_0001').
/// The prefixes are irregular across grades, so this map is the source of truth;
/// grade_scoped_due_count_test.dart locks it against the real vocab assets so a
/// future data change can't silently break the scoping. The prefixes are
/// mutually non-overlapping under startsWith (verified), so no card is
/// double-counted.
const Map<String, String> kGradeVocabIdPrefix = {
  '5': 'eiken5_',
  '4': 'eiken4_',
  '3': 'eiken3_',
  'pre2': 'eikenpre2_',
  'pre2plus': 'pre2plus_',
  '2': 'eiken2_',
  'pre1': 'eiken_pre1_',
};

/// Count of due FSRS cards the current grade's BattleScreen will ACTUALLY show:
/// due cards whose vocabId belongs to [gradeIdPrefix]. The raw
/// `getDueCards().length` over-promises after a grade switch — the FSRS repo
/// still holds the previous grade's cards, but Battle only shows the current
/// grade's deck and drops the rest. The home's 「きょうの ナゾ」count MUST scope
/// the same way, or it tells the child "N reviews are due" then opens a deck
/// with fewer — the exact stranding the review CTA was added to prevent. A due
/// card can only exist for a word the child actually studied (already
/// age-filtered into the deck at creation), so a grade-prefix match equals
/// Battle's effective set without loading any vocab. [gradeIdPrefix] empty ⇒ no
/// scoping (returns the raw count) so an unknown grade never shows a false 0.
/// Pure + public so the honesty invariant is unit-tested.
int gradeScopedDueCount(List<FSRSCard> due, String gradeIdPrefix) =>
    gradeIdPrefix.isEmpty
        ? due.length
        : due.where((c) => c.vocabId.startsWith(gradeIdPrefix)).length;

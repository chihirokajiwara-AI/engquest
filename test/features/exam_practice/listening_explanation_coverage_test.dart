// Gate: higher-grade listening items must carry a teach-why 解説.
//
// The "解説 / Why" panel (listening_practice_screen) only renders when an item's
// `explanation` is non-null/non-empty. 5級/4級 had 100% coverage; the marquee
// 準1級 had ZERO — a paying B2 learner got the raw transcript but never the
// reasoning (flaw-hunt 2026-06-13). This test locks the COMPLETED grades at full
// coverage so no future edit silently ships an item without its teaching. Add a
// grade to [_fullyCovered] once all its items are authored + content-QA'd. (準2/2
// are authored in follow-up ticks.)

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';

/// Grades whose listening 解説 are 100% authored (every item) and content-QA'd.
const _fullyCovered = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];

void main() {
  for (final grade in _fullyCovered) {
    test('every $grade listening item has a non-empty, shuffle-safe 解説', () {
      final items = kListeningItems[grade] ?? const [];
      expect(items, isNotEmpty, reason: '$grade listening bank must exist');
      for (final it in items) {
        expect(
          it.explanation != null && it.explanation!.trim().isNotEmpty,
          isTrue,
          reason: '$grade listening item ${it.audioKey} is missing its 解説 '
              '(the teach-why panel would never show for it)',
        );
        // Shuffle-safe: a 解説 must justify by content, never by choice position.
        final e = it.explanation!;
        expect(e.contains('1番') || e.contains('選択肢'), isFalse,
            reason: '${it.audioKey} 解説 must not reference a choice position '
                '(choices are shuffled at runtime)');
      }
    });
  }
}

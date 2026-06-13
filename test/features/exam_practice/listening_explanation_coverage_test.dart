// Gate: higher-grade listening items must carry a teach-why 解説.
//
// The "解説 / Why" panel (listening_practice_screen) only renders when an item's
// `explanation` is non-null/non-empty. 5級/4級 had 100% coverage; the marquee
// 準1級 had ZERO — a paying B2 learner got the raw transcript but never the
// reasoning (flaw-hunt 2026-06-13). This test locks 準1 at full coverage so no
// future edit silently ships a 準1 listening item without its teaching. Grades
// 3/準2/2 are authored in follow-up ticks; add them here as each is completed.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';

void main() {
  test('every 準1級 listening item has a non-empty 解説', () {
    final items = kListeningItems['pre1'] ?? const [];
    expect(items, isNotEmpty, reason: '準1 listening bank must exist');
    for (final it in items) {
      expect(
        it.explanation != null && it.explanation!.trim().isNotEmpty,
        isTrue,
        reason: '準1 listening item ${it.audioKey} is missing its 解説 '
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

// Canon guard (world-depth audit 2026-06-08): the antagonist's name is サイレント /
// in English "the Silence". The 準2/2級 bosses had invented an off-canon name
// "Lord Silentus" / "Silentus" (a name in no other bible) — a confirmed lore break.
// This test prevents it (or any other off-canon antagonist name) from returning.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quest_data uses the canonical antagonist name (no invented "Silentus")',
      () {
    final src = File('lib/features/quest/quest_data.dart').readAsStringSync();
    expect(
      src.contains('Silentus'),
      isFalse,
      reason: 'Antagonist canon = サイレント / "the Silence". "Lord Silentus"/'
          '"Silentus" was an off-canon invention (world-depth audit 2026-06-08); '
          'use "the Silence" in English copy.',
    );
  });
}

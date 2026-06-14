// COMPOSITION-ARCHITECTURE.md §3 per-solve lore drip (Task #29, 2026-06-14).
// "Every ナゾ solve drops one fragment of サイレント lore." This locks the mechanic
// + the 5級 chapter's coverage so the detective arc stays felt. The drip itself
// (banner shown on a non-clearing solve, subsumed by the colour-flood on the
// clearing solve) is wired in scene_view._openNazo; here we lock the DATA so a
// future edit can't silently strip a scene's fragments back to a bare quiz.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/explore/hotspot.dart';

void main() {
  group('per-solve lore drip (§3)', () {
    test('every 5級 ナゾ (NPC) carries a サイレント lore fragment', () {
      final npcs =
          kTown5Scene.hotspots.where((h) => h.kind == HotspotKind.npc).toList();
      expect(npcs, isNotEmpty);
      for (final h in npcs) {
        expect(h.mysteryFragmentJa, isNotNull,
            reason: 'a 5級 ナゾ has no per-solve lore → §3 drip gap (the case '
                'arc goes unfelt for that solve)');
        expect(h.mysteryFragmentJa!.trim(), isNotEmpty);
      }
    });

    test('5級 fragments read as a 探偵メモ beat (diegetic convention)', () {
      for (final h
          in kTown5Scene.hotspots.where((h) => h.kind == HotspotKind.npc)) {
        expect(h.mysteryFragmentJa!.startsWith('たんていメモ'), isTrue,
            reason: 'lore beats use the 探偵メモ framing so a clue reads as the '
                'unfolding mystery, not スラ chatter: «${h.mysteryFragmentJa}»');
      }
    });

    test('the key season-mystery clue (centre→edge) is seeded in 5級', () {
      // The load-bearing clue ("silence spread centre→edge", paid off at 準1級)
      // must be present somewhere in ch.1 — STORY-BIBLE Clue #1.
      final all = kTown5Scene.hotspots
          .where((h) => h.kind == HotspotKind.npc)
          .map((h) => h.mysteryFragmentJa ?? '')
          .join('\n');
      expect(all.contains('まんなかから'), isTrue,
          reason: 'the centre→edge season-mystery clue must seed in ch.1');
    });

    test('coins never carry lore (only ナゾ solves drip)', () {
      for (final h
          in kTown5Scene.hotspots.where((h) => h.kind == HotspotKind.coin)) {
        expect(h.mysteryFragmentJa, isNull);
      }
    });
  });
}

// COMPOSITION-ARCHITECTURE.md §3 per-solve lore drip (Task #29, 2026-06-14).
// "Every ナゾ solve drops one fragment of サイレント lore." This locks the mechanic
// + the 5級 chapter's coverage so the detective arc stays felt. The drip itself
// (banner shown on a non-clearing solve, subsumed by the colour-flood on the
// clearing solve) is wired in scene_view._openNazo; here we lock the DATA so a
// future edit can't silently strip a scene's fragments back to a bare quiz.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/explore/hotspot.dart';

void main() {
  // The authored chapters so far (CH.1–3). Each adds one assembling bookmark.
  // §3 COMPLETE — all 7 案件簿 (chapters) drip per-solve lore.
  final authoredScenes = {
    '5級': kTown5Scene,
    '4級': kTown4Scene,
    '3級': kTown3Scene,
    '準2級': kTownPre2Scene,
    '準2級プラス': kTownPre2PlusScene,
    '2級': kTown2Scene,
    '準1級': kTownPre1Scene,
  };

  group('per-solve lore drip (§3)', () {
    test('every ナゾ in an authored chapter carries a サイレント lore fragment', () {
      authoredScenes.forEach((label, scene) {
        final npcs =
            scene.hotspots.where((h) => h.kind == HotspotKind.npc).toList();
        expect(npcs, isNotEmpty, reason: '$label has no ナゾ');
        for (final h in npcs) {
          expect(h.mysteryFragmentJa, isNotNull,
              reason: 'a $label ナゾ has no per-solve lore → §3 drip gap (the '
                  'case arc goes unfelt for that solve)');
          expect(h.mysteryFragmentJa!.trim(), isNotEmpty);
        }
      });
    });

    test('fragments read as a 探偵メモ beat (diegetic convention)', () {
      authoredScenes.forEach((label, scene) {
        for (final h
            in scene.hotspots.where((h) => h.kind == HotspotKind.npc)) {
          expect(h.mysteryFragmentJa!.startsWith('たんていメモ'), isTrue,
              reason: '$label lore beats use 探偵メモ framing: '
                  '«${h.mysteryFragmentJa}»');
        }
      });
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

    test('the bookmarks ASSEMBLE across chapters (the narrative payoff)', () {
      // 5級→4級→3級 each reveals the next words of アイラ's torn sentence —
      // STORY-BIBLE Bookmark seeds "Once, I / told a story, / and the whole".
      // (5級's "Once, I" lands in its cleared finale; 4級/3級 drip per-solve.)
      String fragJoin(scene) => scene.hotspots
          .where((h) => h.kind == HotspotKind.npc)
          .map((h) => h.mysteryFragmentJa ?? '')
          .join('\n');
      expect('${kTown5Scene.cleared}'.contains('Once, I'), isTrue,
          reason: 'bookmark #1 "Once, I" (5級 finale)');
      expect(fragJoin(kTown4Scene).contains('told a story,'), isTrue,
          reason: 'bookmark #2 "told a story," (4級 drip)');
      expect(fragJoin(kTown3Scene).contains('and the whole'), isTrue,
          reason: 'bookmark #3 "and the whole" (3級 drip)');
      expect(fragJoin(kTownPre2Scene).contains('grey world'), isTrue,
          reason: 'bookmark #4 "grey world" (準2級 drip)');
      expect(fragJoin(kTownPre2PlusScene).contains('turned to'), isTrue,
          reason: 'bookmark #5 "turned to" (準2級プラス drip)');
      expect(fragJoin(kTown2Scene).contains('colour.'), isTrue,
          reason: 'bookmark #6 "colour." (2級 drip)');
      // The 準1 finale carries the WHOLE assembled sentence + サイレント's true name.
      final pre1 = fragJoin(kTownPre1Scene);
      expect(
          pre1.contains(
              'Once, I told a story, and the whole grey world turned to colour.'),
          isTrue,
          reason: 'bookmark #7 = the complete assembled sentence (準1 finale)');
      expect(pre1.contains('アイラ'), isTrue,
          reason: "サイレント's true name (アイラ) is the last word returned");
    });

    test('coins never carry lore (only ナゾ solves drip)', () {
      authoredScenes.forEach((label, scene) {
        for (final h
            in scene.hotspots.where((h) => h.kind == HotspotKind.coin)) {
          expect(h.mysteryFragmentJa, isNull, reason: '$label coin has lore');
        }
      });
    });
  });
}

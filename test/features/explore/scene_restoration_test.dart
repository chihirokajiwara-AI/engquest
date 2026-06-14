// Guards the lean-Layton "ことばで世界に色が戻る" whole-plate restoration mechanic
// (ART-DIRECTION.md §1.2 / COMPOSITION-ARCHITECTURE.md §2.1): a scene renders
// desaturated until every ナゾ is solved, then floods grey→colour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/scene_view.dart';

void main() {
  group('saturationMatrix', () {
    test('s=1 is the identity matrix (full colour)', () {
      final m = saturationMatrix(1.0);
      expect(m, [
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ]);
    });

    test('s=0 is greyscale — all three colour rows identical (luma)', () {
      final m = saturationMatrix(0.0);
      // Rec.709 luma weights on every row → R=G=B output for any input.
      const lr = 0.2126, lg = 0.7152, lb = 0.0722;
      expect(m[0], closeTo(lr, 1e-9));
      expect(m[1], closeTo(lg, 1e-9));
      expect(m[2], closeTo(lb, 1e-9));
      // Row 2 (green output) and row 3 (blue output) share the same weights.
      expect(m.sublist(5, 8), [m[0], m[1], m[2]]);
      expect(m.sublist(10, 13), [m[0], m[1], m[2]]);
      // Alpha row untouched.
      expect(m.sublist(15), [0, 0, 0, 1, 0]);
    });

    test('luma weights sum to ~1 (no brightness shift at s=0)', () {
      final m = saturationMatrix(0.0);
      expect(m[0] + m[1] + m[2], closeTo(1.0, 1e-9));
    });
  });

  group('allNpcsSolved', () {
    test('real scene with NPCs: false until every NPC ナゾ is solved', () {
      final npcIdx = [
        for (var i = 0; i < kTown5Scene.hotspots.length; i++)
          if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) i,
      ];
      expect(npcIdx, isNotEmpty, reason: '5級 scene should have NPC ナゾ');
      expect(allNpcsSolved(kTown5Scene, {}), isFalse);
      // Solving only some NPCs is still not restored.
      expect(allNpcsSolved(kTown5Scene, {npcIdx.first: true}), isFalse);
      // All NPCs solved → restored (colour floods).
      expect(
        allNpcsSolved(kTown5Scene, {for (final i in npcIdx) i: true}),
        isTrue,
      );
    });

    test('scene with no NPC hotspots is restored (nothing to recolour)', () {
      const sceneNoNpc = SceneDef(
        backgroundAsset: 'x.webp',
        titleJa: 't',
        hotspots: [Hotspot.coin(pos: Alignment.center)],
      );
      expect(allNpcsSolved(sceneNoNpc, {}), isTrue);
    });
  });

  group('nazoProgress', () {
    test('counts only NPC ナゾ (coins excluded) and tracks solved/total', () {
      final npcIdx = [
        for (var i = 0; i < kTown5Scene.hotspots.length; i++)
          if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) i,
      ];
      final coinCount =
          kTown5Scene.hotspots.where((h) => h.kind == HotspotKind.coin).length;
      expect(coinCount, greaterThan(0),
          reason: '5級 scene has a hidden coin → must be excluded from total');

      // None solved.
      final none = nazoProgress(kTown5Scene, {});
      expect(none.total, npcIdx.length);
      expect(none.solved, 0);

      // One solved.
      final one = nazoProgress(kTown5Scene, {npcIdx.first: true});
      expect(one.solved, 1);
      expect(one.total, npcIdx.length);

      // Solving the coin slot must NOT count toward ナゾ progress.
      final coinIdx =
          kTown5Scene.hotspots.indexWhere((h) => h.kind == HotspotKind.coin);
      final coinOnly = nazoProgress(kTown5Scene, {coinIdx: true});
      expect(coinOnly.solved, 0, reason: 'a found coin is not a solved ナゾ');

      // All solved.
      final all = nazoProgress(kTown5Scene, {for (final i in npcIdx) i: true});
      expect(all.solved, all.total);
      expect(all.solved, npcIdx.length);
    });

    test('multi-ナゾ scene so the pill is meaningful (total >= 2)', () {
      // The pill only renders for total >= 2; assert the real 5級 scene clears
      // that bar so the engagement-spine progress cue actually shows.
      expect(nazoProgress(kTown5Scene, {}).total, greaterThanOrEqualTo(2));
    });
  });

  // The world wakes up as you solve (studio build 2026-06-14): saturation rises
  // from the muted floor to full colour PER ナゾ, not in one terminal flip.
  group('progressiveSaturation', () {
    const floor = 0.48;

    test('nothing solved → the muted floor', () {
      expect(progressiveSaturation(0, 3, floor), closeTo(floor, 1e-9));
    });

    test('all solved → full colour (1.0)', () {
      expect(progressiveSaturation(3, 3, floor), closeTo(1.0, 1e-9));
    });

    test('partial solve → between the floor and full, monotonic per solve', () {
      final s0 = progressiveSaturation(0, 3, floor);
      final s1 = progressiveSaturation(1, 3, floor);
      final s2 = progressiveSaturation(2, 3, floor);
      final s3 = progressiveSaturation(3, 3, floor);
      expect(s1, greaterThan(s0));
      expect(s2, greaterThan(s1));
      expect(s3, greaterThan(s2));
      // 1 of 3 solved → floor + 1/3 of the remaining gap.
      expect(s1, closeTo(floor + (1 / 3) * (1 - floor), 1e-9));
    });

    test('a scene with no ナゾ is already fully alive', () {
      expect(progressiveSaturation(0, 0, floor), 1.0);
    });

    test('clamps — never exceeds 1.0 even on bad counts', () {
      expect(progressiveSaturation(5, 3, floor), lessThanOrEqualTo(1.0));
    });
  });
}

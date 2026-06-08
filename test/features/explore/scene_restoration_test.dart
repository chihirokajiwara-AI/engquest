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
}

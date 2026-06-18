import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/chapter.dart';

void main() {
  group('Chapter model — zero-regression wrap of the 7 scenes', () {
    test('kChaptersByGrade mirrors kChapterGradeOrder / kScenesByGrade', () {
      expect(kChaptersByGrade.length, kChapterGradeOrder.length);
      for (final grade in kChapterGradeOrder) {
        final ch = kChaptersByGrade[grade];
        expect(ch, isNotNull, reason: '$grade must have a chapter');
        // Baseline migration: each chapter wraps exactly the existing scene.
        expect(ch!.locations, hasLength(1),
            reason: 'today every chapter is single-location');
        expect(identical(ch.entryLocation.scene, sceneForGrade(grade)), isTrue,
            reason: 'location 0 IS the existing SceneDef — no copy, no change');
        expect(ch.map.nodes, hasLength(1));
        expect(ch.titleJa, sceneForGrade(grade)!.titleJa);
      }
    });

    test('beats derive from existing arrival/cleared text; no video yet', () {
      for (final grade in kChapterGradeOrder) {
        final ch = kChaptersByGrade[grade]!;
        final scene = sceneForGrade(grade)!;
        // No videoAsset is wired anywhere yet → every beat falls back to banner.
        expect(ch.beats.every((b) => b.videoAsset == null), isTrue);
        if (scene.cleared != null) {
          final clear =
              ch.beats.where((b) => b.trigger == BeatTrigger.chapterClear);
          expect(clear, hasLength(1));
          expect(clear.first.narrationJa, scene.cleared);
        }
        if (scene.companionArrivalJa != null) {
          final intro =
              ch.beats.where((b) => b.trigger == BeatTrigger.chapterIntro);
          expect(intro, hasLength(1));
          expect(intro.first.narrationJa, scene.companionArrivalJa);
          expect(intro.first.speaker, 'タロ');
        }
      }
    });

    test('mastery gate == the location NPC (ナゾ) count', () {
      for (final grade in kChapterGradeOrder) {
        final loc = kChaptersByGrade[grade]!.entryLocation;
        final npcs =
            loc.scene.hotspots.where((h) => h.kind == HotspotKind.npc).length;
        expect(loc.gate.requiredFirstTryNazo, npcs);
        expect(loc.nazoCount, npcs);
        expect(npcs, greaterThan(0), reason: 'every scene has ナゾ-givers');
      }
    });
  });

  group('deriveNodeStates — reveal-1-ahead gating', () {
    test('single location: unmet → current, met → cleared', () {
      final ch = kChaptersByGrade['5']!;
      final need = ch.entryLocation.gate.requiredFirstTryNazo;
      expect(deriveNodeStates(ch, [0]), [MapNodeState.current]);
      expect(deriveNodeStates(ch, [need]), [MapNodeState.cleared]);
    });

    test('two locations reveal one ahead and lock the rest', () {
      final scene = sceneForGrade('5')!;
      final ch = Chapter(
        grade: '5',
        titleJa: 't',
        locations: const [],
        map: const ChapterMap(nodes: []),
        beats: const [],
      );
      // Build a synthetic 2-location chapter (both gates require 2 first-try).
      final two = Chapter(
        grade: ch.grade,
        titleJa: ch.titleJa,
        locations: [
          Location(
              scene: scene, gate: const MasteryGate(requiredFirstTryNazo: 2)),
          Location(
              scene: scene, gate: const MasteryGate(requiredFirstTryNazo: 2)),
        ],
        map: const ChapterMap(nodes: [
          MapNode(locationIndex: 0, x: 0.3, y: 0.5),
          MapNode(locationIndex: 1, x: 0.7, y: 0.5),
        ]),
        beats: const [],
      );
      // loc0 unmet → it is current, loc1 locked.
      expect(deriveNodeStates(two, [1, 0]),
          [MapNodeState.current, MapNodeState.locked]);
      // loc0 met, loc1 unmet → loc0 cleared, loc1 now current.
      expect(deriveNodeStates(two, [2, 0]),
          [MapNodeState.cleared, MapNodeState.current]);
      // both met → both cleared.
      expect(deriveNodeStates(two, [2, 2]),
          [MapNodeState.cleared, MapNodeState.cleared]);
    });
  });
}

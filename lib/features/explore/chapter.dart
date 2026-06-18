/// World-depth chapter model (#91 動画 slots / #92 multi-location) — an ADDITIVE
/// wrapper over the existing single-scene-per-grade world. A [Chapter] groups one
/// or more [Location]s (each = an existing [SceneDef]) under a [ChapterMap], with
/// [Beat] slots that can later carry a 動画 cutscene (CEO 1768) and fall back to
/// the current static banner until one is produced. SceneDef / Hotspot /
/// NazoScreen / FSRS / exam stay UNTOUCHED. A chapter with a single location
/// renders exactly as today (zero-regression baseline); locations 2..N are added
/// incrementally as new painted plates land.
///
/// Design: docs/design/WORLD-DEPTH-ARCHITECTURE.md (CEO-approved), confirmed by
/// 2026 latest-first research — Layton "New World of Steam" (late 2026) keeps the
/// chapter→connected-locations→mandatory-gate spine; Duolingo's path makes
/// progression == spaced review, so map advance == 英検 mastery == 合格率.
library;

import 'package:engquest/features/explore/hotspot.dart';

/// Where in a chapter a [Beat] fires.
enum BeatTrigger { chapterIntro, midReveal, chapterClear }

/// A narrative beat. Plays [videoAsset] when a clip exists (web: a lazy, web-safe
/// `<video>` via HtmlElementView — H.264 MP4, `preload="none"`, so zero cold-boot
/// cost); otherwise the caller renders [narrationJa] as the existing static
/// banner. videoAsset stays null until a cutscene is produced → no behaviour
/// change today, but the chapter flow is composed WITH video in mind.
class Beat {
  final BeatTrigger trigger;
  final String? videoAsset;
  final String narrationJa;
  final String? speaker; // 'タロ' / NPC id, or null

  const Beat({
    required this.trigger,
    this.videoAsset,
    required this.narrationJa,
    this.speaker,
  });
}

/// The mastery threshold that opens the road to the NEXT location. Counted in
/// first-try-correct ナゾ (`NazoResult.firstTryCorrect`) — so advancing through
/// the chapter map IS demonstrating 英検 mastery (== 合格率), not mere tapping.
class MasteryGate {
  final int requiredFirstTryNazo;
  const MasteryGate({required this.requiredFirstTryNazo});
}

/// One painted location in a chapter = an existing [SceneDef].
class Location {
  final SceneDef scene;
  final MasteryGate gate;
  const Location({required this.scene, required this.gate});

  /// The ナゾ-giving NPCs in this location (the mandatory puzzles).
  int get nazoCount =>
      scene.hotspots.where((h) => h.kind == HotspotKind.npc).length;
}

/// Per-node visual state on the 案内図 — DERIVED (never stored) from solve state.
/// locked = greyscale + padlock; current = colour + "you are here" marker;
/// cleared = colour + seal.
enum MapNodeState { locked, current, cleared }

/// A node on the chapter map. [x],[y] are normalized 0..1 board positions.
class MapNode {
  final int locationIndex;
  final double x;
  final double y;
  const MapNode({
    required this.locationIndex,
    required this.x,
    required this.y,
  });
}

/// The 案内図 — hub-and-spoke, ≤4 nodes, reveal-1-ahead (2026 child-UX: minimal
/// choices, state shown by saturation + icon + motion, no text for non-readers).
class ChapterMap {
  final List<MapNode> nodes;
  const ChapterMap({required this.nodes});
}

/// A 事件 (case) = one 英検 grade-unit: ordered locations + a map + beats.
class Chapter {
  final String grade; // '5','4','3','pre2','pre2plus','2','pre1'
  final String titleJa;
  final List<Location> locations;
  final ChapterMap map;
  final List<Beat> beats;

  const Chapter({
    required this.grade,
    required this.titleJa,
    required this.locations,
    required this.map,
    required this.beats,
  });

  Location get entryLocation => locations.first;
}

/// Reveal-1-ahead state derivation. [firstTryCorrectPerLocation] gives how many
/// mandatory ナゾ the child has answered first-try-correct in each location. The
/// entry location is always reachable; a location is [cleared] once its gate is
/// met, [current] if it is the first not-yet-met reachable location, and [locked]
/// while any earlier location's gate is unmet. Pure (caller supplies counts) so
/// it is unit-testable without storage.
List<MapNodeState> deriveNodeStates(
  Chapter chapter,
  List<int> firstTryCorrectPerLocation,
) {
  final states = <MapNodeState>[];
  var prevCleared = true; // the entry location is always reachable
  for (var i = 0; i < chapter.locations.length; i++) {
    final met = firstTryCorrectPerLocation[i] >=
        chapter.locations[i].gate.requiredFirstTryNazo;
    if (!prevCleared) {
      states.add(MapNodeState.locked);
    } else {
      states.add(met ? MapNodeState.cleared : MapNodeState.current);
    }
    prevCleared = prevCleared && met;
  }
  return states;
}

/// Wraps an existing grade [scene] as a single-location [Chapter] — the
/// zero-regression baseline. Locations 2..N are appended here as new painted
/// plates land. Beats derive from the scene's existing arrival/cleared text;
/// [Beat.videoAsset] stays null (banner fallback) until a cutscene is produced.
Chapter _wrapSingle(String grade, SceneDef scene) {
  final beats = <Beat>[
    if (scene.companionArrivalJa != null)
      Beat(
        trigger: BeatTrigger.chapterIntro,
        narrationJa: scene.companionArrivalJa!,
        speaker: 'タロ',
      ),
    if (scene.cleared != null)
      Beat(trigger: BeatTrigger.chapterClear, narrationJa: scene.cleared!),
  ];
  final nazo = scene.hotspots.where((h) => h.kind == HotspotKind.npc).length;
  return Chapter(
    grade: grade,
    titleJa: scene.titleJa,
    locations: [
      Location(scene: scene, gate: MasteryGate(requiredFirstTryNazo: nazo)),
    ],
    map: const ChapterMap(nodes: [MapNode(locationIndex: 0, x: 0.5, y: 0.5)]),
    beats: beats,
  );
}

/// The 7 案件 keyed by 英検 grade, in canonical play order. Mirrors
/// [kScenesByGrade]; [chapterGradeDriftIsAligned] keeps them aligned in a test.
final Map<String, Chapter> kChaptersByGrade = {
  for (final grade in kChapterGradeOrder)
    grade: _wrapSingle(grade, kScenesByGrade[grade]!),
};

/// The chapter for [grade], or null when that grade has no scene yet.
Chapter? chapterForGrade(String grade) => kChaptersByGrade[grade];

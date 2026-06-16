# World-depth architecture — the structure for a Layton-grade × 英検-pass hybrid

Authored 2026-06-16 in answer to CEO 1771 ("本当に最高品質で作れるだけの構造考えてあるのか？").
This is the **structure**, designed before building — not piecemeal hotspot-adding.
Spec-freeze gate: this is a structural change; it is PRESENTED for CEO approval
BEFORE #91/#92 are built. #90 (density) is the only piece already shipped, and it
fits this structure as "more hotspots per Location".

## The problem (one sentence)
We need コトバ探偵 to be, simultaneously, a **street-level world-class detective
game** (Layton: many connected locations, a chapter map, hidden discoveries
everywhere, animated cutscenes at beats) AND a **rigorous 英検-pass learning engine**
(every puzzle is a real 英検 item; clearing a case == mastering a 英検 unit) — and
the two must be the SAME structure, not a game skin bolted onto a quiz. Today we
have 7 single-room SceneDefs (3 NPC + 1 coin each, 21 ナゾ total). That is
structurally far too thin (see LAYTON-MECHANICS-STUDY.md) and the game and the
learning are only loosely coupled.

## Constraints (fixed before choosing tools)
- **Zero regression of the 英検-pass engine.** FSRS deck, exam mode (大問1–4),
  CSE estimator, NazoScreen/QuestStep are the live revenue/合格 engine. The new
  structure must WRAP them, never rewrite them.
- **No over-abstraction** (CEO standing rule "不要な抽象化禁止、直接実装"). Direct
  Dart types, not a generic node-graph adventure engine.
- **Compose WITH video in mind** (CEO 1768). Cutscene/動画 slots must exist in the
  structure now, even though the videos are produced later.
- **Game ⇄ learning interlock** (CEO 1755). Game-progress and learning-progress
  must be the same variable, designed cross-domain.
- **Art-gated parts are structured now, filled when plates land** (#54 art-gen).
- Offline, web-safe, no dart:io, no backend dependency.

## Alternatives considered (≥3)
**A — Additive wrapper (CHOSEN).** Keep `SceneDef` as the painted space, rename its
role to **Location**. Introduce `Chapter` that wraps an ordered `List<SceneDef>`
(locations) + a navigation `ChapterMap` + `List<Beat>` (cutscene/video slots) +
an `EikenUnit` binding + a `MasteryGate`. The existing 7 scenes become
"chapter N, location 1" — nothing breaks; we GROW locations/beats from there.
- Cost: low. Risk: low (purely additive). Reaches: multi-location + map + video
  slots + mastery interlock. Over-abstraction: none (concrete types).

**B — Rewrite to a generic scene-graph engine.** Replace SceneDef with nodes/edges
+ a generic event system.
- Rejected: rewrites the live 英検 engine (regression risk on revenue/合格),
  is exactly the spec-churn the governance spec-freeze warns against, and violates
  "no over-abstraction". Max flexibility we do not need.

**C — Content-only (more flat SceneDefs).** Just author more scenes per grade as a
flat list.
- Rejected: never gives the chapter map, the cutscene-slot beats, or the
  game⇄learning gate. More scenes ≠ Layton structure. Fails CEO 1768.

A world-class CTO building on a live revenue product chooses **A**: the additive
wrapper buys the full Layton structure with near-zero regression risk and no
speculative engine.

## The structure (concrete Dart, grounded in existing types)
```dart
/// A CASE — the unit of STORY and of 英検 LEARNING. They are the same unit.
/// (Layton "chapter"; 英検 "unit".)  Wraps existing SceneDef as a Location.
class Chapter {
  final String id;                 // 'c5_01'
  final String eikenLevel;         // '5'
  final String titleJa;            // 「ことばが きえた まち」
  final EikenUnit unit;            // what 英検 skill/words this case teaches+tests
  final List<SceneDef> locations;  // ordered painted spaces (today: length 1)
  final ChapterMap map;            // how locations connect (案内図)
  final List<Beat> beats;          // cutscene/動画 slots at narrative beats
  final MasteryGate clearGate;     // 英検 mastery needed to SOLVE the case
}

/// A narrative beat. Plays a VIDEO when produced; static banner fallback until.
/// This is the CEO-1768 "compose with video in mind" slot — present from day one.
class Beat {
  final BeatTrigger trigger;       // chapterIntro | enterLocation(id) | midReveal | chapterClear
  final String? videoAsset;        // assets/video/...  (null until produced → fallback)
  final String narrationJa;        // static fallback (reuses today's banner text)
  final String? speaker;           // 'スラ' / NPC id
}

/// Map between locations (Layton 案内図). Edges unlock as the case progresses.
class ChapterMap {
  final String startLocationId;
  final List<MapEdge> edges;       // from → to, gated by a clue/solve count
}

/// The HYBRID interlock — binds the case to the 英検 curriculum.
class EikenUnit {
  final ExamPart part;             // 大問1 vocab / listening / reading …
  final List<String> targetVocabIds; // the FSRS cards this case drills (deck feed)
  final CseSkill skill;            // which CSE limiting-skill this case raises
}

/// "Case solved" == 英検 MASTERY, not "tapped all NPCs".
/// Reuses NazoResult.firstTryCorrect — the mastery signal we already measure.
class MasteryGate {
  final int requiredFirstTryNazo;  // master N ナゾ on first try to clear
}
```

## The interlock, stated plainly (CEO 1755 — game ⇄ learning are ONE variable)
- **Game serves learning.** The detective case is the motivation wrapper: a town
  lost its words; you restore them by solving ナゾ. Each ナゾ *is* a real 英検 item
  (vocab/grammar/listening/reading) — unchanged exam content, reskinned framing.
- **Learning serves game.** You do NOT advance the story by tapping; you advance by
  demonstrating 英検 mastery. `MasteryGate.requiredFirstTryNazo` reads
  `NazoResult.firstTryCorrect` — the same first-try signal that feeds 合格率. Master
  the unit → the map opens the next location → the mid-reveal cutscene plays →
  the case clears. **Story progress and 合格率 progress are the same number.**
- **The deck is the case's word-set.** `EikenUnit.targetVocabIds` feeds the FSRS
  Battle deck, so flashcard practice and the case drill the same words. (This is
  the FSRS⇄scene coupling previously deferred as architectural — here it is bound
  cleanly through the Chapter, not hacked into the repo.)

## Migration (additive, zero regression — provable)
1. `Chapter` is NEW; `SceneDef` is UNCHANGED. Today's 7 scenes are wrapped as
   `Chapter(locations: [thatScene], beats: [...from companionArrivalJa + cleared],
   map: single-node, clearGate: requiredFirstTryNazo = NPC count)`.
2. The arrival banner (`companionArrivalJa`) becomes `Beat(chapterIntro)`; the
   `cleared` line becomes `Beat(chapterClear)` — same text, now a video slot.
3. Exam mode, FSRS, CSE, NazoScreen are untouched. The wrapper only adds navigation
   + beats on TOP. A clean checkout still compiles and all 1575 tests stay green
   because nothing existing changed shape.

## Scaling toward Layton density (the volume target, measured)
| Layer | Today | Step target | Layton bar |
|---|---|---|---|
| Locations / chapter | 1 | 3–5 | many + map |
| Hotspots / location | 3 NPC + 2 coin + 4 obs (5級, #90) | dense everywhere | dozens |
| Cutscene slots / chapter | 0 | 3 (intro/reveal/clear) | every beat |
| Chapters / grade | 1 | 2–3 | many |
| Total ナゾ | 21 | 50+ | 100+ |

## Build sequence (what is buildable NOW vs gated)
- **#90 density — SHIPPED** (observation points + 2nd coin in 5級). Fits as "more
  hotspots per Location".
- **#91 cutscene/動画 slots — buildable now (architecture), video gated.** Add `Beat`
  + `BeatTrigger` + wire chapterIntro/chapterClear to today's banners as fallback;
  video asset field present, plays when a file lands. No art needed for the slot.
- **#92 Chapter + ChapterMap + multi-location — buildable now (structure), plates
  gated.** Add `Chapter`/`ChapterMap`/`MapEdge`, wrap the 7 scenes, build the map
  navigation UI. New painted locations are art-gated (#54), but a 2nd location can
  ship grey/placeholder to prove the navigation, then fill when plates land.
- **EikenUnit binding — buildable now.** Bind each existing chapter to its already-
  existing exam part + vocab set; wire `MasteryGate` to `firstTryCorrect`.

## Why this is the highest-quality structure (the bar, not just "it works")
- It makes the GAME and the 英検 engine the **same system** (CEO 1755) instead of a
  quiz with a skin — story progress literally is 合格率 progress.
- It is **Layton-shaped** (locations + map + hidden discoveries + cutscene beats)
  while keeping the proven 英検 engine intact (CEO 1768, zero regression).
- It is **additive and direct** — no rewrite, no speculative engine, grows scene by
  scene toward Layton volume without another spec flip.
- It is **honest about art-gating**: structure ships now, painted plates/videos drop
  into pre-built slots.

## Gate
Per spec-freeze + THINK_BEFORE_EXECUTE: building #91/#92 changes the world model →
this design is presented to the CEO for approval first. On GO, build order is
#91 (Beat slots, lowest risk) → EikenUnit binding → #92 (Chapter/map).
Model used for this design: Opus 4.8 (main). This is a system-design decision (a
Fable-5 trigger); flagged as such for the audit trail.

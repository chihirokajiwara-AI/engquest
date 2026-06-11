# Game-Build Plan — コトバ探偵 game layer (workflow wf_690e14d8, CEO 1247)

_Coordinated, measured plan from game-composition-foundation. The loop builds these units (BUILD) and surfaces gated ones. Honesty: choices/correctIndex bytes NEVER touched._

## Verdict


## Arc → Code


## Parallel/foundational units (build, gated each)

## Sequenced units (wait on dependency)

## Gated units (CEO go)

## Build queue (loop pulls next each tick; verify+adversarial-audit each; re-score)
- [x] G1 — route all 7 town scenes from the map (sceneForGrade), not grade-5 only. DONE 2026-06-11 (items 50,57↑). 6 built scenes were unreachable.
- [x] G2 (DONE 2026-06-11, verified honest, items 48,50↑) — add SceneDef.cleared field; scene-clear → render authored town.cleared beat + advance map node (SceneView pop true on allNpcsSolved; consume in quest_map._openTown & home._goToScene). files: hotspot.dart, scene_view.dart, quest_map_screen.dart, kotoba_home_screen.dart. items 48,50,53.
- [x] H1 (DONE 2026-06-11, verified; model+rail only, no per-case copy yet) — Hotspot.hints: List<NazoHint>? (rung/textJa/coinCost) threaded through NazoScreen._hintLadder; generic fallback when null. HARD RAIL: no hint names the answer/eliminates a distractor (content-qa gate). Model+thread only; per-case copy is sequenced.
- [ ] (more units in workflow output wdv743rm0; the authoritative SPEC is the "Arc → Code" section above — each beat maps to an EXISTING field, choices/correctIndex bytes NEVER touched.)

### Sequenced (wait on dependency — coordinate-first, CEO 1247)
- Per-case CONTENT (teachCards on 19/21 untaught hotspots, per-case authored hints, clue-drip lore into onCorrect, arrival hooks, seed lines, bookmark pages) WAITS on G2 (cleared/advance wiring) + H1 (hint model). Then parallelizable per-case (different data entries).

### Gated (CEO go — surface, never self-build)
- art-generation (cast/scene .webp), BGM/SE, anything needing spend/secret/prod.

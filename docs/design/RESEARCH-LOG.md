# Research Log — living foundation

Dated record of the craft research behind the design bibles. The `foundation-refresh`
workflow (`.claude/workflows/foundation-refresh.js`, cadence in
`docs/governance/AUTONOMOUS-LOOP.md §E`) appends an entry each time it re-researches the
latest craft and proposes bible updates. Newest first.

---

## 2026-06-08 — Inaugural studio research (Layton/DQ craft foundation)

A 6-discipline studio team (game history × Professor Layton & Dragon Quest, character
design, world/narrative design, painted 2D art direction, children's educational-game
design) researched the craft and its creators; an Opus studio-director synthesized the
foundation. Seeded: `COMPOSITION-ARCHITECTURE.md` (lean-Layton), `WORLD-BIBLE.md`,
`CHARACTER-BIBLE.md`, `ART-DIRECTION.md`, and the §-E refresh mechanism itself.

**Headline findings**
- **Professor Layton (Level-5, Akihiro Hino):** story-first, puzzle layered *into* the world
  (puzzle-as-characterisation); the town is the quiz UI; cutscenes only at story peaks; a
  finite hint economy makes accepting help feel chosen. Character design (Takuzō Nagano):
  silhouette-first, recognisable at thumbnail size. Music (Tomohito Nishiura): site-specific,
  *constructs* a place. → our lean-Layton pivot: 級 = 事件簿, 英検 item = the on-scene puzzle,
  static painted scenes, no map traversal.
- **Dragon Quest (Yuji Horii / Akira Toriyama / Koichi Sugiyama):** warmth + accessibility as
  non-negotiable design gates; experience-first; one warm NPC voice; Toriyama's 3-colour
  one-silhouette legibility (the Slime); Sugiyama's music as emotional architecture + the
  level-up recognition ceremony. → we keep the mascot charm + command-window UI craft, drop
  the large roster / overworld grind.
- **Cross-cutting:** discipline produces cohesion, and cohesion is the immersion — achievable
  by a small team via the lean-Layton production model.

**Primary sources** were captured in the per-discipline research outputs (run
`wf_0bc1a3ba`, 2026-06-08). Future `foundation-refresh` runs will list dated URLs here.

**Next refresh due:** ~10 iterations after 2026-06-08, on a 英検/Flutter change, or on CEO signal.

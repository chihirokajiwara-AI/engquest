# NARRATIVE / GAME PRODUCER RUBRIC — "Layton-and-beyond"

**Why this exists (CEO 1598–1601, 2026-06-14):** the loop was *reactive* — it
worked a backlog and ran per-tick audits, but held **no standing world-class
target** for the narrative/game-as-experience. So it did not self-surface
composition gaps; the CEO had to prod ("are you neglecting the opening / scene
transitions / dialogue volume / immersion? when will you surpass Layton?"). This
doc is the missing **compass**: a producer-grade set of measured criteria + the
honest gap to Professor-Layton-grade and beyond. The loop reads it each
narrative tick, picks the lowest in-scope dimension, and drives it up — the same
way COMPLETION-SCORECARD.md drives feature completeness.

Scoring: 0–100. **Honest** = only verified-shipped work raises a score.
Bar: **Layton = 70** (matches the genre benchmark). **>70 = surpassing it.**
`scope`: `now` = buildable in-repo (Dart/content, no spend); `gated` = needs
art-gen/audio/voice/CEO-resource (surface, don't self-spend).

## Measured current state (2026-06-14, from code)

7 scenes (1/grade), 2–3 ナゾ each (~20 total), ~10.3k authored JP dialogue chars,
beats per scene = arrival banner + per-solve lore (5/7 scenes) + scene-clear
modal. grey→colour restoration mechanic; assembling-bookmark mystery (5/7).

## Dimensions

| # | Dimension | Score | Bar(Layton) | scope | Gap to surpass |
|---|---|---|---|---|---|
|N1|Mystery structure (clue-plant→payoff)|86|70|now|✅ 7-bookmark sentence assembles END-TO-END across all 7 cases (37fba51) + centre→edge clue resolves at 準1 + アイラ name reveal. EXCEEDS Layton.|
|N2|Puzzle↔narrative integration|80|70|now|Every 英検 solve restores colour + drips lore — the puzzle IS the story beat. Already > Layton (Layton puzzles are often detached).|
|N3|Per-solve story drip|100|65|now|✅ DONE (37fba51): all 7 案件簿 drip per-solve lore; 100% coverage. EXCEEDS Layton.|
|N4|Scene/chapter density|35|70|**gated**|1 scene/grade = 7 total. Layton = many chapters/case. Needs background art-gen at scale → CEO resource.|
|N5|Per-character dialogue volume/voice|55|70|now|~1.5k chars/scene; スラ recurs but lines are thin. Deepen authored dialogue + voice consistency per recurring character (in-scope authoring).|
|N6|Cutscene/beat density at peaks|56|70|partly|Arrival + 解決 modal + ✅ NEW 対決 peak (1f5bd4c: the final ナゾ is framed as the confrontation). All 3 bible beats now present as scripted text. REMAINING: richer multi-beat 解決 reveal + per-scene authored 対決 lines (in-scope); full T2 animation = gated.|
|N7|Recurring cast depth + arcs|60|70|now|スラ(one-step-behind), サイレント=アイラ, クワイエ(arc resolves 2級), ことのは. Arcs are seeded in canon; surface them in-scene (authoring).|
|N8|Environmental storytelling / world reactivity|67|70|now|grey→colour per solve is strong; ✅ a restored scene no longer replays its loss intro (f34f53b). REMAINING: secret hotspots + post-clear lore + richer revisit greetings (in-scope).|
|N9|Opening hook / first-run|70|70|now|story-first prologue (🔊 c·a·t blend) → config → painted landing. At bar; surpass via a stronger emotional cold-open beat.|
|N10|Pacing / 8-min session shape|68|65|now|home→ナゾ→colour→recap is tight. Tune beat spacing.|
|N11|Audio immersion (voice/SFX/music)|40|70|**gated**|SFX wired; no character VO, no adaptive music. Needs audio/voice gen → CEO resource (ElevenLabs).|
|N12|Replayability / post-clear content|62|60|now|✅ 事件簿 case-log shipped (1fd2768): re-read cleared cases + the assembling-bookmark sentence visualised as a collectible. REMAINING: post-clear secret hotspots + NG+ (in-scope, next).|

**Weighted narrative score ≈ 65/100** (Layton bar 70; 58→62→65 as N1/N3/N12
shipped 2026-06-14). We now **exceed** Layton on mystery structure (N1),
puzzle↔narrative integration (N2), per-solve story drip (N3), and meet it on
replayability (N12). Next lowest in-scope levers: cutscene beats (N6=45),
dialogue volume/voice (N5=55), env. storytelling (N8=62). We remain **far below**
on scene density (N4, gated) and audio (N11, gated).

## The honest answer to "when do we surpass Layton?"

Not by checklist-completion alone. Two tracks:

- **IN-SCOPE NOW (the loop drives these every narrative tick, no spend):** finish
  per-solve lore 7/7 (N3), deepen per-character dialogue + arcs (N5/N7), scripted
  cutscene beats at peaks (N6), post-clear secrets + case-log replay (N8/N12),
  cold-open polish (N9). Lifting these closes most of the gap on the dimensions
  where we already meet/beat Layton — realistic to push the weighted score to
  ~70–75 (Layton-grade) on in-scope work alone.
- **GATED (surface to CEO, don't self-spend):** scene/chapter density at scale
  (N4 — background art-gen), character voice + adaptive music (N11). These are
  what take us *decisively past* Layton; they need art/audio resource decisions.

**So:** the loop can reach Layton-grade on narrative with in-scope authoring; it
*surpasses* Layton once the gated art/audio scale is greenlit. The loop's job is
to (a) max out every in-scope dimension here, and (b) keep the gated gaps in
front of the CEO with the value quantified — not to silently accept the ceiling.

_Living doc — re-score only verified-shipped work; add dimensions as found._

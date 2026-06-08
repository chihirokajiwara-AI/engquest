# 7-CASE WORLD-DESIGN DEPTH AUDIT (2026-06-08)

**Trigger:** CEO msg 877 — "did you do a super-rigorous critical audit of the 7-case
design itself? how deep is it?" **Honest prior answer: no.** This is that audit.

**Method:** the `world-studio` adversarial loop (`.claude/workflows/world-studio.js`) —
super-critical lenses instructed to DEFAULT-REJECT. 4 of 5 lenses returned (the
child-engagement lens did not emit structured output; re-run pending). Lenses:
narrative depth, 英検-pedagogy, world-coherence, art-direction. Scores are 0–10.

## Verdict: the design is DEEP ON PAPER, SHALLOW IN THE BUILD. Overall ≈ 3.5/10.

| 級 | narrative | 英検 | coherence | art | ~avg |
|---|---|---|---|---|---|
| 5級 | 6 | 6 | 8 | 5 | **6.25** ← the only solid case |
| 4級 | 3 | 5 | 2 | 1 | **2.75** |
| 3級 | 3 | 5 | 2 | 4 | **3.5** |
| 準2 | 3 | 4 | 2 | 3 | **3.0** |
| 準2プラス | 3 | 3 | 4 | 5 | **3.75** |
| 2級 | 3 | 5 | 1 | 2 | **2.75** |
| 準1 | 5 | 4 | 5 | 6 | **5.0** |
| lens overall | 4 | 4 | 3 | 3 | **~3.5** |

## The single root cause (every lens converged on it)
**The rich WORLD-BIBLE / CHARACTER-BIBLE depth is NOT IMPLEMENTED in
`quest_data.dart` for 6 of 7 cases.** Only 5級 (Case 1) is fully authored.
- The named headliners (時計屋トック, 書庫番ミネ, 港の案内人ナギ, 橋守ロウ, 学士オーレン) —
  each designed so their 英検 skill IS their personality (puzzle-as-characterisation) —
  **never appear by name** in their own cases. Cases 4級→2級 are 20 generic
  QuestEncounters with emoji NPCs (せんせい/しょうにん/がくせい) that could be shuffled
  between cases with zero narrative loss.
- The **per-case lore drip** (WORLD-BIBLE §4 — the mechanism that makes solving English
  feel like uncovering the サイレント mystery) exists **only in 5級**. So the finale reveal
  has no assembled evidence behind it.
- **No local dramatic question** per case (Layton's "one haunting sentence"); every case
  is encounter-drill → boss → colour. A child finishing 4級 can't say what it was about.

## Concrete defects (beyond the build gap)
1. **ART — plate collision:** `town_2_castle.webp` is the plate for BOTH 4級 and 2級 →
   two of seven cases are visually identical; the 事件簿 index can't read as 7 places.
   準2 has TWO plates for one case. **No 7-node colour script** exists (mandated "before
   any art") → the grey→colour restoration has no graduated warmth arc. Only 1
   STYLE_BIBLE seed (5級) → 6 cases regenerate non-deterministically (cohesion = luck).
2. **英検 — grade-map contamination (breaks the mastery gate):** the 準2 case contains
   仮定法過去/過去完了 (2級 grammar); 準2プラス contains 仮定法過去完了 / inversion / cleft
   (2級/準1). "Case closed = would pass THIS grade" (COMPOSITION §1.1, the load-bearing
   claim) is invalid where the content is the wrong grade.
3. **英検 — writing is MCQ (Habgood failure):** every writing 大問 (E-mail/要約/意見) is
   "pick the correct pre-written model," training recognition, not production — yet
   writing is ~25–33% of 英検 score post-2024 reform. A child who clears all 7 cases in
   this mode still fails the real exam's writing. (Production scoring needs the AI
   backend, #7.)
4. **英検 — 5級 mismatch:** the 5級 exam has no phonics strand, while the dominant 5級
   大問1 (15-item cloze) has zero dedicated ナゾ. Phonics is a good pre-literacy on-ramp
   but is not 5級-exam-aligned; the on-ramp must sit ALONGSIDE real 大問1 cloze.
5. **COHERENCE — antagonist inconsistency:** the サイレント speaker changes per case
   (影 → invented servant "クワイエット / Lord Silentus" [a name in no other canon] →
   サイレントの手先 → unrelated 論駁の番人 → finally the real サイレント), unmooring the
   escalating-argument through-line.

## Deepening plan (CEO-gated; WORLD-BIBLE/CHARACTER-BIBLE spec-frozen)
Ranked highest-leverage first:
1. **Implement the bible in `quest_data.dart` for 4級→準1** — author the named headliners
   with skill-as-trait ナゾ + per-case lore drip + a local dramatic question +
   consistent サイレント escalation. *This is the #1 depth lift: the design already
   exists; the BUILD doesn't match it.* (content-qa gated.)
2. **Decontaminate the grade map** — remove wrong-grade grammar from 準2/準2プラス/etc.;
   align each case to its grade's actual post-2024 大問 structure. Protects the mastery gate.
3. **Fix the art collisions + author governance** — distinct 4級≠2級 plate, one plate per
   準2 case, the 7-node colour script, per-case STYLE_BIBLE seeds.
4. **5級: add real 大問1 cloze ナゾ** alongside the phonics on-ramp.
5. **Writing production** — replace MCQ-model-pick with real production + AI rubric scoring
   (depends on backend #7). Until then, label writing честно as "未測定/practice-only."

**Bottom line for the CEO:** the world's *concept* is strong (5級 and the 準1 finale prove
it), but the depth is mostly **unbuilt** — the loop wrote excellent bibles and then shipped
generic drills for 6/7 cases. Closing the design→build gap (item 1) is where world-class
depth actually gets made.

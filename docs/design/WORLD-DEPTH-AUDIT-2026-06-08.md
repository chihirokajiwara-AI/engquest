# 7-CASE WORLD-DESIGN DEPTH AUDIT (2026-06-08)

**Trigger:** CEO msg 877 — "did you do a super-rigorous critical audit of the 7-case
design itself? how deep is it?" **Honest prior answer: no.** This is that audit.

**Method:** the `world-studio` adversarial loop (`.claude/workflows/world-studio.js`) —
super-critical lenses instructed to DEFAULT-REJECT. The two sections below are: (1) a
manual 4-lens synthesis written while the run was still in flight, and (2) the
**authoritative full 5/5-lens director verdict** (the run completed in ~13 min — it did
not stall — and verified every finding against the actual code). Both reach 3.5/10; the
authoritative section governs. Lenses: narrative depth, 英検-pedagogy, world-coherence,
art-direction, child-engagement. Scores are 0–10.

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

---

## Authoritative director verdict (full world-studio run wf_86d2f055, 5/5 lenses, repo-verified)

_Note: the world-studio run did NOT stall — it completed in ~13 min (longer than the poll window). This director synthesis (all 5 critics incl. child-engagement, verified against the actual code) supersedes the manual 4-lens synthesis above; both reach the same score.
_

**Overall depth: 3.5/10. isWorldClass: False.**


### Honest verdict

The 7-case design is world-class ON PAPER and a grammar-quiz-with-a-skin IN CODE. I verified every audit against the repo: it is worse than the critics' average score implies, because the gap between docs/design/WORLD-BIBLE.md (genuinely excellent — inward spiral, restoration-not-conquest, puzzle-as-character, one lore drip per case) and lib/features/quest/quest_data.dart is near-total for cases 2 through 6. Concretely confirmed: ZERO of the five headliner characters (時計屋トック / 書庫番ミネ / 案内人ナギ / 橋守ロウ / 学士オーレン) appear by name anywhere in the code (grep = 0 each). The mid-arc サイレント lore drip is delivered in exactly ONE case (5級) — the WORLD-BIBLE §4 ITSELF admits "towns 2–6 are currently empty of this thread," and the code confirms it (every drip string greps to 0). There is an outright canon break: the boss in 準2 calls the antagonist "Lord Silentus" (quest_data lines 1184, 1589–1596), a name that exists nowhere else in the bible. The seed lines, the headliners, the ambient world-texture, the mentor ライラ先生 (grep = 0), and スラ's arc-closing line ("I am not one step behind you anymore") are all unbuilt — スラ is still stuck on "one step behind you" at lines 564/697 with no resolution. So the finale's emotional punch rests on a through-line that does not exist in the shipped content.

Two structural failures are graver than the narrative ones because they attack the SOLE VALUE TEST. First, the pedagogy: every writing 大問 (E-mail at 3級/準2, summary at 準2プラス/2級/準1, opinion essay) is implemented as MCQ selection of a pre-written model — the child recognises a compliant answer instead of producing English, so the Habgood test fails on precisely the 25–33% of post-2024 英検 scoring that is production. A kid who clears all seven cases this way still fails the real exam on writing. Second, grade-map contamination: 準2 contains 仮定法 and 過去完了 (2級 grammar), and 準2プラス contains 仮定法過去完了, cleft, and Not-only inversion (2級/準1 grammar). That breaks the "case closed = would pass this grade" mastery gate that COMPOSITION-ARCHITECTURE.md §1.1 declares load-bearing. On the art side I confirmed town_2_castle.webp is assigned to BOTH 4級 and 2級 (WORLD-BIBLE lines 75 and 79 — two of seven cases visually identical), only ONE of seven district seeds is documented in STYLE_BIBLE (5050), and the mandated 7-node colour script is still on the "Make" list (ART-DIRECTION §1.1) — i.e. every plate was generated with no governing emotional-temperature arc. The bones are genuinely world-class; almost none of the muscle is attached.


### Top deepenings (ranked)

1. BUILD THE FIVE HEADLINERS (トック/ミネ/ナギ/ロウ/オーレン) into their cases by name — all five are 100% absent from code (grep=0). Highest-leverage deepening: each one's puzzle-as-character mechanic IS the grade's English thesis, converting six faceless drill-treadmills into Layton cases. Without them there is no reason to care whether the clock restarts or the library opens.

2. AUTHOR THE CASES-2–6 サイレント LORE DRIP via one ナゾ's onCorrect per case (WORLD-BIBLE §4 itself admits these are empty; code confirms all drip strings grep to 0). This is what makes solving English feel like uncovering a mystery, and it is the load-bearing setup for the 準1 finale — currently a cold open. Same pass: add one local dramatic question + seed line per case so each closes a mystery instead of running a fetch-quest.

3. CLOSE THE PRODUCTION GAP — most dangerous flaw for the SOLE VALUE TEST. Every writing 大問 (E-mail, summary, opinion) is MCQ selection of a finished model, training recognition not production on the 25–33% of post-2024 英検 scoring that decides pass/fail. Convert to partial-model-with-blanks so MCQ enforces the output constraint. A child who clears all 7 cases as built still fails the real exam on writing.

4. DECONTAMINATE THE GRADE MAP — remove 仮定法/過去完了 from 準2 and 仮定法過去完了/cleft/inversion from 準2プラス (these are 2級/準1 grammar). The mastery gate ('case closed = would pass this grade,' COMPOSITION-ARCHITECTURE §1.1) is the architectural claim of the whole product, and it is invalid wherever the mapping is wrong (≥3 of 7 cases).

5. FIX THE 準1 BOSS so the ceiling-exam response forces COMPOSITION (gap-fill into サイレント's argument), not a guessable pre-written MCQ; make it the act of returning サイレント's actual first word. Add スラ's verbatim arc-closing line and the absent mentor ライラ先生 so the finale's emotional through-line actually exists.

6. ESTABLISH ART GOVERNANCE before any new plates: author the 7-node colour script (still on ART-DIRECTION's 'Make' list), document all seven district master seeds in STYLE_BIBLE (only 5050 exists), resolve the town_2_castle.webp collision so 4級 and 2級 are not the same image, and fix the 'Lord Silentus' canon break in quest_data.

7. CHUNK CASES INTO 2–5-ナゾ PAINTED CHAPTERS instead of one 20–32-item linear list so the lean-Layton pacing the bible promises actually exists; differentiate the arrival hook by grade so a 7-year-old (5級) and a 17-year-old (準1) are not given the identical three-sentence intro template.


### Per-case deepening proposals (CEO-gated; implementation spec for #59-61)


**5級 — ことばを失った村** (depth 6/10)

The proof-of-concept case; deepen it as the TEMPLATE the other six copy. (1) Add a LOCAL dramatic question the case closes: the clocktower stopped at a specific moment — each phonics/grammar solve recovers one fragment of 'what happened the morning the first word was spoken,' and 解決 answers it. (2) Make the seed line 「Once, I」 literally echoed by THREE named witnesses (セル/アン/ばあや) through the chapter, not only in cleared text, rendered in a handwriting/italic style so it reads as a clue. (3) Split the 32-item linear list into chapters of 2–5 ナゾ with a painted-plate beat between them (a 7-year-old will not sit through 32 then one payoff). (4) Pedagogy: rebalance toward the real 5級 exam — ~8 ナゾ as 大問1 short-sentence cloze (the largest point block, currently 0 dedicated items) and ~5 as 大問2 conversation gaps; keep the phonics arc but frame it as a PRE-5級 on-ramp, not as 英検5級 content (5級 has no phonics strand). (5) Art: give it a sound-architecture motif unique to the case (ear-shaped/speaking-tube windows, all cobwebbed; bell silent on arrival, ringing at 解決) so 'phonics = sound returning' is legible, stopped clock secondary.


**4級 — 風の街** (depth 3/10)

Build the headliner that is 100% absent. (1) 時計屋トック appears from encounter 1; his stopped watch is the through-prop. Each 時制 item solved visibly moves a clock hand (reuse the existing grey→color crossfade for partial state); when all hands tick he can say 'yesterday/tomorrow,' revealing the stopped TIME — encoding the lore drip 'it was humming, once' (WORLD-BIBLE §4.2) fired on his onCorrect at the irregular-past step, not on a faceless NPC. (2) Local question: 'what time did the clock stop, and why?' answered at 解決. (3) Seed line 「明日は、たしかに」 spoken by Tock + two witnesses. (4) Pedagogy: REMOVE item #18 word-order (語句整序 is 3級, mis-trains expectations); add a real 大問4 short-passage inference item; add one 2024 writing-output ナゾ (complete a 15–25 word two-point reply); fix Habgood-failing #7/#8/#16 (guessable by position/elimination). (5) Art: 4級 needs its OWN plate — a split building, amber past-wing + cool-blue future-wing with present-tense entrance between (seed 4040); stop sharing town_2_castle.webp with 2級.


**3級 — 学びの都** (depth 3/10)

(1) Build 書庫番ミネ guarding a SEALED DIARY: each present-perfect/passive item unseals one page; the diary content IS the lore drip — the Silence used to WRITE DOWN every word it heard (a keeper before a swallower). The last page is the revelation beat and feeds 準2's opening for cross-case continuity. (2) Seed line 「私はまだ、ここに」 in ミネ's first encounter. (3) Demote ハーモニー to a single walk-on (currently mis-cast as cleared-text headliner, collapsing the one-deep-headliner discipline). (4) Pedagogy (most damaging fix): the E-mail (#17) and opinion (#18) ナゾ must require PRODUCTION, not selection of a finished reply — use partial-model-with-blanks ('I am in the ___ club, and I practice ___ a week') so MCQ approximates the output constraint. Add 3–4 vocabulary-discrimination items (real 大問1 includes lexis, currently 0) framed as 'the archivist's note has a strange word — which fits?'


**準2級 — 社会の港町** (depth 3/10)

(1) FIRST fix the canon break: replace 'Lord Silentus' (quest_data 1184, 1589–1596) with サイレント everywhere. (2) Build 案内人ナギ as a harbour gate-keeper who answers questions only with questions until you STATE an opinion (correctly formatted) — every 意見表明 item becomes 'satisfy ナギ or stay stuck.' Establish クワイエト (code-only addition) at ~encounter 12 so the boss has setup. (3) Local mystery: the last surviving vocabulary list vanished; opinion-correct solves recover ship's-log fragments; the email task becomes diegetic (write the harbour master for records). Lore drip 'it stopped after two people hurt each other with words' fires at ナギ's 解決. Seed line 「だれかが、ちがうと言った」. (4) Pedagogy: REMOVE past perfect (#7) and subjunctive (#12–13) — 2級 grammar that corrupts the mastery gate; replace with real 準2 大問1 targets (phrasal verbs, modal perfects, B1 不定詞/分詞). Collapse the three fragmentary email ナゾ into ONE 25-word cloze-completion. Redesign the boss MCQ so the correct option is not trivially the longest/most complex string.


**準2級プラス — 試練の橋** (depth 3/10)

This is the real-world DROPOUT WALL (準2→2), needing the strongest emotional scaffold AND the strictest grade map. (1) Build 橋守ロウ as a single named keeper carrying the mid-span lamp; the boss IS ロウ — fog clears one panel per correct summary, and only when the child carries meaning exactly (not more, not less) does he let them pass. His admission that he has held the bridge alone for years is the character moment that counters the wall. Lore drip 'it believed if no one spoke, no one could be wounded' on the paraphrase task; seed line 「向こう岸の声が」; consider restoring a DIRECT サイレント encounter here to end the boss-substitution drift. (2) Pedagogy (worst-mapped case): remove 仮定法過去完了 (#7), 分詞構文 (#8), cleft/強調 (#9), inversion — all 2級/準1. Map every item to the actual 準2プラス 大問1/2 spec (B1-high social vocab, relative adverbs, causative make). Redesign the summary ナゾ toward extraction-under-constraint; add a narration-preview ナゾ (3-panel → pick the most coherent 3-sentence past-tense narration) to prime the grade's UNIQUE Speaking component. (3) Art: far bank visible and warm-amber (a hint of 2級) while near side grey-cold; bridge stone engraved with sentences that become legible as colour returns (seed 2PP25).


**2級 — 学者の城下町** (depth 3/10)

Highest narrative upside in the file — currently the emptiest. (1) Build 学士オーレン, whose thesis ('he hides behind formal register because silence was safer') is the PERFECT match for this case's lore drip. He refuses to engage except in correct formal/passive/subjunctive register; each debate win extracts one admission; the final admission reveals which book was removed the night the Silence spread and who ordered it — the drip lands as a confession: 'We agreed silence was safer. We let it swallow the rest.' This is an indictment of COMPLICITY the player EARNS by beating him in his own register — a 解決 beat ('regret/witness') distinct from reunion/revelation. Make the mini-boss オーレン himself, not the un-set-up 論駁の番人 stone guardian. His 解決 letter is carried to 準1 for continuity. Seed line 「黙っていれば、安全だった」. Introduce 〈ことばの紋章〉 earlier so its 2級 payoff lands. (2) Pedagogy: grammar coverage is the most accurate in the file; the gap is the 2024 大問4 summary task, currently MCQ recognition — add a summary ナゾ with a 4-sentence frame + two blanks that maintain main idea without adding opinion. Replace pure register-guessing items #1–3 with 2級 vocabulary-discrimination (派生語/語形変化). (3) Art: 2級 needs its own plate (stop sharing town_2_castle.webp) — vertical power staging, ascending gates each opened by a different register, the darkest warm-plum before 準1's grey (seed 2020).


**準1級 — 灰色の最後の広場** (depth 5/10)

Strongest case, but its payoff depends on a through-line that is not built. (1) MANDATORY prerequisite: author the cases-2–6 lore drips and headliners FIRST, or this finale is a cold open — the player is told the answer without having gathered clues. (2) Make スラ's finale line verbatim 「I am not one step behind you anymore」 (the seven-beat arc climax; スラ currently never resolves past 'one step behind'). Add the mentor ライラ先生 (absent from code): she appears in written text only, voiceless, until 解決, where her notebook entry gains a spoken voice for the first time as colour floods — a personal mirror of the world arc. Reference オーレン's letter arriving. (3) Boss redesign: the most advanced response in the ceiling exam must not be a tappable pre-written MCQ a child can guess 'C' on. Convert サイレント's confrontation to a gap-fill forcing COMPOSITION ('peace built on ___ words is not peace but a ___') — filling the blank IS giving サイレント its voice back, and Habgood passes. Have サイレント speak its actual first word; the correct action is the player returning THAT specific word, dramatising the 「最初のひとことを、返して」 mechanism. (4) Pedagogy: vocabulary too thin (5 of 20; real 準1 大問1 is 25 low-frequency academic items) — add 8–10 vocab-discrimination ナゾ ('worn inscriptions — which precise word restores meaning?'). Lengthen inference passages toward real 300–500-word complexity. Convert summary/opinion from selection to partial-completion. Add a 二次 preview (read-aloud passage → content-T/F → opinion). (5) Art: this is the emotional peak — give the boss a T2 painted/multi-panel treatment (サイレント is currently a 🌑 emoji); design the サイレント asset (faceless drift, cracked hourglass) BEFORE finalising the plate; render the grey square with watermark-pale ghost-silhouettes of the six prior cases' architecture so it reads as the CENTRE the Silence walked outward from, not a generic void (and not identical to 5級 in the 事件簿 index).

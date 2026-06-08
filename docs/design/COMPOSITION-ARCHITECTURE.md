# COMPOSITION ARCHITECTURE — LEAN-LAYTON (FROZEN by CEO msg 863, 2026-06-08)

**Status:** BINDING. This is the single source of truth for *how the game is composed*
— the shape of a session, what a chapter is, where puzzles and cutscenes sit, and
which existing screens/flows are retired or repurposed. It overrides the
Dragon-Quest-hybrid framing in `A-KEN-QUEST-DESIGN-BIBLE.md §1–§2` wherever they
conflict (see §7 "What is removed"). It is consistent with, and cross-references:
`WORLD-BIBLE.md`, `CHARACTER-BIBLE.md`, `ART-DIRECTION.md`, and the frozen
`OPENING-NARRATIVE-BIBLE.md` (premise/prologue/no-scold spine are preserved exactly).

The sole value test stays: **"an app that gets a kid to PASS 英検."** Lean-Layton is
not a thematic preference — it is the production architecture that lets a small team
ship a world-class painted 英検 RPG without a DQ-scale content factory.

---

## 0. The correction in one sentence

We started DQ-style (walk an overworld, grind levels across towns, collect 6 stones),
drifted into a DQ/Layton hybrid, and the composition warped (歪). **Correct it:** there
is **no character map-movement and no level grind**. The story moves forward through
**static painted scenes**; a **英検 item is the puzzle to solve *in* that scene**
(Layton's puzzle-in-the-world); solving it advances the case. A **級 is a 事件簿 (case
file)**, not a town to wander. The cast is **small and deep**, not a large roster.

---

## 1. The unit of play: 事件簿 (case file) = one 英検 grade

Seven case files, one per grade — `5 → 4 → 3 → 準2 → 準2プラス → 2 → 準1`. (Seven, not
six: 英検 added 準2級プラス in 2025; see `WORLD-BIBLE.md §3`.) A case file is **not** a
place you walk around. It is a **bound sequence of chapters** the detective works
through, like the chapters of a Layton mystery or a 事件 in a 名探偵 manga.

```
事件簿 (級)                       e.g. 事件簿 其ノ一「ことばを失った村」(5級)
 ├─ Chapter 1  (静止画 scene + 数件のナゾ + 1 cutscene beat)
 ├─ Chapter 2  ...
 ├─ ...
 └─ Final Chapter = 対決 (the サイレント confrontation = the boss ナゾ)
解決 (case closed) → 声の石 lights, colour floods the case art, next 事件簿 unlocks.
```

A **chapter** is one **static painted scene** (one WebP plate) that the detective
"reads," plus **2–5 ナゾ (英検 items)** framed as the mysteries *in that scene*, plus at
most **one cutscene beat** at a story peak. No traversal between scenes — finishing a
chapter **cuts** to the next scene (a hard cut or a held dissolve, never a walk).

This maps 1:1 onto code we already have: a chapter ≈ one `SceneDef`
(`lib/features/explore/hotspot.dart`) rendered by `SceneView`; a ナゾ ≈ a `Hotspot.npc`
carrying a `QuestStep` opened in `NazoScreen`. **We are not inventing a new engine — we
are declaring SceneView the spine and retiring the level-grind map as the spine.**

### 1.1 Why this fits 英検 (the load-bearing claim)
- **Intrinsic integration** (Habgood/Ainsworth; `ChildrensEducational.json`): the 英検
  item *is* the mechanic. You cannot close the case without producing correct English.
  The Habgood test is the gate: *can the child answer without understanding the English?*
  If yes → redesign the distractors. Enforced by the existing `content-qa` agent.
- **Puzzle-as-characterisation** (Layton; `GameHistoryProfessor.json`): the ナゾ a
  character poses *is* who they are. The grammar point never changes; the framing
  becomes the character. (`CHARACTER-BIBLE.md` assigns each grade's skill to a person.)
- **Mastery framing, never performance framing**: a wrong answer is "色がまだ戻っていない
  ／もう一度きいて," not "不正解." Picarats-style decay (full→70%→40%, never zero) gives a
  gradient without learned helplessness. (`GameHistoryProfessor.json` concreteTechniques.)
- **Mastery gate = a real 模試.** A case file is *closed for keeps* only when the child
  passes that grade's 2024-format mock in the 合格 band AND FSRS stability holds across
  intervals (no cramming through). Story chapters can be played; **ability cannot be
  skipped.** "Case closed" is operationally synonymous with "would pass this grade now."

---

## 2. Story progression = static images + targeted motion (no overworld)

The default visual state of the game is a **single static painted plate filling the
frame** with the painted UI (`DqDialogBox` / command window) composited on top. The
story advances by **changing the plate** and by **inserting cutscene beats at peaks** —
never by moving a character avatar across a map.

Three motion tiers, in ascending production cost. Prefer the cheapest that lands the beat:

| Tier | What | When | Cost |
|---|---|---|---|
| **T0 Static** | One painted plate, painted UI over it | The default — every chapter "reads" as a still | ~0 (one WebP) |
| **T1 Living-still** | Static plate with ONE small element lightly animated (lamp flicker, mist drift, a 🔊 letter-trace, a grey→colour saturation tween) | On scene entry; on ナゾ solve (the restoration payoff) | low (Flutter tween / ColorFiltered / 1 sprite) |
| **T2 Cutscene beat** | 2–3 painted panels with slide/parallax + one voice line + the leitmotif | EXACTLY at: case **Arrival**, the **対決** (boss), and case **解決** | medium (reuses existing plates) |

**Hard budget (Layton's rule, `GameHistoryProfessor.json`):** at most **3 T2 cutscene
beats per case file** — Arrival, 対決, 解決. More inflates cost; fewer wastes the
emotional punctuation. Everything between those three beats is T0/T1.

This is already half-built: the frozen `OPENING-NARRATIVE-BIBLE.md` specifies the
6-panel prologue (a T2 sequence) and a reusable 3-beat `ArrivalScene` (APPROACH → A
VOICE REACHES YOU → YOUR MOVE). **Lean-Layton makes ArrivalScene the *only* between-
chapter ceremony, and replaces "travel to the next town on a map" with "cut to the next
chapter's plate."**

### 2.1 The grey→colour mechanic IS the world animation
We do not need character walk-cycles to make the world feel alive. The single most
important motion in the game is **colour returning when a word returns**.

**The restoration UNIT is the CHARACTER, not the scene plate (CEO msg 871, 2026-06-08
— asset-scaling correction).** 英検 vocabulary is thousands of words across grades. If
"restore colour" were keyed to *scene plates*, covering that vocabulary would demand a
huge number of painted backgrounds — it does not scale. Instead:

- **PRIMARY — per-character restoration (scales with the cast, not the vocab).** Each of
  the small, deep cast (`CHARACTER-BIBLE.md`) owns a **task list** of many 英検 items
  (vocab / phonics / a skill). The character starts greyed and speaking only "one lonely
  sound / a broken at-level line"; **clearing their tasks gradually returns their colour
  and their voice** (broken → full phrases). ONE character's two assets (`_grey`/`_color`)
  are reused across *dozens–hundreds* of items, so the asset count is **≈ (#characters × 2)
  + a few scene plates**, independent of vocabulary volume. `SceneView` already cross-fades
  each NPC `grey→color` on solve (`AnimatedCrossFade`); extend it to **partial/progressive**
  restoration as a character's task list is worked through.
  - *Canonical 5級 example (CEO):* 灰守セル speaks a single phoneme (`/s/`); clearing each
    of her phoneme tasks one-by-one returns her colour, and at the end she speaks normal
    words. The character is the vessel; the many items ride on her.
- **SECONDARY — whole-plate colour flood = the once-per-CASE 解決 ceremony only.** On
  closing a 事件簿 (not on every chapter), tween a `ColorFiltered` saturation matrix
  (muted floor `0.35 → 1.0`) over ~2s on the background (`Painted2DGameArtDire.json`;
  implemented in `SceneView`, commit b8b26d5). Because it fires **once per case (7 total)**,
  it adds **zero** per-vocab art cost. It is the emotional punctuation, not the workhorse.

Net: the workhorse that carries 英検 volume is the **character** (cheap, reused); the
scene-flood is a rare finale. This keeps production within a small-team budget.

---

## 3. How a 英検 item is framed as the on-scene puzzle (the exact contract)

Every ナゾ is a `Hotspot.npc` in a `SceneDef`, carrying a `QuestStep` (the existing
`QuestEncounter`/teach-step types in `quest_data.dart`). The framing pipeline, in order:

1. **Read the scene.** The static plate is on screen. The detective (player) sees 2–5
   tappable people/objects (`Hotspot`s), each lightly haloed. This is the "crime scene."
2. **A witness speaks.** Tap an NPC → they mutter their **one lonely sound / broken
   at-level line** (`clueLineJa`, voiced best-effort) and a 「？」bubble appears. The NPC
   is greyed (`npcGreyAsset`) — their voice is missing.
3. **The mystery surfaces.** Tap 「？」→ `NazoScreen` opens with the NPC's **in-world
   framing** (`framingJa`) above the 英検 stem. The stem is **the grammar gap as a clue**,
   never "Q: choose the answer." Example (3級, the archivist): *「この日記の最後の行が、ひと
   ことだけ にじんで読めない。『I have ___ here for ten years.』— 彼は今もここにいる。どの語?」*
   The present-perfect *is* the clue to "he is still here."
4. **Reasoning, not guessing.** Picarats decay; ひらめきコイン (hint coins, already in
   `HintCoinService`, found as tappable scenery `Hotspot.coin`) buy a **rule reveal**
   (the grammar rule), never the answer. (`GameHistoryProfessor.json` hint-economy.)
5. **Solve → restoration.** Correct → the NPC `grey→color` cross-fades, speaks their
   **first full at-level phrase**, and drops **one fragment of サイレント lore**
   (`WORLD-BIBLE.md §4`, the per-grade lore drip). Wrong → mastery-framed, replay 🔊, no
   red scold for teach steps; Picarat decays for graded items.
6. **Chapter clears** when all its ナゾ are solved → T1 plate colour-flood → cut to the
   next chapter's plate (or, at case end, the 解決 T2 beat).

**Discipline (from the research, enforced by `content-qa`):**
- The correct option NEVER contains the same keyword as the NPC line (kills pattern-match).
- Three distractors are diagnostic errors (D1 vocab confusion / D2 grammar trap / D3
  pragmatics), and a wrong pick teaches *why* it's wrong (corrective retrieval).
- The ナゾ's topic matches the witness's identity (musician → rhythm/gerund; archivist →
  perfect tenses/memory; harbour pilot → questions/opinion). See `CHARACTER-BIBLE.md`.

---

## 4. Session shape (what a child actually does in 8 minutes)

```
Launch → KotobaHomeScreen (探偵の捜査日誌 streak + きょうのナゾ FSRS-due)  ← KEEP
  ▶ つづける → cut straight into the current chapter's painted SCENE (SceneView)  ← SPINE
       read scene → solve 2–5 ナゾ → chapter clears (colour flood) → next chapter
  (at case peaks) → T2 cutscene beat (Arrival / 対決 / 解決)
  「きょうのナゾ」(FSRS-due) → the same scene, desaturated, recolouring as cards mature
       (ludonarrative SRS bridge — the deck IS the voice-stones; ChildrensEducational.json)
  「英検れんしゅう」→ the 模試/大問 hub = the MASTERY GATE that truly closes a case  ← KEEP
```

`KotobaHomeScreen` is already the landing and already frames everything as a 探偵 case-log
(`きょうの ナゾ`, `じけんげんばへ`). **Lean-Layton keeps the home, but its primary CTA must
land in the SCENE, not the map.** Today `_goToScene()` falls back to `QuestMapScreen` for
grades without a painted scene — that fallback is the warp leaking through (§7). The fix
is to ship a `SceneDef` for every grade so the spine is always the painted scene.

---

## 5. Where cutscenes and partial animation go (precise placement)

Per case file, exactly three T2 moments + T1 sprinkled on solves:

- **Arrival (T2)** — the reused `ArrivalScene` (3 beats, `OPENING-NARRATIVE-BIBLE.md`):
  faded case art + name + "lost thing" → first witness pops in greyed and makes their
  lonely sound → consistent soft CTA. Escalates HOPE by grade via `arrivalHookJa/En/Sound`.
- **対決 (T2)** — the サイレント confrontation = the **final chapter's single ナゾ**. Not a
  battle; a **conversation** at the grade's ceiling. The correct option is the most
  *emotionally honest* reply that is also grammatically correct (Horii's DQ5 principle;
  `GameHistorianDragonQ.json`). 2–3 panels, faceless grey drift, the leitmotif.
- **解決 (T2)** — 声の石 lights, the case plate floods grey→colour, the recovered headliner
  speaks their first full phrase, one big サイレント-lore reveal lands. Each case's 解決
  uses a *different* emotional beat type (reunion / revelation / sacrifice / warmth /
  stakes) so the seven endings don't feel identical (`ChildrensEducational.json`).
- **T1 on every solve** — NPC grey→colour, a lamp/rooftop/flower tints, the 「word-returns」
  chime. This is the per-second feedback that makes a static world feel responsive.

No cutscenes anywhere else. Between beats it is read-scene → solve-ナゾ → cut.

---

## 6. Concrete build plan against the current code

| Concern | Current | Lean-Layton target |
|---|---|---|
| Spine | `KotobaHome → QuestMapScreen (level-select list)` then `QuestScreen` linear quiz runner | `KotobaHome → SceneView` (painted chapter) as the only spine; chapters cut scene→scene |
| Scenes | `SceneView` exists; `SceneDef`s for 5級 + partial others; grades without a scene fall back to the map | A `SceneDef` (or several = chapters) authored for **every** grade so the map is never the entry |
| Puzzle | `NazoScreen` exists, opened from a hotspot | Keep. This is the Layton puzzle-in-the-world. Tighten framing per §3. |
| Map | `QuestMapScreen` = travel/unlock/声の石 trail = the warp's spine | **Repurpose** to a passive **事件簿 index / progress painting** (read-only chapter list + colour state), reachable via「ちずを みる」secondary CTA. NOT the entry, NOT a traversal surface. |
| Linear runner | `QuestScreen` runs a town's 20 encounters back-to-back as the main flow | **Repurpose** as the per-chapter ナゾ host invoked from a scene, or retire in favour of `SceneView`+`NazoScreen`. It must not be the primary loop. |
| Restoration | per-NPC grey→colour on solve | add **whole-plate** saturation tween on chapter clear (§2.1) |
| Mastery gate | `ExamPracticeScreen` / mock reachable from home | Keep; bind "case closed" to passing the grade's mock + FSRS stability (§1.1) |

Implementation order is in §C of the governance append; the top 3 are: (1) author a
`SceneDef` chapter set for every grade so the scene is always the spine; (2) repurpose
`QuestMapScreen` from traversal-spine to a read-only 事件簿 index; (3) whole-plate
grey→colour clear tween.

---

## 7. What is REMOVED / repurposed (name the warped flows)

These are the specific DQ-hybrid elements that distorted the composition. **Removed or
demoted, by name:**

1. **Map traversal as the spine — REMOVED.** `QuestMapScreen` (`lib/features/quest/
   quest_map_screen.dart`) currently is the post-home spine: "the hero travels level by
   level… unlocks the next by clearing a town," a glowing town-node trail. There is **no
   character walking a map** in lean-Layton. Demote it to a passive 事件簿 index (read-
   only), reachable only via the secondary「ちずを みる」CTA. The entry is the painted scene.
2. **Level grind / "travel town to town" loop — REMOVED.** No XP grind to advance; advance
   is solving the case's ナゾ. (FSRS still runs as spaced review — that is *learning*, not
   *grinding* — surfaced diegetically as「きょうのナゾ」.)
3. **The "6 声の石 → walk to collect them" framing — REVISED to 7 case files.** Seven cases
   (準2プラス included), and the 声の石 is the *payoff of closing a case*, not a pickup you
   travel to. The home CTA must land in the scene, not route to the map fallback
   (`KotobaHomeScreen._goToScene` fallback is the warp leaking — close it by giving every
   grade a `SceneDef`).
4. **Large DQ-style roster — REMOVED.** `A-KEN-QUEST-DESIGN-BIBLE.md` implies many NPC
   archetypes per town (teacher/baker/guard repeating). Lean-Layton uses a **small, deep
   cast** (`CHARACTER-BIBLE.md`): protagonist きみ, mentor, mascot スラ, サイレント, +
   exactly **one deep headliner per grade** (seven), plus thin walk-on witnesses only as a
   chapter needs them. Deep over many.
5. **DQ-style "level-up fanfare as the growth ceremony" — REPLACED** by the colour-flood +
   声の石 + first-full-phrase at 解決. (A short fanfare can still punctuate it, but the
   *ceremony* is restoration, not a stat-up jingle.)
6. **The prince/heir/throne/王都/👑 royalty thread — ALREADY REMOVED** by
   `OPENING-NARRATIVE-BIBLE.md` (recast to restoration, not conquest). Lean-Layton keeps it
   removed; the mandatory post-edit leakage grep stays in force.

**Kept (build on, do not replace):** `SceneView` + `Hotspot` + `NazoScreen` (the
puzzle-in-the-world engine), `KotobaHomeScreen` (the 探偵 home/landing), `HintCoinService`
(ひらめきコイン economy), grey/color WebP pairs, `STYLE_BIBLE.md` district seeds, the
prologue + `ArrivalScene`, the 模試/大問 mastery gate, FSRS as the review spine.

---

## 8. The single most important removal

**Map traversal as the spine.** Killing "walk the overworld town-to-town and grind to
unlock the next" — and making the **static painted scene the entry and the spine, with the
英検 item as the puzzle inside it** — is the whole pivot. It cuts production load (no
overworld, no walk-cycles, a small cast), restores the Layton composition, and keeps every
gram of 英検 rigour (the puzzle still gates on producing correct English). Everything else
in this doc serves that one move.

# CHARACTER BIBLE — A SMALL, DEEP CAST (lean-Layton)

**Status:** BINDING casting canon. Lean-Layton (CEO msg 863) mandates a **small cast,
each deeply crafted** — NOT a large DQ roster. This file locks the **four core
characters** + **one deep headliner per 事件簿 (seven)** + a thin bench of walk-on
witnesses used only as a chapter needs them. Every entry follows the AAA/JP discipline in
`CharacterDesignAAAJP.json` and `ChildrensEducational.json`. Cross-refs:
`WORLD-BIBLE.md` (cases), `COMPOSITION-ARCHITECTURE.md` (how they pose ナゾ), `ART-
DIRECTION.md` (look/seed/perf), `STYLE_BIBLE.md` (style-lock + per-character seeds).

**Design rules applied to every character (the gates):**
- **Blackout Test** — readable as a solid-black silhouette at 64px; if role isn't legible,
  redesign before any colour (`CharacterDesignAAAJP.json`, `GameHistoryProfessor.json`).
- **Shape language** — round = friendly/safe; square = reliable/authority; triangle =
  sharp/sad/dangerous. Costume + face echo the primary shape ≥2×.
- **60-30-10 colour** — one dominant identity hue, one secondary, one accent. **No two
  characters in a scene share a dominant hue.** Hues drawn from `STYLE_BIBLE.md` palette
  (dusty teal #5DA9E9 · brass amber #E0A458 · cream #F5EFE0 · plum #4A3B52).
- **Single-desire (Horii)** — one want, one obstacle, expressed in their lines.
- **Puzzle-as-character** — the 英検 skill they pose *is* their personality, not a topic
  they discuss.
- **Two-state** — every character needs `_grey.webp` (voice lost) + `_color.webp`
  (restored); silhouette must survive desaturation.
- **5 expressions max** — neutral, curious, afraid, joyful, determined. Consistency over
  range (children read emotion slower).
- **3-line bible** — (1) one-sentence desire (2) one-sentence obstacle (3) the 英検 skill
  they embody as a trait. Every line of dialogue serves one of the three.

---

## CORE CAST (4) — appears across all seven cases

### 1. きみ — the child detective (PROTAGONIST)
- **Role / fiction:** the player. An ordinary traveller, no royal blood, no fixed gender —
  the one person who can still **hear the sounds inside words and voice them**. The phonics
  skill the child is learning IS the superpower (preserved from `OPENING-NARRATIVE-BIBLE.md`;
  guard hard against any chosen-one back-door).
- **Why designed (gap):** currently きみ is a pronoun with **no visual** — no anchor on the
  title/解決 screens. AAA studios spend ~30% of character budget here; everything else is
  measured against the protagonist (`CharacterDesignAAAJP.json`).
- **Visual hook:** a **detective's listening device** — a small brass ear-horn / 聴音器 worn
  on a cord (the "magnifying glass" of a *sound* detective). One distinctive prop, no other
  character has it. Gender-neutral silhouette = the avatar the child picked in onboarding.
- **Shape / colour:** soft-round hero shape; dominant **cream**, accent **gold** (the one
  surviving spark from the prologue). Reads as "the warmth the Silence couldn't take."
- **Voice:** mostly silent (the player projects onto them — DQ silent-hero principle); スラ
  speaks the companion commentary. きみ "speaks" only through the English the player produces.
- **3-line bible:** (1) wants to give every voice back. (2) is still *practising* — not a
  magic exception, the one who hasn't stopped. (3) embodies **phonemic awareness** — the
  ability to decode/voice sounds, the root skill all seven cases build on.
- **Name:** きみ (2-syllable, no rare kanji, used as direct address). Earned title
  「ことばの勇者」grows from the count of voices returned.

### 2. ライラ先生 — the mentor (MENTOR)
- **Role:** the Layton figure children aspire *up* to. A retired 準1級 examiner who lost her
  own voice to the Silence but can still **write**; she sets each case and sends きみ in.
  ("I'm taking you to the next one.") Replaces the old generic "guide / 賢者ウェブスター."
- **Why this character:** Layton works because the mentor is more famous than the apprentice
  (`CharacterDesignAAAJP.json`). Her arc — she lost her voice, the player returns it at the
  準1級 finale — mirrors the world arc in miniature, giving a *personal* stake.
- **Visual hook:** circular glasses + a worn **notebook** she writes in (she can't speak).
  Primary shape: **square body** (authority/reliable) + **circle glasses** (kind). Dominant
  **brass amber**. Greyed until each case clears, then a little colour returns to her.
- **Voice:** written, shown as elegant handwriting in the dialog box; warm, precise, never
  lectures the player — addresses きみ as a fellow detective who already knows.
- **3-line bible:** (1) wants to hear her own voice once more. (2) can write but not speak —
  she needs きみ's ears and voice. (3) embodies **examiner's precision** — she frames each
  case in terms of exactly what 英検 skill it will test, the bridge between story and 合格.

### 3. スラ — the learning companion / mascot (MASCOT)
- **Role:** the player's living mirror, **exactly one grade behind** — at 4級, スラ speaks
  5級 phrases. Hears its own past self in the player; the player feels like a *teacher*
  (the strongest engagement loop in ed-design; `CharacterDesignAAAJP.json`,
  `ChildrensEducational.json`). Builds directly on the existing スラ in `quest_data.dart`.
- **Why deepen:** スラ already appears in every case but has undifferentiated dialogue and no
  arc. The DQ Slime is beloved because it is constraint-driven simplicity + a "character job."
- **Visual hook (Toriyama rule):** a round **teardrop/orb** body, two expressive dot eyes,
  and a **word-bubble near its mouth that changes as it learns** (a visible vocabulary
  counter). Must pass the Blackout/silhouette test at **16px**. App-icon / merchandise seed.
- **Shape / colour:** pure circle (friendly/safe); dominant **dusty teal**; a single warm
  accent that brightens as it grows. Starts greyed; gains colour as words return.
- **Voice:** simple, eager, naive — asks the question the child is thinking (Luke's role).
  One memorable flaw to drive attachment: **afraid of being left behind** (becomes
  plot-relevant; `ChildrensEducational.json`).
- **Seven-beat arc** (one line per case 解決; pure copy, no engineering):
  1) 5級「I can say one word.」(Hello — already in canon)
  2) 4級「I can say two words now.」
  3) 3級「I asked someone a question — for the first time.」
  4) 準2「I disagreed with someone… and I was right.」
  5) 準2プラス「I told someone something that scared me.」
  6) 2級「I spoke for someone who couldn't.」
  7) 準1「I'm not one step behind you anymore.」
- **3-line bible:** (1) wants to keep up with きみ. (2) is always one grade behind / afraid
  to be left. (3) embodies **the spaced-review loop made lovable** — it speaks the *prior*
  grade correctly, so the player hears mastery at their own retention level.
- **Name:** スラ (onomatopoeic, voiced consonant, warm). Keep the canonical 🟢/orb identity.

### 4. サイレント / the Silence — the antagonist (ANTAGONIST)
- **Role:** not a 魔王 — a melancholy phenomenon who believes silence is peace. The 対決 in
  every case is a **conversation** at that grade's ceiling, not a fight; the finale **returns
  its own last word to it** (`WORLD-BIBLE.md §2`, `OPENING-NARRATIVE-BIBLE.md`).
- **Why deepen:** the strongest emotional concept in the game ("I am tired. And very, very
  quiet.") but currently only an emoji (🌑) + dialogue. Children can't attach to an
  antagonist with no design, so the finale under-lands (`CharacterDesignAAAJP.json`).
- **Visual hook (antagonist-as-wounded-self):** a tall, **faceless grey drift** — no army,
  no throne, only a *suggestion* of a face. One prop: a **cracked hourglass whose sand has
  stopped** (time stopped when it stopped speaking — encodes the backstory without
  exposition). Triangular/angular silhouette = completely different shape language from the
  warm round witnesses.
- **Shape / colour:** monochrome plum-grey on grey; the **only** character with no dominant
  hue — it is *the absence of colour*. As the world heals it gains the faintest warmth; at
  the finale, colour floods it.
- **Voice:** quiet, sad, never threatening — no horror beat for 6-year-olds. States its
  belief, never lectures ("Silence is peace… why bring words back, little one who can still
  hear me?"). The world *answers by becoming warmer*, not by argument.
- **3-line bible:** (1) wants the wounding to stop. (2) believes the only way is to swallow
  all words — its wound is the player's own fear (of sounding wrong, of silence) writ large.
  (3) embodies **the 準1級 ceiling** — nuance, register, the conversation that returns its
  voice.

---

## HEADLINERS — one deep character per 事件簿 (7)

Each case has **one** deeply-built witness who **embodies that grade's skill as a
personality trait** (the puzzle they pose *is* who they are). Build on the named NPCs that
already exist in `quest_data.dart` 5級 where sensible. Each gets: name · dominant hue · 3-word
identity phrase (verbatim for art generation) · one prop · 3-line bible · grey/color pair.

| # | 級 | Headliner | Identity phrase (for art) | Hue | Prop | Embodies (英検 skill as trait) |
|---|---|---|---|---|---|---|
| 1 | 5級 | **灰守（はいもり）セル** (exists) | "grey ember-keeper elder" | brass amber | a dying ember in cupped hands | the first **sound** returning; he can voice one phoneme — phonemic awareness |
| 2 | 4級 | **時計屋トック** (the clockmaker) | "small round clockmaker" | dusty teal | a **stopped pocket-watch** | **tense** — he can only speak of *now*; teach past/future to restart his clock |
| 3 | 3級 | **書庫番ミネ** (the archivist) | "tall thin spectacled archivist" | plum shadow | a sealed diary | **present perfect / memory** — "I have lived here for…"; reading the sealed stacks |
| 4 | 準2 | **港の案内人ナギ** (the harbour pilot) | "weathered harbour pilot, coat" | dusty teal | a foghorn / signboard | **opinion / questions** — answers questions only with questions until you give a view |
| 5 | 準2プラス | **橋守ロウ** (the bridge-keeper) | "lone lamp-bearing bridge keeper" | brass amber | the **mid-span lamp** | **summary / cohesion** — carries meaning from one bank to the other; dense 読解 |
| 6 | 2級 | **学士オーレン** (the scholar) | "robed formal castle scholar" | plum shadow | a debate gavel / scroll | **register / argument** — formal, passive, subjunctive; debate to change his mind |
| 7 | 準1 | (the 対決 itself — **サイレント**, see core cast) | — | — | cracked hourglass | **nuance** — the conversation at the ceiling |

(5級 also keeps its existing charming bench — アン, タオ, ミィ the cat, ロブ the dog, ノナ —
as **thin walk-on witnesses**, each with one trait + one line, per `quest_data.dart`. Some
reappear as cameos in later cases to show they recovered; `ChildrensEducational.json`.)

### Headliner 3-line bibles (the deep ones, beyond the table)
- **時計屋トック (4級):** (1) wants his clock to tick again. (2) is trapped in the present
  tense — he literally cannot say "yesterday" or "tomorrow." (3) embodies **時制**; each
  past/future word the child returns moves a hand on his stopped watch. Carries the 4級
  lore drip ("it was humming, once").
- **書庫番ミネ (3級):** (1) wants to finish reading a diary she has guarded for years.
  (2) the stacks are sealed — only completed *perfect-tense* sentences open them.
  (3) embodies **現在完了 / 読解 / memory**; she found the diary that says the Silence used to
  *write down* every word (3級 lore drip).
- **港の案内人ナギ (準2):** (1) wants the two guilds to stop arguing past each other.
  (2) won't give a straight answer — answers questions with questions — until you state an
  opinion. (3) embodies **意見表明 / 会話**; carries "it stopped after two people hurt each
  other with words" (準2 lore drip).
- **橋守ロウ (準2プラス):** (1) wants someone to reach the far bank. (2) the bridge is fogged
  — you can only cross by *carrying the meaning across* (summary). (3) embodies **要約 / 結束 /
  dense 読解**; carries "it believed if no one spoke, no one could be wounded."
- **学士オーレン (2級):** (1) wants to be right. (2) hides behind formal register and silence
  because "silence was safer." (3) embodies **仮定法 / 論説 / argument**; defeated by *debate*
  in correct register, then admits "we let it swallow the rest" (2級 lore drip).

---

## CASTING DISCIPLINE (governance)
- **No new recurring character** without a 3-line bible + Blackout pass + a hue that's
  unshared in its scene. Walk-on witnesses (≤1 line, no arc) are allowed per chapter need.
- Lock all of the above in `assets/art/CHARACTER_SHEET.md` (identity phrase + per-character
  seed) so every AI art generation is deterministic (`CharacterDesignAAAJP.json`).
- Two-state pipeline (`_grey`/`_color`) is mandatory for all 4 core + 7 headliners; extend
  the existing `npc_*_grey/_color.webp` pattern to きみ, ライラ先生, スラ, サイレント.
- Cross-case cameos: 2–3 early witnesses reappear later, recovered, with one updated line —
  cheap and it makes the world feel continuous (`ChildrensEducational.json`).

## Cross-references
`WORLD-BIBLE.md` · `COMPOSITION-ARCHITECTURE.md` · `ART-DIRECTION.md` · `STYLE_BIBLE.md`
· existing `lib/features/quest/quest_data.dart` (5級 named NPCs to build on).

# CHARACTER-BIBLE — PROPOSED REVISION (2026-06-08)

**Status: PROPOSAL — awaiting CEO approval.** `CHARACTER-BIBLE.md` is spec-frozen
(`AUTONOMOUS-LOOP.md §D`); this is **not** auto-applied. Produced by the standing
`character-studio` loop (`.claude/workflows/character-studio.js`, run `wf_ceeac648`) —
a world-class character designer + art director + producer/director + narrative writer +
pedagogy lens, per CEO msgs 871/874. On approval, the EDITS below fold into
`CHARACTER-BIBLE.md` and the production list (bottom) becomes buildable tasks.

---

## The unifying equation (the directorial through-line)

**voice = colour = a 英検 skill.** The cast is a small chorus of grief that the child
cures *by speaking English*. Each headliner's broken voice IS one 英検 skill; clearing
their large task-list returns their **colour AND their voice** (broken sound → full
phrases). This is what makes the cast both **sellable** (a Gris/Layton-grade emotional
hook) and **pedagogically honest** (Habgood intrinsic-integration: you cannot un-grey a
character without producing the target grammar). The journey is an **inward spiral toward
サイレント** at the centre, scored by **three visible progress strands the child reads at a
glance with zero UI widgets**: きみ's healing ear-horn, ライラ先生's healing glasses,
サイレント's refilling hourglass. **Progress is encoded ON CHARACTER BODIES** — a parent
glancing at the screen literally sees how much English their child has restored.

Asset cost stays **O(#characters × 2), not O(#vocab)**: 11 deep grey/colour pairs + 5 thin
walk-ons + 15 expression sprites for the 3 ever-present core characters.

---

## The cast (4 core + 7 headliners — frozen skeleton kept, deepened)

| Character | Role | 英検 skill embodied | Visual hook (silhouette) | Progress strand |
|---|---|---|---|---|
| **きみ** (protagonist) | child sound-detective; silent hero — "speaks" only via the English the child produces | phonemic awareness (root) | cream brim-hat tilted + brass ear-horn clipped to brim, protrudes forward-left (hat-horn @64px); gender-neutral | ear-horn repairs 1 fracture per case (whole+glowing by 準1) |
| **ライラ先生** (mentor) | retired 準1 examiner; lost her voice, still WRITES; sets each case + names the skill it tests | examiner's precision (story↔合格 bridge) | square body + dark-steel circle glasses + notebook 45° wedge under arm + ink-cuff stain; bright brass amber #C8883A | glasses repair (4級/準2/準1); handwriting steadies; voice returns aloud only at 準1 |
| **スラ** (mascot) | the player's mirror, exactly one grade behind; child feels like a teacher; app-icon seed | the spaced-review loop made lovable (speaks PRIOR grade) | teal teardrop, two dot-eyes, OWNS teal #5DA9E9; **grows a speech-horn** (near-circle@5級 → forward-curving@準1); 16px blackout | growing horn + word-counter; flaw surfaces case 3/5/7 |
| **サイレント** (antagonist + 準1 headliner) | melancholy phenomenon who believes silence is peace; every 対決 is a CONVERSATION, not a fight | 準1 ceiling (nuance/register/倒置/cleft) | **NEGATIVE-FACE: no eyes, no mouth — one faint horizontal seam**; sloped (not sharp); cradled cracked hourglass; plum-grey #6A6070 (absence of hue) | hourglass +1 grain per case; 6 lower 対決 = one progressive confession; seam opens at finale |
| **灰守セル** (5級) | grey ember-keeper elder; first character met; lore-anchor | phonemic awareness (the §2.1 task-list example) | most-round (warmth first), cupped hands hold a dying ember = only warm point in grey scene; ember #E86020 hotter than coat #C89040 | ember brightens per phoneme (7 SATPIN states); coat tints on first CVC blend |
| **時計屋トック** (4級) | round clockmaker trapped in the present tense | 時制 (highest-volume gap) | sphere-dominant; stopped pocket-watch on long chain, disc perpendicular mid-right (only circle, bigger than his face); **sage-ivory #C8D8B0** | hour-hand=past, minute-hand=future; full colour when both reach 12, watch ticks |
| **書庫番ミネ** (3級) | tall archivist guarding a sealed diary | 現在完了/受動態/関係代名詞/Eメール | tall thin column; **archive indigo #3D4A7A** (和紙/old bindings); holds diary TO chest (vs ライラ先生 extends toward player) | 6 padlocks on the diary; glasses colour first |
| **港の案内人ナギ** (準2) | weathered harbour pilot; blames herself for a conversation that wounded two people | 意見表明/会話空所/長文論旨 | weathered horizontal figure; foghorn on shoulder 45°; **salt-teal #4A8A7A** (distinct value from スラ); permanent raised brow (drops at payoff) | foghorn swivel-arrow; answers only with questions until you state an opinion |
| **橋守ロウ** (準2プラス) | lone bridge-keeper at the 準2→2 wall (real dropout point); register = FRUSTRATION (fixes case-5 trough) | 要約/結束/dense 読解 | vertical: lamp on a tall pole above head; square body; **charcoal-brown body so LAMP = only amber** (#7A5020 tarnished) | 5 fog-panels clear to reveal the far bank; lamp brightens (flickers on a mistake) |
| **学士オーレン** (2級) | formal castle scholar; chose silence as safety — the **dark mirror of サイレント** | 仮定法/論説/register/argument | wide-robed authority rectangle; **keeps plum #4A3B52** (sole owner); debate gavel hip→shoulder shift; half-in/out of his own gate | 5 gavel-notches; passive→active speech; 解決 is sobering (sets case-7 register); writes a letter きみ delivers in the finale |

---

## The six surgical CHARACTER-BIBLE edits (on approval)

1. **Resolve the three dominant-hue collisions** so each hue is semiotically OWNED:
   トック→sage-ivory, ミネ→archive-indigo, ナギ→salt-teal (distinct value from スラ),
   ロウ→charcoal body + amber-only lamp. Net: スラ owns teal; plum owned solely by the
   authority/サイレント axis (オーレン); amber value-split (bright ライラ先生 / tarnished ロウ).
2. **きみ terminal silhouette** — hat+ear-horn (round blob fails the 64px blackout test).
3. **スラ silhouette-as-progress** — a growing speech-horn ridge replaces a floating word
   bubble (a UI bubble dies at 16px); the mastery arc IS the silhouette.
4. **サイレント negative-face** — no eyes/mouth, one sealed seam; the art generator cannot
   produce horror; cradled hourglass = loss, not threat.
5. **Prop-breaks-silhouette gate** (new design rule) — every identity prop protrudes at a
   characteristic angle so the blackout read is the prop, not the body.
6. **Three-strand visible progress + cohesion cut** — progress encoded on bodies; and
   **retire ~15 legacy DQ-era generic NPCs** + legacy master PNGs from `quest_data.dart`
   (reassign their ナゾ to the case headliner, copy-only), shrink the 5級 walk-on bench 9→5
   (グレン returns as a free recovered /g/ cameo in 準2).

---

## Production asset list (bounded, one-time; O(#characters×2))

- **A. Audit-only re-hue** (5 existing headliner pairs): トック→sage-ivory, ミネ→indigo,
  ロウ→charcoal+amber-lamp, オーレン→confirm plum, ナギ→pick canonical pair + salt-teal.
- **B. NEW grey/colour pairs (highest priority, 5 = 10 sprites):** きみ, ライラ先生, スラ
  (regenerate off the legacy DQ slime, watercolour register + horn system), サイレント
  (+ standalone hourglass), 灰守セル (+ ember as a ColorFiltered element). **These 4 core
  characters currently have ZERO assets — the protagonist has no face on any screen.**
- **C. Expression sprites (5 each) for the 3 ever-present core** (きみ/ライラ先生/スラ) =
  15 sprites. Headliners reuse 1–2 poses (one case each) — do NOT fund 5×.
- **D. Progress-strand elements** (~0 art cost; Flutter ColorFiltered/tween/α-overlay):
  ear-horn, glasses, hourglass grains, ember tints, watch-hands, 6 padlocks, 5 fog-panels,
  5 gavel-notches, foghorn swivel.
- **E. Walk-ons (5級 bench):** アン/タオ/ミィ/ロブ/ノナ as single-frame glyph-cards.
- **F. Voice lines:** grey-broken + restored-full sets per character via Google TTS
  (already wired); サイレント's 7 whispered lore words = 7×~1s clips. No recording budget.

NPC sprites = WebP **lossless**, ~1024px, composited at runtime by `SceneView` (never baked
per-plate) — per `ART-DIRECTION.md §1`. Independent of the thousands of 英検 vocab items.

---

## Top 5 moves (on CEO approval, in order)

1. **Resolve the 3 hue collisions** — the #1 blocker; every downstream asset depends on it.
2. **Fund the 4 core characters + セル NOW** (5 grey/colour pairs) — the protagonist/antagonist
   have no anchor today, so the title screen + finale under-land (biggest sellability risk).
3. **Lock terminal silhouettes + the prop-breaks-silhouette gate**; run the 64px (16px for
   スラ) blackout test as a hard accept-gate BEFORE any colour pass.
4. **Encode progress on character bodies** (3 through-line strands + per-headliner ticks) —
   a parent SEES their child's English progress with zero UI widgets (near-zero Flutter cost).
5. **Cut the cohesion debt** — retire the ~15 legacy DQ NPCs + master PNGs; reassign their
   ナゾ to the case headliner (copy-only); 9→5 walk-ons. Subtract before adding.

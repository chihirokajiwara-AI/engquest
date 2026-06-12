# コトバ探偵 Opening Redesign — diverse-team synthesis (2026-06-12)

Source: opening-redesign-studio Workflow (scenario writer + Level-5/Layton researcher + cinematic director + child-learning specialist → creative director). CEO 1372/1375.

I have the full picture: the current build is the boxed 6-panel tap-through the cinematic-director critiqued, with reusable `_saturationMatrix`, `_activeLetter` sweep, `BlendWordCard`, and `_sceneStage`. The town scenes reference `town5_lane.webp`, not the canonical grey square. Here is my synthesis.

---

# コトバ探偵 — UNIFIED OPENING SPEC (Creative Director's cut)

## Director's thesis (resolving the central tension)

All four specialists independently converged on one correction to the draft: **the colour must be lost with a named face attached BEFORE the child taps, and the tap must be the child's own un-prompted choice.** The scenario-writer named the whiplash, Level-5 named the "never punish before first input," the cinematic-director gave the radial-from-きみ grammar, and the child-specialist gave the errorless ZPD scaffold. They do not conflict — they stack into a single sequence. My job is to fuse them and kill the three things that fight 本格 tone: the bordered card, the bloom-then-drain whiplash, and the save-the-world map.

**One protagonist of the opening: ランプ (the lampkeeper).** Not きみ, not a map. The child rescues one man's voice. That is the whole emotional contract.

---

## 1. THE FINAL OPENING — beat by beat

Format per beat: **SEE / HEAR (when audio exists) / DO / FEEL**. All JP is child-facing ひらがな; EN is a small gloss for 中高生/adults. Full-bleed throughout — no card, no border. Total ~28-34s (variable by the wait).

### 起 — One mute man, reaching (0–5s)
- **SEE:** Full-bleed `town_pre1_grey_square.webp`, fully desaturated (grey). Slow Ken Burns push-in (1.04→1.10). `npc_lampkeeper_grey` composited as a **foreground parallax sprite**, mid-gesture, reaching up to a dark lamp that won't catch. His name inks once, small, lower-left: **ランプ**. Hold in near-total stillness ~2s.
- **HEAR (later):** ambient near-silence; a single dry "s…" breath.
- **DO:** nothing yet — the game is still.
- **FEEL:** absence. Something is wrong here, and it's wrong for *him*.
- **On-screen:** `「す…」` / *"s…"* — caption fades in under his face. (No exposition yet — face first.)

> **Resolved conflict:** I took the scenario-writer's "open on one face mid-gesture, name him" over the draft's "town + mute NPC," AND over the child-specialist's request to move the first tap into 承. Reason: a tap during 起/承 would spend the child's agency *before* there's a person to rescue — diluting the one moment that matters. I instead satisfy the child-specialist's real concern (don't make them wait 25s passively) by *shortening the passive runway to ~12s* and front-loading emotion, not interaction.

### 承 — His memory blooms (5–11s)
- **SEE:** Colour blooms into the square — but as **ランプ's memory**, radiating outward (radial `ClipPath` reveal) from him, not from きみ. The square fills with warm colour: this is Sonea as it was when he could still name things. Hold **one breath too long** (~2.5s) so it feels precious.
- **HEAR (later):** one warm musical phrase (the future Hisaishi-style cue slots here, 1:1).
- **DO:** nothing — still his moment.
- **FEEL:** longing. *This* is what was lost.
- **On-screen:** `「むかし、ここは いろで あふれてた。」` / *Once, this square overflowed with colour.*

> **Resolved conflict:** Bloom radiates from **ランプ** (his memory), NOT from きみ. The cinematic-director wanted the bloom radial-from-きみ "your voice is the source." I split it: the 承 memory-bloom is *his* (radiates from the lampkeeper), and the **restoration** bloom in the payoff radiates from きみ. This is better than either single proposal — it means the child's circle becomes the colour-source only at the moment the child earns it, making the visual grammar tell the story: his colour was memory, きみ's colour is real.

### 転 — The Silence takes it, ending on his face (11–15s)
- **SEE:** **HARD CUT** (not a dissolve). The colour drains back out — radially, collapsing inward — and **his face greys LAST**. The drain is visibly the Silence pulling at *him*, never at きみ. きみ's small circle survives, lit, at the lower edge.
- **HEAR (later):** the warm phrase cut short / swallowed.
- **DO:** nothing yet — but everything now goes still and **waits**.
- **FEEL:** loss with a face on it. Threat-to-him, not failure-of-mine.
- **On-screen, drained letter-by-letter as read:** `「サイレントが、ことばを たべてしまう。」` / *The Silence eats the words away.*
- Then the promise inks in beside きみ's surviving circle: `「でも、きみの こえは きこえる。」` / *But your voice can still be heard.*

> **Resolved conflict (the whiplash):** The draft bloomed-then-drained generic colour. I made the drain end **on ランプ's face**, greying last, and framed strictly as threat-to-him (Level-5's hard rule: never punish the player with regression before their first input). The hard cut here is the cinematic-director's editing-rhythm beat — it lands as shock, not a slideshow dissolve.

### The wait + the blend — the child chooses to break the Silence (15–24s)
- **SEE:** Everything grey and still except きみ's circle and one soft-pulsing 🔊. **Nothing auto-advances.** After ~4s of no input, the lamp dims one notch to gently re-invite (no timer, no nudge text, no scold).
- **DO (the whole game's thesis, as agency):**
  1. Child taps 🔊 → tile **c** lights + a small colour-return pulse.
  2. Tile **a** lights on the next beat (or the child's next tap) + pulse.
  3. Tile **t** lights + pulse.
  4. The tiles **join** → `cat`. ランプ is addressed: the blend is offered *to him*.
- **HEAR (later):** continuous-blend /k/→/a/→/t/ → "cat" (no choppy schwa); silent-first, each phoneme carried by a **distinct colour-pulse + a mouth-shape change on ランプ's face** so the "sound" is visible with zero audio.
- **FEEL:** *I* did this. I chose to speak into the silence.
- **On-screen (pre-tap):** `「タップして、こえに してみよう。」` / *Tap — and give it a voice.*
- **Errorless guarantee:** out-of-order or hesitant taps still light that phoneme and ease toward the join. **No ✗, no shake, no red, no もう一度.** There is only "not-yet-complete." Guaranteed win, ≤300ms crisp response to each tap (Level-5 "solved with a glance" — perceiving correctly *is* the power).

> **Resolved conflicts (three at once):**
> - **Agency vs spectatorship** (child-specialist): adopted segment-then-join — three taps reveal c·a·t, a join completes it. The current `_sweep` auto-timer is **replaced by tap-driven reveal** so the causal chain is "my taps → the word → his voice." This is the single most important behavioural change.
> - **"Game waits"** (scenario-writer/Gris): adopted fully — no auto-advance, re-invite after 4s.
> - **NPC poses the puzzle** (Level-5): the blend is *offered to ランプ*, not a free-floating UI control. His "s…" is the puzzle he hands you.

### 結 — His thank-you, then a quiet road (24–32s)
- **SEE:** On the join, colour **rushes from きみ's circle up ランプ's body to his face** (cinematic-director: lead restoration with the face; cross-dissolve grey→colour lampkeeper sprite FIRST, before the square finishes). The lamp catches. He looks at きみ. Then the ソネア map **inks in quietly behind them** — and on it, **one or two points stay grey** (Level-5: glimpsed un-restored nodes = the case still open). He points down the road.
- **HEAR (later):** his single restored word — a warm, quiet "…ありがとう."
- **DO:** read his thanks; tap はじめる when ready.
- **FEEL:** I gave a person his voice back. Warm blanket, not save-the-world.
- **On-screen, his first regained word:** `「…ありがとう。」` / *…thank you.*
- **Then, the invitation (restoration, not conquest):** `「いこう。ことばを、とりもどしに。」` / *Let's go — and bring the words back.* → **▶ はじめる / Begin**

> **Resolved conflict (the map):** scenario-writer wanted to cut the gold map; Level-5 wanted it kept but pointing at un-restored greyness. I demoted-and-kept: the map inks **quietly behind a human two-shot**, with grey nodes as a retention pull. This keeps the "warm blanket" tone (no epic overture) while preserving the "a world of waiting cases" hook. The title-card ignition (cinematic-director's per-glyph gold sweep on 「コトバ探偵」) lands HERE, synced to はじめる — type as hero, not a static logo.

> **Rejected for tone (child-specialist, upheld by me as CD):** NO bouncy mascot, NO confetti, NO "すごい！/せいかい！". The restoration *is* the reward. Copy respects the player. This protects the 本格 moat across 小学生→adult.

> **The Luke question (Level-5):** the kimo-kawaii sidekick is **deferred to v2.** Rationale: adding a companion now competes with ランプ for the child's emotional focus in a 30s window and needs bespoke sprites + expression range we don't have. The locked direction's sidekick belongs to the *gameplay loop*, not this rescue. The sidekick's narrating function ("きこえた！") is instead carried by the captions, which already do the no-scold framing. (I am overruling one specialist here, deliberately, for focus.)

---

## 2. LAYTON / LEVEL-5 TECHNIQUES ACTUALLY ADOPTED

1. **The first puzzle is diegetic and posed by a person** — ランプ hands きみ his broken "s…"; the tap *answers him*, and he *reacts* (gratitude). Not a free-floating UI control.
2. **"Solved with a glance" — frictionless, dignified, no fail-state** — guaranteed win, ≤300ms crisp colour-answer to each tap; perceiving correctly = the power (which is literally the game's premise).
3. **Never punish with regression before first input** — the 転 drain is threat-to-ランプ, never undoing きみ's progress; tone stays calm-curious, not tense.
4. **Calm/slow before clever; silence as the instrument** — since score is CEO-owned, the grey-square stillness *is* the 〈サイレント〉; the 承 bloom and 結 restore are built as the two "musical" beats so a future Hisaishi-style cue drops in 1:1 without re-timing.
5. **End on a "case opens," not a "level select"** — the map inks with one/two still-grey nodes; はじめる = accepting a case, not starting a game.
6. **Deferred (v2):** the Luke-style witnessing companion.

---

## 3. IMPLEMENTATION PLAN — `lib/features/quest/prologue_screen.dart`

This is a **re-stage of the same screen** reusing every existing mechanic (`_saturationMatrix`, `_activeLetter`/sweep logic, `BlendWordCard`, `ColorFiltered`, `prefersReducedMotion`). No new art. Ordered, code-only steps:

**A. Repoint the location asset (1 line, highest narrative ROI).**
In `_stage()` cases 1 & 2, replace `town5_lane.webp` → `assets/art/scenes_layton/town_pre1_grey_square.webp` (the canonical 灰色のひろば). *(Verify the file exists at that path before commit.)*

**B. Kill the bordered card; go full-bleed.**
Restructure `build()`: wrap the whole screen in a `Stack`. Layer 0 = `Positioned.fill(Image.asset(grey square, fit: BoxFit.cover))` under a `ColorFiltered(_saturationMatrix(s))`. Layer 1 = lampkeeper foreground sprite (`Positioned` + parallax `Transform.translate`). Layer 2 = bottom **gradient scrim** (`DecoratedBox`, transparent→`black87`, ~38% height) holding the caption text — **delete `DqDialogBox`** from the prologue. Remove the `_sceneStage` gold border/`boxShadow`/`borderRadius` framing entirely.

**C. Add the Ken Burns push-in.**
One `TweenAnimationBuilder<double>` (0→1 over ~7s per held beat) driving `Transform.scale(1.04→1.10)` + slight `Alignment` pan on the background plate; gate behind `prefersReducedMotion` (jump to end-state).

**D. Composite the lampkeeper as a parallax sprite with grey→colour cross-fade.**
Two stacked `Image.asset` (`npc_lampkeeper_grey` / `_color`) with `AnimatedOpacity`; parallax `Transform.translate` keyed to the same Ken Burns `t` (~1.5× background). In the 結 restore, cross-fade grey→colour **and end the bloom on his face** (face plane reveals first).

**E. Make the bloom/drain radial (replace the flat full-frame tween).**
Wrap the colour copy in a `ClipPath` with an expanding/contracting `CircleClipper` (radius driven by `t`). 承: centre on **ランプ** (his memory). 転: collapse the colour inward, face greys last (hard cut into this beat — set this beat's `AnimatedSwitcher` duration to ~0). Restoration: centre the reveal on **きみ's circle** (her voice is the source).

**F. Restructure the panel model + the blend interaction (the behavioural core).**
- Collapse the 6 didactic panels into the **5 kishōtenketsu beats** (起/承/転/wait+blend/結). Update `_panels` copy to the exact lines in §1.
- **Replace the auto-sweep** (`_sweepLetters` `Timer.periodic`) with **tap-driven reveal**: each 🔊 tap advances `_activeLetter` (c→a→t), each lighting a phoneme + firing a colour-pulse; a 4th "join" gesture sets `_blendDone` and triggers ランプ's restoration. Keep `BlendWordCard` but drive `activeLetter` from taps, not a timer.
- **Errorless:** out-of-order taps still light the tapped phoneme and ease toward join; never render ✗/shake/red. Guarantee `_blendDone` is always reachable.
- **The wait:** on the 転→blend beat, remove any auto-advance; after 4s with no tap, dim the lamp one notch (a second `AnimatedOpacity` on the lamp sprite) as a soft re-invite.

**G. Per-beat transition rhythm.**
Replace the uniform 450ms `AnimatedSwitcher` with per-beat durations: ~2000ms cross-dissolve for 起→承; **~0ms hard cut** into 転 and into the tap-payoff; gate all motion behind `prefersReducedMotion`.

**H. Kinetic title at 結.**
After the map inks, bring up full-bleed 「コトバ探偵」 in bundled Noto Serif JP, render desaturated then ignite each glyph to `dqGold` left-to-right (reuse the `_activeLetter` stagger pattern, 80–120ms), landing on はじめる; English "Kotoba Tantei" beneath at ~40% size/opacity. **HARD REQUIREMENT before ship:** verify 「探偵」「ソネア」 glyphs are in the Noto Serif JP subset or it tofus silently (known repo failure mode — see font-subset memory).

**I. Visual phoneme-carrier (hard requirement, not fallback).**
Each phoneme tap must carry the "sound" with **a distinct colour-pulse + a mouth-shape change on ランプ's face** so a silent first-run still reads as "I made a sound," not "I pressed a button." Wire phoneme audio keys as a no-op-safe enhancement for when CEO records.

### Bespoke art/audio that elevates v2 (CEO-owned — does NOT block v1)
- **Audio:** recorded phonemes (/k/ /a/ /t/, continuous-blend "cat") + ランプ's "ありがとう"; a Hisaishi-style opening cue dropped into the 承-bloom and 結-restore beats (built to slot 1:1).
- **Art:** a purpose-painted 灰色のひろば with **pre-separated layers** (sky / mid / lampkeeper / foreground stones) for true multi-plane parallax; a hand-animated colour-bloom **particle pass** (drifting motes seeding from きみ); a lampkeeper sprite with a small **mouth-shape set** (3-4 visemes) for the silent phoneme-carrier; a custom 「コトバ探偵」 logotype lockup.

---

## 4. SINGLE HIGHEST-IMPACT FIRST COMMIT (code-only, no new art/audio)

**Full-bleed re-stage of the grey square + relocate to the canonical 灰色のひろば** — i.e. steps **A + B + C** together:

> Repoint the prologue's scene to `town_pre1_grey_square.webp`, delete the bordered `_sceneStage` card and `DqDialogBox`, restage as a full-bleed `Stack` (`Positioned.fill` + `BoxFit.cover` under the existing `_saturationMatrix` `ColorFiltered`) with a bottom gradient scrim for captions, and add a Ken Burns push-in gated behind `prefersReducedMotion`.

**Why this first:** it is the single change that converts the opening from "asset-preview slideshow" to "cinema," it lands the one narratively-loaded location, it reuses only existing mechanics and assets (zero new art, zero audio), it cannot regress the guaranteed-win hook (the `BlendWordCard` panel is untouched in this commit), and it is the foundation every later beat (radial bloom, parallax lampkeeper, kinetic title) builds on top of. Ship it, screenshot-audit it, then layer D→I.

**Commit message:**
```
feat(prologue): full-bleed re-stage on the canonical grey square

- relocate opening to town_pre1_grey_square.webp (灰色のひろば canon)
- replace bordered _sceneStage card + DqDialogBox with full-bleed Stack
- Positioned.fill + BoxFit.cover under existing _saturationMatrix filter
- bottom gradient scrim for captions; Ken Burns push-in (reduced-motion safe)
```
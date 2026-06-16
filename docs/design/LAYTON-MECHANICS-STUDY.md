# Professor Layton — deep mechanics study (binding reference for world/scene composition)

Authored 2026-06-16 after CEO 1768/1769: the loop polished micro game-feel for many
ticks while NEVER flagging that the world itself — 7 single-room scenes, 3 ナゾ each,
21 ナゾ total — is structurally far too thin to be a Layton-grade game. The flaw-hunt
audited individual screens and missed the macro structure. This doc is the evidence-
based Layton bar that all scene/world work must be measured against.

## What Professor Layton actually IS (researched, with sources)

1. **Tap EVERYTHING — the scene is a dense interactive space.** Tapping random
   objects in/around the world reveals observations, hidden puzzles, AND hint coins;
   hint coins are hidden in *everything* — barrels, rooftops, signs, trees. There are
   dozens of interactive spots per scene, most non-obvious. (StrategyWiki, Curious
   Village Hint Coins; Neoseeker Miracle Mask, 2024-2026.)
2. **Investigation / discovery affordance.** Later games (Miracle Mask) add a
   magnifying glass you slide across the scene; it turns ORANGE over a hint coin,
   hidden puzzle, or collectible — rewarding curiosity-driven searching.
   New World of Steam (2026) adds a **Coin Radar** + **World Map** exploration.
3. **Multi-location chapters.** A chapter spans MANY connected locations (square,
   shop, alley, …) navigated via a map; you ask locals for information on the case.
   (Gematsu/NoisyPixel, New World of Steam 2026 gameplay; Wikipedia.)
4. **Puzzles gate the story.** NPCs request a brain-teaser/puzzle BEFORE the
   narrative proceeds — exactly our NPC→ナゾ→restore loop, but Layton has 100+ puzzles
   (New World of Steam: "biggest collection in the series").
5. **Fully animated CUTSCENES at key beats.** A defining feature — anime cutscenes
   (P.A. Works) at narrative beats; New World of Steam uses fully 3D cutscenes.
   (Siliconera 2012; Gematsu 2026.) CEO 1768: **we will make videos too, and must
   compose WITH video slots in mind from the start.**

## Our gap (measured, honest)

| Dimension | Layton | コトバ探偵 today |
|---|---|---|
| Scenes per chapter | many locations + map | **1 painted scene per grade** |
| Interactive spots per scene | dozens (most hidden) | **3 NPCs + 1 coin** |
| Hidden coins | scattered everywhere | 1, glowing/obvious |
| Discovery affordance | magnifier / Coin Radar | none (hotspots are pre-marked) |
| Cutscenes | animated at every beat | static banners; **no video slot** |
| Total puzzles | 100+ | **21 ナゾ** |

We have the LOOP (NPC→ナゾ→restore) and good micro game-feel, but the WORLD is a thin
skin. This is the structural deficiency the loop must stop ignoring.

## The plan (sequenced; art-free first, art-gated flagged)

1. **Exploration DENSITY now (art-free, code+content).** Per scene, add many more
   interactive hotspots beyond the 3 ナゾ: hidden coins (in scenery, not pre-marked),
   **observation points** (tap an object → a 探偵メモ line / clue / lore — no puzzle),
   and optional mini-discoveries. Make "tap everything → something happens" true.
2. **Discovery affordance (art-free).** A search/「しらべる」 mode (or a Coin-Radar-style
   hint) that nudges curiosity without pre-marking every spot — Layton's magnifier.
3. **Cutscene / 動画 SLOTS (architecture now, video later).** Add optional video-slot
   fields to chapter beats (chapter intro, mid-chapter reveal, chapter clear): play a
   video when present, fall back to the current static beat when absent. Compose the
   chapter flow so video drops in — per CEO 1768.
4. **Multi-location chapters (structure now, plates art-gated).** Generalise SceneDef →
   a chapter of N locations + a chapter map; build the navigation + content model now
   so that when painted plates land (art-gen #54, CEO GO) the chapter fills out.
5. **Volume.** Drive total ナゾ + observations toward Layton density over time.

## Loop governance fix (so this is never missed again)

The flaw-hunt and studio must run a **WHOLE-GAME MACRO STRUCTURE audit** on a regular
cadence — assessing total world scale, content volume, exploration density, and loop
depth against the ambition — NOT only individual screens. A game that is 7 single-room
scenes must be FLAGGED as structurally inadequate even when every screen is polished.
(See AUTONOMOUS-LOOP-CHARTER.md "## MACRO STRUCTURE AUDIT".)

## Sources (2024–2026)
- StrategyWiki — Curious Village / Diabolical Box / Unwound Future Hint Coins.
- Neoseeker Wiki — Miracle Mask (investigation / magnifier).
- Siliconera (2012-01-29) — Bones/P.A. Works anime cutscenes.
- Gematsu (2026-04), NoisyPixel, game8 — New World of Steam: Coin Radar, World Map,
  town growth, biggest puzzle set, 3D cutscenes.
- Wikipedia — Professor Layton; New World of Steam.

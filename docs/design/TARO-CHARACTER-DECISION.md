# タロ (Taro) — companion character DECISION

Decided 2026-06-18 by the diverse latest-researching studio (`taro-design-decide` workflow:
5 expert lenses + 3 adversarial critics + Opus director), per CEO 2013 ("stop asking me —
use the top-tier agent team to decide"). This supersedes the bronze-automaton direction
(CEO 2006/2011 rejected metal as un-lovable + over-literal on the name). Answers every CEO
correction in the #114/#116 thread. NOT final until the CEO's Grok art lands, but the CORE +
form + mechanic are the decided spec.

## Core (role · personality · what it evokes)
タロ = the child's 相棒 AND a **survivor of the サイレント** — a small living **ember of the
world's lost VOICE** that took a soft body so the Silence couldn't devour it. He can faintly
sense where words/voice/colour were buried, but is **too weak to restore them alone**: the
child's **correct 英検 answers feed him light** and bring his colour and voice back. He lost
his own voice, so he never lectures — he cheers in **warm chimes/hums** and looks up to the
child for courage.
- **Vulnerability is STRUCTURAL, not cosmetic**: he genuinely NEEDS the child (co-regulation /
  Tamagotchi caregiving loop = the durable attachment mechanism, not a 2026 mascot trend).
  Every 英検 question becomes an act of CARE — the child heals their friend by learning.
- Talos/ミノス survive **only as spirit**: a small made guardian carrying one vein of living
  LIGHT (ichor → warm glow), **zero literal metal**. ミノス = the little light-coins of
  restored words he gathers.

## Form (decided — no metal, huggable; 3 ownable silhouette traits)
A soft round downy companion the size of a child's cupped hands; **soft brushed dusty-teal
velvet fur**, cream cheeks + underbelly. A 6yo must be able to draw it from memory; survives
16px / single-flat-colour / plush:
1. plump round teal body tapering at the top into a **soft rounded "word-light tuft"** (downy
   bud — NEVER a sharp flame / Calcifer).
2. **HERO FEATURE** — a slightly-too-big round dusty-teal **detective cap** with a small brass
   buckle, slipping charmingly over one eye (instantly "the detective's partner"; ties to
   M5/M6's world; the one thing a kid points at + draws).
3. two big glossy inkwell-dark **eyes + a worried-then-hopeful brow** (the けなげ empathy read;
   Rilakkuma-class restraint = 6+ not babyish).
Stubby rounded nub-arms held up to be carried. NO tail / antennae / clutter. Premium grounded
refined-anime craft identical to M5/M6 (sharp clean linework, soft cel shading, warm rim-light).

## COLOUR = POWER (also a real game-feature spec)
A visible **surface bloom**, not a hidden glowing organ. Default = muted dusty-teal with a
small dim **GREY "silent patch" on his chest** (his missing voice). A **correct 英検 answer
blooms that patch grey→warm honey-amber**, the colour spreading outward across his fur and up
into the tuft, casting a warm brass rim-light. This is simultaneously the attachment hook, the
in-game **progress/restore signal**, and a reuse of the existing **grey/colour pair convention**
(`npc_*_grey` ⇄ `npc_*_color`). (Future wiring candidate: tie the patch fill to 合格率/firstTry
progress so the companion's state == learning progress — the game⇄learning interlock.)

## Name
タロ stays (short, warm, ひらがな-readable for 6yo; faint Talos/言の葉 spirit; pairs with ミノス).
CEO owns names — flagged only that no better candidate emerged.

## Final Grok prompt
See CEO msg 2015 / the workflow output. Positive-only, subject+face front-loaded, the 3 traits,
the chest grey→honey bloom, plain cream-teal bg, premium/4k. Plus a 6-expression sheet
(silent/grey · anxious · wondering · hopeful · beaming honey-amber bloom · awed) — states 1 (grey)
and 5 (full colour) are the load-bearing grey↔colour pair.

## Execution on the CEO's Grok image (per [[distinct-identity-not-ip-copy]] memory)
Import → `assets/art/masters/slime.webp` (name-map `'スラ'→` quest_screen.dart:330/497) +
`assets/art/scenes_layton/npc_slime_{color,grey}.webp` (the scene grey⇄colour pair). Derive the
grey from the silent-patch state. Then the #116 スラ→タロ rename (form-coupled: the slime
onomatopoeia 「ぷる」 → タロ's warm chime/hum tic e.g.「…りん。」; 「スライム」 descriptors → soft
ember-creature; ~90 pure-name tokens → タロ; atomic with chapter.dart speaker-tag + 8 test files).

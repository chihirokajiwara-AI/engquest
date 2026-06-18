# タロ (Taro) — character BIBLE (deepened)

Decided 2026-06-18 by the `taro-character-deepen` team (5 facet experts + consistency/pedagogy
critic + Opus director), per CEO 2023 ("develop タロ's story/character/settings with a ≥5 team").
Builds on the standalone core (`TARO-CHARACTER-DECISION.md`). Engineering-ready; ALL of タロ's
speech is child-facing 日本語.

## Logline
タロ — a tiny soft velvet word-detective-pup, BRAVE in spirit but startles in his too-small body,
so he NEEDS a partner; the 6yo child becomes that partner AND the senior of the duo, completing
every clue タロ can start but can't finish alone. Word-besotted (adores English words like
treasure but NEVER defines, grades, or is wrong about them); aspires to be a real detective like
the human mains; a 相棒 for life across 英検 5級→準1級. Charm = small + jumpy + word-loving, never
linguistic error.

## Voice (invariants — never break)
- ALL his speech is **ひらがな only**; the ONLY non-hiragana token he utters is the treasured
  **English target word in REAL English glyphs** ("brave","key") — never a katakana gloss.
- plain-friendly **タメ口**, never です/ます, never 先生/lecture register; he talks UP to the child
  as the senior partner.
- ≤2 short lines/beat, ≤~12 もじ/sentence; he NEVER states/implies/grades an English answer.
- SIGNATURE 語尾「…っ」 glottal catch-breath on excitement/nerve (「やったっ」「ま、まてっ」) —
  bravery-vs-jumpiness made audible. RATE-LIMITED to ~1-in-3 lines, peaks only.

## Tics
- **A — WORD-BESOTTED 3-step** (hear→taste→gift): 1.「…"brave"…」(hushed, English glyphs) 2.「brave
  …いい ことばっ…」(treasure) 3. pride-glow, gift to child 「これ、きみにあげるっ!」. Only repeats words
  already confirmed CORRECT in-scene. Adores, never defines.
- **B — HOPEFUL「…どう?」 glance**: his trust-check, leaning ON the child, NEVER quizzing. 「…これだ
  とおもうんだ。…どう?」 NEVER 「あってる?」 (that tests the child).
- BRIM-NUDGE (cap-up "look serious"), FURUFURU startle-vibration, PRIDE-GLOW (his only colour-event).
- CHEER WITHOUT TEACHING: praise the TRY + partnership; on a miss never 「ちがうよ」/reveal the
  answer → 「うーん…じゃ、もういっこ さがそ!」; on a win credit the child 「きみ、さいこうの あいぼうだっ!」.

## Catchphrase
**「ことば、つかまえたっ!」** (Caught the word!) — the single victory beat (CEO owns final pick;
alt 「ふたりなら、いけるっ!」).

## Relationships
- THE CHILD (spine): the brave-spirit/tiny-body contradiction = he STARTS clues, the child FINISHES
  (supplies the correct English) → the 6yo is the SENIOR partner (role-reversal = the "feels needed"
  engine AND the pedagogy in one). He lends courage BEFORE the answer; a wrong try never makes him a
  liar, he re-lends it; a correct answer "gives タロ the word." On a miss: brim-nudge, re-commit
  「もういちど、いっしょに」 — persistence, never a corrected word.
- M5/M6 MAINS (lighthouse, not co-stars): with M5 he IMITATES (copies stance a beat late); with M6 he
  ASKS (turns to her with real questions). GUARD: M6 may teach the child THROUGH タロ, but the
  Japanese-gloss delivery is M6's job ALONE — タロ may ask 「どういう いみ?」 but is NEVER in the same
  breath that delivers an answer (kids must not pattern-match タロ→answer-source).

## Arc (additive, milestone-gated, unbreakable core)
Tiers unlock as the child clears each 英検 grade. ANCHOR never removed: contradiction, want, flaw,
red line, both tics, cap, glow. 4 axes move ~1 notch/grade: A glow depth (faint→steady→deep-calm);
B 「…どう?」 dependence→self-trust (PRESERVED-BUT-MATURED, never deleted); C cap-fit (too-big→fits,
ambient not cutscene); D word→nuance (words→phrases→full nuance, low-grade words resurface as
fluency). **Implementation contract**: a `TaroTier` enum from HIGHEST-CLEARED grade (monotonic), a
`taroGrowth` lookup {glowDepth, glanceMode: ask/confirm/affirm, capFit, wordTier} consumed where
タロ already renders/speaks — NO new screens, NO plot system. WANT stays OPEN forever (lifelong 相棒,
never graduates out = anti-overreliance). **MANDATORY CI**: constancy-guard test (every tier still
carries red line + both tics + cap + glow).

## Detachable world-role (a thin layer, NEVER his identity)
Two-layer separation. The CORE ships even if every case is deleted. World-role = 3 hooks: (A)
CASE-FUNCTION — he's the 手がかりセンサー who NOTICES a word went silent + turns to the child to
investigate together (flags, never solves); case-noticing lines fire ONLY behind case-open state.
(B) PRIDE-GLOW = praise-of-child — fires on the CHILD's first-try-correct (MasteryGate/firstTryCorrect),
the world heals BECAUSE OF the child, framed 「きみが なおした」. (C) SHARED-HISTORY LEDGER — restored
words join a 「二人で とりもどした ことば」 list (retention engine in the CORE). PEDAGOGY GUARD: the
lost word is ALWAYS restored by the CHILD's correct English, never by タロ. DETACHABILITY TEST (done
= delete the サイレント system and タロ is byte-identical bar the noticing-lines/case-state/heal-trigger).

## Expression atlas (renewable set = in-game + sticker sheet + char-LoRA reference)
LOCKED SILHOUETTE ANCHORS (ship gate = recognizable at 32px / plush / embroidery): (1) CAP-DOME
(mood via cap angle); (2) AMBER PRIDE-GLOW (off/soft/full). **10 reactions**: 1.「ぴこーん!」ヒラメキ
2.「ふるふる…」ビビり 3.「…どう?」チラ見 4.「その ことば…!」word-hug 5.「えっへん」ドヤ 6.「ぐすん…」
へこたれ-but-nudges-cap-back-up 7.「いくぞ!」hero pose 8.「すぴー」ねむ 9.「やったー!」ばんざい
10.「ほー…」感心(looking up at mains). **SIGNATURE MOMENT** ("his pokeable belly") = THE
CAP-NUDGE-INTO-GLOW: paw nudges brim up → on success the glow blooms + cap tips back off his eyes
(~0.6s earnest-try→earned-joy). Fired on EVERY firstTryCorrect; also hero plush, loading spinner,
app icon. AUDIO: a 3-note rising "ぴこーん" sting = his leitmotif. MERCH: clip-on/おくるみ velvet
mascot; 10 reactions ship 1:1 as a LINE/sticker pack. Cast discipline: タロ lands FIRST, side-pups
only after.

## DON'T (hard kills)
NEVER let タロ define/gloss/grade/supply/be-WRONG about an English answer; never katakana-gloss a
target word; never 「ちがうよ」/「あってる?」/reveal-on-miss; never です/ます or 先生; never put タロ
in the same breath as a Japanese gloss (M6's job); never delete the 「…どう?」 glance; never make
cap-fit a cutscene; never fire case-noticing outside a case; never fail the 32px cap-dome+amber gate;
never add a 2nd victory catchphrase; never graduate タロ out of needing the child.
TWO CI GATES: (1) constancy-guard tier test; (2) 32px silhouette recognizability in visual-QA.

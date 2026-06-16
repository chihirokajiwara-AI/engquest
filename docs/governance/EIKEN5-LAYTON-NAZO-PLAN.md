# 5級 ナゾ = real 英検 questions, Layton-staged — execution plan

Decided via the diverse latest-first team (wf wsxnjzd27: Layton/QuizKnock + 英検5級
pedagogy + intrinsic-integration + kids-product → showrunner → **adversarial critic**)
per CEO 1891/1893/1896 (decide+execute via team, don't ask). Governing principle:
**intrinsic integration — the 英検 question IS the Layton ナゾ** (see
memory `layton-is-the-lodestar`). Efficacy guardrail: never soften a question for
fun; real 合格 = answering REAL 英検 items correctly.

## Critic's authoritative revised build order
1. **ROOT FIX** — replace the ONE phonics scene ナゾ (灰守セル, `_kStep(0)` TeachSound
   /s/) with a real 英検5級 大問1 question. (NPC 2 スラ=`_kStep(12)` greeting + NPC 3
   門番=`_kStep(15)` be動詞 are ALREADY real 英検 — only セル was phonics.)
2. **CORRECT THE LISTENING MODEL** before any listening ナゾ: **英検5級 has NO
   イラスト内容一致 section** — the showrunner invented it; the critic caught it as a
   FATAL content error. Map listening hotspots to the REAL 5級 structure (第1部 会話
   応答選択 ≈10問 wh-questions = largest block; verify counts vs official before build).
3. Author the 4-BEAT diegetic framing for the swapped セル (in-character NPC line tied
   to her want; obstacle logic = the verbatim 英検 stem; diegetic payoff on correct).
4. **NazoScreen presentation upgrade** (NEW widget code, not a data swap — critic
   corrected this): fill the ~60%-empty screen — promote `_framingBox`, render options
   as diegetic runes/lanterns (大問1/2) / word-tiles (大問3), in-character prompt, beat-4
   payoff visibly caused by the chosen word. Attention guardrail: no lore/XP/streak UI
   animates while options are live.
5. Map remaining 5級 task-types onto hotspots from VERIFIED banks: 大問2 (5問) 2-portrait
   NPC-pair; 大問3 語句整序 (5問) "restore the broken inscription" tile-drag.
6. Chapter mystery-meter strip (advances only on `firstTryCorrect`; surfaces the
   existing MasteryGate so town progress == 5級 合格率).
7. **Game-layer de-chocolate** (audit below).
8. Land `INTRINSIC-INTEGRATION-RUBRIC.md` (Attention/Gating/Embodiment/Meaning) as a PR
   gate + a CONTENT-FACT gate (any 英検-section claim verified vs official before build).
9. Verify: analyze 0 + flutter test (incl. listening_pool_integrity / nazo_hint_rail) +
   real-render QA (build→serve:8099→screenshot the 5級 town ナゾ; screen full, no phonics).

## Game-layer audit (intrinsic = KEEP, chocolate = CUT/DEMOTE)
- **KEEP (intrinsic):** restore-colour-on-solve, solve-gated lore fragments, picarat
  (max on first-try), hint-coins (teaching ladder, no picarat penalty), mastery_* badges
  (words mastered), the mystery/case/character narrative (replaces streak as the
  retention engine), 解説-on-a-miss (DEEPEN as primary feedback).
- **CUT/DEMOTE (chocolate):** phonics 5級 ナゾ (wrong content); loss-framed **streak** →
  forward-only 捜査進捗; XP/level → re-anchor "level" to 合格率 thresholds; streak_* /
  practice-count_* badges (activity-gated, not learning-gated); per-tap confetti/coin
  spam (steals attention from the English); avatars = quarantine (low-harm, not embodied).
  NB the picarat→"Top Secret" gallery unlock the showrunner proposed is itself
  chocolate-risk (critic) — only wire if it points back at the English.

## EXECUTION FINDINGS (from the first build attempt, 2026-06-16 — must heed)
- **Do NOT raw-reuse a Phase-C question on a different NPC's hotspot.** Verified index
  map: `_kStep(12)`=greeting(slime/スラ), `15`=be動詞(門番), `16`=he/she(おとこのこ),
  `17`=what-on-hill, **`18`=a/an "this is ___ apple" — npcName='パンやさん' (baker)**.
  Putting `_kStep(18)` on セル broke NPC identity (header `$npc の ナゾ` shows the baker;
  framing is セル) → `header shows case identity` test fails. FIX: **author a
  セル-OWN `QuestEncounter`** (e.g. `kCelArticleNazo`, npcName='灰守セル', hearth-themed
  npcLine + onCorrect, the a/an grammar) and pass it directly as `step:` (QuestEncounter
  extends QuestStep). Content-QA the new line/onCorrect (CLAUDE.md gate).
- **Phonics-audio tests are coupled to the removed ナゾ.** `nazo_screen_smoke_test.dart`
  audio tests (`muted-voice banner`, `missing clip → 準備中`, `present clip`) and the
  first-try/teach-first tests assume the FIRST 5級 NPC is the phonics audio ナゾ. After
  the swap they must be: (a) audio tests → `skip:` with a clear reason (5級 scene is now
  all text-MCQ; rewrite when listening ナゾ land), (b) first-try `solveSequence` → dismiss
  the teach-first card before tapping options, (c) studio-#3 "wrong tap meaning" → pick a
  ナゾ whose teachCard items match its options (スラ greeting), not セル's a/an.
- A swapped 英検 grammar ナゾ needs a `teachCard` (like スラ=kGreetingTeach, 門番=kBeVerbTeach);
  drafted `kArticleTeach` (a/an, items 'a cat'/'an apple'/'an egg') — reuse it.
- Pure-kana hint ladder must not leak the answer ('an') or distractors ('a'/'the'/'one')
  — `nazo_hint_rail_test` enforces it.

## Audience guardrail (CEO 1889, memory target-audience-age-6plus)
5級 candidate is 6+ (年長/小1+) and already decodes → phonics fully OUT of the 5級 core.

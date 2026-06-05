# A-KEN Quest — Opening & Narrative Bible (v1)

Source: 9-agent design panel (4 designers × 4 adversarial critics → director synthesis),
2026-06-05, run wf_3677a039-afa. Briefed with full project context + a live-research
mandate (dated 2025–2026 sources at the end). Replaces the rejected "あなたは、じつは
王子／王女 … 魔王を倒して世界を取りもどそう" framing.

**Status: PROPOSED — awaiting CEO direction nod before build.** Shipping bar is gated on
(a) the 6 CEO-owned phoneme clips, (b) a visual-animation feasibility decision, (c) a
repo-wide post-edit leakage grep. Question `choices`/`correctIndex` are NEVER touched —
every recast is a pure flavour swap on npcLine/npcLineJa/onCorrect/intro/cleared text,
so 英検 integrity and the content-qa gate are preserved.

## Premise
〈ソネア / Sonea〉— the kingdom where language was born; a spoken word became colour. A
spreading quiet, **サイレント / the Silence**, now drains colour and voice wherever a word
is forgotten; people can make only ONE sound ("s…" "a…" "t…"). The Silence is **not a
demon on a throne to be slain** — it is what fills the world where words go missing, and
it believes, gently and mistakenly, that silence is peace. **きみ** travels not to retake
the world by force but to **give it its words back**, one person at a time. The win is
**restoration, never conquest.** Locked spine preserved exactly: audio-first, no-scold,
teach-before-test (phonics SATPIN → CVC blend → 5級 phrases → 20-step grammar → 大問1/2/3).

## Protagonist — きみ
An ordinary traveller, addressed only as **きみ**: no royal blood, no crown, no chosen
birth, no fixed gender. What makes きみ able to help is **the exact skill the child is
learning**: in a world swallowed by the Silence, きみ can still HEAR the small sounds
inside words (/s/ /a/ /t/…) and still VOICE them. The phonics ability IS the superpower —
sound out c-a-t → say "cat" → the word, the colour, and the person's voice return. Every
phonics rep is diegetically meaningful; getting better at the game = getting better at
英検. **Guard against chosen-one-by-accident:** きみ is not a magic exception — きみ is the
one still PRACTISING; NPCs frame the resemblance as shared *skill/vocation*, never
inherited identity. Earned title **「ことばの勇者 / Word-Hero」** grows from the COUNT of
voices returned. No "word-keeper lineage" MacGuffin (rejected as a back-door chosen-one).

## Antagonist — サイレント / the Silence
A phenomenon, not a 魔王: faceless grey drift, no army, no throne, no face. Pushed back
gently and locally every time a word returns. Belief shown not lectured ("Silence is
peace… why bring words back?") — the world answers by becoming warmer. **Never slain;** it
recedes as the world remembers how to speak, and at the end **it too is a victim who lost
its voice — きみ returns the LAST word to サイレント itself**, and colour floods back.
Emotional-safety: "quiet and sad," NOT creepy/threatening — no horror beat for 6-year-olds.
Finale recast STRUCTURALLY: 王都/throne/玉座/👑/crown-cracks/"saved the world" → **灰色の
最後の広場** (the grey last square where the first word was once spoken).

## Prologue — 6 interactive panels (tap-through, skippable, plays once-ever, 1-tap recap)
1. **(くらやみ。ちいさな おとだけ)** s … a … t …
   — black; cream letters fade in, faint gold stroke-trace; /s//a//t/ clips far & small; no BGM; auto-voiced. スキップ▶▶ present from here.
2. **むかし、この くに〈ソネア〉では、こえに だした ことばが、そのまま「いろ」になった。**
   — black lifts to grey village; one flower/rooftop/sky tints to LOW-sat colour; the "word-returns" chime is introduced here as STORY before it's ever a reward.
3. **でも、あるひから ── 「しずけさ」が、ひろがりはじめた。ことばが きえると、いろも、こえも、しずかになる。**
   — the colour is drawn back out to grey (flat-lining waveform, not a monster); faceless grey drift; one gold spark survives.
4. **……けれど、きみは ちがった。きみには、まだ おとが きこえる。そして、まだ こえに だせる。**
   — the spark becomes きみ (gender-neutral silhouette = the avatar the child picked); small colour-circle persists around きみ; FACE+hope arrives EARLY (panel 4/6, age-fit fix).
5. **🔊を おして、おとを きいて、まねしてみよう。おとを つなげば、ことばが よみがえる。**
   — INTERACTIVE: the real gold 🔊 button; on tap, c·a·t tiles light in sequence → "cat", a distant rooftop blinks gold; **guaranteed win, no wrong answer** → the no-scold contract is FELT. Previews the exact core loop.
6. **これは、たたかいの たびじゃない。きえた ことばを、ひとつずつ かえしていく たび。きみの こえで、せかいに ことばを かえそう。 ▶ はじめる**
   — camera lifts to the ソネア map drawing itself in gold; 7 towns, 〈英検5級〉pulses; main theme blooms; 「はじめる ▶」.

## Town arrival pattern (one `ArrivalScene` widget, reused 7×)
3-beat card so a quiz never starts cold: **BEAT 1 APPROACH** (faded town art + JP/EN name
& its "lost thing", 🔊 auto-reads) → **BEAT 2 A VOICE REACHES YOU** (first NPC pops in,
greyed, makes their one lonely sound / broken at-level phrase; frames the need without a
quest-giver lecture) → **BEAT 3 YOUR MOVE** (soft consistent CTA "きみの みみと こえで、
ことばを かえそう。🔊をおして、まねしてみよう。まちがえても だいじょうぶ。" → first 🔊 question fades in
DIRECTLY from the NPC; NPC-talks → NPC-asks, never menu → quiz). **Pacing guards
(mandatory):** skippable from beat 1; on SRS re-visit collapse to a 1-tap recap (<15s to
play); beats auto-advance after each voice line, tap-to-advance-early. **Differentiation:**
new `QuestTown` fields `arrivalHookJa/En/Sound` escalate HOPE as grades rise (lonely child
@5級 → guarded gate @3級 → colour visibly RETURNING @準1級). **Send-off:** clearing plays
the mirror beat — 声の石 lights, colour floods, the recovered NPC speaks their first FULL
phrase. Never touches question count, scoring, or FSRS.

## Prince-thread recast (22 references — flavour text ONLY; choices/correctIndex unchanged)
See the run output for the full old→new table. Highlights: header comment; the prologue
copy (replaced wholesale); おばあさん "castle/prince born/your eyes like his" → "old hall
where the first word was spoken / you listen the way careful listeners used to"; guard
"waited for a true prince" → "waited for someone who could still speak"; サイレント "little
prince" → "little one who can still hear me"; child "you stand like a prince" → "will you
give the world its voice back"; 2級 cleared royal-blood reveal → "proof you returned every
voice"; 準1級 finale 王都/👑/throne/"my heir"/"saved the world" → 灰色のひろば + faceless
🌫️ Silence given its OWN voice back; 王妃の侍女/heir/"know your blood" → ひろばの古いこえ/
"one true voice" (concession-'how' target & correctIndex preserved). A repo-wide grep for
`王子|王女|おうじ|prince|heir|世継ぎ|王家|玉座|crown|👑|救った` AFTER editing is MANDATORY.

## Disclosed risks / shipping gates
- **(a) Audio debt** — the prologue leans on the 6 isolated phoneme clips + a "word-returns"
  leitmotif that are NOT yet recorded (CEO-owned). Mitigation: same-length whispered-TTS
  placeholders + graceful text-first fallback; do NOT call the opening "world-class" until
  real phoneme audio + the leitmotif ship.
- **(b) Visual scope** — desaturation sweeps, drifting letters, waveform-flatline, sync-lit
  tiles imply animation beyond the static command-window. Needs a feasibility pass or a
  stated downscope, else "DQ-grade" degrades to text.
- **(c) Leakage grep** — onboarding/avatar/paywall/title not yet audited for residual
  royalty strings; mandatory repo-wide grep after editing (line numbers shift on edit).
- **(d)** content-qa subagent gate on every new JP/EN line before commit.

## Sources (2025–2026, dated)
Clair Obscur: Expedition 33 prologue (Game Rant, 2025-05-01); "Good intro vs great intro"
(Game Developer); cold-open craft (Angry GM, 2024); Chosen-One trope fatigue (StudioBinder,
2025); Children's-lit trends 2026 (Bright Agency); cozy/restoration frontier (Calcalist/
Ctech, 2025); Inclusive Game Design Playbook (Geena Davis Institute, 2025); input-based EFL
review (Springer, 2025); GenQuest language-learning RPG (arXiv 2510.04498, 2025); teacher-
recommended ed-games 2025 (playreo). Full claims in the run output.

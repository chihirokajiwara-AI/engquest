// game-studio-panel — the STANDING engine of the autonomous loop (CEO 1561/1689/1741).
//
// The loop must be RUN BY a top-tier, latest-2026-updated expert game-app studio:
// parallel discipline experts (each researching current SOTA first) + harsh
// playtesters adversarially audit the LIVE game, and a director synthesises a
// ranked, in-scope, buildable plan. The main loop then builds the #1, gates, ships.
//
// Invoke: Workflow({ name: "game-studio-panel" })
//   optional args: { focus?: string, alreadyBuilt?: string[] }  — focus narrows the
//   panel's lens; alreadyBuilt appends to the do-not-re-propose list so the studio
//   keeps finding NEW gaps each run instead of re-surfacing shipped work.
//
// Recovery note: if the run dies mid-flight, the experts' conclusions are in their
// agent-*.jsonl journals — extract + synthesise manually, do NOT re-run the fan-out.

export const meta = {
  name: 'game-studio-panel',
  description: 'Standing game studio: latest-2026 discipline experts + harsh playtesters → ranked buildable game-feel plan for コトバ探偵 (英検 detective RPG)',
  whenToUse: 'Each loop tick that targets game-as-a-game quality — convene the expert studio rather than solo-polishing.',
  phases: [
    { title: 'Studio', detail: '5 discipline experts audit the live game vs 2026 SOTA' },
    { title: 'Critique', detail: '3 harsh playtesters find what is not fun' },
    { title: 'Synthesize', detail: 'director ranks buildable items + specs the top pick' },
  ],
}

const focus = (args && args.focus) ? `\nFOCUS THIS RUN: ${args.focus}\n` : ''
const extraBuilt = (args && Array.isArray(args.alreadyBuilt)) ? args.alreadyBuilt : []

const BRIEF = `
APP: "コトバ探偵" (Kotoba Tantei / Word Detective) — a Flutter web/mobile RPG that teaches
英検 (Eiken English proficiency, 5級→準1級) to Japanese children ages 4–18. Premium dark-RPG
(Dragon-Quest-grade) aesthetic: deep navy + gold, painterly desaturated scenes.

CORE LOOP: the world lost its words to "the サイレント (Silence)"; colour drained out. The child
is a rookie word-detective. Each 英検 grade = a town/chapter. In a painted SCENE you tap NPCs
(grey, desaturated) → a ナゾ (mystery) opens = an 英検 question framed diegetically. Solving it
restores that NPC's COLOUR (grey→colour) + drips a lore fragment. Clear a chapter → the whole
scene floods to colour + a torn-storybook bookmark word; 7 chapters assemble "Once, I told a
story, and the whole grey world turned to colour. — アイラ". Other surfaces: BATTLE (FSRS
spaced-repetition flashcards), full MOCK exam, a daily-return HOME hub (streak, きょうの ナゾ due
count, live 合格率, daily-goal ring).

ALREADY BUILT — these are IN AUDIT SCOPE. RE-AUDIT them SUPER-STRICTLY at the world-class bar:
built is NOT the same as good. Experience each on a REAL render and name where it actually falls
short (too brief? janky timing? not felt? incoherent? a child wouldn't notice?). You MAY propose
DEEPENING or FIXING one of these if it isn't world-class — that is exactly the job. The ONLY thing
off-limits is proposing to build from scratch something that already exists. The built set:
progressive grey→colour saturation per solve; idle-pulse halo on unsolved NPCs; twinkling hidden
coin; answer juice (wrong-answer shake + correct-answer elastic pop); diegetic CASE-CLOSED stamp;
fade+zoom transition into a ナゾ; correct-answer full-screen gold burst in NazoScreen; momentum
banner on a correct streak; restored NPCs respond when re-tapped (re-readable lore); achievements
gallery w/ capstone celebration; case-log assembling the bookmark sentence; "to be continued" hook;
recent game-studio ships: NazoScreen correct-answer gold burst, scene bubble/banner entry motion,
restored-NPC responsiveness, Battle 2-choice child recall (auto-easy on streak), Battle per-POS
サイレント word-rescue frame, scene session-ピカラット accumulator, cinematic scene-entry settle.${extraBuilt.length ? '\nAlso recently built: ' + extraBuilt.join('; ') + '.' : ''}

HARD SCOPE — propose ONLY things buildable NOW in pure Flutter/Dart, OFFLINE, with NO new art
generation, NO new audio/voice generation, NO backend/server, NO Claude/AI runtime, NO billing,
NO legal/store. Game-feel must come from CODE: animation, motion, layout, timing, juice,
micro-interaction, world-logic, progression, reward scheduling, diegetic framing, sound-FREE
feedback. Existing bundled assets only.${focus}
`

const EXPERT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['discipline', 'sota', 'topGap', 'fix'],
  properties: {
    discipline: { type: 'string' },
    sota: { type: 'array', minItems: 2, maxItems: 4, items: {
      type: 'object', additionalProperties: false, required: ['claim', 'source', 'date'],
      properties: { claim: { type: 'string' }, source: { type: 'string' }, date: { type: 'string' } } } },
    topGap: { type: 'object', additionalProperties: false,
      required: ['title', 'whyNotGamelike', 'evidenceInApp'],
      properties: { title: { type: 'string' }, whyNotGamelike: { type: 'string' }, evidenceInApp: { type: 'string' } } },
    fix: { type: 'object', additionalProperties: false,
      required: ['what', 'areaOrFiles', 'inScope', 'effort'],
      properties: { what: { type: 'string' }, areaOrFiles: { type: 'string' },
        inScope: { type: 'boolean' }, effort: { type: 'string', enum: ['S', 'M', 'L'] } } },
  },
}
const CRITIC_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['persona', 'biggestComplaint', 'specificMoment', 'oneFix'],
  properties: { persona: { type: 'string' }, biggestComplaint: { type: 'string' },
    specificMoment: { type: 'string' }, oneFix: { type: 'string' } },
}
const SYNTH_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['ranked', 'topPick'],
  properties: {
    ranked: { type: 'array', minItems: 3, maxItems: 6, items: {
      type: 'object', additionalProperties: false,
      required: ['rank', 'title', 'leverage', 'effort', 'inScope'],
      properties: { rank: { type: 'number' }, title: { type: 'string' }, leverage: { type: 'string' },
        effort: { type: 'string', enum: ['S', 'M', 'L'] }, inScope: { type: 'boolean' } } } },
    topPick: { type: 'object', additionalProperties: false,
      required: ['title', 'why', 'implementationSpec', 'acceptance', 'filesLikely'],
      properties: { title: { type: 'string' }, why: { type: 'string' }, implementationSpec: { type: 'string' },
        acceptance: { type: 'string' }, filesLikely: { type: 'string' } } },
  },
}

const DISCIPLINES = [
  { key: 'game-feel/juice', lens: 'moment-to-moment juice: motion, easing, anticipation, follow-through, sound-free screen feedback, tactile micro-interactions (Vlambeer "juice it or lose it" lineage + 2026 mobile feel).' },
  { key: 'world/narrative', lens: 'environmental storytelling, mystery pacing, curiosity gaps, the サイレント lore drip, a living world that responds (Layton/Ghibli-grade).' },
  { key: 'reward/progression psychology', lens: 'reward scheduling, flow, variable-but-fair reward, session shape, the "あと1問" pull, kid-appropriate (COPPA, no dark patterns).' },
  { key: 'art-direction (motion/composition, NOT new art)', lens: 'using EXISTING assets better via motion/parallax/lighting/composition/colour-grade to hit the premium dark-RPG bar. No new image generation.' },
  { key: 'level/encounter design', lens: 'the detective case-loop depth: hotspot variety, puzzle pacing, the tap-NPC→ナゾ→restore rhythm, difficulty curve, avoiding "a quiz with a skin".' },
]
const CRITICS = [
  { persona: 'a literal 6-year-old who cannot read much English and gets bored fast' },
  { persona: 'a paying parent who wants to SEE it is a real game worth ¥, not a worksheet' },
  { persona: 'a hardcore Professor Layton / Ghibli fan judging it as a premium adventure game' },
]

phase('Studio')
const experts = (await parallel(DISCIPLINES.map((d) => () =>
  agent(
    `You are a world-class ${d.key} expert in a game studio.\n${BRIEF}\n\nYOUR LENS: ${d.lens}\n\n` +
    `LATEST-FIRST MANDATE: before judging, use WebSearch (load via ToolSearch "select:WebSearch") for CURRENT ` +
    `2026 state-of-the-art in your discipline for children's educational / detective / cozy-mystery games; cite ` +
    `dated sources. Then audit THIS game (reason from the brief; you MAY read files under ` +
    `~/dev/engquest-flutter/lib/features/ — explore/, battle/, home/, exam_practice/, quest/ — to ground evidence). ` +
    `CRITICAL: the ALREADY-BUILT features are IN SCOPE — RE-AUDIT them super-strictly (built ≠ good). Pick at least ` +
    `one recently-shipped game-feel feature and judge HARSHLY whether it actually hits the world-class bar (timing, ` +
    `feel, coherence, would-a-child-notice); a "deepen/fix an existing feature" finding is fully valid and often ` +
    `higher-leverage than a greenfield one. Do NOT exempt shipped work from criticism, and do NOT merely confirm ` +
    `what exists. Output your SINGLE highest-leverage gap (new OR a shortfall in something already built) that ` +
    `makes it feel less like a world-class GAME, and ONE concrete IN-SCOPE fix (pure Flutter/Dart, offline, no ` +
    `art-gen/audio/backend/AI/billing). Be specific + buildable. Reject your own idea if it needs new art or audio.`,
    { label: `expert:${d.key}`, phase: 'Studio', schema: EXPERT_SCHEMA, model: 'sonnet', agentType: 'Explore' }
  ).then((r) => ({ discipline: d.key, ...r })).catch(() => null)
))).filter(Boolean)
log(`Studio: ${experts.length}/${DISCIPLINES.length} experts reported`)

phase('Critique')
const critics = (await parallel(CRITICS.map((c) => () =>
  agent(
    `You are ${c.persona}, play-testing the game below and HARD to please.\n${BRIEF}\n\n` +
    `Imagine actually playing (tap an NPC, answer a ナゾ, watch colour return, do a battle, open the home hub). ` +
    `From YOUR persona, what is the single most boring / confusing / not-fun MOMENT? Be brutally specific. Then ` +
    `give ONE concrete IN-SCOPE fix (no new art/audio/backend). Do not be polite.`,
    { label: `critic:${c.persona.slice(0, 22)}`, phase: 'Critique', schema: CRITIC_SCHEMA, model: 'sonnet' }
  ).catch(() => null)
))).filter(Boolean)
log(`Critique: ${critics.length}/${CRITICS.length} playtesters reported`)

phase('Synthesize')
const synthesis = await agent(
  `You are the game director. Synthesize the studio panel + harsh playtests into a buildable plan to raise the ` +
  `GAME-as-a-game quality of コトバ探偵.\n${BRIEF}\n\nEXPERT FINDINGS:\n${JSON.stringify(experts, null, 1)}\n\n` +
  `PLAYTESTER COMPLAINTS:\n${JSON.stringify(critics, null, 1)}\n\nProduce a ranked list (3–6) of the highest-` +
  `leverage IN-SCOPE improvements (dedupe overlaps; weight what MULTIPLE people hit; reject anything needing new ` +
  `art/audio/backend/AI/billing or already-built). Pick the SINGLE #1 to build NOW with a precise implementation ` +
  `spec a senior Flutter engineer could execute in one focused session, concrete acceptance criteria, and likely ` +
  `files (lib/features/explore, battle, home, exam_practice, quest/ui/dq_ui.dart). Favour something that changes ` +
  `how the game FEELS, is verifiable, and is genuinely fun — not another utility/polish tweak.`,
  { label: 'director:synthesis', phase: 'Synthesize', schema: SYNTH_SCHEMA }
)

return { experts, critics, synthesis }

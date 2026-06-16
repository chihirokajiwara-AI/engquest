export const meta = {
  name: 'diverse-values-council',
  description: 'STANDING council of conflicting stakeholder VALUE systems that reach a COLLECTIVE conclusion on コトバ探偵 — grounded in the FULL accumulated knowledge base (each member READS the memory index + design bibles) AND today\'s latest 2026 web research. Exists because one narrow engineering lens was concluding alone (CEO 1834/1836).',
  phases: [
    { title: 'Ground+Value', detail: 'each value-persona reads the corpus + latest 2026 web, then judges from its lens' },
    { title: 'Conclude', detail: 'surface the value CONFLICTS and reach a ranked collective conclusion' },
  ],
}

// The accumulated knowledge base every member must read (the CEO's "understand ALL
// prior research" requirement — the originals, not a summary).
const MEM = '/Users/openclaw/.claude/projects/-Users-openclaw-dev-engquest-flutter/memory'
const D = 'docs/design'
const G = 'docs/governance'
const B = 'docs/business'

// args may carry the focus question / fresh designs to evaluate; default to the
// standing brief.
const FOCUS = (typeof args === 'string' && args) ? args : `
Evaluate コトバ探偵's current direction and the two fresh team designs:
[A] 4-MAIN CAST (memory cast-opening-redesign-2026-06-16): four "faces of きみ" — カイト
(M5 male, SPEAKING, lost-sentence secret), セナ (M6 female, READING, grandfather's
notebook), レン (M7 NEW male, GRAMMAR/beginner, blank book), + a NEW female LISTENING
face. Select = gender-first → NAME + one-line secret (retire "classic/street").
[B] OPENING REDESIGN: cold-open on the living 5級 town DYING (colour drains, no static
menu) → CAST detective gender-first by name+secret → child CAUSES the first restoration
AS that detective via the c·a·t blend (errorless) → roll into real 5級 Case 1; defer the
form to an optional 探偵手帳 card on Home. ~90% buildable now.
`

const VALUES = [
  { id: 'paying-parent', persona: 'a paying Japanese parent of a 6yo paying ¥999/mo', read: [`${MEM}/MEMORY.md`, `${B}/revenue-roadmap.md`, `${G}/QUALITY-CONSTITUTION.md`], lens: 'child safety/COPPA, trust, does it ACTUALLY help 英検-pass, screen-time guilt, value-for-money, would I recommend it' },
  { id: 'the-6yo-child', persona: 'the 6-year-old NON-READER child playing it', read: [`${MEM}/MEMORY.md`, `${D}/UX-AUDIT-2026-06-07.md`, `${G}/NARRATIVE-PRODUCER-RUBRIC.md`], lens: 'is it FUN, do I understand what to do, do I feel clever, do I want to come back, anything boring/confusing/scary' },
  { id: 'eiken-teacher', persona: 'a veteran 英検 cram-school teacher', read: [`${MEM}/MEMORY.md`, `${D}/EIKEN5-PHONICS-STAGE.md`, `${D}/A-KEN-QUEST-DESIGN-BIBLE.md`], lens: 'does this measurably move a child to PASSING 英検 (real question types, real transfer) or is it edutainment theatre' },
  { id: 'retention-strategist', persona: 'a F2P/subscription mobile-games business strategist', read: [`${MEM}/MEMORY.md`, `${B}/revenue-roadmap.md`, `${G}/COMPLETION-SCORECARD.md`], lens: 'D1/D7/D30 retention, the activation moment, churn, the 5,000-user path, what makes a parent keep paying' },
  { id: 'art-director', persona: 'a world-class game art director', read: [`${MEM}/MEMORY.md`, `${D}/ART-DIRECTION.md`, `${D}/WORLD-BIBLE.md`, `${D}/CHARACTER-BIBLE.md`], lens: 'visual cohesion/beauty, the dusty-teal/brass identity, does the cast+world read as ONE premium IP vs a thin asset pile, the bar vs Layton/Ghibli' },
  { id: 'cultural-authenticity', persona: 'a Japanese children\'s-media cultural critic', read: [`${MEM}/MEMORY.md`, `${D}/WORLD-BIBLE.md`, `${D}/OPENING-NARRATIVE-BIBLE.md`], lens: 'is it authentically made for Japanese kids (register, ひらがな, cultural texture) or a generic westernized shell; does the サイレント mystery resonate' },
  { id: 'accessibility-inclusion', persona: 'a children\'s accessibility & inclusion advocate', read: [`${MEM}/MEMORY.md`, `${D}/UX-AUDIT-2026-06-07.md`, `${G}/QUALITY-CONSTITUTION.md`], lens: 'non-readers, reduce-motion, screen-readers, gender/identity inclusiveness of cast+select, the youngest 4yo, no child left out' },
  { id: 'child-dev-psychologist', persona: 'a child developmental psychologist', read: [`${MEM}/MEMORY.md`, `${G}/NARRATIVE-PRODUCER-RUBRIC.md`, `${D}/CHARACTER-2026-RESEARCH.md`], lens: 'intrinsic motivation, errorless-success+emotional safety, healthy challenge, identity via avatar, character attachment, no dark patterns on kids' },
]

phase('Ground+Value')
const VERDICT = { type:'object', additionalProperties:false,
  required:['value','readConfirm','latest','strongest','missing','nonNegotiable','onCast','onOpening','verdict'],
  properties:{
    value:{type:'string'},
    readConfirm:{type:'string', description:'one concrete fact you took from the corpus you READ (proves you read it, not guessed)'},
    latest:{type:'string', description:'1-2 dated 2025-2026 web sources you grounded in (with dates)'},
    strongest:{type:'string', description:'the single most important thing for THIS value'},
    missing:{type:'string', description:'what is MISSING/narrow/WRONG from THIS value that a single engineering synthesizer overlooks — adversarial & specific'},
    nonNegotiable:{type:'string'},
    onCast:{type:'string', description:'keep/change/reject the 4-main cast + why, from your value'},
    onOpening:{type:'string', description:'keep/change/reject the opening redesign + why, from your value'},
    verdict:{type:'string', enum:['ship','ship-with-changes','not-ready']},
  }}

const opinions = await parallel(VALUES.map(v => () =>
  agent(
    `You are ${v.persona}. Judge コトバ探偵 STRICTLY from your value system — you will DISAGREE with other stakeholders; that is the point.\n\nFIRST, GROUND YOURSELF (do not skip — the CEO requires the council understand ALL prior research + today's latest):\n1. Read these accumulated-knowledge files: ${v.read.join(', ')}. (MEMORY.md is the index of every hard-won learning so far.)\n2. THEN WebSearch the current 2026 state-of-the-art from your value lens and cite DATED 2025-2026 sources. Today is 2026-06-16 — get fresh values/evidence, not stale.\n\nYOUR VALUE LENS: ${v.lens}\n\nTHEN evaluate this focus:\n${FOCUS}\n\nBe adversarial and specific; name what a ship-it-green engineering mindset would miss from your value. Return the structured verdict (readConfirm must cite a concrete fact from the files you read).`,
    { label: `value:${v.id}`, phase: 'Ground+Value', schema: VERDICT, agentType: 'general-purpose' }
  ).then(r => ({ id: v.id, ...r })).catch(() => null)
))

phase('Conclude')
const valid = opinions.filter(Boolean)
const conclusion = await agent(
  `You are the council CHAIR. Do NOT impose your own taste — make the COLLECTIVE conclusion of these ${valid.length} conflicting, corpus-grounded, latest-2026 value systems, with the conflicts VISIBLE not averaged. (This council exists because one narrow engineering lens concluded alone — CEO 1834/1836.)\n\nFirst, read ${D}/WORLD-BIBLE.md and ${MEM}/cast-opening-redesign-2026-06-16.md so your synthesis is grounded in canon.\n\nThe ${valid.length} grounded value verdicts (JSON):\n${JSON.stringify(valid, null, 2)}\n\nProduce a CEO-actionable conclusion:\n1) CONFLICTS: the 3-5 sharpest genuine DISAGREEMENTS between value systems (teacher-rigor vs child-fun vs business-retention vs parent-safety vs art-ambition) — state each tension honestly, do not resolve by fiat.\n2) CONVERGENCE: the non-negotiables that survive EVERY lens.\n3) RANKED BUILD CONCLUSION: what to build NOW for cast + opening + product, each item tagged with WHICH values drive it and which it trades off; bias to what raises 英検-pass value AND child-experience AND sellability TOGETHER.\n4) The single highest-leverage thing the narrow engineering lens was MISSING.\nDecisive, but show the disagreement. Your final message IS the deliverable.`,
  { label: 'council-chair', phase: 'Conclude', agentType: 'general-purpose' }
)

return { values: valid.map(v => ({ id:v.id, verdict:v.verdict, nonNegotiable:v.nonNegotiable })), conclusion }

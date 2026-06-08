export const meta = {
  name: 'world-studio',
  description: 'Standing WORLD-DESIGN studio loop: super-critical adversarial lenses AUDIT the 7-case (事件簿) design for DEPTH (default-REJECT), score each case 0-10, expose shallowness/cliché/weak 英検-mapping, then an Opus director gives a brutal verdict + concrete deepening proposals (CEO-gated, non-destructive)',
  whenToUse: 'When the world/story pillar is the focus or its depth is in question (CEO 877). Output is a critical audit + deepening proposal for CEO approval — WORLD-BIBLE is spec-frozen, so it proposes, never auto-edits.',
  phases: [
    { title: 'Refute', detail: '5 adversarial lenses attack each case for depth (default-reject)' },
    { title: 'Verdict', detail: 'director: brutal honest verdict + per-case deepening proposals' },
  ],
}

// Why (CEO msg 877, 2026-06-08): "did you do a super-rigorous critical AUDIT of the
// 7-case design itself? how DEEP is it?" This is that audit — adversarial, not a
// self-congratulatory pass. Non-destructive: WORLD-BIBLE.md is spec-frozen → propose only.

const APP = `
PRODUCT: A-KEN Quest「コトバ探偵」— Flutter-web 英検 RPG for Japanese children (4-18).
SOLE value = "an app that gets a kid to PASS 英検". Architecture: LEAN-LAYTON (static
painted scenes; no map traversal/grind; 英検 item = the puzzle; 級 = 事件簿). The world is
7 case-files, one per grade (5→4→3→準2→準2プラス→2→準1), an inward spiral toward サイレント.
Repo: /Users/openclaw/dev/engquest-flutter. READ docs/design/WORLD-BIBLE.md (the 7 cases),
COMPOSITION-ARCHITECTURE.md, CHARACTER-BIBLE.md (+ the 2026-06-08 proposal), and
lib/features/quest/quest_data.dart (what's actually built). WORLD-BIBLE.md is SPEC-FROZEN.
`

const LIVE = `LATEST-FIRST: WebSearch/WebFetch current (dated) sources for your lens (narrative-design depth, 英検 spec per grade, children's-media engagement, world-building craft, art-direction distinctiveness) and cite them. Treat the existing bible as stale-until-verified.`

const LENSES = [
  { key: 'narrative-depth', role: 'BRUTAL NARRATIVE CRITIC. Attack each of the 7 cases for SHALLOWNESS: is the mystery a real mystery or a fetch-quest reskin? Is there a genuine reveal/turn? Is the サイレント spiral earned or asserted? Are the 7 endings distinct or copy-paste? Name clichés. A "case" that is just "solve N items → colour returns" with no dramatic question FAILS.' },
  { key: 'eiken-mapping', role: 'BRUTAL 英検 PEDAGOGY CRITIC. For EACH case, is the assigned skill/級 mapping real and sufficient, or hand-wavy? Does the case actually exercise that grade\'s ACTUAL 英検 大問 structure (post-2024 reform) at the right difficulty step-up? Where does the fiction let a child progress WITHOUT the target English (Habgood failure)? Is the per-grade difficulty curve honest?' },
  { key: 'child-engagement', role: 'BRUTAL CHILD-ENGAGEMENT CRITIC (ages 4-18). Would a real 7-year-old / 13-year-old care about THIS case, or is it adult-pleasing literary melancholy that bores kids? Is the emotional hook age-appropriate across the huge age range? Where will a child quit? Is "grief/silence" too bleak for the 5級 entry?' },
  { key: 'world-coherence', role: 'BRUTAL WORLD-COHERENCE CRITIC. Is the lore consistent across 7 cases or retrofitted? Does the geography/spiral hold? Are the 7 districts distinct identities or interchangeable "sad grey town"? Is the サイレント mythology coherent and paid off? Plot holes?' },
  { key: 'art-distinctiveness', role: 'BRUTAL ART-DIRECTION CRITIC. Will the 7 case plates read as 7 DISTINCT places at a glance, or 7 variations of one brown-grey street? Is each district\'s visual motif strong + producible (perf-aware) + tied to its 級? Where is the art direction generic?' },
]

const AUDIT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['lens', 'overallDepth', 'perCase', 'worstFlaws', 'sources'],
  properties: {
    lens: { type: 'string' },
    overallDepth: { type: 'number', description: '0 = shallow/broken, 10 = world-class deep' },
    perCase: {
      type: 'array', description: 'One entry per case you can assess (5/4/3/pre2/pre2plus/2/pre1).',
      items: { type: 'object', additionalProperties: false, required: ['grade', 'depthScore', 'verdict', 'fix'],
        properties: {
          grade: { type: 'string' },
          depthScore: { type: 'number', description: '0-10 depth for THIS case through THIS lens' },
          verdict: { type: 'string', description: 'The brutal honest finding (what is shallow/missing/cliché).' },
          fix: { type: 'string', description: 'The concrete deepening this case needs.' },
        } },
    },
    worstFlaws: { type: 'array', description: 'The 2-3 most damning depth failures across the whole design.', items: { type: 'string' } },
    sources: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['title', 'url', 'date'],
      properties: { title: { type: 'string' }, url: { type: 'string' }, date: { type: 'string' } } } },
  },
}

phase('Refute')
const audits = (await parallel(LENSES.map((l) => () =>
  agent(`${APP}\n\nYOUR LENS: ${l.role}\n\n${LIVE}\n\nDEFAULT TO REJECT: assume the design is shallower than it claims and prove it. Read the bibles + quest_data, then score depth per case and name the flaws bluntly. Do NOT praise; your job is to find what is not yet world-class. Respect lean-Layton + the SOLE value (英検) in your FIXES.`,
    { label: `refute:${l.key}`, phase: 'Refute', model: 'sonnet', schema: AUDIT_SCHEMA })
))).filter(Boolean)

phase('Verdict')
const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['honestVerdict', 'overallDepthScore', 'perCaseDeepening', 'topDeepenings', 'isWorldClass'],
  properties: {
    honestVerdict: { type: 'string', description: 'A brutally honest 1-2 paragraph assessment of how deep the 7-case design actually is right now (for the CEO). No sugar-coating.' },
    overallDepthScore: { type: 'number', description: '0-10 consolidated depth of the 7-case design as it stands.' },
    perCaseDeepening: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['grade', 'currentDepth', 'deepeningProposal'],
        properties: { grade: { type: 'string' }, currentDepth: { type: 'number' }, deepeningProposal: { type: 'string', description: 'Concrete WORLD-BIBLE deepening for this case (CEO-gated).' } } },
    },
    topDeepenings: { type: 'array', description: 'The few highest-value deepenings to make the 7 cases world-class.', items: { type: 'string' } },
    isWorldClass: { type: 'boolean', description: 'Honest: is the 7-case design ALREADY world-class-deep? (Almost certainly false — say so and why.)' },
  },
}
const verdict = await agent(
  `${APP}\n\nYou are the WORLD-DESIGN DIRECTOR. Five adversarial critics attacked the 7-case design for depth. Give the CEO a BRUTALLY HONEST verdict on how deep it actually is, a consolidated 0-10 depth score, and concrete per-case deepening proposals (CEO-gated; WORLD-BIBLE is spec-frozen → propose, do not auto-apply). Do not defend the design; synthesize the strongest criticisms into the deepening plan.\n\nADVERSARIAL AUDITS (JSON):\n${JSON.stringify(audits, null, 2)}`,
  { label: 'world-director', phase: 'Verdict', model: 'opus', schema: VERDICT_SCHEMA }
)

return { critics: audits.length, verdict }

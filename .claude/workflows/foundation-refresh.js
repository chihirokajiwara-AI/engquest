export const meta = {
  name: 'foundation-refresh',
  description: 'Periodic LIVING-FOUNDATION refresh: discipline teams re-research the latest (dated) craft, score the current design bibles for staleness/gaps, and PROPOSE concrete bible updates for CEO approval (does NOT auto-edit the spec-frozen bibles)',
  whenToUse: 'Run ~every 10 iterations, on a major external change, or on CEO signal. Keeps docs/design/*.md from going stale. Output is a proposal for CEO approval — never an auto-commit to frozen specs.',
  phases: [
    { title: 'Re-research', detail: 'discipline experts re-research latest craft + score the current bible' },
    { title: 'Propose', detail: 'studio-director consolidates dated, per-doc proposed updates for CEO approval' },
  ],
}

// Why this exists (CEO msg 869, 2026-06-08): the world/character/art/pedagogy bibles
// in docs/design/ are a LIVING foundation, not a frozen one-time artifact. This
// workflow is the standing mechanism that re-researches the latest craft and proposes
// concrete updates. It is intentionally NON-DESTRUCTIVE: the four lean-Layton docs are
// spec-frozen (AUTONOMOUS-LOOP.md §D) and change only via CEO approval, so this only
// PROPOSES diffs — a human/CEO applies them.

const APP = `
PRODUCT: A-KEN Quest「ことばの勇者」/「コトバ探偵」— Flutter-web 英検 RPG for Japanese
children (ages 4-18). SOLE value = "an app that gets a kid to PASS 英検". Architecture is
LEAN-LAYTON (no map traversal/level grind; static painted scenes; 英検 item = the puzzle
in the scene; 級 = 事件簿). Repo: /Users/openclaw/dev/engquest-flutter. The design
foundation lives in docs/design/*.md and is SPEC-FROZEN (changes need CEO approval).
`

const LIVE = `LATEST-FIRST MANDATE: run WebSearch/WebFetch for CURRENT (this-month) authoritative, DATED sources before proposing. Treat both your training knowledge and the existing bible as stale-until-verified. Prefer primary sources (creator interviews, official material, peer-reviewed learning science, reputable design analyses). Every proposed change MUST cite a dated source.`

// Each discipline owns one (or more) bible file(s) to re-audit against the latest craft.
const DISCIPLINES = [
  { key: 'layton-composition', bible: 'docs/design/COMPOSITION-ARCHITECTURE.md', lens: 'Professor Layton / Level-5 composition + puzzle-in-world craft (Akihiro Hino philosophy). Re-check the lean-Layton composition against the latest known Level-5 practice and 2D narrative-puzzle design.' },
  { key: 'world-narrative', bible: 'docs/design/WORLD-BIBLE.md', lens: 'game world-building & narrative design craft. Re-check the 7 case-file world against current best practice.' },
  { key: 'character-design', bible: 'docs/design/CHARACTER-BIBLE.md', lens: 'character design (silhouette/colour-language/archetype/arc; Toriyama-grade legibility). Re-check the small-deep cast.' },
  { key: 'art-direction', bible: 'docs/design/ART-DIRECTION.md', lens: 'painted 2D art direction + Flutter-web perf-aware asset pipeline (CanvasKit/Skwasm, formats, compression, colour script). Re-check against the latest Flutter-web rendering + image guidance.' },
  { key: 'pedagogy', bible: 'docs/design/A-KEN-QUEST-DESIGN-BIBLE.md', lens: "children's educational-game design + learning science (intrinsic integration, FSRS/spaced-repetition, mastery framing, retention) fused with REAL 英検 mastery. Re-check the learning design." },
]

const AUDIT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['discipline', 'bible', 'stalenessScore', 'staleFindings', 'proposedUpdates', 'newSources'],
  properties: {
    discipline: { type: 'string' },
    bible: { type: 'string' },
    stalenessScore: { type: 'number', description: '0 = fully current/world-class, 10 = badly out of date / missing' },
    staleFindings: {
      type: 'array', description: 'Where the current bible is stale, wrong, shallow, or missing vs the latest craft.',
      items: { type: 'object', additionalProperties: false, required: ['issue', 'severity'],
        properties: { issue: { type: 'string' }, severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] } } },
    },
    proposedUpdates: {
      type: 'array', description: 'Concrete proposed edits to the bible (for CEO approval — not auto-applied).',
      items: { type: 'object', additionalProperties: false, required: ['section', 'change', 'rationale', 'source'],
        properties: {
          section: { type: 'string', description: 'Which section/heading of the bible' },
          change: { type: 'string', description: 'The concrete proposed wording/addition/removal' },
          rationale: { type: 'string' },
          source: { type: 'string', description: 'Dated citation backing this change' },
        } },
    },
    newSources: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['title', 'url', 'date'],
      properties: { title: { type: 'string' }, url: { type: 'string' }, date: { type: 'string' } } } },
  },
}

phase('Re-research')
const audits = (await parallel(DISCIPLINES.map((d) => () =>
  agent(
    `${APP}\n\nYOUR LENS: ${d.lens}\n\nSTEP 1 — READ the current bible at ${d.bible} (and cross-referenced docs/design/*.md as needed).\nSTEP 2 — ${LIVE}\nSTEP 3 — Score how stale/world-class it is now, list stale/shallow/missing findings, and propose CONCRETE, dated updates. Respect the LEAN-LAYTON architecture (do not propose reintroducing map-traversal/level-grind/large-roster). The SOLE value is passing 英検 — never propose anything that dilutes learning rigor.`,
    { label: `refresh:${d.key}`, phase: 'Re-research', model: 'sonnet', schema: AUDIT_SCHEMA }
  )
))).filter(Boolean)

phase('Propose')
const PROPOSAL_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['summary', 'overallStaleness', 'perDocProposals', 'topChanges', 'researchLogEntry'],
  properties: {
    summary: { type: 'string', description: '1-2 paragraphs: what changed in the craft since the bibles were written, and what most needs updating.' },
    overallStaleness: { type: 'number', description: '0-10 across the whole foundation' },
    perDocProposals: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['doc', 'proposals'],
        properties: { doc: { type: 'string' }, proposals: { type: 'string', description: 'Markdown: the concrete proposed edits for this doc, each with a dated source.' } } },
    },
    topChanges: { type: 'array', description: 'The few highest-value updates to make now (CEO decides).', items: { type: 'string' } },
    researchLogEntry: { type: 'string', description: 'A dated markdown bullet block to append to a docs/design/RESEARCH-LOG.md (date + key new sources + headline findings).' },
  },
}
const proposal = await agent(
  `${APP}\n\nYou are the STUDIO DIRECTOR. ${DISCIPLINES.length} discipline experts re-researched the latest craft and audited the current design bibles for staleness. Consolidate into a single FOUNDATION-REFRESH PROPOSAL for the CEO to approve — concrete per-doc proposed edits with dated sources, ranked. Do NOT auto-apply: the bibles are spec-frozen and change only via CEO approval. Be honest where the foundation is already world-class (propose nothing rather than churn).\n\nDISCIPLINE AUDITS (JSON):\n${JSON.stringify(audits, null, 2)}`,
  { label: 'refresh-director', phase: 'Propose', model: 'opus', schema: PROPOSAL_SCHEMA }
)

return { audited: audits.length, proposal }

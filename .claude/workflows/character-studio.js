export const meta = {
  name: 'character-studio',
  description: 'Standing CHARACTER-DESIGN studio loop: a world-class character designer + art director + producer/director + narrative writer + pedagogy lens deeply develop the コトバ探偵 cast (bios, arcs, visual language, expression range, voice, 英検-skill embodiment, vocab-task scaling) and PROPOSE CHARACTER-BIBLE updates + production asset lists for CEO approval',
  whenToUse: 'Run when deepening the cast (CEO 874): not a one-off — re-run to push each character to world-class. Output proposes CHARACTER-BIBLE.md diffs (spec-frozen → CEO approves) and a concrete per-character asset/production list. Pass args (a character name or grade) to focus on one; omit for the whole cast.',
  phases: [
    { title: 'Design', detail: 'discipline experts deeply develop the cast (latest craft, dated)' },
    { title: 'Direct', detail: 'producer/director consolidates a coherent cast + CEO-facing proposals' },
  ],
}

// Why (CEO msg 874, 2026-06-08): "the per-character idea is just ONE example — think
// further ahead, design deeper; you haven't built a standing character-design loop run
// by world-class character designers + producer/director." This is that loop. It is the
// CHARACTER-DESIGN instance of the per-discipline studio pattern (AUTONOMOUS-LOOP §G).
// Non-destructive: CHARACTER-BIBLE.md is spec-frozen — this PROPOSES, the CEO approves.

const APP = `
PRODUCT: A-KEN Quest「ことばの勇者」/「コトバ探偵」— Flutter-web 英検 RPG for Japanese
children (4-18). SOLE value = "an app that gets a kid to PASS 英検". Architecture: LEAN-
LAYTON (static painted scenes; no map traversal/grind; 英検 item = the puzzle in the scene;
級 = 事件簿). Restoration UNIT = the CHARACTER (CEO 871): a SMALL deep cast, each owning a
large task-list of 英検 items; clearing tasks returns that character's colour + voice
(grey→colour, broken sound → full phrases). Asset cost scales with the cast, not vocab.
Repo: /Users/openclaw/dev/engquest-flutter. READ docs/design/CHARACTER-BIBLE.md (current
cast), WORLD-BIBLE.md, COMPOSITION-ARCHITECTURE.md §2.1, and lib/features/quest/quest_data.dart
(existing NPCs) before proposing. CHARACTER-BIBLE.md is SPEC-FROZEN (CEO approval to change).
`

const LIVE = `LATEST-FIRST: WebSearch/WebFetch current (dated) character-design craft (silhouette theory, colour-language, archetype/arc, JP charm/legibility à la Toriyama/Nagano, kids'-IP character appeal) before proposing; cite dated sources.`

const LENSES = [
  { key: 'character-designer', role: 'WORLD-CLASS CHARACTER DESIGNER. Silhouette-first legibility (recognisable at thumbnail), colour language, shape grammar, archetype, expression range (the emotion sheet), distinctive visual hook. Push each character from "exists" to "iconic".' },
  { key: 'art-director', role: 'ART DIRECTOR. Cast visual cohesion (one world), grey/colour pair design, how each reads on the painted plates, production feasibility on Flutter-web (perf-aware: grey/color webp pairs + an expression sprite budget). Identity-gate consistency.' },
  { key: 'producer-director', role: 'PRODUCER/DIRECTOR. The cast as a whole: each character\'s ROLE in the player journey + emotional arc across the 7 cases, marketability/charm (a mascot kids love + tell friends about — growth pillar 16/17), pacing of who appears when, and ruthless cuts (small deep cast > large shallow). Think FAR ahead, not one mechanic.' },
  { key: 'narrative-writer', role: 'NARRATIVE WRITER. Each character\'s backstory, voice, want, flaw, and arc (greyed/broken → restored), their relationship to the サイレント and to きみ (the player). Distinct speech patterns. The arc must pay off the "words return" theme.' },
  { key: 'pedagogy', role: 'LEARNING DESIGNER. Bind each character to a 英検 skill/domain so their identity TEACHES it (Layton puzzle-as-characterisation), and design how ONE character carries a LARGE task-list across many vocab/phonics items with GRADUAL restoration — so the design scales to real 英検 volume without diluting rigor.' },
]

const DESIGN_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['lens', 'castNotes', 'perCharacter', 'sources'],
  properties: {
    lens: { type: 'string' },
    castNotes: { type: 'string', description: 'Cross-cast observations from this lens (cohesion, gaps, who is shallow, who to cut/add).' },
    perCharacter: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['name', 'proposal'],
        properties: { name: { type: 'string' }, proposal: { type: 'string', description: 'Concrete deepening for this character through this lens (with dated craft rationale).' } } },
    },
    sources: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['title', 'url', 'date'],
      properties: { title: { type: 'string' }, url: { type: 'string' }, date: { type: 'string' } } } },
  },
}

phase('Design')
const focus = (typeof args === 'string' && args) ? `\n\nFOCUS THIS RUN ON: ${args}. Go deep on this; mention others only as needed for cohesion.` : ''
const designs = (await parallel(LENSES.map((l) => () =>
  agent(`${APP}\n\nYOUR LENS: ${l.role}\n\n${LIVE}${focus}\n\nRead the current CHARACTER-BIBLE + quest_data NPCs, then deepen the cast through your lens. Think FORWARD (the whole 7-case journey), not just one mechanic. Respect lean-Layton (small deep cast) + the SOLE value (英検). Return castNotes + perCharacter proposals + dated sources.`,
    { label: `design:${l.key}`, phase: 'Design', model: 'sonnet', schema: DESIGN_SCHEMA })
))).filter(Boolean)

phase('Direct')
const DIRECTION_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['summary', 'finalCast', 'characterBibleProposal', 'productionAssets', 'topMoves'],
  properties: {
    summary: { type: 'string', description: 'The directorial through-line: what the cast IS and how it serves the journey + 英検 + sellability.' },
    finalCast: {
      type: 'array', description: 'The directed cast (keep it small + deep). Cut/merge shallow ones.',
      items: { type: 'object', additionalProperties: false, required: ['name', 'role', 'eikenSkill', 'visualHook', 'arc', 'voice'],
        properties: { name: { type: 'string' }, role: { type: 'string' }, eikenSkill: { type: 'string' }, visualHook: { type: 'string' }, arc: { type: 'string' }, voice: { type: 'string' } } },
    },
    characterBibleProposal: { type: 'string', description: 'Markdown: the concrete proposed CHARACTER-BIBLE.md revision (for CEO approval — not auto-applied).' },
    productionAssets: { type: 'string', description: 'Markdown: per-character asset/production list (grey/colour pair, expression sprites, voice lines) within a small-team + Flutter-web-perf budget.' },
    topMoves: { type: 'array', description: 'The few highest-leverage character moves to make now.', items: { type: 'string' } },
  },
}
const direction = await agent(
  `${APP}\n\nYou are the STUDIO DIRECTOR for character design. Five lenses (designer, art director, producer/director, writer, pedagogy) developed the cast. Direct it into ONE coherent, world-class, FORWARD-LOOKING cast — small and deep, each character iconic, each bound to a 英検 skill, each with a restoration arc that scales across a large task-list. Cut shallow characters. Output a concrete CHARACTER-BIBLE proposal + production asset list for CEO approval (spec-frozen → propose, do not auto-apply).\n\nLENS DESIGNS (JSON):\n${JSON.stringify(designs, null, 2)}`,
  { label: 'character-director', phase: 'Direct', model: 'opus', schema: DIRECTION_SCHEMA }
)

return { lenses: designs.length, direction }

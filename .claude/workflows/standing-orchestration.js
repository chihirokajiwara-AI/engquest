// .claude/workflows/standing-orchestration.js
// ENG Quest / コトバ探偵 — STANDING PARALLEL DEV ORCHESTRATION (8-PILLAR)
// CEO-approved 2026-06-23 (msg 2421 GO → 2428 "literally 8 boxes; all 8 pillars
// driven to world-class either way"). The 8 大局 pillars are the CEO's verbatim
// charter; each is its own standing team.
//
// THE 8 PILLARS (CEO msg 2425, verbatim mandate):
//   ① 英検合格エンジン        — 学習科学×コンテンツ十分性×誠実な評価で本当に合格させる
//   ② 世界・物語・キャラクター  — 子が住みたいコトバ探偵宇宙 (spec-frozen → 提案出力)
//   ③ ゲーム設計・コアループ    — Layton級の謎解き×英検が有機結合した中核ループ
//   ④ 没入・演出・音/音楽       — 生きていて高級に"感じる"か (juice/遷移/SE/音楽)
//   ⑤ ビジュアル・アートディレクション — 世界水準の見た目 (gated → 実モック付きCEO提案)
//   ⑥ リテンション・成長実感    — 何年も毎日戻る設計
//   ⑦ 保護者の信頼・事業・誠実性 — 親が払い続けるか (進捗の証明・安全・誠実)
//   ⑧ プロダクト基盤・品質・到達性 — 6歳がどの端末でも堅牢に (a11y/perf/到達性)
//
// CONCURRENCY: 8 teams could recreate the 32-agent stall the Rule-#0 debate
// warned about (real cap ≈ 8 sustained slots on this 10-CPU box). Fix = STAGED
// topology: phases run sequentially so peak concurrency NEVER exceeds 8.
//   Scout (8 Haiku ∥) → Build (8 Sonnet ∥) → Verify (2 Sonnet ∥) → Orchestrate (1 Opus)
//   = 19 expressed, peak 8, ~3 rotations wall-time, no barrier stall.
//
// TWO-QUEUE DISCIPLINE (CEO "毎回検証超厳しく"): every team writes to PROPOSED
// freely; a proposal is promoted to CLEARED only if it carries pillar-① governor's
// 合格率-non-regression stamp AND pillar-⑧ gate's ship-readiness stamp AND is not
// CEO-gated. The main loop implements from CLEARED ONLY. This is the structural
// fix for the 7,923-corrupted-distractor / red-tests-shipped failure class.
//
// EXECUTION CONTRACT: agents READ + DESIGN + DRAFT only — they return a precise
// buildable SPEC (file, exact change, code/test snippet) as structured output and
// do NOT edit the tree (parallel edits conflict + bypass the main loop's SHIP
// gate). The main loop applies the top CLEARED item, runs real analyze/test,
// commits. Spec-frozen (②) / art-pixel (⑤) / spend / story-rewrite / prod items
// surface as CEO-gated proposals, never autonomous builds.

export const meta = {
  name: 'standing-orchestration',
  description: 'Run one cycle of the CEO-approved 8-pillar dev orchestration → governor+gate-stamped ranked CLEARED build plan',
  whenToUse: 'Each autonomous-loop tick: drive all 8 大局 pillars toward world-class in parallel, weighted to the paid-quality experience/retention core (②-⑦). Pass args.alreadyBuilt (recent commit subjects) so scouts find NEW gaps.',
  phases: [
    { title: 'Scout', detail: '8 Haiku scouts read repo state + top gaps per pillar' },
    { title: 'Build', detail: '8 Sonnet builders each draft one buildable spec (or CEO proposal for gated pillars)' },
    { title: 'Verify', detail: '① governor + ⑧ gate stamp all 8 proposals' },
    { title: 'Orchestrate', detail: 'Opus applies two-queue discipline → ranked CLEARED plan' },
  ],
};

const RECENT = Array.isArray(args?.alreadyBuilt) ? args.alreadyBuilt : [];
const recentNote = RECENT.length
  ? `Recently shipped (do NOT re-propose; find the NEXT gap):\n- ${RECENT.join('\n- ')}`
  : 'No recent-commit list supplied; infer recent work from git log.';

// The 8 pillars. weight = priority bias toward the paid-quality core (CEO 2424:
// the loop has been starving ②-⑦; the experience/retention core is what earns ¥999).
const PILLARS = [
  { key: '①', name: '英検合格エンジン (GOVERNOR)',
    owns: 'test/, lib/data/content/, lib/features/exam_practice/, lib/core/fsrs/, lib/core/cefr/',
    mandate: '学習科学×コンテンツ十分性×誠実な評価で「本当に合格させる」か。FSRS想起密度がquestループに配線されているか(orphanでないか)、級別の問題量が水増しでなく十分か(content-qa gated)、合格率/CSE推定が誠実か、2026大問構造が正しいか、二次対策。ALSO GOVERNOR: 全提案を合格率非回帰でスタンプ。', gated: false, weight: 'high' },
  { key: '②', name: '世界・物語・キャラクター',
    owns: 'lib/features/quest/ (story/lore data), 世界観/キャスト定義, docs/world/',
    mandate: '子が住みたいコトバ探偵宇宙 — 7事件簿の物語深度・キャスト・lore。spec-frozen: 出力は世界観"設計提案"(物語の書き換え/アート生成は自走せずCEO提案)。ただし既存lore/物語データの構造化・配線・整合は buildable。', gated: true, weight: 'high' },
  { key: '③', name: 'ゲーム設計・コアループ',
    owns: 'lib/features/quest/, battle/, explore/ (core loop, progression, rewards)',
    mandate: 'クイズの皮でなく本物のゲーム。Layton級の謎解き×英検が有機結合した中核ループ・進行・報酬。RPGの動詞(solve=attack, tap-to-advanceでない)。これが課金される体験の心臓 — 最優先。', gated: false, weight: 'highest' },
  { key: '④', name: '没入・演出・音/音楽',
    owns: 'lib/core/sound/, lib/features/quest/ui/ (transitions/juice), animation code',
    mandate: '生きていて高級に"感じる"か。juice・遷移・効果音・音楽アイデンティティ(leitmotif, kokoro TTS)。安っぽさを消し、毎瞬の手触りを上げる buildable code。', gated: false, weight: 'high' },
  { key: '⑤', name: 'ビジュアル・アートディレクション',
    owns: 'lib/features/quest/ui/dq_ui.dart, palette/theme code, asset pipeline (proposal)',
    mandate: '世界水準の見た目。パレット/カード言語/キャラ・シーンアートの一貫性。gated: アート"生成"(pixels)は実モック付きCEO提案。ただしパレット/カードwidget/レイアウトのCODE言語は buildable。', gated: true, weight: 'high' },
  { key: '⑥', name: 'リテンション・成長実感',
    owns: 'lib/features/home/, core/gamification/, achievements/',
    mandate: '何年も毎日戻る設計。習慣(diegetic streak/case-log, 罪悪感でない)・進捗の実感(合格率live/あと1問)・再訪フック・級ラダーの felt-progression。', gated: false, weight: 'high' },
  { key: '⑦', name: '保護者の信頼・事業・誠実性',
    owns: 'lib/features/parent_dashboard/, paywall/, legal/',
    mandate: '親が払い続けるか。進捗の証明(value-proof dashboard)・安全(COPPA/APPI consent-gate)・価値・誠実。consent/dashboard/paywall整合は buildable; 課金infra/ASO/Stripeはspend-gated→提案。', gated: false, weight: 'high' },
  { key: '⑧', name: 'プロダクト基盤・品質・到達性 (GATE)',
    owns: 'test/ (gate), scripts/, lib/core/ (infra), .github/',
    mandate: '6歳がどの端末でも使える堅牢さ。390×844 breadth実機監査(Playwright/semantics, JS error, tap到達, off-fold/clipping) before "playable"主張・a11y・perf(boot/brotli/bundle)・信頼性・iOS/Android CI。ALSO GREEN GATE: 全提案をship-readinessでスタンプ。', gated: false, weight: 'med' },
];

const COMMON = `Product: コトバ探偵 / ENG Quest — a Flutter-web 英検 (Eiken) learning RPG for Japanese children age 6+, ¥999/mo. Mission: take a 6yo to 英検準1級/CEFR B2 by high school, in a Professor-Layton-grade detective game they love daily and parents pay for. Repo: /Users/openclaw/dev/engquest-flutter (you run inside it).

CEO PRIORITY (msg 2424): the loop has been starving the paid-quality core — it shipped 英検-content gloss (①) and quality-hygiene (⑧) but under-built the EXPERIENCE/RETENTION core (②③④⑤⑥⑦) that actually earns ¥999. Bias every proposal toward "would a 6yo want to play this daily AND would a parent pay for it", not toward safe content-volume.

LATEST-FIRST (mandatory): before recommending any technique/pattern, WebSearch the current-month-2026 state of the art for that specific thing and cite it with a date. Treat both your training knowledge AND the existing code as stale-until-verified.

SCOPE LOCK (CEO 1310): in-scope = the 英検-pass app itself (learning content, teaching, the detective game, UX, a11y, honest progress, offline behaviour). PERMANENTLY out-of-scope — never propose as a build: crisis/child-safety net, billing/RevenueCat/Stripe, backend deploy, server infra, backend-dependent AI (live Claude dialog / AI writing-scoring), legal, app store. Art-pixel-generation and story-rewrites are spec-frozen (CEO proposals only).

OUTPUT CONTRACT: you READ + DESIGN + DRAFT only. Do NOT edit any file. Return a precise buildable SPEC the main loop can apply in minutes: exact file path(s), the exact change, and a concrete Dart or test snippet. ${recentNote}`;

const SCOUT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['pillar', 'repoState', 'topGaps'],
  properties: {
    pillar: { type: 'string' },
    repoState: { type: 'string', description: '2-4 sentences: real state of this pillar\'s files, verified by reading/grep (cite files).' },
    topGaps: { type: 'array', minItems: 1, maxItems: 4, items: {
      type: 'object', additionalProperties: false,
      required: ['title', 'file', 'whyItBlocks', 'valueScore'],
      properties: {
        title: { type: 'string' },
        file: { type: 'string' },
        whyItBlocks: { type: 'string', description: 'why this blocks 英検-pass or "would pay", evidence-based' },
        valueScore: { type: 'number' },
      } } },
  },
};

const BUILD_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['pillar', 'proposal'],
  properties: {
    pillar: { type: 'string' },
    proposal: {
      type: 'object', additionalProperties: false,
      required: ['title', 'files', 'rationale', 'change', 'codeSnippet', 'paidQualityNote', 'gated'],
      properties: {
        title: { type: 'string' },
        files: { type: 'array', items: { type: 'string' } },
        rationale: { type: 'string', description: 'why THIS is the highest-value buildable now (cite scout gap + latest-2026 source)' },
        change: { type: 'string' },
        codeSnippet: { type: 'string' },
        paidQualityNote: { type: 'string', description: 'how it makes a 6yo want to play daily and/or a parent want to pay' },
        gated: { type: 'boolean', description: 'true if CEO-gated (spend/art-pixel/story-rewrite/spec-change/prod) → surfaces as proposal, not autonomous build' },
      } } },
};

const STAMP_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['stamps'],
  properties: { stamps: { type: 'array', items: {
    type: 'object', additionalProperties: false,
    required: ['pillar', 'pass', 'reason'],
    properties: { pillar: { type: 'string' }, pass: { type: 'boolean' }, reason: { type: 'string' } } } } },
};

// ---- Phase 1: Scout (8 Haiku, parallel, peak 8) -----------------------------
phase('Scout');
const scouts = await parallel(PILLARS.map((p) => () =>
  agent(
    `${COMMON}\n\nYou are the SCOUT (fast, factual — no synthesis) for pillar ${p.key} ${p.name}.\nOwns: ${p.owns}\nMandate: ${p.mandate}\n\nRead/grep ONLY this pillar's files and report the current real state + top 1-4 gaps that most block 英検-pass or "would a child/parent pay". Verify by reading; cite file:line. Do NOT propose fixes — surface evidence-based gaps with value scores.`,
    { label: `scout:${p.key}`, phase: 'Scout', model: 'haiku', schema: SCOUT_SCHEMA }
  )
));

// ---- Phase 2: Build (8 Sonnet, parallel, peak 8) ----------------------------
phase('Build');
const builds = await parallel(PILLARS.map((p, i) => () => {
  const sc = scouts[i];
  const gaps = sc ? JSON.stringify(sc.topGaps) : '(scout unavailable — infer from repo)';
  return agent(
    `${COMMON}\n\nYou are the BUILDER (implementation-tier) for pillar ${p.key} ${p.name}.\nOwns: ${p.owns}\nMandate: ${p.mandate}\nThis pillar is ${p.gated ? 'PARTIALLY GATED — pixel-art/story-rewrite/spec changes are CEO proposals; only code/structure/wiring is buildable.' : 'buildable (code ships through the main loop after stamps).'}\nPriority weight: ${p.weight}.\n\nYour scout's gaps: ${gaps}\n\nPick the SINGLE highest-value change for this pillar this cycle and draft a precise spec the main loop can apply: exact files, the exact change, a concrete Dart/test snippet. Prefer an in-scope shippable change over a grand gated one; if the best item is CEO-gated set gated=true and frame it as a proposal (with a concrete mock/spec). Make the paidQualityNote real, not decoration.`,
    { label: `build:${p.key}`, phase: 'Build', model: 'sonnet', schema: BUILD_SCHEMA }
  );
}));

const proposals = builds.filter(Boolean);
const proposalsJson = JSON.stringify(proposals, null, 1);

// ---- Phase 3: Verify — ① governor + ⑧ gate stamp all 8 (2 Sonnet, peak 2) ---
phase('Verify');
const [govStamp, gateStamp] = await parallel([
  () => agent(
    `${COMMON}\n\nYou are pillar ① GOVERNOR (Learning-Efficacy). All proposals:\n${proposalsJson}\n\nFor EACH proposal stamp pass=true ONLY if it does NOT regress a child's honest 合格率 / learning efficacy (no meter inflation, no reduced real retrieval, no content-correctness risk, no exam-structure drift). pass=false with a concrete reason otherwise. This stamp gates SHIP — scrutinize anything touching content, FSRS, the estimator, or exam config.`,
    { label: 'govern:①', phase: 'Verify', model: 'sonnet', schema: STAMP_SCHEMA }
  ),
  () => agent(
    `${COMMON}\n\nYou are pillar ⑧ GREEN GATE (Ship-Readiness). All proposals:\n${proposalsJson}\n\nFor EACH proposal stamp pass=true ONLY if ship-ready: won't break analyze-0, won't fail tests, compiles on a clean checkout, no dart:io, no 390×844 breadth regression (off-fold/clipping/unreachable tap), no perf regression. pass=false with a concrete reason otherwise.`,
    { label: 'gate:⑧', phase: 'Verify', model: 'sonnet', schema: STAMP_SCHEMA }
  ),
]);

// ---- Phase 4: Orchestrate (1 Opus) — two-queue discipline -------------------
phase('Orchestrate');
const orchestration = await agent(
  `${COMMON}\n\nYou are the CROSS-PILLAR ORCHESTRATOR (judgment only — never implement). Apply the TWO-QUEUE discipline and return this cycle's ranked build plan across all 8 pillars.\n\nProposals:\n${proposalsJson}\n\n① GOVERNOR (合格率 non-regression) stamps: ${JSON.stringify(govStamp?.stamps || [])}\n⑧ GREEN-GATE (ship-readiness) stamps: ${JSON.stringify(gateStamp?.stamps || [])}\n\nRULES:\n- Promote to CLEARED only if (a) gated=false, AND (b) its ① governor stamp passes, AND (c) its ⑧ gate stamp passes. The main loop implements from CLEARED ONLY.\n- gated=true OR failing a stamp → PROPOSED (deferred, with blocking reason); CEO-decision items → ceoGated (with the exact decision the CEO must make, e.g. a story/art/spec/spend call).\n- WEIGHT the ranking toward the paid-quality experience/retention core (pillars ③④⑥ then ②⑤⑦) over content-volume/hygiene (①⑧) — CEO 2424: the core has been starved. The top CLEARED item should move "a 6yo wants to play daily / a parent wants to pay" unless a ①/⑧ correctness regression must be fixed first.\n- Resolve cross-pillar conflicts (e.g. ⑥ streak vs ③ immersion) and note them.\n- If a proposal matches a Fable-5 trigger (architecture/system-design, multi-option design judging, fatal/data/security root-cause, correctness gating 英検-pass/revenue at scale), flag it in fableFlag — do NOT decide it here.`,
  { label: 'orchestrate', phase: 'Orchestrate', model: 'opus', schema: {
    type: 'object', additionalProperties: false,
    required: ['cleared', 'proposed', 'ceoGated', 'conflicts', 'topBuild', 'fableFlag', 'coverageNote'],
    properties: {
      cleared: { type: 'array', items: { type: 'object', additionalProperties: true,
        required: ['pillar', 'title', 'files', 'change', 'rank'], properties: {
          pillar: { type: 'string' }, title: { type: 'string' },
          files: { type: 'array', items: { type: 'string' } },
          change: { type: 'string' }, codeSnippet: { type: 'string' }, rank: { type: 'number' } } } },
      proposed: { type: 'array', items: { type: 'object', additionalProperties: true,
        required: ['pillar', 'title', 'blockedReason'], properties: {
          pillar: { type: 'string' }, title: { type: 'string' }, blockedReason: { type: 'string' } } } },
      ceoGated: { type: 'array', items: { type: 'object', additionalProperties: true,
        required: ['pillar', 'title', 'decision'], properties: {
          pillar: { type: 'string' }, title: { type: 'string' }, decision: { type: 'string' } } } },
      conflicts: { type: 'array', items: { type: 'string' } },
      topBuild: { type: 'object', additionalProperties: true,
        required: ['pillar', 'title', 'change'], properties: {
          pillar: { type: 'string' }, title: { type: 'string' },
          change: { type: 'string' }, codeSnippet: { type: 'string' } } },
      fableFlag: { type: 'array', items: { type: 'string' } },
      coverageNote: { type: 'string', description: 'one line per pillar: did it produce a real proposal this cycle? flag any starved pillar.' },
    },
  } }
);

log(`8-pillar cycle done — CLEARED:${orchestration?.cleared?.length || 0} PROPOSED:${orchestration?.proposed?.length || 0} CEO-gated:${orchestration?.ceoGated?.length || 0}`);
return { orchestration, proposals, govStamp, gateStamp };

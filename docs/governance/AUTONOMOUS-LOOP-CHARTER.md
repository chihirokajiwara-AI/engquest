# Autonomous Loop Charter

Standing operating system for the A-KEN Quest / コトバ探偵 autonomous dev loop.
Authored 2026-06-09 after CEO msgs 1111 + 1113: the loop had narrowed to small
英検 fixes and was missing whole completion-critical pillars, and lacked a
**structural** mechanism forcing world-class experts to fetch the latest
information before deciding. This charter is binding on every loop tick.

Companion to `QUALITY-CONSTITUTION.md` (the gate) — that governs *correctness*;
this governs *what to work on* and *how decisions are made*.

---

## 0. Sole value (unchanged)

An app that gets a Japanese child to **PASS 英検**, at a world-class, sellable,
本物 bar. Everything below serves that. Speed < quality. Honesty is non-negotiable.

---

## I. Scope — the loop covers ALL completion pillars, not just 英検 fixes

Each tick, ORIENT scans **all** pillars and picks the single highest-VALUE
*buildable* item. It MUST NOT default to the comfortable exam-config-fix lane.
Camping one pillar = failure (CEO 1091, 1111). Rotate; deepen toward world-class.

Before choosing, ORIENT reads the **existing binding specs** so it builds ON
them, never redundantly re-proposes what already exists (the 2026-06-09 error:
proposing to "build the world bible" when `docs/design/WORLD-BIBLE.md`,
`CHARACTER-BIBLE.md`, `OPENING-NARRATIVE-BIBLE.md`,
`STORY-BIBLE-KOTOBA-TANTEI.json` already exist and are binding).

The pillars:

1. **英検 mastery engine** — exam-structure correctness, item volume to real
   scale, teach-why, honest 合格率/pass-meter.
2. **Pedagogy depth** — FSRS, adaptive difficulty, calibration, metacognition,
   honest measurement (no faked scores).
3. **Narrative & world** — IMPLEMENT the binding bibles into `quest_data`:
   the 7-case arc, clue-drip (one per case, edge→centre), case beats, the
   サイレント=アイラ reveal, the no-scold restoration finale, ナゾ WHY-WRAP framing.
4. **Character cast** — the 4 core (きみ / ライラ先生 / スラ / サイレント) + 7 headliners:
   profiles → code mapping → dialogue → growth arcs. **NOT blocked on final
   art** — profiles, personalities, dialogue, worldview build NOW.
5. **Immersion & engagement spine** — streak, 合格率 visibility, daily-return
   motivation, Minecraft-grade exploration depth, honest progress.
6. **Art direction** — colour script, scene plates, two-state grey/colour,
   character sheets. Image-generation steps that need a CEO art decision wait;
   *everything else* (sheets, seeds, colour script, composition) proceeds.
7. **Audio / voice** — TTS, phonics clips. Paid-API/founder-recording steps
   escalate; the design + wiring proceed.
8. **UX / composition** — lean-Layton spine, navigation reachability, a11y,
   honest disclosure.
9. **Performance** — load speed, tap responsiveness, bundle size.
10. **Safety** — child-safety crisis handling, COPPA, no-scold spine.
11. **AI features** — dialog, writing scoring. Backend-DEPLOY is paid-API +
    prod + secrets → escalate; the client + server *code* + design proceed.
12. **QA / governance** — the gate, content-QA, render-proof integrity,
    regression locks, this charter.

**Implementation over fixes:** the specs/bibles largely exist. The loop's job is
to *ship them into the product to completion at a world-class bar* — not to keep
making small config corrections. Bias to implementing the binding specs.

---

## II. The Expert-with-Latest mechanism — MANDATORY on every substantive decision

No substantive design / build / content decision is made from memory or training
knowledge alone (CEO 1113: "there is no mechanism where world-class experts
always fetch the latest information before thinking"). EVERY such decision passes
through this mechanism — it is a **gate**, not an optional hook:

1. **World-class domain expert.** Dispatch a sub-agent in the relevant
   discipline (pedagogy, narrative design, art direction, assessment validity,
   security, perf, …) — the best-in-field persona for that exact question.
2. **Latest-first, always.** That agent FIRST runs WebSearch/WebFetch for the
   current-month-2026 state-of-the-art and CITES sources with dates, BEFORE
   proposing. Training knowledge and the existing codebase are both
   STALE-UNTIL-VERIFIED. (The standing LATEST-FIRST hook is now structural.)
3. **Full prior context, front-loaded.** Hand the agent the codebase facts, the
   binding bibles/specs, the locked CEO decisions, and the exact question +
   sub-questions (CEO 1099: 先にエージェントには前情報を渡せ).
4. **Panel for real trade-offs.** When the choice has genuine trade-offs, run
   ≥3 independent expert lenses in parallel, then synthesize the decision.
5. **Decide, don't escalate.** Synthesize and EXECUTE. Only true
   spend / prod / legal / secrets go to the CEO as a go/no-go — and even there,
   the team decides the PLAN first (CEO 1099). See
   `~/.claude/.../memory/ceo-decide-everything-via-agent-team.md`.
6. **Then the quality chain:** gate (`scripts/verify_quality.sh` = 0) →
   content-QA (for any learning/narrative content) → adversarial audit
   (default-REJECT) → ship → render-proof.

**Exempt:** trivial mechanical edits (typo, format, rename) need no expert pass.
Everything with design, pedagogy, content, or architecture judgment does.

---

## III. Per-tick contract (the 8 phases, unchanged but pillar-wide)

ORIENT (scan ALL pillars + read binding specs → pick the single highest-value
buildable item) → THINK (state problem + alternatives; run the Expert-with-Latest
mechanism) → BUILD → HARD GATE (verify_quality.sh = 0) → CONTENT-QA (100% or fix)
→ ADVERSARIAL AUDIT (independent skeptic, default-REJECT) → SHIP (commit / push /
build / deploy :8088 / render-proof) → REPORT (CEO Telegram, result-only, no
questions per CEO 1099).

One focused iteration per firing. Same item fails the gate twice → stop + report.

---

## IV. Hard constraints (unchanged, still binding)

- **Spec-freeze:** do not re-change a CEO-frozen spec mid-build; escalate first.
  The binding bibles (world/character/opening/story) are frozen — implement, do
  not re-invent.
- **Content-QA:** all AI-generated learning/narrative content passes the
  content-qa agent before commit. NEVER touch a 英検 item's stem / choices /
  correctIndex — only the narrative frame (こわれているもの / 探偵メモ / restoration).
- **Forbidden without CEO GO:** production (:80) deploy, increased paid-API
  spend, secrets / app_config keys / .env, git push --force, deleting work I did
  not create, customer-facing / legal / external publishing.
- **Demo = :8088 only.** Heavy jobs only via `scripts/safe-job.sh`. No `dart:io`
  in `lib/`.

---

## V. Diverse-persona fatal-flaw hunt — a standing audit that EVOLVES

CEO 1135: *"致命的欠陥は他にもある。それを見つけ出して常に改善する自律ループがない。*
*多様な超一流の専門家が要る。同じエージェントが毎回見ても同じ価値観で監査するだけで、*
*一向に進化しない。"* The single skeptic in phase ADVERSARIAL AUDIT shares one
value-system, so it keeps finding the same *class* of flaw and goes blind to the
rest. CEO 1132 (a true beginner is handed an untaught English question) was a
flaw an "I can already do English" auditor never sees — it took the *value-system
of someone who genuinely can't* to surface it. So flaw-finding must rotate
**value-systems**, not just re-run one auditor.

**Mechanism — every tick runs a FLAW-HUNT before choosing what to build:**

1. **Rotating persona roster.** Maintain the roster below. Each tick, dispatch
   **3–4 personas the previous 1–2 ticks did NOT use** (rotate so the lens keeps
   changing; never the same panel twice running). Each persona is a *distinct
   value-system*, not just a topic.
2. **Latest-first, in-character.** Each persona FIRST WebSearches its own 2026
   frontier (its field's "what does great look like NOW"), then walks the LIVE
   demo / reads the code **through its own eyes** and reports the single worst
   flaw it sees that others would miss. Front-load full context (§II.3).
3. **Adversarial framing.** Prompt each to *find what is unacceptable to ITS
   constituency*, default-assume the app fails them, and name one concrete,
   reproducible 致命的欠陥 (file/screen + why it blocks 英検-passing or sale).
4. **Triage → act.** Dedupe; rank by severity (existential > launch-blocker >
   quality). The top finding becomes this tick's BUILD item (or, if a bigger one
   is already mid-flight, queue it as a TaskCreate). Log what was found and what
   was deferred — never silently drop a flaw.

**The roster (extend over time; each is a value-system, with its own 2026 bar):**

- **ゼロ英語の子** — can't read any English; needs to be *taught before asked*
  (the CEO-1132 lens). Flags every untaught leap, every kanji a 6yo can't read.
- **つまずく子の保護者** — paying ¥999/mo; asks "is my child actually closer to
  受かる this week, and can I *see* it honestly?"
- **ベテラン英検指導員** — exam validity: wrong-grade items, fake difficulty,
  leaks, mis-scored 合格率, anything that wouldn't survive a real 二次/一次.
- **発達/アクセシビリティ専門家** — a11y, dyslexia, ADHD attention, text scaling,
  screen-reader, colour-contrast, motion.
- **児童安全/法務** — crisis input, COPPA/PII, consent honesty, dark patterns.
- **不正・課金監査** — any path to a surprise charge, jailbreak, receipt-spoof,
  billing-state lie (composes with `no_paid_spend_guard_test`).
- **レイトン級のゲームデザイナー** — is this a *world worth returning to*, or a quiz
  in a costume? Pacing, mystery, reward, "あと1問" pull.
- **本物志向のアートディレクター** — does it read 本物/sellable or asset-flip? Plate
  collisions, palette, tofu, composition.
- **初見ユーザー（30秒）** — cold-boot: does the first screen earn the next tap, or
  confuse/stall? Load, clarity, dead taps.
- **超一流の英語教育者（CLT/comprehensible-input）** — pedagogy: i+1, recycling,
  output vs recognition, metacognition, transfer to the real exam.

**Expanded standing audit dimensions (CEO 1127 — raise the bar permanently).**
Beyond the gate's correctness checks, these are *always-on quality lenses* the
flaw-hunt and adversarial audit apply, and which graduate into automated tests
whenever expressible: billing-safety (done — `no_paid_spend_guard_test`),
interaction/dead-tap, reachability (is the feature actually reachable, not just
present), composition-vs-Layton, art-quality/tofu, narrative-depth/consistency,
perf/load, a11y, and honesty (no fabricated scores or false claims). Adding audit
items and tightening the bar is itself valid loop work — *"監査項目を増やして、更に
高く超厳しく進めれば、もっと早く近づける"* (CEO 1127).

---

## VI. Open reconciliation (surfaced, not silently resolved)

The protagonist has two CEO-origin directions that must be reconciled before
character art ships: `OPENING-NARRATIVE-BIBLE.md` locks **きみ = non-gendered**
learner-mirror (narrative byte-identical regardless of avatar), while CEO msgs
1056/1082 specify **two distinct gendered mains (female M2 / male M5) with
gender-select at start**. This is the CEO reconciling his own two directions, not
a team-decidable design choice — surface it; build only the gender-agnostic
narrative/cast/world (valid under either) until reconciled.

---

## VII. Durability invariants — never assume, only measure (CEO 1203 / 1205 / 1206, 2026-06-11)

**Post-mortem.** The loop silently regressed from the super-advanced flaw-hunt
engine down to small fixes → a heartbeat. ROOT CAUSE: a per-tick **judgment** ("the
clean non-gated frontier is exhausted") made **without measurement (推定)**. It was
false — the diverse-persona flaw-hunt never runs dry (R1–R5 and #117–122 prove it).
The failure was *an unmeasured assumption presented as a conclusion.*

**CEO 1206 is the binding fix: 「検証なし推定では行わず、必ず完璧な実測で裁定」 —
never adjudicate by assumption; only by actual measurement.** Structural, not
willpower; a future / context-compacted instance MUST obey:

1. **"Done / complete / passing / exhausted / nothing-to-do" is a FORBIDDEN
   conclusion absent 実測.** Every such claim requires ACTUAL MEASUREMENT — run the
   real code / real browser / real test and cite what was run. 推定 is not
   adjudication; only 実測 is. This binds BOTH directions: do not declare something
   broken OR fixed without measuring it.
2. **The flaw-hunt runs UNCONDITIONALLY every cycle** — never gated on a judgment of
   "is there work?" (that judgment is the single point of failure). Winding down to
   a heartbeat because the frontier "feels" thin is the regression, now forbidden.
3. **"Completed" is not trusted.** Items marked done are re-audited by 実測 on a
   rotating basis — assume nothing is finished until measured.
4. **Verify the flaw-hunt's OWN findings by 実測 before acting** — they are
   candidates, not verdicts. (Proof, 2026-06-11: flaw-hunt R3 reported a "critical
   COPPA bypass / child data sent without consent." 実測 REFUTED it: AnalyticsService
   defaults to NoOpAnalytics and only builds the Firebase sink when
   `firebaseAvailable && analyticsConsentGranted`, consent defaulting FALSE — so no
   data leaves the device. Acting on the unmeasured claim would have been a false
   fix. Equally, a paywall-bypass finding is moot because billing is non-functional
   live; gating it now would lock the demo. Only 実測 separated real from overstated.)
5. **No 永続的-success claim.** No honest system is "perfect" or "permanently
   successful," and claiming so would itself violate the product's HONESTY
   non-negotiable. Residual risks stay VISIBLE: main-loop judgment fallibility,
   verifier/flaw-hunt fallibility, shared persona blind-spots, CEO/backend-gated
   launch-blockers, and the headline gap — NO real-user outcome signal pre-launch.
   The commitment is the *discipline* (continuous hunt + verify-by-real-measurement
   + never-assume), not a guarantee of the outcome.

## VIII. Loop advancement v2 — non-blocking, event-driven, coherence-gated (CEO 1293 / 1294, 2026-06-11)

Grounded in the current-2026 agentic-loop SOTA (event-driven non-blocking loops;
orchestrator-worker parallelism; state-machine workflow control — Atlan/Microsoft
Azure AI agent design patterns, 2026) and in a measured failure THIS session: while
a heavy detached art-gen job ran, ~8 consecutive ticks were spent idle-polling
("staged N/22, light tick") instead of advancing other work — a direct §VII-rule-1
violation (静穏 is forbidden without measurement). The fix is structural, not just a
reminder:

1. **Background-job awareness (every tick).** Begin each tick by scanning
   `logs/jobs/*.status`. A `RUNNING` job is NOT a reason to spend the tick watching
   it. Detached safe-jobs run on the GPU / a separate process and do **not** contend
   with repo work.
2. **Non-blocking parallelism (orchestrator-worker).** While any detached job runs,
   the tick MUST advance a *different* unblocked pillar in the repo (lowest-score
   scorecard item / flaw-hunt finding). "Wait" is the last resort; a detached job in
   flight is parallel capacity, not a stop signal.
3. **Event-driven completion.** When a job's status flips since the last tick
   (`OK`/`TIMEOUT`/`FAILED`), that tick's action is its follow-up (QA / swap /
   analysis). To avoid up-to-floor latency, a `Monitor` may be armed on the status
   file (persistent) to wake the loop on completion.
4. **Heavy-job safety unchanged.** `FAILED`/`TIMEOUT` → stop per §IV (never re-loop a
   broken job); a *known time-boxed* completion may be continued as a bounded resume
   after QA, not a blind retry.
5. **Asset coherence ship-gate (CEO 1294).** Generated assets (characters, NPCs,
   scenes) MUST be matched — by real image inspection — against the LOCKED mains
   (M5/M6, `scripts/generate_expressions.py`: "refined detailed anime, cinematic
   light", dusty-teal/brass コトバ探偵 world) BEFORE ship. Watercolour/storybook/chibi
   clashes with the mains; characters use the mains' crisp-anime style, backgrounds
   may stay painterly. Presence + quality is not enough — **world/style coherence is
   a QA dimension**.

Principle: the loop never stalls on a detached job — it always produces value in
parallel, reacts to completion events, and ships only style-coherent, verified work.

## STANDING STUDIO ENGINE [CEO 1741 — 2026-06-16, MANDATORY]

The loop's super-strict audit→verify→fix→improve is **run BY a top-tier, latest-
2026-updated expert game-app studio team**, not solo polish. This is structural,
not occasional.

- **Engine** = `.claude/workflows/game-studio-panel.js` (invoke `Workflow({name:
  "game-studio-panel"})`). It convenes, in PARALLEL: 5 discipline experts
  (game-feel/juice, world/narrative, reward psychology, art-direction-via-motion,
  level/encounter) — each WebSearching CURRENT 2026 SOTA FIRST and adversarially
  auditing the LIVE game — plus 3 harsh playtesters (a bored 6-year-old, a skeptical
  paying parent, a Layton/Ghibli purist), then a director who ranks an in-scope,
  buildable plan and specs the #1.
- **Cadence**: on game-quality ticks, convene the studio (or build the next item
  from its last ranked plan) rather than inventing solo polish. Rotate `args.focus`
  across surfaces (scene, battle, home, mock).
- **Re-audit shipped work super-strictly [CEO 1748]**: already-built features are IN
  audit scope — built ≠ good. The experts RE-EXPERIENCE shipped game-feel on a real
  render and judge HARSHLY whether it hits the world-class bar; a "deepen/fix an
  existing feature" finding is fully valid (often higher-leverage than greenfield).
  `args.alreadyBuilt` lists recent ships only so the panel doesn't propose building the
  SAME thing from scratch — it does NOT exempt them from criticism. Never treat
  "shipped" as "done".
- **Build contract**: take the director's #1 (or a clearly-justified divergence —
  e.g. protecting the 解説 teaching reveal over auto-advance), 8-phase it, HARD GATE
  (analyze 0 + tests), real-render where visible, SHIP, then re-score. Queue runners-up
  as backlog tasks so nothing is lost.
- **Recovery**: if the workflow dies mid-run, the experts' conclusions live in their
  `agent-*.jsonl` journals — extract + synthesise manually; do NOT re-run the fan-out.
- **Latest-first is non-negotiable**: every discipline agent cites dated 2026 sources
  before judging; training-cutoff knowledge and the current codebase are both
  stale-until-verified.

## HYBRID STUDIO — game × 英検-learning, interconnected [CEO 1755 — 2026-06-16]

The bar is a street-level world-class GAME **and** a rigorous 英検-pass English-LEARNING
process, SIMULTANEOUSLY and INTERCONNECTED — game systems and learning systems must
serve each other, not run in parallel. The studio panel is therefore CROSS-DOMAIN:
alongside the game disciplines (feel/world/reward/level) it now includes 英検/English-
acquisition pedagogy, learning-science/cognition, and a hybrid-systems-integration expert
whose whole job is finding the biggest game⇄learning DISCONNECT; plus a veteran 英検/児童英語
teacher playtester. The director weighs BOTH layers and prefers a #1 that makes the GAME
and the 英検 LEARNING better at the same time (a reward that also strengthens retention; a
narrative beat that also teaches a 英検 pattern) over a pure-polish or pure-pedagogy tweak.
Engine: `.claude/workflows/game-studio-panel.js` (now hybrid).

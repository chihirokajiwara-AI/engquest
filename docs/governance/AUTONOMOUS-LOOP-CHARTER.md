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

## V. Open reconciliation (surfaced, not silently resolved)

The protagonist has two CEO-origin directions that must be reconciled before
character art ships: `OPENING-NARRATIVE-BIBLE.md` locks **きみ = non-gendered**
learner-mirror (narrative byte-identical regardless of avatar), while CEO msgs
1056/1082 specify **two distinct gendered mains (female M2 / male M5) with
gender-select at start**. This is the CEO reconciling his own two directions, not
a team-decidable design choice — surface it; build only the gender-agnostic
narrative/cast/world (valid under either) until reconciled.

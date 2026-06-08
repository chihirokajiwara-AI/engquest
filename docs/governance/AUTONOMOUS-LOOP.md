# Autonomous Loop — Quality-Enforced Contract

**Purpose.** Drive A-KEN Quest toward completion autonomously (cron wake-ups)
WITHOUT quality or depth decay. This is the contract every loop iteration MUST
follow. It exists because:

- The previous autonomous loop was **archived 2026-06-01** (T37) after it
  committed red tests and left the tree non-compiling. Root cause: **no hard
  gate**. This contract makes the gate non-skippable.
- The naive-loop failure mode is that the *builder* also *reviews*, so it
  rationalizes shallow/wrong work as good. This contract forces an **independent
  adversarial audit with veto power** — quality is structural, not willpower.

The CEO's sole value metric: **"an app that gets a kid to PASS 英検."** Every
iteration is judged against that, not "did something ship."

---

## One iteration = these phases, in order. None may be skipped.

### 1. ORIENT
Read: `CLAUDE.md` task queue, the live task list, `docs/design/OPUS-REVIEW-*`,
this file. Pick the **single highest-value buildable item** that is NOT in the
FORBIDDEN list (§8). Prefer **deepening existing work to world-class** over
adding shallow new surface ("subtract before adding"; "deepen, don't just add").

### 2. THINK (before building)
State the problem + constraints, ≥1 alternative, and why this approach a
world-class CTO/英検 expert would choose. If the item needs a CEO-frozen spec
change → STOP, escalate (§8). LATEST-FIRST: for any tech/spec/pedagogy decision,
verify against current dated sources before acting.

### 3. BUILD the increment (focused, single concern).

### 4. HARD GATE — non-negotiable (the T37 fix)
`scripts/verify_quality.sh` MUST exit 0:
- R1 content integrity · R2 asset contract · R3 render-proof · R5 leakage
- `flutter analyze` 0 issues · `flutter test` all green
Plus **clean-checkout safety**: no untracked file that committed code references.
If it fails → fix or revert. **NEVER commit red.**

### 5. CONTENT-QA GATE (any AI-generated learning content)
Spawn the `content-qa` rubric audit (`.claude/agents/content-qa.md`, run via a
general-purpose agent if the type isn't registered) over the NEW content. Verify:
single defensible answer, same-POS plausible distractors, correct level, no
language leakage, no position bias. **100% PASS or fix.** (This gate exists
because 7,923 corrupted distractors once shipped.)

### 6. ADVERSARIAL WORLD-CLASS AUDIT — the anti-shallowness teeth (R8, automated)
Spawn an **independent** auditor (Opus-tier) whose ONLY job is to **REFUTE**:
find the flaw, the shallowness, the 英検-spec violation, the thing a world-class
英検 expert / senior engineer would reject. **Default to REJECT if uncertain.**
- If it finds a real flaw → send back, do NOT ship. Fix, re-audit.
- Use **perspective-diverse** auditors for non-trivial work: (a) 英検-spec
  correctness, (b) pedagogical depth, (c) child-UX, (d) code/render. Majority
  refute → block.
- Every ~5 iterations, also run a **COMPLETENESS CRITIC**: "what's missing,
  shallow, or unverified across the product?" → its findings become backlog.
- Every ~5 iterations, also run a **UX / JOURNEY WALKTHROUGH** (added 2026-06-07
  after CEO 721: the loop caught content bugs but missed screen-structure defects
  — it found 4 core screens crashing to blank grey). An agent screenshots every
  `?preview=` route on the live demo + reads the backing code, hunting: blank/
  crashing screens, button label≠behavior, dead ends, confusing labels, too-hard/
  too-easy steps, missing expected pages, child-UX/immersion gaps → P0–P2 backlog.
  A single happy-path screenshot is NOT enough; walk the WHOLE journey.

### 7. SHIP (only if 4+5+6 all pass)
Commit (descriptive, prefix per CLAUDE.md) → push → build web → **demo-deploy
(:8088 ONLY)** → capture a render-proof screenshot.

### 8. REPORT to CEO (Telegram, every iteration)
What shipped + evidence (commit hash, gate result, screenshot) + **what the
adversarial audit found / blocked** + what's next. Be honest about anything
skipped, failed, or deferred. No overclaiming.

### 9. FORBIDDEN without explicit CEO approval (escalate, never auto-do)
- Production deploy (`:80` / rsync to prod path) — demo only.
- Spending money / paid-API calls (Azure key, etc.).
- Touching secrets / `app_config.dart` keys / `.env`.
- `git push --force`; deleting or overwriting work you didn't create.
- Changing a CEO-frozen spec (spec-freeze gate).
- Anything customer-facing / legal / external-publishing.

### 10. STOP CONDITIONS (暴走防止)
- Same item fails the gate **twice** → STOP, report, do NOT re-loop the failure.
- Heavy jobs (art/model/build) ALWAYS via `scripts/safe-job.sh` (detached +
  timeout); poll; stop on FAILED/TIMEOUT.
- Backlog empty → run the completeness critic to generate new high-value work;
  if still nothing → report idle + await CEO.

---

**Driver.** A durable cron fires this contract on a schedule. The loop owns
build→gate→audit→commit→demo-deploy→report. The CEO owns the FORBIDDEN set.
Stop the loop anytime via CronDelete (or ask me to stop it).

---

## Multi-pillar studio cadence (CEO 2026-06-08)

CEO msgs 859/861: the autonomous loop must stop being a **code-only, solo-decided**
builder and become a **continuous multi-disciplinary STUDIO**. The product is advanced
across **12 pillars** by **discipline teams** to a **world-class bar**, each protected by
the existing **adversarial audit** (§6). World, story, character, and art are now
**continuously advanced — not just code**. This section *adds to*, and does not replace,
the iteration contract above; every iteration still passes §4 (hard gate), §5 (content-QA),
§6 (adversarial audit), §7 (ship), §8 (report).

This cadence operates **under the lean-Layton architecture** (CEO msg 863) frozen in
`docs/design/COMPOSITION-ARCHITECTURE.md` + `WORLD-BIBLE.md` + `CHARACTER-BIBLE.md` +
`ART-DIRECTION.md`. Those four docs are spec-frozen: do not re-warp them toward the old
DQ-hybrid (map traversal / level grind / large roster) without CEO approval (§8 spec-freeze).

### A. The 12 pillars (ranked; pedagogy is TOP)
1. **Pedagogy / learning-efficacy [TOP]** — does it measurably move a kid toward 合格?
   intrinsic integration (Habgood test), corrective retrieval, FSRS stability, mastery (not
   performance) framing. The sole value test lives here.
2. **Content volume + correctness** — 英検-spec-accurate items/vocab at every grade; single
   defensible answer, diagnostic distractors, no leakage (the 7,923-corruption guard).
3. **World / story / character** — `WORLD-BIBLE.md` cases, seed lines, lore drip, daily-life
   texture; `CHARACTER-BIBLE.md` small-deep cast, スラ arc, サイレント backstory.
4. **Art direction** — `ART-DIRECTION.md` colour script, grey→colour, painted-UI cohesion,
   identity-gate consistency.
5. **Sound / music / SFX** — per-case theme, hero leitmotif, restoration chime, level/解決
   ceremony (`MUSIC-DESIGN.md`).
6. **Voice / pronunciation** — phoneme clips, TTS quality, ASR/speaking practice fidelity.
7. **Game-feel / juice** — scene transitions, solve feedback, parallax, Picarat decay feel.
8. **Performance** — web load (P0): eager-budget, deferred plates, Skwasm, audio weight.
9. **Retention** — 捜査日誌 streak (no guilt), きょうのナゾ FSRS framing, daily-return hook.
10. **Safety / a11y / legal** — COPPA, child-crisis routing, ふりがな, contrast, no-scold.
11. **AI / backend** — Claude proxy/key security, billing correctness, jailbreak resistance.
12. **QA coverage** — render-proof every `?preview=` route, clean-checkout, journey walks.

### B. How each iteration runs as a studio (layers onto §1–§9)
- **Pick the top pillar this iteration** (ORIENT, §1): default to the **highest-ranked
  pillar with the largest gap to world-class**, biased to pedagogy. Rotate so world/
  character/art/sound are advanced continuously, not starved by code-only work. Every ~5
  iterations the **completeness critic** (§6) scores all 12 pillars and names the laggard →
  it becomes the next pick.
- **Convene a discipline team** for that pillar (THINK/BUILD, §2–3): spawn pillar-matched
  subagents, **model-tiered** (per MEMORY "model routing by tier", CEO 2026-06-07):
  Haiku = status/grep/log; **Sonnet = code, infra, content, content-qa, art-pipeline**;
  **Opus = judgment/design/architecture only**. Main loop stays Opus. Cut tokens by tiering,
  never by downgrading the main model.
- **Set a world-class bar, in writing** for the increment: name the named creators/works it
  must stand next to (e.g. Layton puzzle-in-world, Toriyama silhouette, Sugiyama theme-per-
  context, Oga atmospheric depth, Habgood intrinsic integration — see
  `docs/design/*` + the studio research). "It works" is the floor; "best way to do this"
  is the bar.
- **Adversarial audit with veto** (§6): the independent auditor refutes against **that
  pillar's** world-class bar (e.g. art audits silhouette/colour-script/identity-gate;
  pedagogy audits Habgood/leakage/level). Default REJECT if uncertain. Majority refute →
  block. World/character/art changes are audited with the **same teeth** as code — a thin or
  incoherent world beat is a defect, exactly like a red test.

### C. Lean-Layton build priority (current top-of-backlog)
Until done, the loop should prefer these (they realise the frozen pivot):
1. Author a `SceneDef` chapter set for **every grade** so the painted scene — never the
   level-select map — is the spine (`COMPOSITION-ARCHITECTURE.md §6`). Closes the
   `KotobaHomeScreen._goToScene` map-fallback (the warp leaking through).
2. **Repurpose `QuestMapScreen`** from a traversal/level-grind spine into a passive,
   read-only **事件簿 index / progress painting** (secondary CTA only).
3. **Whole-plate grey→colour tween** on chapter clear (`ART-DIRECTION.md §1.2`).
4. 7-node **colour script** + per-case lighting table in `STYLE_BIBLE.md`.
5. Visual designs + grey/color pairs + `CHARACTER_SHEET.md` lock for the 4 core characters
   (きみ, ライラ先生, スラ, サイレント), which currently have none.
6. Per-case **lore drip** (towns 2–6, currently empty) + スラ seven-beat arc + per-case
   narrative seed line — pure copy, gated by `content-qa`.

### D. Anti-regression
- Do NOT reintroduce: character map-movement, level grinding, a large NPC roster, or the
  prince/heir/throne thread. These are the removed warp (`COMPOSITION-ARCHITECTURE.md §7–8`).
- Spec-freeze: the four lean-Layton docs change only via CEO approval (§8).

### E. Living-foundation refresh (CEO msg 869, 2026-06-08)
The design bibles in `docs/design/*.md` are a **living foundation, not a frozen one-time
artifact**. Continuous *building* (§A–B) and the every-5-iteration completeness critic (§6)
are not enough — the **research itself must be periodically re-run** so the foundation does
not go stale as the craft (Layton/DQ/learning-science/Flutter-web) and the 英検 spec evolve.

- **Mechanism:** the committed, reusable `foundation-refresh` workflow
  (`.claude/workflows/foundation-refresh.js`). It sends a discipline team to **re-research
  the latest (dated, LATEST-FIRST) craft**, **score each bible for staleness/gaps**, and
  emit a **concrete, per-doc, dated proposal**. It is **non-destructive**: the lean-Layton
  docs are spec-frozen (§D), so it **PROPOSES diffs for CEO approval** — it never auto-edits.
- **Cadence:** run it **~every 10 iterations**, on a **major external change** (英検 reform,
  Flutter/renderer shift, new platform capability), or on **CEO signal**. Invoke by name:
  `Workflow({ name: "foundation-refresh" })`.
- **Output handling:** present the proposal to the CEO; on approval, apply the diffs in a
  normal gated iteration, and append a dated entry (sources + headline findings) to
  `docs/design/RESEARCH-LOG.md` so the foundation's evolution is auditable.
- **Honesty rule:** propose nothing rather than churn — if a bible is already world-class and
  current, the refresh says so. Staleness is reported with a 0–10 score per doc.

### F. Commercial / growth pillars (CEO msg 872, 2026-06-08)
Pillars 1–12 (§A) make the app **world-class**; they do not by themselves make it **売れる
(sellable)**. A great app that no parent discovers, trusts, or pays for fails the business.
These commercial pillars are now **first-class loop concerns**, advanced and audited like the
rest. (Several touch the FORBIDDEN set — paid APIs, billing, legal, customer-facing copy,
store publishing — so those are DESIGNED/queued in the loop but **executed only on CEO
approval**, not auto-shipped.)

13. **Monetization & billing correctness** — subscription (¥999, decided), Stripe + store
    IAP (App Store / Google Play) with **server-side receipt validation**; no in-memory
    billing (see "launch-blockers" memory). [Ties #7, #30, #55.] *gated: paid/legal*
14. **Activation & conversion funnel** — first-session "aha" (a kid solves a real 英検 item
    and feels it), free→paid trial design, parent paywall timing, conversion measurement.
15. **Parent value & ROI proof** — the parent dashboard must *prove* progress toward 合格
    (CSE trajectory, mock pass-rate, time-on-task) so the ¥999 is obviously worth it; this
    is the purchase justification, not a nicety.
16. **Efficacy evidence & social proof** — measured score gains, 合格 stories, ratings/review
    prompts at the right moment. A paid 英検 app lives or dies on "does it actually work."
17. **Growth / discoverability** — ASO (store listing, keywords, screenshots, preview),
    referral/word-of-mouth, SEO for the web build. *store publishing gated*
18. **Analytics & experimentation** — activation/retention-cohort/churn/conversion metrics
    + an A/B framework (partially exists) to optimize the funnel on evidence, not guesses.
19. **Trust, support & compliance** — privacy/COPPA, 特定商取引法 + 返金 policy + 利用規約
    (#55), crisis-safety routing, a feedback/support channel. *legal gated*

**How they run:** same studio cadence (§B) — a commercial pillar can be the iteration's top
pick (esp. once the product bar is high enough to monetize), convene a discipline team
(growth/edu-marketing/biz/legal lenses), set a world-class bar (e.g. Duolingo-grade
onboarding funnel, mikan-grade efficacy proof), adversarial-audit it. **The completeness
critic (§6) now scores ALL 19 pillars.** The biggest current commercial gaps are tracked as
backlog tasks; pedagogy + content (1–2) still outrank them — a sellable app that doesn't
teach 英検 is worthless.

### G. Per-discipline standing studio loops (CEO msg 874, 2026-06-08)
A discipline is not "done" after one pass — each needs a **standing, expert-staffed loop that
keeps DESIGNING DEEPER and FURTHER AHEAD**, not a one-off mechanic. The §B rotation picks the
top pillar each iteration; this section makes the deep work **reusable** as named workflows so
a discipline can be pushed to world-class repeatedly. Each is **non-destructive** (proposes;
CEO approves spec-frozen changes) and **model-tiered** (Sonnet lenses, Opus director).

- **`character-studio`** (`.claude/workflows/character-studio.js`) — CEO 874: a world-class
  **character designer + art director + producer/director + narrative writer + pedagogy**
  team deeply develops the cast (silhouette/colour language, expression range, backstory,
  arc, voice, 英検-skill embodiment, vocab-task scaling), thinking across the whole 7-case
  journey — not just one mechanic (per-character restoration is ONE example, not the design).
  Proposes `CHARACTER-BIBLE.md` diffs + a per-character production asset list.
  `Workflow({ name: "character-studio", args: "<character or grade, optional>" })`.
- **`foundation-refresh`** (§E) — the cross-cutting re-research loop.
- **Template for the rest:** the same pattern extends to `world-studio`, `art-studio`,
  `sound-studio`, `pedagogy-studio`, etc. — author one when that discipline becomes the top
  pillar and needs deep, recurring, expert-driven development. Each: ~5 discipline lenses →
  Opus director → CEO-gated bible proposal + production list. Reuse `character-studio.js` as
  the structural template.

Rule: do not mistake a single mechanic for the design. When a discipline is the iteration
focus, run (or author) its studio loop and push to the world-class bar, then adversarial-audit
(§6) against named masters.

### H. Commercial Quality Audit — standing mechanism (CEO msg 913, 2026-06-08)
CEO: per-change audits do NOT ratchet the *whole product* to a sellable, world-class bar —
"there is no mechanism to raise image/page quality to a level fit for general sale." This is
that mechanism. **Run it every ~5 iterations** (alongside the §6 completeness critic) and burn
its findings into the backlog. First run: `docs/design/COMMERCIAL-QUALITY-AUDIT-2026-06-08.md`.

Procedure:
1. **Capture, don't imagine.** Screenshot the real live screens from the deployed demo via
   `?preview=<route>` at phone size (390×844): at minimum title, onboarding, prologue, home
   (kotobahome), a painted scene (explore), questmap, exam, passmeter. CanvasKit → wait on the
   `flutter-first-frame` event.
2. **Default-REJECT panel.** Spawn a perspective-diverse panel whose ONLY job is to refute
   sellability: art-direction, product/UX commercial-readiness, subtract-skeptic (CEO 914 —
   cut game-y features that don't serve 英検 passing), 英検-pedagogy. Opus for the judgment
   lenses, Sonnet for pedagogy. Each reads the screenshots + a commercial rubric grounded in
   **current dated sources** (LATEST-FIRST), and returns severity-ranked, file-actionable
   defects. Bar = "world-class, commercially-sellable 2026 product a Japanese parent pays
   ¥999/mo for, whose SOLE value is the child PASSING 英検."
3. **Adversarially verify every factual claim BEFORE acting.** A convergent-looking panel can
   be confidently WRONG (2026-06-08 run: a critic's #1 "blocker" — "5級 has no 語句整序" — was
   FALSE per eiken.or.jp; acting on it would have removed a real section). Visual/UX
   observations are reliable; 英検-spec claims must be checked against eiken.or.jp + the
   codebase's own guards.
4. **Output = state, not a memo.** Write `docs/design/COMMERCIAL-QUALITY-AUDIT-<date>.md`
   (findings + verification outcomes) and create ranked backlog tasks. Ship the safe verified
   quick-wins; **escalate big spec changes** (e.g. demoting the RPG front-door) to the CEO with
   the screenshot evidence — do not unilaterally rip out CEO-approved specs.

CEO 914 lens (subtract-before-add): the core value is 英検 PASSING. Treat game-y decoration on
the critical path as a defect to SUBTRACT, never a feature to add. The pass-meter + grade-
targeted practice are the product; the world is, at most, an optional reward.

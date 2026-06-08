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

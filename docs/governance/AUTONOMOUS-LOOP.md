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

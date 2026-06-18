# MODEL ROUTING — binding, enforced (CEO 2056, 2026-06-18)

**Problem this fixes:** token consumption was climbing because the per-role model
rule existed in CLAUDE.md but was **not executed** — delegated subagents were
spawned with no `model:` tier, so they silently inherited the launch model
(Opus 4.8) even for research / grep / status work. The default session model
stays Opus 4.8 (CEO: unchanged). What changes is that *delegated* work must be
**deliberately tiered every time**.

## The tiers (pick one per delegated task)
| Tier | Use for | Cost |
|------|---------|------|
| **haiku**  | status, grep, log-reading, typecheck, file-navigation, screenshot capture, "did X happen?" lookups | cheapest |
| **sonnet** | code, infra, content-QA, web research, implementation, code-review, test-running — **the BULK of delegated work** | mid |
| **opus**   | judgment ONLY: design synthesis, multi-option adjudication, root-cause of a fatal/data/security bug, flaw-hunt **triage** (not the per-persona search) | most |

Fable 5 is a session-launch model, not an Agent/Workflow option — not selectable for delegated subagents.

## The binding rule (enforced by `scripts/guard-model-routing.sh`, PreToolUse)
1. **Every `Agent`/`Task` call MUST pass an explicit `model:`.** A spawn with no
   model is BLOCKED (the implicit Opus-inherit is the bloat source). Choose from
   the table by the task's role.
2. **Every `Workflow` whose script contains `agent(` MUST set `opts.model` on its
   agent() calls.** A workflow with agent() and zero `model:` is BLOCKED. Tier each
   agent: sonnet for the research/impl bulk, haiku for grep/status, opus only for
   the director/synthesis step.
3. Fail-open: parse errors / other tools / un-inspectable scriptPath → allowed.

## Routing the loop's recurring work
- **§V flaw-hunt personas** (WebSearch + walk code → find one flaw) → **sonnet**.
  The triage/decision of which finding to build → main loop (Opus) or an explicit
  opus agent. (Previously these ran Opus by default — the main regression.)
- **Real-render screenshot capture / git-status / grep / log checks** delegated to
  an agent → **haiku**.
- **Design / character / palette panels** → research facets **sonnet**, the
  director/synthesis **opus**.
- **content-qa, code-reviewer, test-runner** subagents → **sonnet**.
- The **main loop itself** is launch-fixed to Opus 4.8 (cannot self-switch
  mid-session); keep its own per-tick work minimal and push real work to tiered
  subagents rather than doing it inline on Opus.

Audit: state which tier each delegated task used so over/under-spend is visible.

## Self-audit (CEO 2058, 2026-06-18) — VERIFIED LIVE + honest limitations
Empirically probed in the running session (not assumed):
- **Agent spawn with no model → BLOCKED** (live probe hit the gate). Disproves the
  worry that PreToolUse might not fire on the Agent tool (cf. anthropics/claude-code
  #34692) and confirms the settings.json edit is active this session + the matcher
  matches the real tool name "Agent".
- **Workflow with an un-tiered agent() → BLOCKED** (live probe).
- Strengthened after the audit: the Workflow check was too lenient (any single
  `model:` passed); now blocks when `agent(` count > `model:` count, so a
  partially-tiered script (one tiered + several un-tiered agents) is caught too.
  Re-tested 8 cases (block/allow/fail-open) all correct.

## Audit findings — ADDRESSED (CEO 2060, 2026-06-18)
The self-audit's 4 residual limitations were acted on, not just noted:
1. **"Choice not correctness" (all-opus passed) → FIXED.** `model:opus` on a
   delegated Agent/Task is now BLOCKED unless the prompt/description carries a
   judgment justification (judg|synthes|adjudicat|root-cause|triage|architect|
   design|decision|deliberat|flaw-hunt). So opus is enforced as judgment-only;
   lazily tagging a grep/research task opus is rejected. (Lenient direction: a
   genuine opus task just states its judgment nature.)
2. **Fail-open silent breakage → DECIDED + made DETECTABLE.** Fail-open is kept
   deliberately (fail-closed would halt ALL delegation = worse). Detectability
   added via `scripts/test-model-routing-gate.sh` (11 cases, exits non-zero if the
   gate stops blocking) — run it to confirm the gate is healthy; a silent
   regression now shows up as a test failure instead of invisible bloat.
3. **Heuristic count → IMPROVED.** `//` line-comments are stripped before counting
   `agent(`/`model:`, so commented-out calls no longer miscount.
4. **No refund of past spend → unfixable** (tokens already spent); future bloat is
   what the gate prevents. Acknowledged, not papered over.
Self-test: `scripts/test-model-routing-gate.sh` → "ALL PASS — gate healthy".

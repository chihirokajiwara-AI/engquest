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

KNOWN RESIDUAL LIMITATIONS (honest — not yet enforced):
1. The gate enforces that a tier is CHOSEN, not that it is the RIGHT one — tagging
   everything `opus` passes the gate while still bloating. Mitigation = this table
   + stating the tier per task; NOT machine-enforced.
2. Fail-open: a broken guard script silently reverts to no enforcement (chosen so a
   parser bug can't halt all delegation). A heavy guard bug would re-open the bloat.
3. The Workflow count check is heuristic — `agent(`/`model:` inside comments or
   strings can miscount (errs toward under-blocking, never false-blocks a fully
   tiered script).
4. This prevents FUTURE bloat only; spend already incurred (earlier character
   workflows + flaw-hunts that ran Opus-by-default) is not refunded.

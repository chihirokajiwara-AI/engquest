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

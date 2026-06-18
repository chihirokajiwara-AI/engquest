#!/usr/bin/env bash
# guard-model-routing.sh — PreToolUse(Agent|Task|Workflow) guard.
#
# Enforces DELIBERATE per-role model routing (CEO 2056, 2026-06-18): the routing
# rule existed in docs but was not EXECUTED — delegated subagents were spawned
# with no model tier, silently inheriting Opus 4.8 (the token-bloat source).
# This makes the rule binding: every delegated subagent MUST pick a tier.
#   haiku  = status / grep / log / typecheck / screenshot-capture / file-nav
#   sonnet = code / infra / content-qa / research / implementation (the BULK)
#   opus   = judgment / design-synthesis / flaw-triage ONLY
# Authoritative table: docs/governance/MODEL-ROUTING.md
#
# Contract: exit 2 = block (Claude sees stderr, must re-issue). Fail-OPEN on any
# parse error or unknown tool -> exit 0 (never break normal work).

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

PARSED=$(printf '%s' "$INPUT" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    ti=d.get('tool_input',{}) or {}
    tool=d.get('tool_name','') or '-'
    model=str(ti.get('model','') or '').strip() or '-'
    body=str(ti.get('script','') or '')+str(ti.get('scriptPath','') or '')
    nagent=body.count('agent(')
    nmodel=body.count('model:')+body.count('model :')
    # untiered = at least one agent() call without a matching model: tier.
    untiered='1' if nagent>nmodel else '0'
    print(tool, model, nagent, untiered)
except Exception:
    print('- - 0 0')
" 2>/dev/null || echo "- - 0 0")

TOOL=$(printf '%s' "$PARSED" | awk '{print $1}')
MODEL=$(printf '%s' "$PARSED" | awk '{print $2}')
NAGENT=$(printf '%s' "$PARSED" | awk '{print $3}')
UNTIERED=$(printf '%s' "$PARSED" | awk '{print $4}')

case "$TOOL" in
  Agent|Task)
    if [ "$MODEL" = "-" ] || [ -z "$MODEL" ]; then
      echo "BLOCKED — model routing not set (CEO 2056). Every subagent MUST pass an explicit model: per docs/governance/MODEL-ROUTING.md — haiku (status/grep/log/typecheck/screenshot) | sonnet (code/infra/content-qa/research/impl, the BULK) | opus (judgment/design-synthesis/flaw-triage ONLY). Re-issue the Agent call with model:." >&2
      exit 2
    fi
    ;;
  Workflow)
    if [ "$UNTIERED" = "1" ]; then
      echo "BLOCKED — this Workflow has agent() call(s) with NO model tier (CEO 2056): agent() count exceeds model: count. Per docs/governance/MODEL-ROUTING.md set opts.model on EVERY agent() — sonnet for the research/impl bulk, haiku for grep/status, opus ONLY for the director/synthesis. Add the missing model: and re-run." >&2
      exit 2
    fi
    ;;
esac
exit 0

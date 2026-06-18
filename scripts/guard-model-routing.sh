#!/usr/bin/env bash
# guard-model-routing.sh — PreToolUse(Agent|Task|Workflow) guard.
#
# Enforces DELIBERATE, CORRECT per-role model routing (CEO 2056/2058/2060):
#   haiku  = status / grep / log / typecheck / screenshot-capture / file-nav
#   sonnet = code / infra / content-qa / research / implementation (the BULK)
#   opus   = judgment ONLY: design-synthesis / adjudication / root-cause of a
#            fatal-data-security bug / flaw-hunt triage
# Authoritative table: docs/governance/MODEL-ROUTING.md
#
# Three enforcements:
#  (A) Agent/Task with NO model:            -> BLOCK (kills the implicit Opus-inherit).
#  (B) Agent/Task with model:opus but NO    -> BLOCK (opus is judgment-only; addresses
#      judgment justification in prompt          the self-audit #1 "choice not correctness").
#  (C) Workflow whose agent() count exceeds -> BLOCK (per-agent tiering; // comments
#      its model: count (comments stripped)      stripped first — self-audit #3).
# Contract: exit 2 = block. Fail-OPEN on any parse error / other tool (self-audit #2:
# fail-closed would halt ALL delegation, which is worse; detectability is provided by
# scripts/test-model-routing-gate.sh instead).

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

PARSED=$(printf '%s' "$INPUT" | python3 -c "
import sys,json,re
def strip(s):
    # drop // line-comments so commented-out agent(/model: don't miscount
    return '\n'.join(re.sub(r'//.*$','',ln) for ln in s.splitlines())
try:
    d=json.load(sys.stdin)
    ti=d.get('tool_input',{}) or {}
    tool=d.get('tool_name','') or '-'
    model=str(ti.get('model','') or '').strip() or '-'
    text=(str(ti.get('prompt','') or '')+' '+str(ti.get('description','') or '')).lower()
    justif='1' if re.search(r'judg|synthes|adjudicat|root.?cause|triage|architect|design|decision|deliberat|flaw.?hunt',text) else '0'
    body=strip(str(ti.get('script','') or '')+str(ti.get('scriptPath','') or ''))
    nagent=body.count('agent(')
    nmodel=body.count('model:')+body.count('model :')
    untiered='1' if nagent>nmodel else '0'
    print(tool, model, justif, untiered)
except Exception:
    print('- - 0 0')
" 2>/dev/null || echo "- - 0 0")

TOOL=$(printf '%s' "$PARSED" | awk '{print $1}')
MODEL=$(printf '%s' "$PARSED" | awk '{print $2}')
JUSTIF=$(printf '%s' "$PARSED" | awk '{print $3}')
UNTIERED=$(printf '%s' "$PARSED" | awk '{print $4}')

case "$TOOL" in
  Agent|Task)
    if [ "$MODEL" = "-" ] || [ -z "$MODEL" ]; then
      echo "BLOCKED — model routing not set (CEO 2056). Every subagent MUST pass an explicit model: per docs/governance/MODEL-ROUTING.md — haiku (status/grep/log/typecheck/screenshot) | sonnet (code/infra/content-qa/research/impl, the BULK) | opus (judgment ONLY). Re-issue with model:." >&2
      exit 2
    fi
    if [ "$MODEL" = "opus" ] && [ "$JUSTIF" = "0" ]; then
      echo "BLOCKED — model:opus on a delegated task with no judgment justification (CEO 2060 self-audit #1). opus is judgment-ONLY (design-synthesis / adjudication / root-cause / flaw-triage). If this is research/code/grep/status use sonnet or haiku; if it genuinely needs opus judgment, say so in the prompt (judgment/synthesis/root-cause/triage/architecture/decision)." >&2
      exit 2
    fi
    ;;
  Workflow)
    if [ "$UNTIERED" = "1" ]; then
      echo "BLOCKED — this Workflow has agent() call(s) with NO model tier (CEO 2056): agent() count exceeds model: count. Per docs/governance/MODEL-ROUTING.md set opts.model on EVERY agent() — sonnet for the research/impl bulk, haiku for grep/status, opus ONLY for the director/synthesis." >&2
      exit 2
    fi
    ;;
esac
exit 0

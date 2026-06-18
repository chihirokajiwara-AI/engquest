#!/usr/bin/env bash
# test-model-routing-gate.sh — self-test for guard-model-routing.sh.
# Addresses self-audit #2 (fail-open is silent): run this to confirm the gate
# still BLOCKS what it should and ALLOWS what it should. Exits non-zero on any
# mismatch so a broken/disabled guard is detectable (not silent). No agents spawn.
set -uo pipefail
cd "$(dirname "$0")/.."
G=scripts/guard-model-routing.sh
fail=0
chk(){ # <expected_exit> <label> <json>
  printf '%s' "$3" | "$G" >/dev/null 2>&1; got=$?
  if [ "$got" != "$1" ]; then echo "FAIL[$got!=$1]: $2"; fail=1; else echo "ok: $2"; fi
}
# --- must BLOCK (exit 2) ---
chk 2 "Agent no model"                 '{"tool_name":"Agent","tool_input":{"prompt":"x"}}'
chk 2 "Agent opus no justification"    '{"tool_name":"Agent","tool_input":{"prompt":"grep the logs","model":"opus"}}'
chk 2 "Workflow 1 agent 0 model"       '{"tool_name":"Workflow","tool_input":{"script":"await agent(\"a\");"}}'
chk 2 "Workflow 2 agent 1 model"       '{"tool_name":"Workflow","tool_input":{"script":"await agent(\"a\",{model:\"sonnet\"}); await agent(\"b\");"}}'
# --- must ALLOW (exit 0) ---
chk 0 "Agent opus WITH justification"  '{"tool_name":"Agent","tool_input":{"prompt":"root-cause judgment of this fatal bug","model":"opus"}}'
chk 0 "Agent sonnet"                    '{"tool_name":"Agent","tool_input":{"prompt":"x","model":"sonnet"}}'
chk 0 "Agent haiku"                     '{"tool_name":"Agent","tool_input":{"prompt":"x","model":"haiku"}}'
chk 0 "Workflow 1 agent 1 model"        '{"tool_name":"Workflow","tool_input":{"script":"await agent(\"a\",{model:\"sonnet\"});"}}'
chk 0 "Workflow commented-out agent"    '{"tool_name":"Workflow","tool_input":{"script":"// await agent(\"x\");\nawait agent(\"y\",{model:\"sonnet\"});"}}'
chk 0 "Bash"                            '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
chk 0 "malformed (fail-open)"           'not json'
if [ "$fail" = 0 ]; then echo "ALL PASS — gate healthy"; else echo "GATE BROKEN"; exit 1; fi

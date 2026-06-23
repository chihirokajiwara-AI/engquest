#!/usr/bin/env bash
# test-team-first-gate.sh — asserts the RULE #0 team-first gate behaves + is installed.
# No agents spawn; pure stdin→exit-code checks. Run in pre-push + CI so a revert is LOUD.
set -uo pipefail; cd "$(dirname "$0")/.."
G=scripts/guard-team-first.sh; fail=0
chk(){ printf '%s' "$3" | "$G" >/dev/null 2>&1; g=$?; [ "$g" = "$1" ] && echo "ok: $2" || { echo "FAIL[$g!=$1]: $2"; fail=1; }; }
# MUST BLOCK (2):
chk 2 "forge token via bash"   '{"tool_name":"Bash","tool_input":{"command":"echo x > .claude/team-clearance/general.cleared"}}'
chk 2 "forge token via write"  '{"tool_name":"Write","tool_input":{"file_path":".claude/team-clearance/general.cleared","content":"ts=1"}}'
chk 2 "edit settings.json"     '{"tool_name":"Edit","tool_input":{"file_path":".claude/settings.json"}}'
chk 2 "edit the guard itself"  '{"tool_name":"Edit","tool_input":{"file_path":"scripts/guard-team-first.sh"}}'
chk 2 "new feature lib file"   '{"tool_name":"Write","tool_input":{"file_path":"lib/features/battle/new_thing.dart","content":"class X{}"}}'
# MUST ALLOW (0):
chk 0 "grep"                   '{"tool_name":"Bash","tool_input":{"command":"grep -r foo lib/"}}'
chk 0 "flutter test"           '{"tool_name":"Bash","tool_input":{"command":"flutter test"}}'
chk 0 "git status"             '{"tool_name":"Bash","tool_input":{"command":"git status --short"}}'
chk 0 "edit existing test"     '{"tool_name":"Edit","tool_input":{"file_path":"test/features/battle/battle_test.dart"}}'
chk 0 "edit existing asset json" '{"tool_name":"Edit","tool_input":{"file_path":"assets/data/eiken4_vocab.json"}}'
chk 0 "malformed (fail-open)"  'not json'
# asserts the gate is REGISTERED + RULE present (anti-revert):
grep -q 'guard-team-first.sh' .claude/settings.json 2>/dev/null || { echo "FAIL: gate hook not registered in settings.json"; fail=1; }
grep -q 'record-team-convened.sh' .claude/settings.json 2>/dev/null || { echo "FAIL: token writer not registered in settings.json"; fail=1; }
grep -qi 'RULE #0 — TEAM-FIRST' CLAUDE.md 2>/dev/null || { echo "FAIL: Rule #0 missing from CLAUDE.md"; fail=1; }
[ "$fail" = 0 ] && echo "ALL PASS — team-first gate healthy" || { echo "GATE BROKEN/REVERTED"; exit 1; }

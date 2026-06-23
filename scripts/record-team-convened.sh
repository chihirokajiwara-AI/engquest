#!/usr/bin/env bash
# record-team-convened.sh — PostToolUse(Workflow|Agent|Task). Writes the
# team-clearance token AFTER a real team run. The main loop cannot invoke this
# path via Bash (guard-team-first.sh blocks Bash/Write to the token dir), and it
# only fires when a genuine Workflow tool actually completed (tool_response present)
# AND the script shows a real multi-expert team signature.
# Designed by the team-first enforcement Workflow (2026-06-23, run wjvkh60b9).
set -uo pipefail
REPO="/Users/openclaw/dev/engquest-flutter"
TOKEN_DIR="$REPO/.claude/team-clearance"; mkdir -p "$TOKEN_DIR" 2>/dev/null || true
INPUT=$(cat 2>/dev/null || true); [ -z "$INPUT" ] && exit 0
if command -v timeout >/dev/null 2>&1; then TO="timeout 3"; elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 3"; else TO=""; fi
# Only honor a Workflow/Agent that actually RAN a multi-expert team and RETURNED output.
INFO=$(printf '%s' "$INPUT" | $TO python3 -c "
import sys,json,re
try:
 d=json.load(sys.stdin); ti=d.get('tool_input',{}) or {}
 resp=json.dumps(d.get('tool_response','') or d.get('tool_result','') or '')
 if not resp or resp in ('\"\"','null','{}'): print('SKIP'); raise SystemExit
 s=str(ti.get('script','') or ti.get('scriptPath','') or ti.get('prompt',''))
 # require a real team-workflow signature (a known studio OR >=4 agent() spawns)
 known=re.search(r'diverse[-_]values[-_]council|game[-_]studio[-_]panel|character[-_]studio|world[-_]studio|foundation[-_]refresh|flawhunt|council|panel|studio',s,re.I)
 nag=len(re.findall(r'agent\(',s))
 if not known and nag<4: print('SKIP'); raise SystemExit
 scope='general'
 for k,v in [('diverse[-_]values','product'),('game[-_]studio','game'),('character','character'),('world[-_]studio','world'),('foundation','foundation')]:
  if re.search(k,s,re.I): scope=v; break
 print(scope)
except SystemExit: pass
except Exception: print('SKIP')
" 2>/dev/null) || exit 0
{ [ "$INFO" = "SKIP" ] || [ -z "$INFO" ]; } && exit 0
SCOPE="$INFO"; TS=$(date +%s); N=$(date +%s | tail -c 6)$RANDOM
printf 'ts=%s scope=%s src=posttooluse nonce=%s consumed=false\n' "$TS" "$SCOPE" "$N" > "$TOKEN_DIR/$SCOPE.cleared" 2>/dev/null || true
# governance/general also cleared so a council run can authorize the cross-cutting edit it decided
printf 'ts=%s scope=general src=posttooluse nonce=%s consumed=false\n' "$TS" "$N" > "$TOKEN_DIR/general.cleared" 2>/dev/null || true
printf '%s | TOKEN_WRITTEN scope=%s\n' "$(date -u +%FT%TZ)" "$SCOPE" >> "$REPO/.claude/team-first-audit.log" 2>/dev/null || true
exit 0

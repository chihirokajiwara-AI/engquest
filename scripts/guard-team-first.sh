#!/usr/bin/env bash
# guard-team-first.sh — PreToolUse(Bash|Write|Edit) gate for RULE #0 (TEAM-FIRST).
# Contract (house std): exit 2 = BLOCK; exit 0 = allow; fail-OPEN on any parse error
# (a guard bug must never paralyze the loop). Canonical doc: docs/governance/DECISION-GATE.md
#
# Substantive output (new feature commit / new lib file / Telegram direction msg) is
# BLOCKED unless a FRESH, hook-written team-clearance token exists for the scope.
# Classification is on the STAGED GIT DIFF (ground truth), not the commit message
# (agent-controlled). There is NO self-serve skip token. Token forgery is blocked:
# any Bash/Write/Edit that targets the token dir is itself blocked here, so only the
# PostToolUse writer (record-team-convened.sh) can create tokens.
#
# Designed by a 5-expert + red-team Workflow (2026-06-23, run wjvkh60b9) at CEO
# direction ("team-first must be the #1 rule, mechanically enforced — text has failed").
set -uo pipefail
REPO="/Users/openclaw/dev/engquest-flutter"
TOKEN_DIR="$REPO/.claude/team-clearance"
AUDIT="$REPO/.claude/team-first-audit.log"
TTL=14400          # 4h — one work session
SUBSTANTIVE_LINES=50   # >= this many changed lines in lib/ design paths => substantive

INPUT=$(cat 2>/dev/null || true); [ -z "$INPUT" ] && exit 0
# Portable bounded-parse: macOS has no `timeout`; use gtimeout if present, else none
# (PreToolUse input is small/bounded, so json.load won't hang).
if command -v timeout >/dev/null 2>&1; then TO="timeout 3"; elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 3"; else TO=""; fi
P=$(printf '%s' "$INPUT" | $TO python3 -c "
import sys,json
try:
 d=json.load(sys.stdin); ti=d.get('tool_input',{}) or {}
 print('TOOL='+repr(d.get('tool_name','') or ''))
 print('CMD='+repr((ti.get('command','') or '').replace(chr(10),' ')[:1000]))
 print('FPATH='+repr(ti.get('file_path','') or ti.get('path','') or ''))
 print('TEXT='+repr((ti.get('text','') or ti.get('message','') or '')[:400]))
except Exception:
 print('TOOL=\"\"');print('CMD=\"\"');print('FPATH=\"\"');print('TEXT=\"\"')
" 2>/dev/null) || exit 0
eval "$P" 2>/dev/null || exit 0
TOOL="${TOOL:-}"; CMD="${CMD:-}"; FPATH="${FPATH:-}"; TEXT="${TEXT:-}"
log(){ printf '%s | %s\n' "$(date -u +%FT%TZ)" "$1" >> "$AUDIT" 2>/dev/null || true; }

# --- FORGERY BLOCK: agent must never write the token dir (any tool) ---
if printf '%s%s' "$CMD" "$FPATH" | grep -Eq 'team-clearance|team-first-audit\.log'; then
  log "FORGE_BLOCKED tool=$TOOL"
  { echo "🚫 team-clearance/ is hook-owned and NOT agent-writable."
    echo "Tokens are written ONLY by the PostToolUse(Workflow) hook on a real team run."
    echo "Run the actual team Workflow; the token appears automatically. (RULE #0)"; } >&2
  exit 2
fi

# --- TIER 2: mechanical fast-pass (Bash) — never needs a team ---
if [ "$TOOL" = "Bash" ]; then
  printf '%s' "$CMD" | grep -Eiq \
   '^(grep|find|cat|ls|head|tail|wc|diff|echo|printf|true|false|exit|which|type|mkdir|cd|pwd|touch [^.])' && exit 0
  printf '%s' "$CMD" | grep -Eiq \
   'flutter (analyze|test|pub get|doctor|clean)|dart (format|analyze|test|pub)' && exit 0
  printf '%s' "$CMD" | grep -Eiq \
   'git (status|log|diff|show|fetch|stash|branch|tag|ls-files|rev-parse|describe|add|restore)' && exit 0
  printf '%s' "$CMD" | grep -Eiq \
   'scripts/(verify|audit|pre-push|safe-job|smoke|test-)|audit_realbrowser|playwright|node scripts/smoke|python3 scripts/verify' && exit 0
fi

# --- TIER 2: Write/Edit to provably non-design paths ---
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
  printf '%s' "$FPATH" | grep -Eiq \
   '(^|/)(test/|\.dart_tool/|build/)|\.g\.dart$|\.freezed\.dart$|\.mocks\.dart$|pubspec\.lock$|(^|/)\.github/|scripts/(verify|audit)' && exit 0
  # editing an EXISTING file outside design paths => mechanical. BUT never fast-pass
  # the governance files (settings.json / the guards) — those are protected below so
  # the loop cannot silently weaken its own constraint.
  if [ -f "$FPATH" ] && ! printf '%s' "$FPATH" | grep -Eq 'lib/(features|core)/|docs/(design|governance|business)/|\.claude/settings\.json$|scripts/guard-team-first\.sh$|scripts/record-team-convened\.sh$'; then exit 0; fi
fi

# --- protect settings.json + this gate from silent reversion (substantive by force) ---
NEEDS=0; SCOPE="general"
if printf '%s' "$FPATH" | grep -Eq '\.claude/settings\.json$|scripts/guard-team-first\.sh$|scripts/record-team-convened\.sh$'; then
  NEEDS=1; SCOPE="governance"
fi

# --- classify git commit / Telegram by GROUND TRUTH (diff / keyword) ---
if [ "$NEEDS" = "0" ] && [ "$TOOL" = "Bash" ] && printf '%s' "$CMD" | grep -Eq 'git[[:space:]]+(commit|merge[^-]|cherry-pick)'; then
  NEWLIB=$(cd "$REPO" 2>/dev/null && git diff --cached --name-status 2>/dev/null | grep -Ec '^A[[:space:]]+(lib/|assets/|docs/(design|governance)/)' || echo 0)
  DESIGN=$(cd "$REPO" 2>/dev/null && git diff --cached --name-only 2>/dev/null | grep -Ec '^(lib/(features|core)/|docs/(design|governance|business)/)' || echo 0)
  LINES=$(cd "$REPO" 2>/dev/null && git diff --cached --numstat 2>/dev/null | awk '{s+=$1+$2} END{print s+0}' || echo 0)
  NEWLIB=${NEWLIB//[^0-9]/}; DESIGN=${DESIGN//[^0-9]/}; LINES=${LINES//[^0-9]/}
  if [ "${NEWLIB:-0}" -ge 1 ] || { [ "${DESIGN:-0}" -ge 1 ] && [ "${LINES:-0}" -ge "$SUBSTANTIVE_LINES" ]; }; then
    NEEDS=1
    SCOPE=$(printf '%s' "$CMD" | grep -oE '(feat|fix|refactor|perf)\([a-z0-9_-]+\)' | head -1 | sed -E 's/.*\(([a-z0-9_-]+)\)/\1/'); [ -z "$SCOPE" ] && SCOPE="general"
  else
    log "MECH_COMMIT lines=$LINES design=$DESIGN new=$NEWLIB"; exit 0
  fi
fi
# new lib/design file creation via Write => substantive
if [ "$NEEDS" = "0" ] && { [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; } && [ ! -f "$FPATH" ] \
   && printf '%s' "$FPATH" | grep -Eq 'lib/(features|core)/|docs/(design|governance|business)/'; then
  NEEDS=1; SCOPE=$(printf '%s' "$FPATH" | grep -oE 'lib/(features|core)/[^/]+' | sed -E 's#.*/##'); [ -z "$SCOPE" ] && SCOPE="general"
fi
# large WRITE to an existing frozen design/governance doc => substantive
if [ "$NEEDS" = "0" ] && [ "$TOOL" = "Write" ] && [ -f "$FPATH" ] \
   && printf '%s' "$FPATH" | grep -Eq 'docs/(design|governance|business)/'; then
  NEEDS=1; SCOPE="governance"
fi
# Telegram product-direction announcement (lower stakes: still gated)
if [ "$NEEDS" = "0" ] && printf '%s' "$TEXT$CMD" | grep -Eiq '(設計|デザイン|アーキ|architecture|方針|direction|decided|決定|提案|propose|リリース|launch|next step).{0,40}(決|建|will|should|やる|進め)'; then
  NEEDS=1; SCOPE="product"
fi
[ "$NEEDS" = "0" ] && exit 0

# --- TIER 1: require a fresh, valid, unconsumed team-clearance token ---
NOW=$(date +%s); HIT=""
if [ -d "$TOKEN_DIR" ]; then
  for f in "$TOKEN_DIR/$SCOPE.cleared" "$TOKEN_DIR/general.cleared"; do
    [ -f "$f" ] || continue
    grep -q 'src=posttooluse' "$f" 2>/dev/null || { log "FORGED_TOKEN_REJECT $f"; continue; }  # only hook-written tokens
    grep -q 'consumed=true' "$f" 2>/dev/null && continue
    TS=$(grep -oE 'ts=[0-9]+' "$f" | head -1 | tr -dc 0-9); [ -z "$TS" ] && continue
    [ $((NOW-TS)) -gt "$TTL" ] && continue
    HIT="$f"; break
  done
fi
if [ -n "$HIT" ]; then
  # consume immediately: ONE team run authorizes ONE substantive output (no stream).
  printf '\nconsumed=true consumed_at=%s\n' "$NOW" >> "$HIT" 2>/dev/null || true
  log "TEAM_ALLOWED scope=$SCOPE token=$(basename "$HIT")"; exit 0
fi

# --- BLOCK (self-contained message; survives /compact) ---
log "BLOCKED scope=$SCOPE tool=$TOOL"
{ echo "========================================================"
  echo "  RULE #0 TEAM-FIRST GATE — BLOCKED (scope: $SCOPE)"
  echo "========================================================"
  echo "  No fresh team-clearance token. The ORDER is TEAM -> DECIDE -> EXECUTE."
  echo "  You reached EXECUTE (substantive commit/new-file/direction) without a team."
  echo ""
  echo "  Solo-deciding accidents this prevents: 16h hang, red code shipped,"
  echo "  7,923 corrupted items, false 'solid' verification, exists-as-quality."
  echo ""
  echo "  TO UNBLOCK — run the team Workflow FIRST (do NOT write any token yourself):"
  echo "    product/direction/cast/art -> diverse-values-council"
  echo "    game x 英検 quality         -> game-studio-panel"
  echo "    world/story                -> world-studio   |  character -> character-studio"
  echo "  The Workflow's PostToolUse hook writes .claude/team-clearance/<scope>.cleared"
  echo "  automatically on completion. Then re-attempt this action."
  echo ""
  echo "  THERE IS NO SKIP TOKEN. Text bypasses have failed 15+ times; this gate has none."
  echo "  (canonical: docs/governance/DECISION-GATE.md  •  RULE #0 in CLAUDE.md)"
  echo "========================================================"; } >&2
exit 2

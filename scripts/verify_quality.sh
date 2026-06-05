#!/usr/bin/env bash
# scripts/verify_quality.sh — A-KEN Quest ENFORCED quality gate
#
# Implements rules R1/R2/R3/R5 from docs/governance/QUALITY-CONSTITUTION.md,
# plus flutter analyze + flutter test.
#
# Usage:
#   ./scripts/verify_quality.sh          # full gate (all checks)
#   ./scripts/verify_quality.sh --fast   # skip flutter analyze/test (CI only)
#
# Exit code: 0 = all gates pass; non-zero = one or more gates failed.
# This script is the pre-commit / pre-deploy gate. A failing gate BLOCKS the change.
#
# NOTE: This script does NOT modify guard-heavy-jobs.sh or any app code.
#       It is read-only analysis + test execution only.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass()  { echo -e "${GREEN}${BOLD}[PASS]${RESET} $*"; }
fail()  { echo -e "${RED}${BOLD}[FAIL]${RESET} $*"; }
warn()  { echo -e "${YELLOW}${BOLD}[WARN]${RESET} $*"; }
info()  { echo -e "${BLUE}${BOLD}[INFO]${RESET} $*"; }
hr()    { echo -e "${BOLD}────────────────────────────────────────────────────────────${RESET}"; }

FAST_MODE=0
[[ "${1:-}" == "--fast" ]] && FAST_MODE=1

FAILURES=()
WARNINGS=()

# ── Check: python3 available ──────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  fail "python3 not found — required for R1/R2/R3 checks"
  exit 1
fi

hr
echo -e "${BOLD}A-KEN Quest Quality Gate — $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
hr
echo ""

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  R1 — CONTENT INTEGRITY                                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
hr
echo -e "${BOLD}R1 CONTENT INTEGRITY${RESET}"
hr

R1_OUTPUT=$(python3 "$REPO_ROOT/scripts/qa/check_content_integrity.py" 2>&1)
R1_EXIT=$?
echo "$R1_OUTPUT"
echo ""
if [[ $R1_EXIT -ne 0 ]]; then
  fail "R1 CONTENT INTEGRITY — failed"
  FAILURES+=("R1: content integrity violations in vocab JSON or quest data")
else
  pass "R1 CONTENT INTEGRITY"
fi

# ── R1b: Quest data structural test (delegated to flutter test) ───────────────
# Covered by R5 flutter test below (test/features/quest/quest_data_test.dart).
# Noted here for traceability.

echo ""

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  R2 — ASSET CONTRACT                                                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
hr
echo -e "${BOLD}R2 ASSET CONTRACT${RESET}"
hr

R2_OUTPUT=$(python3 "$REPO_ROOT/scripts/qa/check_asset_contract.py" 2>&1)
R2_EXIT=$?
echo "$R2_OUTPUT"
echo ""
if [[ $R2_EXIT -ne 0 ]]; then
  fail "R2 ASSET CONTRACT — unregistered missing assets found"
  FAILURES+=("R2: asset contract violated — missing assets not in ALLOWED_MISSING.txt")
else
  pass "R2 ASSET CONTRACT"
fi

echo ""

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  R3 — SMOKE-TEST PRESENCE (warn-only in v1)                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
hr
echo -e "${BOLD}R3 SMOKE-TEST PRESENCE${RESET}"
hr

R3_OUTPUT=$(python3 "$REPO_ROOT/scripts/qa/check_smoke_tests.py" 2>&1)
R3_EXIT=$?
echo "$R3_OUTPUT"
echo ""
if [[ $R3_EXIT -ne 0 ]]; then
  fail "R3 SMOKE-TEST PRESENCE — gaps detected (HARD_FAIL=1 was set)"
  FAILURES+=("R3: screen widgets missing smoke tests")
else
  # R3 is warn-only in v1; any WARNs are surfaced but don't block
  if echo "$R3_OUTPUT" | grep -q '\[WARN\]'; then
    warn "R3 SMOKE-TEST PRESENCE — backlog visible (not blocking in v1)"
    WARNINGS+=("R3: some screens lack smoke tests (see output above)")
  else
    pass "R3 SMOKE-TEST PRESENCE"
  fi
fi

echo ""

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  R5 — LEAKAGE GREP                                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
hr
echo -e "${BOLD}R5 LEAKAGE GREP${RESET}"
hr
echo "  Scanning for residual 魔王/王子/王女/prince/heir patterns in lib/ ..."
echo ""

# Allowed: lines that are code comments documenting the recast
# (contain 'trope', 'recast', 'prince/princess trope', etc.)
# NOTE: \b word-boundaries prevent false-positives like 'their' (contains 'heir')
#       or 'printer' (contains 'prince').
R5_JP_PATTERN='魔王|まおう|王子|王女|おうじ|玉座|👑'
R5_EN_PATTERN='\bprince\b|\bprincess\b|\bheir\b|\bheiress\b'
ALLOW_PATTERN='trope|recast'

# Japanese patterns (no word-boundary needed)
R5_JP_HITS=$(grep -rn --include="*.dart" -E "$R5_JP_PATTERN" "$REPO_ROOT/lib/" 2>/dev/null \
             | grep -viE "$ALLOW_PATTERN" || true)
# English patterns — use \b word boundaries (-P for Perl regex)
R5_EN_HITS=$(grep -rnP --include="*.dart" "$R5_EN_PATTERN" "$REPO_ROOT/lib/" 2>/dev/null \
             | grep -viE "$ALLOW_PATTERN" || true)
R5_HITS="${R5_JP_HITS}${R5_EN_HITS}"

if [[ -n "$R5_HITS" ]]; then
  echo "$R5_HITS" | while IFS= read -r line; do
    echo "  [FAIL] $line"
  done
  COUNT=$(echo "$R5_HITS" | wc -l | tr -d ' ')
  echo ""
  fail "R5 LEAKAGE GREP — ${COUNT} residual reference(s) found"
  echo "  These lines must either be removed or be in a code comment containing 'trope' or 'recast'."
  FAILURES+=("R5: ${COUNT} residual narrative leakage line(s) in lib/")
else
  echo "  No residual references found."
  echo ""
  pass "R5 LEAKAGE GREP"
fi

echo ""

if [[ $FAST_MODE -ne 1 ]]; then

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  flutter analyze                                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
hr
echo -e "${BOLD}flutter analyze${RESET}"
hr

ANALYZE_OUTPUT=$(flutter analyze 2>&1)
ANALYZE_EXIT=$?
echo "$ANALYZE_OUTPUT"
echo ""
if [[ $ANALYZE_EXIT -ne 0 ]]; then
  fail "flutter analyze — issues found"
  FAILURES+=("flutter analyze: non-zero exit")
elif echo "$ANALYZE_OUTPUT" | grep -q "No issues found"; then
  pass "flutter analyze — No issues found"
else
  # analyze exited 0 but might have infos/warnings
  if echo "$ANALYZE_OUTPUT" | grep -qE "warning|error|hint|info"; then
    warn "flutter analyze — exited 0 but output contains diagnostics (check above)"
    WARNINGS+=("flutter analyze: check output for infos/warnings")
  else
    pass "flutter analyze"
  fi
fi

echo ""

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  flutter test                                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
hr
echo -e "${BOLD}flutter test${RESET}"
hr

TEST_OUTPUT=$(flutter test 2>&1)
TEST_EXIT=$?
echo "$TEST_OUTPUT"
echo ""
if [[ $TEST_EXIT -ne 0 ]]; then
  fail "flutter test — test failures detected"
  FAILURES+=("flutter test: non-zero exit (tests failed)")
else
  pass "flutter test — all tests green"
fi

echo ""

fi  # end FAST_MODE guard

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SUMMARY                                                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
hr
echo -e "${BOLD}SUMMARY${RESET}"
hr

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}Warnings (non-blocking):${RESET}"
  for w in "${WARNINGS[@]}"; do
    warn "  $w"
  done
  echo ""
fi

if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo ""
  pass "ALL GATES PASSED — change is ready to commit/deploy"
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}GATE FAILURES (${#FAILURES[@]}):${RESET}"
  for f in "${FAILURES[@]}"; do
    fail "  $f"
  done
  echo ""
  fail "QUALITY GATE BLOCKED — fix the above failures before committing or deploying"
  echo ""
  echo "  Reference: docs/governance/QUALITY-CONSTITUTION.md"
  echo ""
  exit 1
fi

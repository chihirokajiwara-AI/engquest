#!/usr/bin/env bash
# engquest-dev.sh — Autonomous ENG Quest development orchestrator
# Runs Claude Code sessions with expert personas to implement tasks from CLAUDE.md
#
# Usage:
#   ./scripts/engquest-dev.sh              # Run one development cycle
#   ./scripts/engquest-dev.sh --dry-run    # Show what would be done without executing
#
# Architecture:
#   1. Architect agent picks the next task from CLAUDE.md
#   2. Flutter Dev agent implements the task
#   3. Build verification (flutter analyze + flutter test)
#   4. Auto-commit on success
#
# Cost: $0/session (Claude Max flat-rate)

set -euo pipefail

PROJECT_DIR="$HOME/dev/engquest-flutter"
LOG_DIR="$PROJECT_DIR/logs/autonomous"
LOCK_FILE="/tmp/engquest-dev.lock"
MAX_BUDGET=5  # USD per session (safety cap)
DRY_RUN="${1:-}"

mkdir -p "$LOG_DIR"

# ── Lock: prevent concurrent runs ──────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "[$(date -Iseconds)] Another session is running (PID $LOCK_PID). Exiting."
    exit 0
  fi
  echo "[$(date -Iseconds)] Stale lock file found. Removing."
  rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SESSION_LOG="$LOG_DIR/$TIMESTAMP.log"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$SESSION_LOG"
}

log "=== ENG Quest Autonomous Dev Session ==="
log "Project: $PROJECT_DIR"
log "Budget cap: \$$MAX_BUDGET"

cd "$PROJECT_DIR"

# ── Pre-flight checks ─────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  log "ERROR: claude CLI not found"
  exit 1
fi

if ! command -v flutter &>/dev/null; then
  log "ERROR: flutter not found"
  exit 1
fi

# Check for uncommitted changes — don't clobber work in progress
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  log "WARNING: Uncommitted changes detected. Stashing before autonomous work."
  git stash push -m "auto-stash before autonomous session $TIMESTAMP"
fi

if [ "$DRY_RUN" = "--dry-run" ]; then
  log "DRY RUN — would execute claude session. Exiting."
  exit 0
fi

# ── Main Development Session ──────────────────────────────────────────────
# Single Claude Code session that reads CLAUDE.md, picks a task, implements it,
# verifies the build, and commits.

PROMPT='You are an expert Flutter developer working on ENG Quest, an English learning RPG for Japanese children.

Read CLAUDE.md in the project root to understand the project and find the task queue.

Your mission for this session:
1. Pick the HIGHEST PRIORITY unchecked task ([ ]) from the Task Queue in CLAUDE.md
2. Implement it completely with production quality
3. Write tests for any new functionality
4. Run `flutter analyze` — fix any issues until zero errors
5. Run `flutter test` — fix any failures
6. Update CLAUDE.md: change the task from `[ ]` to `[x]`
7. Commit all changes with a descriptive commit message

Rules:
- NEVER import dart:io (web app — breaks compilation)
- Use package:http/http.dart for HTTP
- Japanese UI text for child-facing screens
- If flutter analyze or flutter test fail, fix the issues before committing
- If you cannot complete a task, leave it unchecked and add a note with the blocker
- One task per session — do it well rather than doing many poorly
- Do NOT push to remote — only local commit'

log "Starting Claude Code session..."

# Run Claude Code with autonomous permissions and budget cap
claude -p "$PROMPT" \
  --dangerously-skip-permissions \
  --max-budget-usd "$MAX_BUDGET" \
  --output-format text \
  2>&1 | tee -a "$SESSION_LOG"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  log "Session completed successfully."
  # Log what was committed
  LAST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "no commit")
  log "Last commit: $LAST_COMMIT"
else
  log "Session exited with code $EXIT_CODE"
fi

# ── Post-session cleanup ──────────────────────────────────────────────────
# Verify build state
if flutter analyze --no-pub 2>/dev/null | grep -q "No issues found"; then
  log "Post-check: flutter analyze PASS"
else
  log "Post-check: flutter analyze has issues (may need manual review)"
fi

log "=== Session complete ==="

#!/usr/bin/env bash
# safe-job.sh — the ONLY sanctioned way to run heavy/long jobs.
#
# Guarantees, every time:
#   - DETACHED: returns control to the agent immediately (never blocks the loop)
#   - HARD TIMEOUT: the job is killed after <timeout_seconds> no matter what
#   - LOGGED: stdout/stderr -> logs/jobs/<name>.log
#   - STATUS: logs/jobs/<name>.status records OK / FAILED / TIMEOUT on exit,
#     so a poller STOPS instead of looping forever on a stuck/failed job.
#
# This exists because heavy ML/training/download jobs run directly in the agent
# loop caused a 16-hour hang (CEO unreachable) on 2026-06-03. See CLAUDE.md
# 「暴走防止」. Portable timeout (no coreutils dependency on macOS).
#
# Usage:   scripts/safe-job.sh <name> <timeout_seconds> <command ...>
# Example: scripts/safe-job.sh kokoro_pre1 3600 \
#            /tmp/kokoro-venv/bin/python scripts/generate_kokoro_audio.py --grade eiken_pre1
# Poll:    cat logs/jobs/kokoro_pre1.status ; tail -f logs/jobs/kokoro_pre1.log

set -uo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: scripts/safe-job.sh <name> <timeout_seconds> <command...>" >&2
  exit 64
fi

name=$1; tmo=$2; shift 2
case "$tmo" in (*[!0-9]*|'') echo "timeout_seconds must be an integer" >&2; exit 64;; esac

dir="logs/jobs"; mkdir -p "$dir"
log="$dir/${name}.log"; status="$dir/${name}.status"

nohup bash -c '
  tmo=$1; status=$2; shift 2
  "$@" &
  job=$!
  ( sleep "$tmo"; kill -9 "$job" 2>/dev/null ) &
  watch=$!
  wait "$job"; rc=$?
  kill "$watch" 2>/dev/null
  if [ "$rc" -gt 128 ]; then state=TIMEOUT
  elif [ "$rc" -eq 0 ]; then state=OK
  else state=FAILED
  fi
  echo "$state rc=$rc ended=$(date +%s)" > "$status"
' _ "$tmo" "$status" "$@" > "$log" 2>&1 &

wpid=$!
echo "RUNNING pid=$wpid started=$(date +%s) timeout=${tmo}s" > "$status"
echo "launched '${name}' pid=$wpid timeout=${tmo}s log=$log status=$status (non-blocking)"

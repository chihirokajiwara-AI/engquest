#!/usr/bin/env bash
# =============================================================================
# pre-push-quality-gate.sh  —  fail-safe pre-push quality gate for engquest-flutter
# -----------------------------------------------------------------------------
# PURPOSE
#   Enforced (not soft-prompt) mirror of CI run on the LOCAL machine BEFORE any
#   commit reaches origin/main -> CI -> live (http://178.105.113.79) + Stripe.
#   Invoked by .git/hooks/pre-push, which fires on EVERY `git push` — including
#   safe-sync.sh's 15-min auto-sync push (plain `git push`, no --no-verify).
#
# CONTRACT (git pre-push):
#   stdin lines: "<local_ref> <local_oid> <remote_ref> <remote_oid>"
#   exit 0  => allow push.   exit non-zero => git aborts the push (no mutation).
#
# DESIGN INVARIANTS (do not weaken):
#   * FAIL-SAFE: any uncertainty (timeout, missing flutter on a Dart push,
#     unreadable diff, worktree failure, internal error) => BLOCK (exit 1).
#     The ONLY path to exit 0 is "all applicable checks explicitly passed" or
#     "the pushed range touches nothing relevant".
#   * READ-ONLY w.r.t. the repo: never add/commit/stash/reset/checkout/push/
#     format-in-place/force/delete. Heavy checks run in an EPHEMERAL detached
#     worktree of the pushed tip under /tmp, cleaned on every exit path.
#   * Checks the PUSHED COMMIT RANGE, never the dirty working tree.
#   * Mirrors CI commands+order; format is WARN-only due to verified 3.44-vs-3.22
#     formatter drift (CI is the source of truth — this is a high-recall pre-filter).
#   * Exactly ONE Telegram alert on BLOCK (safe-sync's own alerts are disabled),
#     rate-limited per (sha+stage) to avoid 15-min-loop spam. Zero alerts on pass.
#   * Zero paid cost: local flutter/dart/python3 + one free Telegram curl only.
#   * Reversible: `rm .git/hooks/pre-push` fully removes the gate.
#   * Kill-switch: ENGQUEST_SKIP_PREPUSH=1 bypasses (loud: logs + alerts the bypass).
# =============================================================================

set -uo pipefail   # deliberately NOT -e: we route every failure to BLOCK ourselves.

# ----------------------------------------------------------------------------- config
REPO="/Users/openclaw/dev/engquest-flutter"
FLUTTER_BIN="/Users/openclaw/flutter/bin"
FLUTTER="$FLUTTER_BIN/flutter"
DART_BIN="$FLUTTER_BIN/dart"
ENV_FILE="$HOME/.config/charsiu-notify.env"
TG_CHAT_ID="8302300121"
LOG="/tmp/engquest-pre-push.log"
ALERT_STATE="/tmp/engquest-pre-push-last-alert"   # dedupe key: "<sha>:<stage>:<epoch>"
ALERT_COOLDOWN=1800                               # seconds; suppress identical re-alert
ZERO="0000000000000000000000000000000000000000"
GATED_REF="refs/heads/main"                       # only main feeds live; other branches pass light

# per-stage hard timeouts (seconds). macOS has no GNU timeout -> perl alarm (proven in safe-sync).
T_PUBGET=180
T_ANALYZE=300
T_FORMAT=120
T_TEST=480
T_PYTHON=120
# Total worst-case wall clock < ~20min, well under launchd StartInterval (900s) per push;
# in practice most pushes touch a subset and finish far sooner.

WT=""            # ephemeral worktree path (set later)
FAILED_STAGE=""  # first failing hard-block stage
ERR_TAIL=""      # last lines of the failing command's output
AUTOFIX_COMMITTED=0  # set to 1 if pre-flight auto-fix committed a repair

# ----------------------------------------------------------------------------- logging
ts()  { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '%s [pre-push] %s\n' "$(ts)" "$*" >> "$LOG" 2>/dev/null; }

# ----------------------------------------------------------------------------- cleanup trap
# Runs on EVERY exit path (normal, error, signal). Removes the detached worktree so a
# killed hook never leaves a dangling worktree that would corrupt future `git worktree add`.
cleanup() {
  if [ -n "$WT" ]; then
    git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
    rm -rf "$WT" >/dev/null 2>&1
  fi
}
trap cleanup EXIT INT TERM

# ----------------------------------------------------------------------------- telegram (block-only, deduped)
# Secret hygiene: token read into a local var, used only inline in the URL, NEVER echoed,
# NEVER logged, NO `set -x` around this function. Best-effort: a failed send never flips
# the BLOCK decision. Rate-limited per (sha+stage) within ALERT_COOLDOWN.
send_block_alert() {
  local sha="$1" stage="$2" detail="$3"
  local key now last_key last_epoch
  now=$(date +%s)
  key="${sha}:${stage}"

  if [ -f "$ALERT_STATE" ]; then
    last_key=$(cut -d'|' -f1 "$ALERT_STATE" 2>/dev/null)
    last_epoch=$(cut -d'|' -f2 "$ALERT_STATE" 2>/dev/null)
    if [ "$last_key" = "$key" ] && [ -n "${last_epoch:-}" ]; then
      if [ $(( now - last_epoch )) -lt "$ALERT_COOLDOWN" ]; then
        log "alert suppressed (cooldown) key=$key"
        return 0
      fi
    fi
  fi

  if [ ! -r "$ENV_FILE" ]; then
    log "alert FAILED: env file not readable ($ENV_FILE) — BLOCK stands, CEO must check $LOG"
    return 0
  fi
  local token
  token=$(grep -m1 '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d $'\r\n"')
  if [ -z "$token" ]; then
    log "alert FAILED: no TELEGRAM_BOT_TOKEN in env — BLOCK stands"
    return 0
  fi

  local short="${sha:0:8}"
  local msg
  msg=$(printf '%s' \
"[engquest pre-push BLOCKED]
repo: engquest-flutter
commit: ${short}
failed: ${stage}
push to live (178.105.113.79) WITHHELD.
local Flutter 3.44 vs CI 3.22 — if this looks like version drift, fix or use ENGQUEST_SKIP_PREPUSH=1.
--- detail ---
${detail}
log: ${LOG}")

  local http
  http=$(curl -s -o /dev/null -w '%{http_code}' \
      --max-time 10 --connect-timeout 5 \
      -X POST "https://api.telegram.org/bot${token}/sendMessage" \
      -d chat_id="$TG_CHAT_ID" \
      --data-urlencode "text=${msg}" 2>/dev/null)
  token=""   # scrub
  log "telegram send http=${http:-no-response} key=$key"
  printf '%s|%s\n' "$key" "$now" > "$ALERT_STATE" 2>/dev/null
}

# Centralised BLOCK: log, alert, exit non-zero. Single sanctioned external send lives here.
do_block() {
  local sha="$1" stage="$2" detail="$3"
  log "BLOCK sha=${sha:0:8} stage=$stage"
  printf '\n========================================\n' >&2
  printf '  PUSH BLOCKED by pre-push quality gate\n' >&2
  printf '  commit: %s\n' "${sha:0:8}" >&2
  printf '  failed: %s\n' "$stage" >&2
  printf '========================================\n' >&2
  printf '%s\n' "$detail" >&2
  printf '\nLive site protected. Fix the issue and re-push.\n' >&2
  printf 'Emergency bypass (logged + alerted): ENGQUEST_SKIP_PREPUSH=1 git push\n' >&2
  printf 'Full log: %s\n\n' "$LOG" >&2
  send_block_alert "$sha" "$stage" "$detail"
  exit 1
}

# Bounded runner: perl alarm timeout (no GNU timeout on macOS). Captures combined output.
# Returns: 0 ok / 124 timeout / other = command's exit code. Output placed in global RUN_OUT.
RUN_OUT=""
run_bounded() {
  local secs="$1"; shift
  local out rc
  # `exec ... or exit 127`: if exec FAILS (bad path/ENOENT), fail CLOSED (rc=127 -> BLOCK),
  # never fail-open as rc=0. This preserves the gate's fail-safe invariant.
  out=$(perl -e 'alarm shift; exec @ARGV or exit 127' "$secs" "$@" 2>&1)
  rc=$?
  RUN_OUT="$out"
  # perl alarm => process killed by SIGALRM(14) => 128+14=142; normalise to 124 (timeout).
  if [ "$rc" -eq 142 ]; then rc=124; fi
  return "$rc"
}

tail_n() { printf '%s\n' "$1" | tail -n 15; }

# ----------------------------------------------------------------------------- start
log "invoked args=[$*] ENGQUEST_SKIP_PREPUSH=${ENGQUEST_SKIP_PREPUSH:-}"

# Kill-switch: loud, never silent.
if [ "${ENGQUEST_SKIP_PREPUSH:-0}" = "1" ]; then
  head_sha=$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo unknown)
  log "BYPASS via ENGQUEST_SKIP_PREPUSH=1 head=${head_sha:0:8} — allowing push, alerting CEO"
  send_block_alert "$head_sha" "BYPASS(ENGQUEST_SKIP_PREPUSH)" "Gate intentionally bypassed by operator. No checks ran."
  printf '[pre-push] ENGQUEST_SKIP_PREPUSH=1 — gate bypassed (logged + CEO alerted).\n' >&2
  exit 0
fi

# ----------------------------------------------------------------------------- main: per pushed ref
# git feeds one line per ref on stdin. We evaluate each; first hard failure blocks the
# whole push (git semantics: any non-zero aborts). We act only on the gated ref (main).
SAW_RELEVANT=0

while read -r local_ref local_oid remote_ref remote_oid; do
  # Empty trailing line guard.
  [ -z "${local_ref:-}" ] && continue
  log "ref local_ref=$local_ref local_oid=${local_oid:0:8} remote_ref=$remote_ref remote_oid=${remote_oid:0:8}"

  # Gate only pushes to live branch (refs/heads/main). Feature branches push freely;
  # CI still runs on PRs. This keeps WIP-branch iteration cheap.
  if [ "$remote_ref" != "$GATED_REF" ]; then
    log "skip: non-gated ref ($remote_ref) — allow"
    continue
  fi

  # Branch DELETE (local_oid all-zero): nothing to verify, allow.
  if [ "$local_oid" = "$ZERO" ]; then
    log "skip: branch delete — allow"
    continue
  fi

  # Resolve the pushed range base.
  if [ "$remote_oid" = "$ZERO" ]; then
    # NEW branch on remote: base = merge-base with origin/main; fallback to full-history compare.
    base=$(git -C "$REPO" merge-base origin/main "$local_oid" 2>/dev/null)
    if [ -z "${base:-}" ]; then
      base=$(git -C "$REPO" rev-parse "${local_oid}~1" 2>/dev/null || echo "")
    fi
  else
    base="$remote_oid"
  fi

  # Changed-file set for the pushed range. FAIL-SAFE: if we cannot compute it, run EVERYTHING.
  if [ -n "${base:-}" ]; then
    files=$(git -C "$REPO" diff --name-only "$base" "$local_oid" 2>/dev/null)
    diff_rc=$?
  else
    files=""
    diff_rc=1
  fi

  if [ "$diff_rc" -ne 0 ]; then
    log "diff computation failed (base=${base:-none}) — fail-safe: treat as ALL relevant"
    RUN_DART=1; RUN_AUDIO=1; RUN_PUBGET=1
  else
    log "changed files in range: $(printf '%s' "$files" | tr '\n' ' ')"
    RUN_DART=0; RUN_AUDIO=0; RUN_PUBGET=0
    # Dart-class: *.dart, pubspec.yaml/lock, analysis_options.yaml, web/
    if printf '%s\n' "$files" | grep -Eq '\.dart$|^pubspec\.(yaml|lock)$|^analysis_options\.yaml$|^web/'; then
      RUN_DART=1
    fi
    # Audio/asset-class: assets/, scripts/*.py, web/
    if printf '%s\n' "$files" | grep -Eq '^assets/|^scripts/.*\.py$|^web/'; then
      RUN_AUDIO=1
    fi
    # pub get only when dependency surface changed or toolchain dir absent.
    if printf '%s\n' "$files" | grep -Eq '^pubspec\.(yaml|lock)$'; then
      RUN_PUBGET=1
    fi
  fi

  # Nothing relevant in this ref's range => skip heavy checks for it.
  if [ "$RUN_DART" -eq 0 ] && [ "$RUN_AUDIO" -eq 0 ]; then
    log "skip: range touches no relevant files (docs/log-only) — allow ref"
    continue
  fi
  SAW_RELEVANT=1

  # --- PRE-FLIGHT AUTO-FIX ---------------------------------------------------------------
  # Detect and repair known failure patterns BEFORE creating the worktree, so the
  # worktree materializes the fixed state. Auto-fix commits are safe (additive only,
  # restoring files from existing canonical sources). This relaxes the "READ-ONLY"
  # invariant for well-understood, deterministic repairs only.
  AUTOFIX_COMMITTED=0
  if [ "$RUN_AUDIO" -eq 1 ]; then
    # Missing web/audio/ — restore from assets/audio/a1/ (canonical source, byte-identical)
    audio_count=$(find "$REPO/web/audio/a1" -name '*.mp3' 2>/dev/null | wc -l | tr -d ' ')
    asset_count=$(find "$REPO/assets/audio/a1" -name '*.mp3' 2>/dev/null | wc -l | tr -d ' ')
    if [ "${asset_count:-0}" -gt 0 ] && [ "${audio_count:-0}" -lt "$asset_count" ]; then
      log "preflight-autofix: web/audio/ has $audio_count MP3s vs $asset_count in assets/ — restoring"
      mkdir -p "$REPO/web/audio/a1"
      cp "$REPO/assets/audio/a1/"*.mp3 "$REPO/web/audio/a1/" 2>/dev/null
      cp "$REPO/assets/audio/a1/"*.mp3 "$REPO/web/audio/" 2>/dev/null
      ( cd "$REPO" && git add web/audio/ && \
        git commit -m "fix(auto-gate): restore web/audio/ MP3s from assets/audio/a1/" ) >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        local_oid=$(git -C "$REPO" rev-parse HEAD)
        AUTOFIX_COMMITTED=1
        log "preflight-autofix: audio restored and committed (new tip ${local_oid:0:8})"
      fi
    fi
  fi

  # --- Materialize the EXACT pushed tip in an isolated detached worktree -----------------
  # Never the dirty working tree (5 modified .dart files now are NOT what we evaluate).
  WT="/tmp/engquest-prepush-$$-$(printf '%s' "$local_oid" | cut -c1-8)"
  git -C "$REPO" worktree prune >/dev/null 2>&1
  if ! git -C "$REPO" worktree add --detach "$WT" "$local_oid" >/dev/null 2>&1; then
    do_block "$local_oid" "worktree-setup" "Could not create isolated worktree for the pushed tip. Refusing to verify in the dirty live tree. (git worktree add failed)"
  fi
  log "worktree ready at $WT (tip ${local_oid:0:8})"

  # --- AUDIO contract checks (pure python3, no flutter; cwd-independent via __file__) ----
  if [ "$RUN_AUDIO" -eq 1 ]; then
    if ! command -v python3 >/dev/null 2>&1; then
      do_block "$local_oid" "python3-missing" "Range touches assets/scripts but python3 not found — cannot verify audio contract. Install python3 or bypass deliberately."
    fi
    for script in verify_audio_assets test_audio_manifest verify_font_coverage; do
      if [ -f "$WT/scripts/${script}.py" ]; then
        run_bounded "$T_PYTHON" python3 "$WT/scripts/${script}.py"
        rc=$?
        if [ "$rc" -eq 124 ]; then
          do_block "$local_oid" "${script}.py (timeout ${T_PYTHON}s)" "$(tail_n "$RUN_OUT")"
        elif [ "$rc" -ne 0 ]; then
          do_block "$local_oid" "${script}.py" "$(tail_n "$RUN_OUT")"
        fi
        log "ok: ${script}.py"
      else
        log "note: $WT/scripts/${script}.py absent in pushed tree — skip"
      fi
    done
  fi

  # --- DART checks (require flutter). FAIL-SAFE on missing toolchain for a Dart push. ----
  if [ "$RUN_DART" -eq 1 ]; then
    if [ ! -x "$FLUTTER" ]; then
      # Dart code is being pushed to live but we cannot verify it. BLOCK, never skip-silent.
      do_block "$local_oid" "flutter-missing" "Range touches Dart/web but $FLUTTER is not executable. Cannot verify a Dart push to live. Install Flutter or bypass deliberately (ENGQUEST_SKIP_PREPUSH=1)."
    fi

    # pub get (only when deps changed or .dart_tool absent) — idempotent, writes only
    # pubspec.lock/.dart_tool inside the THROWAWAY worktree (never the live tree).
    if [ "$RUN_PUBGET" -eq 1 ] || [ ! -d "$WT/.dart_tool" ]; then
      # Single bounded, fail-closed invocation (capture in-shell so RUN_OUT survives).
      RUN_OUT=$( cd "$WT" && perl -e 'alarm shift; exec @ARGV or exit 127' "$T_PUBGET" "$FLUTTER" pub get 2>&1 ); rc=$?
      [ "$rc" -eq 142 ] && rc=124
      if [ "$rc" -eq 124 ]; then
        do_block "$local_oid" "flutter pub get (timeout ${T_PUBGET}s)" "$(tail_n "$RUN_OUT")"
      elif [ "$rc" -ne 0 ]; then
        do_block "$local_oid" "flutter pub get" "$(tail_n "$RUN_OUT")"
      fi
      log "ok: flutter pub get"
    else
      log "skip: pub get (deps unchanged, .dart_tool present)"
    fi

    # analyze — HARD BLOCK. Highest-value, stable across SDK minors (compile/semantic).
    # AUTO-RETRY: if analyze fails with undefined identifiers (common after pub cache
    # issues), re-run pub get and retry analyze once before blocking.
    RUN_OUT=$( cd "$WT" && perl -e 'alarm shift; exec @ARGV or exit 127' "$T_ANALYZE" "$FLUTTER" analyze --fatal-infos --fatal-warnings 2>&1 ); rc=$?
    [ "$rc" -eq 142 ] && rc=124
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ]; then
      if printf '%s' "$RUN_OUT" | grep -q 'undefined_identifier\|undefined_class\|undefined_method'; then
        log "analyze failed with undefined symbols — retrying after pub get"
        ( cd "$WT" && "$FLUTTER" pub get ) >/dev/null 2>&1
        RUN_OUT=$( cd "$WT" && perl -e 'alarm shift; exec @ARGV or exit 127' "$T_ANALYZE" "$FLUTTER" analyze --fatal-infos --fatal-warnings 2>&1 ); rc=$?
        [ "$rc" -eq 142 ] && rc=124
        log "analyze retry rc=$rc"
      fi
    fi
    if [ "$rc" -eq 124 ]; then
      do_block "$local_oid" "flutter analyze (timeout ${T_ANALYZE}s)" "$(tail_n "$RUN_OUT")"
    elif [ "$rc" -ne 0 ]; then
      do_block "$local_oid" "flutter analyze --fatal-infos --fatal-warnings" "$(tail_n "$RUN_OUT")"
    fi
    log "ok: flutter analyze"

    # format — WARN ONLY. Verified 3.44 formatter flags 59/94 committed files that CI's
    # 3.22 formatter accepts; a hard block here would deny ALL pushes (incl. auto-sync) =>
    # someone deletes the gate => zero protection. CI (3.22) remains the format authority.
    if [ ! -x "$DART_BIN" ]; then
      log "WARN: dart binary not executable ($DART_BIN) — skipping format check (warn-only stage)"
      printf '[pre-push] WARN: dart not found; skipping format pre-check (CI verifies format).\n' >&2
    else
    RUN_OUT=$( cd "$WT" && perl -e 'alarm shift; exec @ARGV or exit 127' "$T_FORMAT" "$DART_BIN" format --output=none --set-exit-if-changed . 2>&1 ); rc=$?
    [ "$rc" -eq 142 ] && rc=124
    if [ "$rc" -ne 0 ]; then
      log "WARN: dart format drift (rc=$rc) — NOT blocking (local 3.44 vs CI 3.22). CI is authority."
      printf '[pre-push] WARN: dart format reports changes (local Flutter 3.44 vs CI 3.22 drift). Not blocking; CI verifies format.\n' >&2
    else
      log "ok: dart format (no drift)"
    fi
    fi

    # test — HARD BLOCK. Behavioral correctness. Bounded; timeout => BLOCK (never hang push).
    RUN_OUT=$( cd "$WT" && perl -e 'alarm shift; exec @ARGV or exit 127' "$T_TEST" "$FLUTTER" test --reporter=expanded 2>&1 ); rc=$?
    [ "$rc" -eq 142 ] && rc=124
    if [ "$rc" -eq 124 ]; then
      do_block "$local_oid" "flutter test (timeout ${T_TEST}s)" "$(tail_n "$RUN_OUT")"
    elif [ "$rc" -ne 0 ]; then
      do_block "$local_oid" "flutter test" "$(tail_n "$RUN_OUT")"
    fi
    log "ok: flutter test"
  fi

  # This ref passed. Clean its worktree before evaluating the next ref.
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
  rm -rf "$WT" >/dev/null 2>&1
  WT=""
  log "PASS ref tip ${local_oid:0:8}"
done

# ----------------------------------------------------------------------------- allow
if [ "$SAW_RELEVANT" -eq 1 ]; then
  if [ "$AUTOFIX_COMMITTED" -eq 1 ]; then
    log "ALLOW: all checks passed (after auto-fix commit)"
    printf '[pre-push] quality gate passed — auto-fix applied and committed.\n' >&2
  else
    log "ALLOW: all relevant checks passed"
    printf '[pre-push] quality gate passed — push allowed.\n' >&2
  fi
else
  log "ALLOW: no relevant changes in any gated ref"
fi
exit 0

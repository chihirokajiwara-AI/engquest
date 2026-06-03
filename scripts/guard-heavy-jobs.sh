#!/usr/bin/env bash
# guard-heavy-jobs.sh — PreToolUse(Bash) guard.
#
# Blocks heavy / long-running ML / model-download / generation / build commands
# when they are about to run DIRECTLY in the agent loop. They must instead go
# through scripts/safe-job.sh (detached + hard timeout) — so a stuck or failing
# job can NEVER hang the bot again.
#
# Root cause this prevents: 2026-06-03 16-hour hang (LoRA training + Qwen
# download ran in-loop, blocked on failure, CEO unreachable). See CLAUDE.md
# 「暴走防止」. Mirrors the exit-2-to-block contract of email-send-guard.sh.
#
# Fail-OPEN: any parse error or empty command -> allow (never break normal work).

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)
CMD=$(printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))
except Exception:
    print('')" 2>/dev/null || true)

# nothing to inspect -> allow
[ -z "$CMD" ] && exit 0

# Already routed safely (through safe-job.sh, or carries an explicit timeout) -> allow
if printf '%s' "$CMD" | grep -Eq 'safe-job\.sh|(^|[[:space:]])g?timeout[[:space:]]'; then
  exit 0
fi

# High-signal "this is actually executing something heavy" patterns.
# API-call patterns ( .from_pretrained( etc.) only appear in python -c / heredoc
# execution; script patterns require a python invocation, so a benign
# `cat train.py` / `grep generate_...` does NOT match.
HEAVY='accelerate[[:space:]]+launch'
HEAVY="$HEAVY"'|snapshot_download\(|hf_hub_download\(|\.from_pretrained\(|\.from_single_file\('
HEAVY="$HEAVY"'|StableDiffusion[A-Za-z]*Pipeline|QwenImage[A-Za-z]*Pipeline|DiffusionPipeline'
HEAVY="$HEAVY"'|flutter[[:space:]]+build|docker[[:space:]]+(run|build)'
HEAVY="$HEAVY"'|python[0-9.]*[^|;&]*(train[A-Za-z0-9_]*\.py|generate_kokoro_audio|generate_tts_audio|generate_gtts_audio|generate_category_images|generate_[A-Za-z_]*image)'

if printf '%s' "$CMD" | grep -Eq "$HEAVY"; then
  {
    echo "🚫 重い処理をループ内で直接実行しようとしました（ブロック）。"
    echo ""
    echo "ML訓練 / モデルDL / 画像・音声生成 / 長時間ビルド は、必ず分離ジョブで実行:"
    echo "   scripts/safe-job.sh <name> <timeout秒> <command...>"
    echo "   → detached + hard timeout + status記録。即座に制御が返り、失敗/タイムアウトで停止します。"
    echo "状態確認: cat logs/jobs/<name>.status   ログ: tail logs/jobs/<name>.log"
    echo ""
    echo "（2026-06-03の16時間ハング再発防止ガード / CLAUDE.md 暴走防止）"
  } >&2
  exit 2
fi

exit 0

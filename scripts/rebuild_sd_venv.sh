#!/usr/bin/env bash
# Rebuild the Stable-Diffusion art venv PERSISTENTLY at ~/.venvs/sd, then
# regenerate the コトバ探偵 scene plates.
#
# Root cause this fixes: the SD venv lived in /tmp (/tmp/sd-venv), which macOS
# periodically cleans — so torch/diffusers eroded mid-session and art gen failed
# with "No module named 'torch'". ~/.venvs survives (like the kokoro venv), so
# the venv stays put across reboots/cleanups.
#
# The HF model cache (~/.cache/huggingface, ~6.5G) is NOT in /tmp and survives,
# so only the Python packages are reinstalled here.
#
# Heavy job: ALWAYS run via scripts/safe-job.sh (detached + hard timeout).
set -euo pipefail

VENV="$HOME/.venvs/sd"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

PY="/opt/homebrew/opt/python@3.13/bin/python3.13"
[ -x "$PY" ] || PY="$(command -v python3.13 || command -v python3)"

echo "[rebuild] python: $PY"
echo "[rebuild] venv:   $VENV"

if [ ! -x "$VENV/bin/python" ]; then
  "$PY" -m venv "$VENV"
fi

"$VENV/bin/pip" install --upgrade pip
# torch (MPS wheel on arm64 macOS) + diffusers stack. No torchvision (unused).
"$VENV/bin/pip" install torch diffusers transformers accelerate safetensors

echo "[rebuild] packages installed; regenerating scene art…"
cd "$REPO"
"$VENV/bin/python" scripts/generate_scene_art.py
echo "[rebuild] DONE"

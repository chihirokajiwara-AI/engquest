#!/usr/bin/env bash
# #133 pre-literacy nav-label audio generator. ¥0, on-device, no torch/venv/safe-job.
# macOS `say -v Kyoko` (ja_JP) -> ffmpeg libmp3lame -> assets/audio/ui_ja/<key>.mp3.
# Bundled as assets (~7KB/clip, negligible vs the #48 925MB problem) and played via
# AudioCueService.play(AssetSource('audio/ui_ja/<key>.mp3')). Re-run anytime to regen.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/audio/ui_ja"
JSON="$ROOT/scripts/nav_labels_ja.json"
mkdir -p "$OUT"
command -v ffmpeg >/dev/null || { echo "ffmpeg missing"; exit 1; }
say -v '?' | grep -qi kyoko || { echo "Kyoko ja_JP voice missing"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# iterate keys (skip _doc); python for robust JSON parse
/usr/bin/python3 - "$JSON" <<'PY' | while IFS=$'\t' read -r key reading; do
import json,sys
d=json.load(open(sys.argv[1]))
for k,v in d.items():
    if k.startswith("_"): continue
    print(f"{k}\t{v}")
PY
  say -v Kyoko -o "$TMP/$key.aiff" "$reading"
  ffmpeg -y -i "$TMP/$key.aiff" -ar 24000 -ac 1 -b:a 96k -codec:a libmp3lame "$OUT/$key.mp3" >/dev/null 2>&1
  echo "  $key.mp3  ($(wc -c <"$OUT/$key.mp3") bytes)  \"$reading\""
done
echo "done -> $OUT"

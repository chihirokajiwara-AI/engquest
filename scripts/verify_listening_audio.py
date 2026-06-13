#!/usr/bin/env python3
"""
A-KEN Quest — 英検 Listening audio coverage gate.

Every ListeningItem in lib/features/exam_practice/listening_data.dart carries an
`audioKey` that the listening practice screen plays via
  AudioCueService.play('audio/listening/<audioKey>')
(listening_practice_screen.dart). AudioCueService SWALLOWS a missing clip
silently — so a listening item whose MP3 isn't bundled ships a dead 🔊 button and
is quietly dropped from the by-ear 合格率. That is the same silent-shortfall
failure mode the reading_pool_integrity_test and verify_font_coverage gates exist
for, but listening audio had no guard.

This gate asserts, for every referenced audioKey:
  1. assets/audio/listening/<audioKey> exists on disk and is non-empty, AND
  2. it is NOT still registered in assets/ALLOWED_MISSING.txt (stale-waiver guard
     — a clip that exists must not also be waived as "missing").

Exit 0 when fully covered; exit 1 with the exact gap list otherwise. No Flutter
or network needed — pure file + regex, CI-friendly.
"""

import os
import re
import shutil
import subprocess
import sys

# A clip shorter than this almost certainly means synthesis silently failed
# (empty/near-silent output that still has a valid MP3 header, so the byte-size
# check passes). The shortest legitimate clip — a 5級 single-line 応答 like
# "Thank you very much." — is ~1.8s, so 0.4s is a very conservative floor with
# zero false positives. Only enforced when ffprobe is available (CI-safe).
_MIN_DURATION_S = 0.4


def _duration_seconds(path: str):
    """Clip duration via ffprobe, or None if ffprobe is unavailable / fails."""
    if not shutil.which("ffprobe"):
        return None
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", path],
            capture_output=True, text=True, timeout=15,
        )
        return float(out.stdout.strip())
    except (ValueError, OSError, subprocess.SubprocessError):
        return None

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(
    REPO, "lib", "features", "exam_practice", "listening_data.dart"
)
AUDIO_DIR = os.path.join(REPO, "assets", "audio", "listening")
ALLOWED_MISSING = os.path.join(REPO, "assets", "ALLOWED_MISSING.txt")

AUDIO_KEY_RE = re.compile(r"audioKey:\s*'([^']+)'")


def main() -> int:
    with open(DATA, encoding="utf-8") as f:
        keys = sorted(set(AUDIO_KEY_RE.findall(f.read())))

    if not keys:
        print("FAILED — no audioKey values found in listening_data.dart")
        return 1

    waived = set()
    if os.path.exists(ALLOWED_MISSING):
        with open(ALLOWED_MISSING, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("audio/listening/"):
                    # form: "audio/listening/<key> | date | note"
                    waived.add(line.split("|")[0].strip().split("/")[-1])

    errors = []
    ffprobe_ok = shutil.which("ffprobe") is not None
    for key in keys:
        path = os.path.join(AUDIO_DIR, key)
        if not os.path.exists(path):
            errors.append(f"{key}: no bundled clip (assets/audio/listening/{key})")
        elif os.path.getsize(path) == 0:
            errors.append(f"{key}: clip is zero bytes")
        else:
            # Catch a silently-failed synthesis: a valid-but-near-silent MP3
            # passes the byte check but plays as nothing. (ffprobe-gated → CI-safe.)
            dur = _duration_seconds(path)
            if dur is not None and dur < _MIN_DURATION_S:
                errors.append(
                    f"{key}: clip is only {dur:.2f}s "
                    f"(< {_MIN_DURATION_S}s — likely a silent synthesis failure)"
                )
        if key in waived:
            errors.append(
                f"{key}: exists on disk but still waived in ALLOWED_MISSING.txt "
                "(stale waiver — remove it)"
            )

    if errors:
        print(f"FAILED — {len(errors)} listening-audio issue(s):")
        for e in errors:
            print(f"  - {e}")
        print(
            f"\n{len(keys) - len([e for e in errors if 'no bundled' in e or 'zero' in e])}"
            f"/{len(keys)} clips OK. Generate missing clips via:\n"
            "  scripts/safe-job.sh listening_audio 1800 "
            "~/.venvs/kokoro/bin/python scripts/generate_listening_audio.py"
        )
        return 1

    dur_note = (
        "bundled, non-empty & ≥%.1fs" % _MIN_DURATION_S
        if ffprobe_ok
        else "bundled & non-empty (duration check skipped — no ffprobe)"
    )
    print(f"OK: all {len(keys)} referenced 英検 listening clips {dur_note}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

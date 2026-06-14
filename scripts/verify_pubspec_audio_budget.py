#!/usr/bin/env python3
"""verify_pubspec_audio_budget.py — lock the #48 audio-bundle fix.

The per-word 英検 vocab MP3s (assets/audio/eiken5 … eiken_pre1, ~21k files,
~925MB) are DELIBERATELY not bundled: bundling them added ~21,184 of the
AssetManifest's 23,266 entries (a 1.3MB manifest fetched+parsed on EVERY cold
start) and ~925MB to the web build, for ZERO live audio (the deploy excludes
them and the Google-TTS key is unconfigured, so TtsService falls through to
"unavailable"). See the pubspec.yaml comment around the `assets:` block.

This was the single biggest cold-start tax the CEO hit on :8088. Nothing stopped
it from silently coming back — a one-line `- assets/audio/eiken_pre1/` re-bloats
the build by hundreds of MB and only a real-browser/deploy audit would notice.
This verifier makes the exclusion CI-enforceable.

Contract: NO pubspec asset declaration may bundle a per-word 英検 audio dir
(any `assets/audio/eiken...`). The intentionally-bundled audio (a1 / phonics /
quiz / listening / ui_ja) is unaffected.

Exit 0 = clean. Non-zero = a heavy word-audio dir is bundled again.

Run:  python3 scripts/verify_pubspec_audio_budget.py
"""
from __future__ import annotations

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBSPEC = os.path.join(REPO, "pubspec.yaml")

# Per-word audio dirs (one MP3 per vocab word, per grade) — the ~925MB problem.
# Matches assets/audio/eiken5, eiken4, eiken3, eiken_pre2, eiken2, eiken_pre1.
HEAVY_RE = re.compile(r"assets/audio/eiken[0-9_a-z]*")


def main() -> int:
    if not os.path.exists(PUBSPEC):
        print(f"FAIL: pubspec.yaml not found at {PUBSPEC}")
        return 1

    offenders: list[str] = []
    in_assets = False
    with open(PUBSPEC, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            stripped = line.strip()
            # Track the `assets:` list block (a 4-space indented `- ...` list).
            if re.match(r"^\s*assets:\s*$", line):
                in_assets = True
                continue
            if in_assets:
                # A new top-level/2-space key ends the assets list.
                if stripped and not stripped.startswith("- ") and not stripped.startswith("#"):
                    if re.match(r"^\s{0,2}\S", line):
                        in_assets = False
                if stripped.startswith("- "):
                    path = stripped[2:].strip()
                    if HEAVY_RE.search(path):
                        offenders.append(path)

    print("------------------------------------------------------------")
    print("PUBSPEC AUDIO BUDGET (#48 — no bundled per-word 英検 MP3s)")
    print("------------------------------------------------------------")
    if offenders:
        print("FAIL: per-word 英検 audio is bundled again — this re-adds ~hundreds")
        print("      of MB + thousands of AssetManifest entries to the cold start.")
        for o in offenders:
            print(f"  offending pubspec asset: {o}")
        print("Fix: do NOT bundle per-word MP3s; serve pronunciation on demand")
        print("(network/CDN) when it ships. Keep only a1/phonics/quiz/listening/ui_ja.")
        return 1

    print("OK: no per-word 英検 audio dir is bundled (the #48 fix holds).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

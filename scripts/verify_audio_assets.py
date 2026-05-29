#!/usr/bin/env python3
"""verify_audio_assets.py — ENG Quest audio asset integrity check.

Validates that every word in assets/content/audio_manifest.json marked
status="ready" has a corresponding MP3 present in the Flutter serving locations:

  1. assets/audio/a1/        — bundled Flutter asset (mobile/desktop + web build)
  2. web/audio/a1/           — copied verbatim into build/web by `flutter build web`,
                               served at the manifest's declared webPath (/audio/a1/...)

These two MUST be byte-identical (they are the same manifest-authoritative seed
batch, 6.5 KB each) so the Flutter app gets the exact audio described by the
manifest regardless of platform.

A third, INDEPENDENT location is checked for presence only:

  3. web/audio/              — flat layout for the standalone web/index.html demo
                               (audio/{id}_{word}.mp3). This is a separate, larger
                               300-word TTS generation and is NOT required to match
                               the a1/ seed batch byte-for-byte.

Also checks that the manifest's webPath / localCachePath strings match the
on-disk filenames.

Exit code 0 = all good. Non-zero = at least one inconsistency (CI-friendly).

Run:  python3 scripts/verify_audio_assets.py
"""
from __future__ import annotations

import hashlib
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, "assets", "content", "audio_manifest.json")

ASSET_DIR = os.path.join(REPO, "assets", "audio", "a1")   # bundled asset
WEB_A1_DIR = os.path.join(REPO, "web", "audio", "a1")      # flutter web build path
WEB_FLAT_DIR = os.path.join(REPO, "web", "audio")          # standalone demo path


def md5(path: str) -> str:
    with open(path, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()


def main() -> int:
    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)

    words = manifest["words"]
    ready = [w for w in words if w.get("status") == "ready"]

    errors: list[str] = []
    checked = 0

    for w in ready:
        wid = w["id"]
        fname = w["audioFile"]

        asset_p = os.path.join(ASSET_DIR, fname)
        web_a1_p = os.path.join(WEB_A1_DIR, fname)
        web_flat_p = os.path.join(WEB_FLAT_DIR, fname)

        # 1. Presence in all three locations
        for label, p in (
            ("assets/audio/a1", asset_p),
            ("web/audio/a1", web_a1_p),
            ("web/audio (flat)", web_flat_p),
        ):
            if not os.path.exists(p):
                errors.append(f"{wid}: MISSING in {label} ({fname})")

        # 2. assets/audio/a1 and web/audio/a1 MUST be byte-identical (Flutter pair)
        if os.path.exists(asset_p) and os.path.exists(web_a1_p):
            if md5(asset_p) != md5(web_a1_p):
                errors.append(
                    f"{wid}: assets/audio/a1 differs from web/audio/a1 ({fname})"
                )
            checked += 1

        # 3. Manifest path strings match the real filename
        web_path = w.get("webPath", "")
        if web_path and os.path.basename(web_path) != fname:
            errors.append(f"{wid}: webPath basename != audioFile ({web_path})")
        local_path = w.get("localCachePath", "")
        if local_path and os.path.basename(local_path) != fname:
            errors.append(f"{wid}: localCachePath basename != audioFile ({local_path})")

    print(f"Manifest words: {len(words)}  |  ready: {len(ready)}")
    print(f"Fully verified (present in 3 dirs, a1 pair byte-identical): {checked}")

    if errors:
        print(f"\nFAILED — {len(errors)} issue(s):")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("\nOK — all ready audio assets present, identical, and manifest-consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""test_audio_manifest.py — ENG Quest native-app audio manifest contract.

The native Flutter app pronounces words from bundled Neural2 MP3s described by
assets/content/audio_manifest.json. lib/core/audio/tts_service.dart parses each
entry via AudioManifestEntry.fromJson, which treats these fields as REQUIRED,
non-null:

    id, word, ipa, audioFile, storagePath, localCachePath, status, syllableCount

If any required key is missing the app throws at startup (`json[k] as String`
on null). If a `localCachePath` has no matching bundled MP3, that word silently
degrades to robotic on-device TTS — directly weakening the pronunciation thesis.

This test makes the contract CI-enforceable:

  A. Manifest is 1:1 with src/data/content_db/vocab_a1_300.json (300 words)
  B. Every entry has all Dart-required keys with the right primitive types
  C. Every entry.localCachePath resolves to a real file in assets/audio/a1/
  D. Every entry.audioFile matches the {id}_{word}.mp3 naming convention
  E. No status=='ready' entry points at a 0-byte / stub MP3
  F. The orphaned web/public/ duplicate tree does not exist

Exit 0 = all contracts hold. Non-zero = at least one broken (CI-friendly).

Run:  python3 scripts/test_audio_manifest.py
"""
from __future__ import annotations

import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(REPO, "assets", "content", "audio_manifest.json")
SRC_VOCAB = os.path.join(REPO, "src", "data", "content_db", "vocab_a1_300.json")
# Flutter bundles MP3s here (pubspec: assets/audio/a1/). The manifest's
# localCachePath ("audio/a1/x.mp3") is the on-DEVICE TTS cache key, not a
# bundle path — so we resolve audioFile against the real asset dir.
ASSETS_AUDIO_A1 = os.path.join(REPO, "assets", "audio", "a1")
WEB_AUDIO_A1 = os.path.join(REPO, "web", "audio", "a1")
WEB_PUBLIC = os.path.join(REPO, "web", "public")

# Mirror AudioManifestEntry.fromJson (lib/core/audio/tts_service.dart).
REQUIRED_STR = ["id", "word", "ipa", "audioFile", "storagePath",
                "localCachePath", "status"]
REQUIRED_INT = ["syllableCount"]


def safe_word(word: str) -> str:
    return word.replace(" ", "_")


def load_vocab() -> list[dict]:
    data = json.load(open(SRC_VOCAB, encoding="utf-8"))
    return data if isinstance(data, list) else data.get("words", data)


def main() -> int:
    errors: list[str] = []

    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    words = manifest.get("words", [])
    vocab = load_vocab()

    man_ids = {w.get("id") for w in words}
    voc_ids = {v["id"] for v in vocab}

    # ---- A: 1:1 with vocab ----
    if len(words) != 300:
        errors.append(f"A: manifest has {len(words)} words, expected 300")
    only_voc = sorted(voc_ids - man_ids)
    only_man = sorted(man_ids - voc_ids)
    if only_voc:
        errors.append(f"A: {len(only_voc)} vocab word(s) missing from manifest: {only_voc[:8]}")
    if only_man:
        errors.append(f"A: {len(only_man)} manifest word(s) not in vocab: {only_man[:8]}")

    voc_by_id = {v["id"]: v for v in vocab}
    audio_resolved = 0

    for w in words:
        wid = w.get("id", "<no-id>")

        # ---- B: Dart-required keys + types ----
        for k in REQUIRED_STR:
            if not isinstance(w.get(k), str):
                errors.append(f"B: {wid}: missing/invalid string field '{k}'")
        for k in REQUIRED_INT:
            if not isinstance(w.get(k), int):
                errors.append(f"B: {wid}: missing/invalid int field '{k}'")

        # ---- D: audioFile naming ----
        v = voc_by_id.get(wid)
        if v:
            expect = f"{wid}_{safe_word(v['word'])}.mp3"
            if w.get("audioFile") != expect:
                errors.append(f"D: {wid}: audioFile '{w.get('audioFile')}' != expected '{expect}'")

        # ---- C + E: bundled asset exists & non-stub (+ web/nginx twin) ----
        af = w.get("audioFile")
        lcp = w.get("localCachePath")
        # localCachePath must be the canonical on-device cache key
        if isinstance(af, str) and lcp != f"audio/a1/{af}":
            errors.append(f"C: {wid}: localCachePath '{lcp}' != expected 'audio/a1/{af}'")
        if isinstance(af, str):
            asset_path = os.path.join(ASSETS_AUDIO_A1, af)
            web_path = os.path.join(WEB_AUDIO_A1, af)
            if not os.path.exists(asset_path):
                errors.append(f"C: {wid}: missing bundled asset -> assets/audio/a1/{af}")
            else:
                audio_resolved += 1
                if w.get("status") == "ready" and os.path.getsize(asset_path) < 1000:
                    errors.append(f"E: {wid}: status=ready but bundled MP3 is "
                                  f"{os.path.getsize(asset_path)} bytes (stub?)")
            if not os.path.exists(web_path):
                errors.append(f"C: {wid}: missing nginx twin -> web/audio/a1/{af}")

    # ---- F: orphaned web/public removed ----
    if os.path.isdir(WEB_PUBLIC):
        errors.append("F: orphaned web/public/ duplicate tree still exists (should be removed)")

    print(f"Manifest words       : {len(words)} (vocab: {len(vocab)})")
    print(f"Bundled MP3s resolved: {audio_resolved}/{len(words)}")
    print(f"Ready count          : {sum(1 for w in words if w.get('status') == 'ready')}")

    if errors:
        print(f"\nFAILED — {len(errors)} broken contract(s):")
        for e in errors[:40]:
            print(f"  - {e}")
        if len(errors) > 40:
            print(f"  ... and {len(errors) - 40} more")
        return 1

    print("\nOK — native audio manifest: 300 words, Dart-schema-valid, all bundled.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

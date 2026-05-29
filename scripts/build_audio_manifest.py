#!/usr/bin/env python3
"""
scripts/build_audio_manifest.py
ENG Quest — Rebuild the native-app audio manifest for ALL 300 A1 words.

Why this exists
---------------
The standalone web demo (web/index.html) already ships 300 Neural2 MP3s in
web/audio/. The *native* Flutter app, however, only knew about the first 30
words via assets/content/audio_manifest.json — so 270/300 words fell back to
robotic on-device TTS, weakening the pronunciation-acquisition thesis the MVP
validates.

Worse, the committed manifest entries used a `webPath` key but omitted
`storagePath`, which lib/core/audio/tts_service.dart parses as a *required*
non-null String — i.e. AudioManifest.fromJson would throw at app startup.

This script makes the native manifest the single source of truth for all 300
words, with a schema that exactly matches AudioManifestEntry.fromJson:

  id, word, ipa, audioFile, storagePath, localCachePath, status, syllableCount
  (plus webPath / fileSizeBytes / ttsVoice as informational extras)

It also mirrors the already-generated MP3s from web/audio/ into the two
locations the native app + nginx serve from:

  assets/audio/a1/{id}_{word}.mp3   (Flutter bundled asset — pubspec)
  web/audio/a1/{id}_{word}.mp3      (manifest webPath, served by nginx)

No TTS API call is made: the audio already exists. This is a pure
re-packaging + manifest-schema-fix step. Idempotent.

Run:  python3 scripts/build_audio_manifest.py
"""
from __future__ import annotations

import json
import os
import re
import shutil
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
VOCAB = REPO / "src" / "data" / "content_db" / "vocab_a1_300.json"
MANIFEST = REPO / "assets" / "content" / "audio_manifest.json"
ASSETS_AUDIO = REPO / "assets" / "audio" / "a1"
WEB_AUDIO_A1 = REPO / "web" / "audio" / "a1"
WEB_AUDIO_FLAT = REPO / "web" / "audio"  # 300 flat MP3s (demo source of truth)

STORAGE_BASE = "gs://engquest-audio/tts/a1/"
TTS_VOICE = "en-US-Neural2-C"


def safe_word(word: str) -> str:
    """Mirror index.html / verify_web_demo_assets.py naming."""
    return word.replace(" ", "_")


def estimate_syllables(word: str) -> int:
    """Cheap English syllable estimate (vowel-group heuristic).

    Only used as a fallback for words whose IPA we don't already have.
    Good enough for the manifest's informational `syllableCount` field;
    not used for any pronunciation logic.
    """
    w = word.lower().strip()
    if not w:
        return 1
    groups = re.findall(r"[aeiouy]+", w)
    count = len(groups)
    # Silent trailing 'e' (e.g. "apple" -> keep, "cake" -> drop)
    if w.endswith("e") and not w.endswith(("le", "ée")) and count > 1:
        count -= 1
    return max(1, count)


def load_vocab() -> list[dict]:
    data = json.loads(VOCAB.read_text(encoding="utf-8"))
    return data if isinstance(data, list) else data.get("words", data)


def load_existing_ipa() -> dict[str, dict]:
    """Preserve human-curated ipa/syllableCount from the current manifest."""
    if not MANIFEST.exists():
        return {}
    try:
        m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except Exception:
        return {}
    out = {}
    for w in m.get("words", []):
        out[w["id"]] = {
            "ipa": w.get("ipa", ""),
            "syllableCount": w.get("syllableCount"),
        }
    return out


def main() -> int:
    vocab = load_vocab()
    existing = load_existing_ipa()

    ASSETS_AUDIO.mkdir(parents=True, exist_ok=True)
    WEB_AUDIO_A1.mkdir(parents=True, exist_ok=True)

    words: list[dict] = []
    copied_assets = 0
    copied_web = 0
    missing_src: list[str] = []

    for v in vocab:
        vid = v["id"]
        word = v["word"]
        fname = f"{vid}_{safe_word(word)}.mp3"
        src = WEB_AUDIO_FLAT / fname

        if not src.exists():
            missing_src.append(fname)
            status = "pending"
            size = 0
        else:
            status = "ready"
            size = src.stat().st_size
            # Mirror into Flutter bundled assets
            dst_asset = ASSETS_AUDIO / fname
            if (not dst_asset.exists()) or dst_asset.stat().st_size != size:
                shutil.copy2(src, dst_asset)
                copied_assets += 1
            # Mirror into web/audio/a1 (manifest webPath, served by nginx)
            dst_web = WEB_AUDIO_A1 / fname
            if (not dst_web.exists()) or dst_web.stat().st_size != size:
                shutil.copy2(src, dst_web)
                copied_web += 1

        prev = existing.get(vid, {})
        ipa = prev.get("ipa") or ""
        syl = prev.get("syllableCount") or estimate_syllables(word)

        words.append({
            "id": vid,
            "word": word,
            "ipa": ipa,
            "audioFile": fname,
            "storagePath": f"{STORAGE_BASE}{fname}",
            "localCachePath": f"audio/a1/{fname}",
            "webPath": f"/audio/a1/{fname}",
            "status": status,
            "syllableCount": syl,
            "fileSizeBytes": size,
            "ttsVoice": TTS_VOICE,
        })

    ready = sum(1 for w in words if w["status"] == "ready")

    manifest = {
        "version": "2.0.0",
        "generated": date.today().isoformat(),
        "description": "ENG Quest A1 vocabulary TTS audio manifest (all 300 words)",
        "ttsProvider": "google-cloud-tts",
        "ttsVoice": TTS_VOICE,
        "ttsSampleRate": 24000,
        "audioFormat": "mp3",
        "speakingRate": 0.85,
        "storageBase": STORAGE_BASE,
        "totalWords": len(words),
        "readyCount": ready,
        "words": words,
    }

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Manifest words      : {len(words)}")
    print(f"Ready (have audio)  : {ready}")
    print(f"Copied -> assets    : {copied_assets}")
    print(f"Copied -> web/a1    : {copied_web}")
    if missing_src:
        print(f"MISSING source MP3s : {len(missing_src)} -> {missing_src[:8]}")
        return 1
    print("OK — native manifest now covers all 300 words with correct schema.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

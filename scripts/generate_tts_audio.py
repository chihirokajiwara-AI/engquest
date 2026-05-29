#!/usr/bin/env python3
"""
scripts/generate_tts_audio.py
ENG Quest — Batch generate word audio via Google Cloud TTS API

Usage:
  export GOOGLE_TTS_API_KEY=AIzaSy...
  python3 scripts/generate_tts_audio.py

Output:
  - MP3 files in assets/audio/a1/{vocabId}_{word}.mp3
  - Updates assets/content/audio_manifest.json (status: pending → ready)
  - Upload to Firebase Storage: gs://engquest-audio/tts/a1/

Cost: ~$0.0006 for all 30 A1 seed words (Neural2 voice)
Requirements: pip install requests

Voice: en-US-Neural2-C (natural female, child-friendly, slower pace for learners)
"""

import json
import os
import sys
import base64
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("❌ Missing dependency: pip install requests")
    sys.exit(1)

# ── Config ────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).parent.parent
MANIFEST_PATH = REPO_ROOT / "assets" / "content" / "audio_manifest.json"
AUDIO_OUTPUT_DIR = REPO_ROOT / "assets" / "audio" / "a1"

GOOGLE_TTS_API_KEY = os.environ.get("GOOGLE_TTS_API_KEY")
GOOGLE_TTS_ENDPOINT = "https://texttospeech.googleapis.com/v1/text:synthesize"

TTS_CONFIG = {
    "voice": {
        "languageCode": "en-US",
        "name": "en-US-Neural2-C",
        "ssmlGender": "FEMALE",
    },
    "audioConfig": {
        "audioEncoding": "MP3",
        "sampleRateHertz": 24000,
        "speakingRate": 0.85,  # Slower for children learning
        "pitch": 0.0,
        "effectsProfileId": ["small-bluetooth-speaker-class-device"],
    },
}

# ── Rate limiting ──────────────────────────────────────────────────────────────

REQUESTS_PER_MINUTE = 30  # Google TTS free tier: 300/min; staying conservative
SLEEP_BETWEEN_REQUESTS = 60 / REQUESTS_PER_MINUTE  # 2 seconds


# ── Main ───────────────────────────────────────────────────────────────────────

def generate_audio(word: str) -> bytes | None:
    """Call Google TTS API and return MP3 bytes."""
    if not GOOGLE_TTS_API_KEY:
        print("❌ GOOGLE_TTS_API_KEY not set. Export it first.")
        return None

    payload = {
        "input": {"text": word},
        **TTS_CONFIG,
    }

    try:
        url = f"{GOOGLE_TTS_ENDPOINT}?key={GOOGLE_TTS_API_KEY}"
        resp = requests.post(url, json=payload, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        audio_b64 = data.get("audioContent", "")
        if not audio_b64:
            print(f"  ⚠️  Empty audioContent for '{word}'")
            return None
        return base64.b64decode(audio_b64)
    except requests.HTTPError as e:
        print(f"  ❌ API error for '{word}': {e.response.status_code} {e.response.text[:200]}")
        return None
    except Exception as e:
        print(f"  ❌ Error for '{word}': {e}")
        return None


def main():
    print("🎵 ENG Quest — TTS Audio Generator")
    print(f"   Manifest: {MANIFEST_PATH}")
    print(f"   Output:   {AUDIO_OUTPUT_DIR}")
    print()

    if not GOOGLE_TTS_API_KEY:
        print("❌ GOOGLE_TTS_API_KEY not set.")
        print("   export GOOGLE_TTS_API_KEY=AIzaSy...")
        print()
        print("📋 Dry run mode — listing words that would be generated:")
        manifest = json.loads(MANIFEST_PATH.read_text())
        for word_entry in manifest["words"]:
            status = word_entry["status"]
            icon = "✅" if status == "ready" else "⏳"
            print(f"  {icon} {word_entry['id']:15s} {word_entry['word']:12s} {word_entry['ipa']}")
        print()
        print(f"Total: {len(manifest['words'])} words")
        return

    # Load manifest
    manifest = json.loads(MANIFEST_PATH.read_text())
    words = manifest["words"]

    # Create output directory
    AUDIO_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    generated = 0
    skipped = 0
    failed = 0

    for i, word_entry in enumerate(words, 1):
        vocab_id = word_entry["id"]
        word = word_entry["word"]
        audio_file = word_entry["audioFile"]
        output_path = AUDIO_OUTPUT_DIR / audio_file

        print(f"[{i:2d}/{len(words)}] {vocab_id}: '{word}' ({word_entry['ipa']})")

        # Skip if already generated
        if output_path.exists() and output_path.stat().st_size > 1000:
            print(f"         ✅ Already exists ({output_path.stat().st_size} bytes) — skip")
            word_entry["status"] = "ready"
            skipped += 1
            continue

        # Generate
        audio_bytes = generate_audio(word)
        if audio_bytes is None:
            word_entry["status"] = "failed"
            failed += 1
            continue

        # Save MP3
        output_path.write_bytes(audio_bytes)
        word_entry["status"] = "ready"
        generated += 1
        print(f"         ✅ Generated: {len(audio_bytes):,} bytes → {audio_file}")

        # Rate limit
        if i < len(words):
            time.sleep(SLEEP_BETWEEN_REQUESTS)

    # Update manifest with new statuses
    manifest["words"] = words
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))

    print()
    print("─" * 50)
    print(f"✅ Generated: {generated}")
    print(f"⏭️  Skipped:   {skipped}")
    print(f"❌ Failed:    {failed}")
    print()
    print("Next steps:")
    print("  1. Upload to Firebase Storage:")
    print("     gsutil -m cp assets/audio/a1/*.mp3 gs://engquest-audio/tts/a1/")
    print("  2. Update pubspec.yaml if adding audioplayers dependency")
    print("  3. Test playback in BattleScreen")


if __name__ == "__main__":
    main()

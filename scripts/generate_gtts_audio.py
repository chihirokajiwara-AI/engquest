#!/usr/bin/env python3
"""
scripts/generate_gtts_audio.py
ENG Quest — Generate native pronunciation MP3s for ALL 300 A1 words.

Why gTTS (Google Translate TTS) instead of Cloud TTS Neural2?
  The Cloud Text-to-Speech API is disabled on the available GCP project and
  the service account cannot enable it. gTTS uses Google Translate's public
  TTS endpoint — real Google voice, no API key / project / billing required.
  This eliminates the robotic browser Web-Speech fallback for all 300 words
  (previously only 50 had real audio; 250 fell back to SpeechSynthesis).

Output naming MUST match web/index.html -> playPronunciation():
    audio/{id}_{word_with_spaces_as_underscores}.mp3
  e.g. eiken5_046_ice_cream.mp3

Usage:
    pip install gTTS
    python3 scripts/generate_gtts_audio.py

Idempotent: skips files that already exist (>1KB). Retries 3x per word.
"""
import json
import os
import sys
import time
from pathlib import Path

try:
    from gtts import gTTS
except ImportError:
    print("Missing dependency: pip install gTTS")
    sys.exit(1)

REPO_ROOT = Path(__file__).parent.parent
VOCAB_PATH = REPO_ROOT / "src" / "data" / "content_db" / "vocab_a1_300.json"
AUDIO_DIR = REPO_ROOT / "web" / "audio"


def load_words():
    data = json.loads(VOCAB_PATH.read_text())
    if isinstance(data, dict):
        for key in ("words", "items"):
            if key in data:
                return data[key]
        # fallback: first list value
        for v in data.values():
            if isinstance(v, list):
                return v
    return data


def main():
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    words = load_words()
    generated = skipped = failed = 0
    errors = []

    for item in words:
        wid = item["id"]
        word = item["word"]
        fname = f"{wid}_{word.replace(' ', '_')}.mp3"
        path = AUDIO_DIR / fname

        if path.exists() and path.stat().st_size > 1000:
            skipped += 1
            continue

        ok = False
        last_err = ""
        for _ in range(3):
            try:
                gTTS(word, lang="en", tld="com", slow=False).save(str(path))
                if path.stat().st_size < 500:
                    raise ValueError("file too small")
                ok = True
                break
            except Exception as e:  # noqa: BLE001
                last_err = str(e)[:100]
                time.sleep(1.0)

        if ok:
            generated += 1
            time.sleep(0.15)  # polite to the public endpoint
        else:
            failed += 1
            errors.append((wid, word, last_err))

    print(f"Generated={generated} Skipped={skipped} Failed={failed}")
    total = len([f for f in os.listdir(AUDIO_DIR) if f.endswith(".mp3")])
    print(f"Total MP3 in web/audio: {total}")
    for e in errors[:20]:
        print("ERR", e)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

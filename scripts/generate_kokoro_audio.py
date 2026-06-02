#!/usr/bin/env python3
"""
A-KEN Quest — Batch audio generation using Kokoro TTS (local, ¥0)

Generates pronunciation audio for all Eiken vocabulary.
Output: assets/audio/{grade}/{vocab_id}_{word}.mp3

Usage:
    python3 scripts/generate_kokoro_audio.py                    # all grades
    python3 scripts/generate_kokoro_audio.py --grade eiken2     # single grade
    python3 scripts/generate_kokoro_audio.py --dry-run          # count only
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_AUDIO = PROJECT_ROOT / "assets" / "audio"
ASSETS_DATA = PROJECT_ROOT / "assets" / "data"
# Also check lib/data/content for .dart vocab files
LIB_CONTENT = PROJECT_ROOT / "lib" / "data" / "content"

GRADE_FILES = {
    "eiken5": ASSETS_DATA / "eiken5_vocab.json",
    "eiken4": ASSETS_DATA / "eiken4_vocab.json",
    "eiken3": ASSETS_DATA / "eiken3_vocab.json",
    "eiken_pre2": ASSETS_DATA / "eiken_pre2_vocab.json",
    "eiken2": ASSETS_DATA / "eiken2_vocab.json",
    "eiken_pre1": ASSETS_DATA / "eiken_pre1_vocab.json",
}

def load_vocab(grade: str) -> list[dict]:
    """Load vocabulary from JSON file."""
    path = GRADE_FILES.get(grade)
    if not path or not path.exists():
        print(f"[WARN] {grade}: file not found at {path}")
        return []
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    # Handle both formats: list or dict with "words" key
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and "words" in data:
        return data["words"]
    return []

def sanitize_filename(word: str) -> str:
    """Make word safe for filesystem."""
    return word.lower().replace(" ", "_").replace("'", "").replace("/", "_").replace("\\", "_")

def generate_audio_for_grade(grade: str, pipeline, voice: str, dry_run: bool = False):
    """Generate audio for all words in a grade."""
    import soundfile as sf
    import numpy as np

    words = load_vocab(grade)
    if not words:
        print(f"[{grade}] No vocabulary found")
        return 0, 0

    out_dir = ASSETS_AUDIO / grade
    out_dir.mkdir(parents=True, exist_ok=True)

    total = len(words)
    generated = 0
    skipped = 0

    for i, entry in enumerate(words):
        word = entry.get("english", entry.get("word", ""))
        vocab_id = entry.get("id", f"{grade}_{i+1:03d}")

        if not word:
            continue

        safe_word = sanitize_filename(word)
        out_file = out_dir / f"{vocab_id}_{safe_word}.mp3"

        # Skip if already exists
        if out_file.exists() and out_file.stat().st_size > 100:
            skipped += 1
            continue

        if dry_run:
            generated += 1
            continue

        try:
            # Generate with Kokoro: word spoken twice (clear pronunciation)
            text = f"{word}. {word}."
            audio_segments = []
            for gs, ps, audio in pipeline(text, voice=voice):
                audio_segments.append(audio)
                break  # first segment only

            if audio_segments:
                audio_data = audio_segments[0]
                # Save as WAV first, then convert concept
                wav_path = out_file.with_suffix(".wav")
                sf.write(str(wav_path), audio_data, 24000)

                # Convert to MP3 using ffmpeg if available
                mp3_result = os.system(
                    f'ffmpeg -y -i "{wav_path}" -codec:a libmp3lame -qscale:a 6 -ar 24000 "{out_file}" -loglevel quiet 2>/dev/null'
                )
                if mp3_result == 0 and out_file.exists():
                    wav_path.unlink()  # remove WAV
                else:
                    # ffmpeg not available or failed — rename WAV
                    wav_path.rename(out_file.with_suffix(".wav"))
                    out_file = out_file.with_suffix(".wav")

                generated += 1

            if (i + 1) % 50 == 0:
                print(f"  [{grade}] {i+1}/{total} ({generated} generated, {skipped} skipped)")

        except Exception as e:
            print(f"  [{grade}] ERROR for '{word}': {e}")

    print(f"[{grade}] Complete: {generated} generated, {skipped} skipped, {total} total")
    return generated, skipped

def main():
    parser = argparse.ArgumentParser(description="Generate Kokoro TTS audio for A-KEN Quest")
    parser.add_argument("--grade", choices=list(GRADE_FILES.keys()), help="Single grade to generate")
    parser.add_argument("--voice", default="af_heart", help="Kokoro voice (default: af_heart)")
    parser.add_argument("--dry-run", action="store_true", help="Count words without generating")
    args = parser.parse_args()

    grades = [args.grade] if args.grade else list(GRADE_FILES.keys())

    # Dry run: just count
    if args.dry_run:
        total_need = 0
        for grade in grades:
            words = load_vocab(grade)
            out_dir = ASSETS_AUDIO / grade
            existing = len(list(out_dir.glob("*.*"))) if out_dir.exists() else 0
            need = len(words) - existing
            print(f"[{grade}] {len(words)} words, {existing} existing, {need} to generate")
            total_need += max(0, need)
        print(f"\nTotal to generate: {total_need}")
        return

    # Initialize Kokoro
    print("Initializing Kokoro TTS...")
    from kokoro import KPipeline
    pipeline = KPipeline(lang_code='a')  # American English
    print(f"Ready. Voice: {args.voice}")

    total_gen = 0
    total_skip = 0
    start = time.time()

    for grade in grades:
        print(f"\n{'='*50}")
        print(f"Generating: {grade}")
        print(f"{'='*50}")
        gen, skip = generate_audio_for_grade(grade, pipeline, args.voice)
        total_gen += gen
        total_skip += skip

    elapsed = time.time() - start
    print(f"\n{'='*50}")
    print(f"COMPLETE: {total_gen} generated, {total_skip} skipped in {elapsed:.1f}s")
    print(f"Output: {ASSETS_AUDIO}/")

if __name__ == "__main__":
    main()

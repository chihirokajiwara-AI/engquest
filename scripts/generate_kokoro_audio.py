#!/usr/bin/env python3
"""
A-KEN Quest — Batch audio generation using Kokoro TTS (local, ¥0)

Multi-segment learning audio (CEO-approved format, 2026-06-02):
  Upper grades (準2/2/準1) — 7 segments:
    word(0.7) | silence | word(1.0) | silence | "{word} means {def}."(1.0) | silence | example(1.0)
  Lower grades (5/4/3) — 5 segments:
    word(0.7) | silence | word(1.0) | silence | example(1.0)
  silence = 0.5s (numpy.zeros(12000) @ 24kHz)

Output: assets/audio/{grade}/{vocab_id}_{sanitized_word}.mp3

Usage:
    python3 scripts/generate_kokoro_audio.py                 # all grades (regenerate)
    python3 scripts/generate_kokoro_audio.py --grade eiken2  # single grade
    python3 scripts/generate_kokoro_audio.py --grade eiken_pre1 --limit 3   # test first 3
    python3 scripts/generate_kokoro_audio.py --dry-run
"""

import argparse
import json
import os
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_AUDIO = PROJECT_ROOT / "assets" / "audio"
ASSETS_DATA = PROJECT_ROOT / "assets" / "data"

GRADE_FILES = {
    "eiken5": ASSETS_DATA / "eiken5_vocab.json",
    "eiken4": ASSETS_DATA / "eiken4_vocab.json",
    "eiken3": ASSETS_DATA / "eiken3_vocab.json",
    "eiken_pre2": ASSETS_DATA / "eiken_pre2_vocab.json",
    "eiken2": ASSETS_DATA / "eiken2_vocab.json",
    "eiken_pre1": ASSETS_DATA / "eiken_pre1_vocab.json",
}
UPPER = {"eiken_pre2", "eiken2", "eiken_pre1"}
SAMPLE_RATE = 24000

# Words whose underscore suffix is a POS/category disambiguation TAG (strip it).
# All other underscore words are real phrases -> underscores become spaces.
SPOKEN_OVERRIDE = {
    "back_dir": "back", "bag_clothing": "bag", "bag_dl": "bag", "bicycle_tr": "bicycle",
    "clean_verb": "clean", "drink_noun": "drink", "game_sport": "game", "hard_adj": "hard",
    "lesson_music": "lesson", "music_hobby": "music", "no_adj": "no", "park_play": "park",
    "station_tr": "station", "walk_tr": "walk", "card_game": "card game",
}


def load_vocab(grade):
    path = GRADE_FILES.get(grade)
    if not path or not path.exists():
        print(f"[WARN] {grade}: file not found at {path}")
        return []
    data = json.load(open(path, encoding="utf-8"))
    return data["words"] if isinstance(data, dict) and "words" in data else (data if isinstance(data, list) else [])


def sanitize_filename(word):
    return word.lower().replace(" ", "_").replace("'", "").replace("/", "_").replace("\\", "_")


def spoken_word(word):
    if word in SPOKEN_OVERRIDE:
        return SPOKEN_OVERRIDE[word]
    return word.replace("_", " ")


def synth(pipeline, text, voice, speed):
    import numpy as np
    chunks = []
    for _, _, audio in pipeline(text, voice=voice, speed=speed):
        a = audio.detach().cpu().numpy() if hasattr(audio, "detach") else np.asarray(audio)
        chunks.append(a.astype(np.float32))
    return np.concatenate(chunks) if chunks else None


def build_audio(pipeline, entry, grade, voice, silence):
    import numpy as np
    sw = spoken_word(entry.get("word", ""))
    if not sw:
        return None
    ex = (entry.get("exampleSentences") or [""])[0].strip()
    parts = [synth(pipeline, sw, voice, 0.7), silence, synth(pipeline, sw, voice, 1.0), silence]
    if grade in UPPER:
        d = (entry.get("englishDefinition") or "").strip()
        if d:
            parts += [synth(pipeline, f"{sw} means {d}.", voice, 1.0), silence]
    if ex:
        parts += [synth(pipeline, ex, voice, 1.0)]
    parts = [p for p in parts if p is not None]
    return np.concatenate(parts) if parts else None


def generate_for_grade(grade, pipeline, voice, limit=None):
    import soundfile as sf
    import numpy as np
    silence = np.zeros(int(SAMPLE_RATE * 0.5), dtype=np.float32)

    words = load_vocab(grade)
    if limit:
        words = words[:limit]
    if not words:
        print(f"[{grade}] no vocabulary")
        return 0, 0
    out_dir = ASSETS_AUDIO / grade
    out_dir.mkdir(parents=True, exist_ok=True)

    total, gen, err = len(words), 0, 0
    for i, entry in enumerate(words):
        word = entry.get("word", "")
        vocab_id = entry.get("id", f"{grade}_{i+1:04d}")
        if not word:
            continue
        out_file = out_dir / f"{vocab_id}_{sanitize_filename(word)}.mp3"
        try:
            audio = build_audio(pipeline, entry, grade, voice, silence)
            if audio is None:
                err += 1
                continue
            wav = out_file.with_suffix(".wav")
            sf.write(str(wav), audio, SAMPLE_RATE)
            rc = os.system(f'ffmpeg -y -i "{wav}" -codec:a libmp3lame -qscale:a 5 -ar {SAMPLE_RATE} "{out_file}" -loglevel quiet')
            if rc == 0 and out_file.exists():
                wav.unlink()
                gen += 1
            else:
                err += 1
        except Exception as e:
            err += 1
            print(f"  [{grade}] ERROR '{word}': {e}")
        if (i + 1) % 100 == 0:
            print(f"  [{grade}] {i+1}/{total} ({gen} ok, {err} err)")
    print(f"[{grade}] done: {gen} generated, {err} errors, {total} total")
    return gen, err


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--grade", choices=list(GRADE_FILES.keys()))
    p.add_argument("--voice", default="af_heart")
    p.add_argument("--limit", type=int, default=None)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    grades = [args.grade] if args.grade else list(GRADE_FILES.keys())

    if args.dry_run:
        for g in grades:
            print(f"[{g}] {len(load_vocab(g))} words")
        return

    print("Initializing Kokoro TTS...")
    from kokoro import KPipeline
    pipeline = KPipeline(lang_code="a")  # American English
    print(f"Ready. Voice: {args.voice}, format: multi-segment")

    start, tot_g, tot_e = time.time(), 0, 0
    for g in grades:
        print(f"\n{'='*50}\n{g}\n{'='*50}")
        gg, ee = generate_for_grade(g, pipeline, args.voice, args.limit)
        tot_g += gg
        tot_e += ee
    print(f"\nCOMPLETE: {tot_g} generated, {tot_e} errors in {time.time()-start:.0f}s")


if __name__ == "__main__":
    main()

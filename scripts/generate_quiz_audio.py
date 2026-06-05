#!/usr/bin/env python3
"""
A-KEN Quest — quiz LINE + OPTION audio (Kokoro TTS) for the ドラクエ quest.

The grammar/応答 quizzes are read aloud so a child HEARS the English, not just
reads it (CEO directive 2026-06-05): the question is read normally + a 🔊 replay
button; every answer option plays its own clip when tapped. Cloze (穴埋め) lines
keep a `___` blank, rendered here as a short SILENCE so the question never gives
the answer away.

Input manifest comes from `tool/dump_quiz_audio.dart` (shares the runtime slug,
so keys can't drift). Output: assets/audio/quiz/<key>.mp3 (whole utterance, slow
then natural). Connected speech only — NO phonemes (founder's job).

Usage:
    # regenerate the manifest, then the clips (英検5級):
    dart run tool/dump_quiz_audio.dart > /tmp/quiz_manifest.json
    python3 scripts/generate_quiz_audio.py /tmp/quiz_manifest.json
    python3 scripts/generate_quiz_audio.py /tmp/quiz_manifest.json --dry-run

Run under scripts/safe-job.sh (Kokoro is CPU-heavy).
"""

import argparse
import json
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
OUT_DIR = PROJECT_ROOT / "assets" / "audio" / "quiz"
SAMPLE_RATE = 24000


def synth(pipeline, text, voice, speed):
    import numpy as np
    chunks = []
    for _, _, audio in pipeline(text, voice=voice, speed=speed):
        a = audio.detach().cpu().numpy() if hasattr(audio, "detach") else np.asarray(audio)
        chunks.append(a.astype(np.float32))
    return np.concatenate(chunks) if chunks else None


def build_line(pipeline, text, voice, gap):
    """Whole utterance slow then natural. `___` cloze blanks become a silent gap
    so a read-aloud cloze question never voices the answer."""
    import numpy as np

    def render(speed):
        parts = []
        segments = [s.strip() for s in text.split("___")]
        for i, seg in enumerate(segments):
            if seg:
                s = synth(pipeline, seg, voice, speed)
                if s is not None:
                    parts.append(s)
            if i < len(segments) - 1:
                parts.append(gap)  # audible blank
        return [p for p in parts if p is not None]

    parts = render(0.85) + [gap] + render(1.0)
    return np.concatenate(parts) if parts else None


def write_mp3(audio, out_file):
    import os
    import soundfile as sf
    wav = out_file.with_suffix(".wav")
    sf.write(str(wav), audio, SAMPLE_RATE)
    rc = os.system(
        f'ffmpeg -y -i "{wav}" -codec:a libmp3lame -qscale:a 5 '
        f'-ar {SAMPLE_RATE} "{out_file}" -loglevel quiet'
    )
    ok = rc == 0 and out_file.exists()
    if ok:
        wav.unlink()
    return ok


def main():
    p = argparse.ArgumentParser()
    p.add_argument("manifest", help="JSON from tool/dump_quiz_audio.dart")
    p.add_argument("--voice", default="af_heart")
    p.add_argument("--limit", type=int, default=None)
    p.add_argument("--only", default=None, help="substring filter on the key")
    p.add_argument("--force", action="store_true", help="re-render existing clips")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    items = json.loads(Path(args.manifest).read_text())
    if args.only:
        items = [it for it in items if args.only in it["key"]]
    if args.limit:
        items = items[: args.limit]

    if args.dry_run:
        print(f"[quiz] {len(items)} clips planned:")
        for it in items:
            print(f"  {it['key']:42s}  «{it['text']}»")
        return

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print("Initializing Kokoro TTS...")
    from kokoro import KPipeline
    import numpy as np
    pipeline = KPipeline(lang_code="a")
    gap = np.zeros(int(SAMPLE_RATE * 0.5), dtype=np.float32)
    print(f"Ready. Voice: {args.voice}. Output: {OUT_DIR}")

    start, gen, skip, err = time.time(), 0, 0, 0
    for it in items:
        out_file = OUT_DIR / f"{it['key']}.mp3"
        if out_file.exists() and not args.force:
            skip += 1
            continue
        try:
            audio = build_line(pipeline, it["text"], args.voice, gap)
            if audio is not None and write_mp3(audio, out_file):
                gen += 1
                print(f"  ok  {it['key']}")
            else:
                err += 1
                print(f"  ERR {it['key']} (synth/encode failed)")
        except Exception as e:  # noqa: BLE001
            err += 1
            print(f"  ERR {it['key']}: {e}")
    print(f"\nDONE: {gen} generated, {skip} skipped, {err} errors "
          f"in {time.time()-start:.0f}s")


if __name__ == "__main__":
    main()

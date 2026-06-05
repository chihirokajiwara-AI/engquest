#!/usr/bin/env python3
"""
A-KEN Quest — 英検5級『言葉を失った村』BLEND / WORD / PHRASE audio (Kokoro TTS).

Generates the segmented blend clips, whole words, and short phrases for the
phonics stage into assets/audio/phonics/. Reuses the existing Kokoro multi-segment
format from generate_kokoro_audio.py.

DOES NOT generate PHONEMES. Pure isolated phonemes (phoneme_s.mp3 etc.) cannot be
made by TTS without a trailing schwa (it would teach "tuh"/"kuh", which breaks
blending) — per the hardened spec those are generated with espeak-ng + a human
ear-QA / hand-recording pass, owned by the founder. This script leaves them alone.

Output files (asset KEYS referenced by quest_data.dart):
  blend_*.mp3   — segmented "c … a … t …… cat" (letters slow, then whole word)
  phrase_*.mp3  — "a red cat" / "Hello!" etc. (whole phrase, twice)

Usage:
    python3 scripts/generate_phonics_audio.py            # generate all
    python3 scripts/generate_phonics_audio.py --dry-run  # list planned files
    python3 scripts/generate_phonics_audio.py --limit 3  # first 3 (smoke test)

Run under scripts/safe-job.sh on the heavy-job host (Kokoro is CPU-heavy).
"""

import argparse
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
OUT_DIR = PROJECT_ROOT / "assets" / "audio" / "phonics"
SAMPLE_RATE = 24000

# CVC words on the 英検5級 syllabus (verified in eiken5_vocab.json) + the
# minimal-pair distractors the steps use (cap/dig/sit). Each entry: (key, letters).
# `letters` drives the slow segmented "c … a … t" pass before the blended word.
BLENDS = {
    # nonsense blending-practice syllable (Phase A′) — NOT vocab
    "sat": ["s", "a", "t"],
    # Phase B real 5級 CVC words
    "cat": ["c", "a", "t"],
    "dog": ["d", "o", "g"],
    "sun": ["s", "u", "n"],
    "box": ["b", "o", "x"],
    "bag": ["b", "a", "g"],
    "bed": ["b", "e", "d"],
    "big": ["b", "i", "g"],
    "bad": ["b", "a", "d"],
    "pen": ["p", "e", "n"],
    "man": ["m", "a", "n"],
    "hat": ["h", "a", "t"],
    "top": ["t", "o", "p"],
    "hot": ["h", "o", "t"],
    "bus": ["b", "u", "s"],
    "run": ["r", "u", "n"],
    "red": ["r", "e", "d"],
    "fox": ["f", "o", "x"],
    # minimal-pair distractors used by the authored steps
    "cap": ["c", "a", "p"],
    "dig": ["d", "i", "g"],
    "sit": ["s", "i", "t"],
}

# Short phrases (whole-phrase clips, said twice with a gap).
PHRASES = {
    "a_red_cat": "a red cat",
    "i_see_a_dog": "I see a dog.",
    "hello": "Hello!",
    "im_fine": "I'm fine.",
    "thank_you": "Thank you.",
}

# Letter -> a syllable Kokoro pronounces as the SOUND, not the letter-name, for
# the slow segmented sweep. (These are deliberate sound exemplars; the pure
# isolated phonemes themselves are the founder's espeak-ng/recorded job.)
LETTER_SOUND = {
    "a": "ah", "e": "eh", "i": "ih", "o": "oh", "u": "uh",
    "b": "buh", "c": "kuh", "d": "duh", "f": "fff", "g": "guh",
    "h": "huh", "m": "mmm", "n": "nnn", "p": "puh", "r": "rrr",
    "s": "sss", "t": "tuh", "x": "ks",
}


def synth(pipeline, text, voice, speed):
    import numpy as np
    chunks = []
    for _, _, audio in pipeline(text, voice=voice, speed=speed):
        a = audio.detach().cpu().numpy() if hasattr(audio, "detach") else np.asarray(audio)
        chunks.append(a.astype(np.float32))
    return np.concatenate(chunks) if chunks else None


def build_blend(pipeline, letters, word, voice, silence):
    """Segmented: each letter-sound slow, then the whole word slow, then natural."""
    import numpy as np
    parts = []
    for ch in letters:
        seg = synth(pipeline, LETTER_SOUND.get(ch, ch), voice, 0.6)
        if seg is not None:
            parts += [seg, silence]
    parts += [synth(pipeline, word, voice, 0.7), silence]   # blended, slow
    parts += [synth(pipeline, word, voice, 1.0)]            # natural
    parts = [p for p in parts if p is not None]
    return np.concatenate(parts) if parts else None


def build_phrase(pipeline, text, voice, silence):
    """Whole phrase, slow then natural."""
    import numpy as np
    parts = [synth(pipeline, text, voice, 0.8), silence, synth(pipeline, text, voice, 1.0)]
    parts = [p for p in parts if p is not None]
    return np.concatenate(parts) if parts else None


def write_mp3(audio, out_file):
    import soundfile as sf
    import os
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


def planned():
    items = [(f"blend_{k}.mp3", "blend", k, v) for k, v in BLENDS.items()]
    items += [(f"phrase_{k}.mp3", "phrase", v, None) for k, v in PHRASES.items()]
    return items


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--voice", default="af_heart")
    p.add_argument("--limit", type=int, default=None)
    p.add_argument("--only", default=None,
                   help="only generate files whose name contains this substring "
                        "(e.g. --only line_ to regen just the Phase C lines)")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    items = planned()
    if args.only:
        items = [it for it in items if args.only in it[0]]
    if args.limit:
        items = items[: args.limit]

    if args.dry_run:
        print(f"[phonics] {len(items)} clips planned (NO phonemes):")
        for fn, kind, a, b in items:
            print(f"  {fn:24s} ({kind})")
        return

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print("Initializing Kokoro TTS...")
    from kokoro import KPipeline
    import numpy as np
    pipeline = KPipeline(lang_code="a")  # American English
    silence = np.zeros(int(SAMPLE_RATE * 0.45), dtype=np.float32)
    print(f"Ready. Voice: {args.voice}. Output: {OUT_DIR}")

    start, gen, err = time.time(), 0, 0
    for fn, kind, a, b in items:
        out_file = OUT_DIR / fn
        try:
            if kind == "blend":
                audio = build_blend(pipeline, b, a, args.voice, silence)
            else:
                audio = build_phrase(pipeline, a, args.voice, silence)
            if audio is not None and write_mp3(audio, out_file):
                gen += 1
                print(f"  ok  {fn}")
            else:
                err += 1
                print(f"  ERR {fn} (synth/encode failed)")
        except Exception as e:  # noqa: BLE001
            err += 1
            print(f"  ERR {fn}: {e}")
    print(f"\nDONE: {gen} generated, {err} errors in {time.time()-start:.0f}s")
    print("Reminder: phonemes (phoneme_*.mp3) are NOT generated here — "
          "founder records them (espeak-ng draft + ear-QA).")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
A-KEN Quest — Listening item audio (Kokoro TTS) for 英検 Listening sections.

Each ListeningItem carries:
  - transcripts: list of spoken lines
      * 1 line  → single-speaker clip (応答選択 / 文内容一致 prompts)
      * 2+ lines → speaker-alternating dialogue (A / B / A / B …)
        "Question: ..." lines at the end are spoken in a distinct "narrator" voice.

Voices:
  Speaker A  → af_heart  (female, warm — 英検 "Speaker A" convention)
  Speaker B  → am_echo   (male, clear)
  Narrator   → af_sky    (female, measured — question reader)

Output: assets/audio/listening/<key>.mp3
Each clip is synthesized at natural speed (英検 plays at natural pace;
the 🔊 replay button lets children re-listen).

Usage:
    # Full generation (all 52 seed items):
    python3 scripts/generate_listening_audio.py

    # Dry-run — list what would be generated:
    python3 scripts/generate_listening_audio.py --dry-run

    # Only missing items (skip already-generated):
    python3 scripts/generate_listening_audio.py

    # Force-regenerate all:
    python3 scripts/generate_listening_audio.py --force

    # Filter by grade or key prefix:
    python3 scripts/generate_listening_audio.py --only l5

IMPORTANT — run under scripts/safe-job.sh (Kokoro is CPU-heavy):
    scripts/safe-job.sh generate_listening 3600 \\
        python3 scripts/generate_listening_audio.py

After generation, remove the corresponding entries from assets/ALLOWED_MISSING.txt.

R2 contract:
  All keys match assets/audio/listening/<key>.mp3 on disk after a successful run.
  AudioCueService swallows missing-clip errors gracefully until then.
"""

import argparse
import json
import time
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).parent.parent
OUT_DIR = PROJECT_ROOT / "assets" / "audio" / "listening"
SAMPLE_RATE = 24000

VOICE_A        = "af_heart"   # Speaker A / single-speaker items
VOICE_B        = "am_echo"    # Speaker B in dialogues
VOICE_NARRATOR = "af_sky"     # "Question: ..." lines


def _synth(pipeline, text: str, voice: str) -> "np.ndarray | None":
    """Synthesize one utterance. Returns float32 array or None."""
    import numpy as np
    chunks = []
    for _, _, audio in pipeline(text, voice=voice, speed=1.0):
        a = audio.detach().cpu().numpy() if hasattr(audio, "detach") else np.asarray(audio)
        chunks.append(a.astype(np.float32))
    return np.concatenate(chunks) if chunks else None


def _silence(seconds: float) -> "np.ndarray":
    import numpy as np
    return np.zeros(int(SAMPLE_RATE * seconds), dtype=np.float32)


def build_clip(pipeline, transcripts: list[str]) -> "np.ndarray | None":
    """Synthesize one ListeningItem into a single audio array.

    Rules:
    - 1-line items → single voice (VOICE_A), natural speed.
    - Multi-line items → alternate A/B, except lines starting 'Question:'
      which always use VOICE_NARRATOR.
    - 0.5s gap between turns; 0.7s after the last content line before Question.
    """
    import numpy as np
    import re
    parts: list["np.ndarray"] = []
    gap_turn    = _silence(0.5)   # between dialogue turns
    gap_q       = _silence(0.7)   # before the "Question:" line
    gap_post_q  = _silence(0.3)   # after Question, before end

    if len(transcripts) == 1:
        seg = _synth(pipeline, transcripts[0], VOICE_A)
        if seg is not None:
            parts.append(seg)
    else:
        content_lines   = [t for t in transcripts if not t.startswith("Question:")]
        question_lines  = [t for t in transcripts if t.startswith("Question:")]

        for i, line in enumerate(content_lines):
            voice = VOICE_A if i % 2 == 0 else VOICE_B
            # Drop the textual speaker label ("A: " / "B: "). The two distinct
            # voices already mark who is speaking; real 英検 never announces "A"/
            # "B", so synthesizing the label spoke a spurious "ay"/"bee" before
            # every turn. (Question: lines are handled separately below.)
            clean = re.sub(r'^[A-Za-z]:\s+', '', line)
            seg = _synth(pipeline, clean, voice)
            if seg is not None:
                parts.append(seg)
            if i < len(content_lines) - 1:
                parts.append(gap_turn)

        for q_line in question_lines:
            parts.append(gap_q)
            # Strip "Question: " prefix for cleaner TTS pronunciation
            q_text = q_line.removeprefix("Question: ")
            seg = _synth(pipeline, q_text, VOICE_NARRATOR)
            if seg is not None:
                parts.append(seg)
            parts.append(gap_post_q)

    return np.concatenate(parts) if parts else None


def write_mp3(audio, out_file: Path) -> bool:
    """Write float32 audio to mp3 via soundfile + ffmpeg."""
    import os
    import soundfile as sf
    wav = out_file.with_suffix(".wav")
    sf.write(str(wav), audio, SAMPLE_RATE)
    rc = os.system(
        f'ffmpeg -y -i "{wav}" -codec:a libmp3lame -qscale:a 2 '
        f'-ar {SAMPLE_RATE} "{out_file}" -loglevel quiet'
    )
    ok = rc == 0 and out_file.exists()
    if ok:
        wav.unlink(missing_ok=True)
    return ok


def collect_items() -> list[dict]:
    """Load the seed manifest by importing the Dart data as a Python literal.

    We parse the listening_data.dart statically: the audioKey and transcripts
    fields are the only values we need and they appear as string literals.
    This keeps the generation script self-contained (no Dart toolchain needed).
    """
    dart_file = PROJECT_ROOT / "lib" / "features" / "exam_practice" / "listening_data.dart"
    src = dart_file.read_text(encoding="utf-8")

    import re
    # Extract ListeningItem(…) blocks from the Dart source.
    # We want audioKey and transcripts for each item.
    items = []
    # Match each ListeningItem constructor
    block_re = re.compile(
        r"ListeningItem\s*\("
        r".*?audioKey:\s*'([^']+)'"
        r".*?transcripts:\s*\[(.*?)\]"
        r".*?\)",
        re.DOTALL,
    )
    for m in block_re.finditer(src):
        audio_key = m.group(1).strip()
        raw_transcripts = m.group(2)
        # Extract string literals from the transcripts list
        strings = re.findall(r"'((?:[^'\\]|\\.)*)'", raw_transcripts)
        # Un-escape simple dart escape sequences
        strings = [s.replace("\\'", "'").replace("\\n", "\n") for s in strings]
        # Flatten: concatenate adjacent string literals that form one logical line
        # (Dart allows adjacent strings like 'foo ' 'bar' → 'foo bar')
        # We split on the alternation pattern: odd/even items are not adjacent
        # when separated by a comma—so just deduplicate adjacent same-turn chunks.
        lines = []
        for raw in strings:
            raw = raw.strip()
            if raw:
                lines.append(raw)
        items.append({"key": audio_key, "transcripts": lines})
    return items


def main():
    p = argparse.ArgumentParser(description="Generate listening audio clips via Kokoro TTS")
    p.add_argument("--dry-run", action="store_true", help="list items without generating")
    p.add_argument("--force",   action="store_true", help="re-render existing clips")
    p.add_argument("--only",    default=None,        help="substring filter on the key")
    args = p.parse_args()

    items = collect_items()
    if not items:
        print("[ERROR] No items parsed from listening_data.dart — check the regex.", file=sys.stderr)
        sys.exit(1)

    if args.only:
        items = [it for it in items if args.only in it["key"]]

    if args.dry_run:
        print(f"[listening] {len(items)} clips planned:")
        for it in items:
            print(f"  {it['key']:25s}  {it['transcripts'][0][:60]}…" if it["transcripts"] else f"  {it['key']}")
        return

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print("Initializing Kokoro TTS…")
    try:
        from kokoro import KPipeline
    except ImportError:
        print("[ERROR] Kokoro not installed. Run: pip install kokoro soundfile", file=sys.stderr)
        sys.exit(1)

    import numpy as np  # noqa: F401 — ensure numpy available
    pipeline = KPipeline(lang_code="a")
    print(f"Ready. Output: {OUT_DIR}\nGenerating {len(items)} clips…\n")

    start = time.time()
    gen = skip = err = 0
    for it in items:
        out_file = OUT_DIR / it["key"]
        if out_file.exists() and not args.force:
            skip += 1
            continue
        try:
            audio = build_clip(pipeline, it["transcripts"])
            if audio is not None and write_mp3(audio, out_file):
                gen += 1
                print(f"  ok   {it['key']}")
            else:
                err += 1
                print(f"  ERR  {it['key']} (synth/encode failed)")
        except Exception as e:  # noqa: BLE001
            err += 1
            print(f"  ERR  {it['key']}: {e}")

    elapsed = time.time() - start
    print(f"\nDONE: {gen} generated, {skip} skipped, {err} errors in {elapsed:.0f}s")
    if err:
        sys.exit(1)


if __name__ == "__main__":
    main()

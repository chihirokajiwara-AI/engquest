#!/usr/bin/env python3
"""
A-KEN Quest — 英検5級 pure-phoneme clips via ElevenLabs (phoneme_*.mp3).

CONTEXT / WHY THIS EXISTS
-------------------------
The 5級『言葉を失った村』phonics front door teaches isolated sounds
(/s/ /a/ /t/ /k/ /o/ /g/) via phoneme_*.mp3. These were long left UNGENERATED
because plain TTS appends a schwa to consonants ("tuh"/"kuh"), which DESTROYS
blending (c-a-t must be /k//a//t/, never "kuh-a-tuh"). The hardened spec marked
them founder-ear-QA / hand-record only (see generate_phonics_audio.py header).

CEO (2026-06-08) provisioned an ElevenLabs key and directed us to try it.
ElevenLabs supports SSML <phoneme> tags (CMU arpabet / IPA) on phoneme-capable
English models, which is materially better than generic TTS for forcing a sound.
This script generates a TEST BATCH using CMU arpabet phoneme tags so a HUMAN
(the founder / CEO) can ear-QA each clip. It does NOT certify correctness — the
agent cannot hear audio, and the schwa risk on STOPS (t/k/g) is real. Do NOT wire
these into the live flow until ear-verified; continuants (s/a/o) are lower risk.

SECURITY: the key is read from the env var ELEVENLABS_API_KEY (injected from
Google Secret Manager at run time). It is never hard-coded, printed, or committed.

USAGE (run under scripts/safe-job.sh — external API, detached + timeout):
    ELEVENLABS_API_KEY=$(gcloud secrets versions access latest \
        --secret=elevenlabs_token_api --project=75848961004) \
      python3 scripts/generate_phonemes_elevenlabs.py
Options via env: ELEVENLABS_VOICE (default Rachel), ELEVENLABS_MODEL
(default eleven_flash_v2 — phoneme-tag capable English model).
"""

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

OUT_DIR = Path(__file__).parent.parent / "assets" / "audio" / "phonics"

# phoneme key -> (CMU arpabet symbol, grapheme inside the tag, short IPA note)
# CMU arpabet is more consistent than IPA per ElevenLabs guidance. The short
# vowels use the 英検5級 CVC values (cat / dog), NOT letter names.
PHONEMES = {
    "phoneme_s": ("S", "s", "/s/ — voiceless, sustained 'sss' (continuant)"),
    "phoneme_a": ("AE", "a", "/æ/ — short a as in 'cat' (continuant)"),
    "phoneme_t": ("T", "t", "/t/ — voiceless STOP (schwa risk)"),
    "phoneme_c": ("K", "c", "/k/ — voiceless STOP (schwa risk)"),
    "phoneme_o": ("AA", "o", "/ɑ/ — short o as in 'dog' (continuant)"),
    "phoneme_g": ("G", "g", "/g/ — voiced STOP (schwa risk)"),
}


def synth(key: str, arpabet: str, grapheme: str, voice: str, model: str) -> bytes:
    ssml = f'<phoneme alphabet="cmu-arpabet" ph="{arpabet}">{grapheme}</phoneme>'
    body = json.dumps(
        {
            "text": ssml,
            "model_id": model,
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice}",
        data=body,
        headers={
            "xi-api-key": os.environ["ELEVENLABS_API_KEY"],
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def main() -> int:
    if not os.environ.get("ELEVENLABS_API_KEY"):
        print("[phonemes] ERROR: ELEVENLABS_API_KEY not set in env", file=sys.stderr)
        return 2
    voice = os.environ.get("ELEVENLABS_VOICE", "21m00Tcm4TlvDq8ikWAM")  # Rachel
    model = os.environ.get("ELEVENLABS_MODEL", "eleven_flash_v2")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"[phonemes] voice={voice} model={model} → {OUT_DIR}")
    failed = 0
    for key, (arpabet, grapheme, note) in PHONEMES.items():
        try:
            audio = synth(key, arpabet, grapheme, voice, model)
            (OUT_DIR / f"{key}.mp3").write_bytes(audio)
            print(f"[phonemes] OK  {key}.mp3  {len(audio):>6} bytes  ({note})")
        except urllib.error.HTTPError as e:
            failed += 1
            print(
                f"[phonemes] FAIL {key}: HTTP {e.code} {e.read()[:200]!r}",
                file=sys.stderr,
            )
        except Exception as e:  # noqa: BLE001 — report any failure to safe-job
            failed += 1
            print(f"[phonemes] FAIL {key}: {e}", file=sys.stderr)

    print(
        f"[phonemes] done. {len(PHONEMES) - failed}/{len(PHONEMES)} generated. "
        "EAR-QA REQUIRED before wiring into the live flow "
        "(stops t/c/g = schwa risk; agent cannot verify audio)."
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

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

# phoneme key -> (bare IPA symbol to input as text, short note)
# CEO 969 directive: input ONLY the single phonetic symbol so the model produces
# the pure phoneme, not a syllable. a→æ, o→ɒ (英検5級 short vowels: cat/dog).
# CEO ear-QA (msg 984): a OK, c(=/k/ from "k") OK & best. s too short → sustain;
# o(ɒ) sounded between オ/ア → try open-o "ɔ". t→"ティー" and g→"ジィー" (read as
# LETTER NAMES): bare-letter TTS can't make these voiceless/voiced stops — they are
# the founder's hand-record job (frozen-spec). Kept here for the record only.
PHONEMES = {
    "phoneme_s": ("ssss", "/s/ — sustained voiceless continuant"),
    "phoneme_a": ("æ", "/æ/ — short a as in 'cat' (vowel) [CEO OK]"),
    "phoneme_t": ("t", "/t/ — STOP — TTS reads 'tee'; HAND-RECORD"),
    "phoneme_c": ("k", "/k/ — STOP [CEO OK, best]"),
    "phoneme_o": ("ɔ", "/ɒ/ — short o as in 'dog' (vowel)"),
    "phoneme_g": ("ɡ", "/ɡ/ — STOP — TTS reads 'gee'; HAND-RECORD"),
}


def synth(key: str, ipa: str, voice: str, model: str) -> bytes:
    # Input the bare IPA symbol as the text (CEO 969). Low style, max stability
    # so the voice does not add prosody/vowels around the sound.
    body = json.dumps(
        {
            "text": ipa,
            "model_id": model,
            "voice_settings": {"stability": 0.85, "similarity_boost": 0.4,
                               "style": 0.0},
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
    # Jessica — playful, bright, warm, young, American (best for kids' phonics;
    # CEO 970/978 approved a warm young female American voice). Verified via /voices.
    voice = os.environ.get("ELEVENLABS_VOICE", "cgSgspJ2msm6clMCkdW9")
    model = os.environ.get("ELEVENLABS_MODEL", "eleven_multilingual_v2")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"[phonemes] voice={voice} model={model} → {OUT_DIR}")
    only = set(os.environ.get("ONLY", "").split()) if os.environ.get("ONLY") else None
    failed = 0
    for key, (ipa, note) in PHONEMES.items():
        if only is not None and key not in only:
            print(f"[phonemes] skip {key} (not in ONLY)")
            continue
        try:
            audio = synth(key, ipa, voice, model)
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

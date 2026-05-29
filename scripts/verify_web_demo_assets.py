#!/usr/bin/env python3
"""verify_web_demo_assets.py — ENG Quest standalone web demo asset integrity.

The LIVE product at http://178.105.113.79:8080/ is the standalone single-file
demo `web/index.html` (300 A1 words embedded inline). Its runtime resolves two
asset families purely by string convention, with NO build step to catch typos:

  1. Audio  — playPronunciation() builds  `audio/{id}_{word.replace(' ','_')}.mp3`
              served from  web/audio/{id}_{word}.mp3   (flat layout)
  2. Images — card render builds  `images/categories/{category}.svg`
              served from  web/images/categories/{category}.svg
              (falls back to _default.svg on error)

If any of these silently 404, the demo degrades quietly: native Google TTS audio
falls back to robotic Web Speech, and category art falls back to a placeholder —
directly weakening the pronunciation-acquisition thesis that the MVP validates.

This test makes those contracts explicit and CI-enforceable:

  A. Embedded VOCAB is 1:1 with src/data/content_db/vocab_a1_300.json (300 words)
  B. Every embedded word resolves to an existing MP3 (index.html's exact naming)
  C. Every category used by embedded words has a real (non-default) SVG

Exit code 0 = all good. Non-zero = at least one broken contract (CI-friendly).

Run:  python3 scripts/verify_web_demo_assets.py
"""
from __future__ import annotations

import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(REPO, "web", "index.html")
SRC_VOCAB = os.path.join(REPO, "src", "data", "content_db", "vocab_a1_300.json")
AUDIO_DIR = os.path.join(REPO, "web", "audio")            # flat demo layout
CATEGORY_DIR = os.path.join(REPO, "web", "images", "categories")

# Must mirror playPronunciation() in web/index.html.
AUDIO_PATH_TMPL = "{id}_{safe_word}.mp3"
# Must mirror the card-image src builder in web/index.html.
CATEGORY_PATH_TMPL = "{category}.svg"


def safe_word(word: str) -> str:
    """Replicate index.html: word.replace(/ /g, '_')."""
    return word.replace(" ", "_")


def load_embedded_vocab() -> list[dict]:
    html = open(INDEX, encoding="utf-8").read()
    m = re.search(r"const VOCAB = \[(.*?)\n\];", html, re.S)
    if not m:
        raise SystemExit("FATAL: could not locate `const VOCAB = [ ... ];` in index.html")
    block = m.group(1)
    entries = re.findall(r"\{\"id\":\"[^\"]+\".*?\}", block)
    return [json.loads(e) for e in entries]


def load_source_vocab() -> list[dict]:
    data = json.load(open(SRC_VOCAB, encoding="utf-8"))
    return data if isinstance(data, list) else data.get("words", data)


def main() -> int:
    errors: list[str] = []

    embedded = load_embedded_vocab()
    source = load_source_vocab()

    emb_ids = {w["id"] for w in embedded}
    src_ids = {w["id"] for w in source}

    # ---- Contract A: embedded VOCAB == source vocab_a1_300.json ----
    if len(embedded) != 300:
        errors.append(f"A: embedded VOCAB has {len(embedded)} words, expected 300")
    only_src = sorted(src_ids - emb_ids)
    only_emb = sorted(emb_ids - src_ids)
    if only_src:
        errors.append(f"A: {len(only_src)} word(s) in source missing from demo: {only_src[:8]}")
    if only_emb:
        errors.append(f"A: {len(only_emb)} word(s) in demo not in source: {only_emb[:8]}")

    # ---- Contract B: every embedded word has its MP3 (exact runtime naming) ----
    audio_checked = 0
    for w in embedded:
        fname = AUDIO_PATH_TMPL.format(id=w["id"], safe_word=safe_word(w["word"]))
        if not os.path.exists(os.path.join(AUDIO_DIR, fname)):
            errors.append(f"B: MISSING audio for '{w['word']}' ({w['id']}) -> web/audio/{fname}")
        else:
            audio_checked += 1

    # ---- Contract C: every used category has a real (non-default) SVG ----
    used_categories = sorted({w["category"] for w in embedded})
    cat_checked = 0
    for cat in used_categories:
        fname = CATEGORY_PATH_TMPL.format(category=cat)
        if not os.path.exists(os.path.join(CATEGORY_DIR, fname)):
            errors.append(
                f"C: MISSING category art '{cat}' -> web/images/categories/{fname} "
                f"(demo would fall back to _default.svg)"
            )
        else:
            cat_checked += 1

    print(f"Embedded demo words : {len(embedded)} (source: {len(source)})")
    print(f"Audio MP3s resolved : {audio_checked}/{len(embedded)}")
    print(f"Category SVGs        : {cat_checked}/{len(used_categories)} "
          f"({', '.join(used_categories)})")

    if errors:
        print(f"\nFAILED — {len(errors)} broken contract(s):")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("\nOK — live web demo: 300 words, all audio + category art resolve cleanly.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

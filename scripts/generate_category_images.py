#!/usr/bin/env python3
"""Generate child-friendly placeholder SVG illustrations for each vocab category.

ENG Quest pedagogy: visual word-association lets L1-L2 learners bind English
words to images directly, without leaning on a Japanese-translation crutch.
Until per-word artwork exists, every word shows its category illustration as a
consistent, friendly visual anchor on the battle flashcard.

Outputs one SVG per category to:
  - web/images/categories/<Category>.svg        (live web app)
  - assets/images/categories/<Category>.svg      (Flutter app)

Categories are read from src/data/content_db/vocab_a1_300.json so this stays in
sync with the content DB.  Idempotent — safe to re-run.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOCAB = os.path.join(ROOT, "src", "data", "content_db", "vocab_a1_300.json")
WEB_OUT = os.path.join(ROOT, "web", "images", "categories")
FLUTTER_OUT = os.path.join(ROOT, "assets", "images", "categories")

SIZE = 240

# Per-category: (background gradient stops, accent color, emoji glyph, JP label)
# Emoji rendered as text keeps the SVG tiny and universally supported, while the
# gradient + soft shapes give each category a distinct, recognisable identity.
CATEGORY_STYLE = {
    "Animals":          ("#FFB347", "#FF8C42", "🐾", "どうぶつ"),
    "Food":             ("#FF6B6B", "#E63946", "🍎", "たべもの"),
    "Family":           ("#FF9FB2", "#E5577D", "👨\u200d👩\u200d👧", "かぞく"),
    "Colors":           ("#A78BFA", "#7C3AED", "🎨", "いろ"),
    "Numbers":          ("#4ECDC4", "#1A9E94", "🔢", "すうじ"),
    "Actions":          ("#FFD93D", "#F4A300", "🏃", "うごき"),
    "Adjectives":       ("#6BCB77", "#2E9E4D", "✨", "ようす"),
    "School":           ("#5DA9E9", "#2E6FB7", "🏫", "がっこう"),
    "Time_Weather":     ("#74C0FC", "#2B8FD8", "🌤️", "とき・てんき"),
    "Greetings_Social": ("#FFB7C5", "#E5739B", "👋", "あいさつ"),
    "Body":             ("#FF8FA3", "#D6536D", "🖐️", "からだ"),
    "Places":          ("#9ED2C6", "#4FA793", "🗺️", "ばしょ"),
}

# Generic fallback so a new category never renders a broken image.
FALLBACK = ("#8E9AAF", "#5C6B86", "⭐", "")


def _esc(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def build_svg(bg: str, accent: str, glyph: str, jp_label: str, name: str) -> str:
    s = SIZE
    cx = s / 2
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}"
     viewBox="0 0 {s} {s}" role="img"
     aria-label="{_esc(name)} category illustration">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{bg}"/>
      <stop offset="100%" stop-color="{accent}"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="38%" r="55%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect x="0" y="0" width="{s}" height="{s}" rx="32" fill="url(#bg)"/>
  <rect x="0" y="0" width="{s}" height="{s}" rx="32" fill="url(#glow)"/>
  <circle cx="{cx}" cy="100" r="62" fill="#ffffff" fill-opacity="0.22"/>
  <text x="{cx}" y="100" font-size="78" text-anchor="middle"
        dominant-baseline="central">{glyph}</text>
  <text x="{cx}" y="190" font-size="26" font-weight="700" text-anchor="middle"
        fill="#ffffff" font-family="system-ui, sans-serif"
        dominant-baseline="central">{_esc(name)}</text>
  <text x="{cx}" y="218" font-size="15" text-anchor="middle"
        fill="#ffffff" fill-opacity="0.85"
        font-family="system-ui, sans-serif"
        dominant-baseline="central">{_esc(jp_label)}</text>
</svg>
"""


def load_categories() -> list[str]:
    with open(VOCAB, encoding="utf-8") as f:
        data = json.load(f)
    cats = list(data.get("categories", {}).keys())
    # Also sweep the words array in case categories map is incomplete.
    seen = set(cats)
    for w in data.get("words", []):
        c = w.get("category")
        if c and c not in seen:
            seen.add(c)
            cats.append(c)
    return cats


def main() -> int:
    os.makedirs(WEB_OUT, exist_ok=True)
    os.makedirs(FLUTTER_OUT, exist_ok=True)

    cats = load_categories()
    written = []
    for name in cats:
        bg, accent, glyph, jp = CATEGORY_STYLE.get(name, FALLBACK)
        svg = build_svg(bg, accent, glyph, jp, name)
        for out_dir in (WEB_OUT, FLUTTER_OUT):
            path = os.path.join(out_dir, f"{name}.svg")
            with open(path, "w", encoding="utf-8") as f:
                f.write(svg)
        written.append(name)

    # Also emit a default fallback the app can use for unknown categories.
    bg, accent, glyph, jp = FALLBACK
    default_svg = build_svg(bg, accent, glyph, jp, "Word")
    for out_dir in (WEB_OUT, FLUTTER_OUT):
        with open(os.path.join(out_dir, "_default.svg"), "w", encoding="utf-8") as f:
            f.write(default_svg)

    print(f"Generated {len(written)} category SVGs (+ _default) in:")
    print(f"  {WEB_OUT}")
    print(f"  {FLUTTER_OUT}")
    for n in written:
        print(f"  - {n}.svg")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

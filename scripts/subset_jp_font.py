#!/usr/bin/env python3
"""Subset the bundled Japanese serif font to the app's actual character set.

WHY: the full Noto Serif JP variable font is ~13.5MB (8.5MB gzipped). Bundling it
fixed the 文字化け (tofu) but blocked CanvasKit's first frame for ~10s on web — a
load-speed regression. CJK fonts are huge because of the kanji outlines. Since the
demo has no backend (no runtime-generated Japanese — Claude dialog is dead until
the proxy ships), ALL Japanese the app can display comes from bundled sources, so
we can subset to exactly that inventory with ZERO tofu risk and cut the file size
several-fold.

Coverage kept:
  - every character found in lib/**.dart, assets/data/**.json, assets/content/**
  - all hiragana/katakana, CJK punctuation, fullwidth/halfwidth forms
  - Basic + Latin-1 ASCII, common symbols
  - the variable `wght` axis is preserved, so all UI weights still render.

Re-run after adding new Japanese UI/content:
  python3 scripts/subset_jp_font.py
It downloads the full font to tools/fonts/ (cached, gitignored) and writes the
subset to assets/fonts/NotoSerifJP.ttf (committed).
"""
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FULL_URL = "https://github.com/google/fonts/raw/main/ofl/notoserifjp/NotoSerifJP%5Bwght%5D.ttf"
FULL_PATH = os.path.join(ROOT, "tools", "fonts", "NotoSerifJP-full.ttf")
OUT_PATH = os.path.join(ROOT, "assets", "fonts", "NotoSerifJP.ttf")

# Directories whose text the bundled app can render.
SCAN = [
    ("lib", (".dart",)),
    ("assets/data", (".json",)),
    ("assets/content", (".json", ".txt", ".md")),
]

# Unicode ranges always kept (kana, punctuation, ASCII, fullwidth) so even
# content we did not scan renders its kana/punctuation.
KEEP_RANGES = [
    (0x0020, 0x007E),   # Basic Latin
    (0x00A0, 0x00FF),   # Latin-1 supplement
    (0x2010, 0x2027),   # general punctuation (dashes, quotes, …)
    (0x2030, 0x205E),   # more punctuation
    (0x3000, 0x303F),   # CJK symbols & punctuation
    (0x3040, 0x309F),   # Hiragana
    (0x30A0, 0x30FF),   # Katakana
    (0x31F0, 0x31FF),   # Katakana phonetic extensions
    (0xFF00, 0xFFEF),   # Halfwidth & Fullwidth forms
]


def collect_chars():
    chars = set()
    for rel, exts in SCAN:
        base = os.path.join(ROOT, rel)
        if not os.path.isdir(base):
            continue
        for dirpath, _, files in os.walk(base):
            for fn in files:
                if not fn.endswith(exts):
                    continue
                try:
                    with open(os.path.join(dirpath, fn), encoding="utf-8") as fh:
                        chars.update(fh.read())
                except (UnicodeDecodeError, OSError):
                    pass
    # Keep only code points >= space (drop control chars).
    return {c for c in chars if ord(c) >= 0x20}


def main():
    os.makedirs(os.path.dirname(FULL_PATH), exist_ok=True)
    if not os.path.exists(FULL_PATH):
        print(f"downloading full font -> {FULL_PATH}")
        urllib.request.urlretrieve(FULL_URL, FULL_PATH)
    full_mb = os.path.getsize(FULL_PATH) / 1e6

    chars = collect_chars()
    unicodes = ",".join(f"U+{ord(c):04X}" for c in sorted(chars))
    ranges = ",".join(f"U+{a:04X}-{b:04X}" for a, b in KEEP_RANGES)
    print(f"scanned {len(chars)} distinct chars from bundled sources")

    cmd = [
        "pyftsubset", FULL_PATH,
        f"--unicodes={ranges},{unicodes}",
        f"--output-file={OUT_PATH}",
        "--layout-features=*",       # keep kerning/positioning
        "--name-IDs=*",
        "--drop-tables-=",           # keep variable tables (fvar/gvar/STAT)
        "--recalc-bounds",
    ]
    print("running pyftsubset…")
    subprocess.run(cmd, check=True)
    out_mb = os.path.getsize(OUT_PATH) / 1e6
    print(f"DONE: {full_mb:.1f}MB -> {out_mb:.1f}MB  ({OUT_PATH})")


if __name__ == "__main__":
    sys.exit(main())

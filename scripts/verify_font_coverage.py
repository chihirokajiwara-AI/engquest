#!/usr/bin/env python3
"""CI gate: assert the COMMITTED JP subset font covers every source Japanese char.

Companion to subset_jp_font.py. That script REGENERATES the subset from source;
this one ASSERTS the committed `assets/fonts/NotoSerifJP.ttf` already covers every
Japanese-script character the app can display — so a contributor who adds new
Japanese text but forgets to re-run the subset is caught at CI time instead of
shipping silent tofu (□). This is the "wire fontTools coverage into CI" follow-up
that test/qa/vocab_gloss_charset_test.dart (#97) explicitly deferred (that test is
only a foreign-script tripwire; it allows the whole CJK block, wider than the
bundled subset). Real incident: 囚 ("囚われている") was tofu until the subset was
regenerated.

SCOPE: only codepoints the JP serif font is RESPONSIBLE for are asserted — kana,
CJK ideographs (+ Ext A / compatibility), CJK symbols & punctuation, and fullwidth
forms. ASCII/Latin render from the Latin font and emoji from the system emoji
font, so they are out of scope (asserting them would false-positive on 🐾/🕵️).

Exit 0 if every in-scope source char is in the font cmap; 1 (listing the missing
chars) otherwise. Requires fontTools (`pip install fonttools`).
"""
import os
import sys

# Reuse the exact source-scan used to BUILD the subset, so the gate and the
# generator never disagree about what "source characters" means.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from subset_jp_font import collect_chars, OUT_PATH  # noqa: E402

# Unicode ranges the bundled Japanese serif font is responsible for rendering.
_JP_RANGES = [
    (0x3000, 0x303F),   # CJK symbols & punctuation (、。「」 etc.)
    (0x3040, 0x309F),   # Hiragana
    (0x30A0, 0x30FF),   # Katakana
    (0x31F0, 0x31FF),   # Katakana phonetic extensions
    (0x3400, 0x4DBF),   # CJK Unified Ideographs Extension A
    (0x4E00, 0x9FFF),   # CJK Unified Ideographs
    (0xF900, 0xFAFF),   # CJK Compatibility Ideographs
    (0xFF00, 0xFFEF),   # Halfwidth & Fullwidth forms
]


def _in_scope(cp: int) -> bool:
    return any(a <= cp <= b for a, b in _JP_RANGES)


def _font_codepoints(path: str) -> set:
    from fontTools.ttLib import TTFont
    font = TTFont(path)
    cps = set()
    for table in font["cmap"].tables:
        cps |= set(table.cmap.keys())
    return cps


def main() -> int:
    # Graceful skip when fontTools is absent (e.g. a dev machine). CI installs
    # fonttools explicitly, so enforcement stays real there; this only avoids
    # hard-blocking a local pre-push on a missing optional dependency.
    try:
        import fontTools  # noqa: F401
    except ModuleNotFoundError:
        print("SKIP: fontTools not installed — font-coverage gate not enforced "
              "locally (CI installs it). `pip install fonttools` to run here.")
        return 0
    if not os.path.exists(OUT_PATH):
        print(f"FAIL: bundled font missing: {OUT_PATH}")
        return 1
    source = {c for c in collect_chars() if _in_scope(ord(c))}
    covered = _font_codepoints(OUT_PATH)
    missing = sorted(c for c in source if ord(c) not in covered)
    if missing:
        shown = "".join(missing[:120])
        print(
            f"FAIL: {len(missing)} Japanese source char(s) NOT in the bundled "
            f"subset (tofu risk).\n"
            f"  Re-run `python3 scripts/subset_jp_font.py` and commit the font.\n"
            f"  missing: {shown}"
        )
        return 1
    print(f"OK: all {len(source)} in-scope JP source chars covered by "
          f"{os.path.basename(OUT_PATH)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

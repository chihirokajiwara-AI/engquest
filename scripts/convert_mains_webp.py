#!/usr/bin/env python3
"""Bundle the LOCKED M5/M6 mains as app assets — WebP q90 (#58, CEO 3758 ①)."""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "character" / "reference"
DST = ROOT / "assets" / "art" / "characters"
DST.mkdir(parents=True, exist_ok=True)
pairs = [("m5_street_male.png", "m5_hero.webp"), ("m6_classic_female.png", "m6_hero.webp")]
for s, d in pairs:
    img = Image.open(SRC / s).convert("RGBA")
    img.save(DST / d, "WEBP", quality=90, method=6)
    print(f"  {s} {(SRC/s).stat().st_size//1024}KB -> {d} {(DST/d).stat().st_size//1024}KB")
print("DONE")

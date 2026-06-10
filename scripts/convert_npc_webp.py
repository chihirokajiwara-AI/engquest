#!/usr/bin/env python3
"""Convert assets/art/npc/*.png → WebP q90 (#131).

The NPC dialogue portraits are painterly 832x1216 illustrations stored as PNG — a
poor format for painterly art. They render at ≤96px (DqPortrait) up to ~480px
(explore scene_view), so the source dimensions are KEPT (no downscale — the
rural-persona "10x oversized" claim was refuted by the large explore display).
WebP q90 is visually lossless at these sizes and ~50-65% smaller, cutting the web
bundle for low-bandwidth users. WebP is already proven in this app (quest_map,
hotspot). Writes .webp beside each .png (the .png is removed after ref update).
"""
from pathlib import Path
from PIL import Image

NPC = Path(__file__).resolve().parent.parent / "assets" / "art" / "npc"

def main():
    total_png = total_webp = 0
    for png in sorted(NPC.glob("*.png")):
        img = Image.open(png).convert("RGBA")
        webp = png.with_suffix(".webp")
        img.save(webp, "WEBP", quality=90, method=6)
        pb, wb = png.stat().st_size, webp.stat().st_size
        total_png += pb; total_webp += wb
        print(f"  {png.name}: {pb//1024}KB → {webp.name}: {wb//1024}KB "
              f"({100*(pb-wb)//pb}% smaller)")
    print(f"TOTAL: {total_png//1024}KB → {total_webp//1024}KB "
          f"({100*(total_png-total_webp)//total_png}% smaller)")

if __name__ == "__main__":
    main()

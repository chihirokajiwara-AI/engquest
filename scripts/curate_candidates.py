#!/usr/bin/env python3
"""curate_candidates.py — the SELECT half of generate-many → select-best (#art).

CEO 2026-06-16 (#1794): "場面画像はたくさん並列生成して、その中からハイクオリティを選定。
1回で最高は出ない。" The 2026 standard (memory: layton-grade-production-research) is
over-generate → AUTO-FILTER → curate → human pick → paint-over. This tool is the
first, ¥0, dependency-light AUTO-FILTER stage:

  1. de-duplicate near-identical candidates (perceptual dHash, Hamming distance) so
     12 candidates aren't 12 copies of one seed — keep the sharpest per cluster.
  2. coarse no-reference quality proxy (Laplacian-variance sharpness; drops blurry /
     mushy generations) → rank survivors best-first.
  3. emit a ranked JSON manifest + an HTML contact sheet for the HUMAN final pick.

This is deliberately the COARSE pre-filter only. Per the research the real gates are
layered ON TOP and are NOT in this ¥0 stage:
  - LAION aesthetic predictor (drop bottom 50%) — model download, add later
  - an MLLM reviewer scoring "matches コトバ探偵 style + correct subject" — the real
    style/consistency judge (sharpness says nothing about on-style-ness)
  - human picks 1 of ~3 → paint-over finish
So: sharpness rank ≠ "best art"; it only removes blurry/dupe noise before the human/
MLLM look. Honest by design.

Only deps: Pillow + numpy (already present). dHash is implemented here (no imagehash).

Usage:
  python3 scripts/curate_candidates.py --dir candidates/town5_square \
      --out candidates/town5_square/_curation --keep 3
  # open <out>/contact_sheet.html to pick; <out>/ranking.json is the machine record.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

try:
    import numpy as np
    from PIL import Image
except Exception as e:  # pragma: no cover - env guard
    sys.stderr.write("needs Pillow + numpy: {0}\n".format(e))
    raise SystemExit(2)

_EXTS = (".png", ".jpg", ".jpeg", ".webp")


def _dhash(img: "Image.Image", size: int = 8) -> int:
    g = img.convert("L").resize((size + 1, size))
    a = np.asarray(g, dtype=np.int16)
    bits = a[:, 1:] > a[:, :-1]
    h = 0
    for i, v in enumerate(bits.flatten()):
        if v:
            h |= 1 << i
    return h


def _sharpness(img: "Image.Image") -> float:
    # Laplacian-variance: a standard blur metric (higher = crisper).
    g = np.asarray(img.convert("L"), dtype=np.float64)
    lap = (
        -4.0 * g
        + np.roll(g, 1, 0)
        + np.roll(g, -1, 0)
        + np.roll(g, 1, 1)
        + np.roll(g, -1, 1)
    )
    return float(lap.var())


def _hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def analyse(path: str) -> dict:
    with Image.open(path) as img:
        img.load()
        w, h = img.size
        return {
            "path": path,
            "name": os.path.basename(path),
            "w": w,
            "h": h,
            "sharpness": round(_sharpness(img), 2),
            "dhash": _dhash(img),
        }


def dedup(items: list[dict], dist: int) -> list[dict]:
    """Cluster by dHash Hamming distance; keep the sharpest representative."""
    kept: list[dict] = []
    for it in sorted(items, key=lambda x: -x["sharpness"]):
        dup = False
        for k in kept:
            if _hamming(it["dhash"], k["dhash"]) <= dist:
                k.setdefault("near_dupes", []).append(it["name"])
                dup = True
                break
        if not dup:
            kept.append(it)
    return kept


def write_html(out_dir: str, ranked: list[dict]) -> str:
    rows = []
    for i, it in enumerate(ranked, 1):
        rel = os.path.relpath(it["path"], out_dir)
        dupes = it.get("near_dupes", [])
        rows.append(
            "<figure style='display:inline-block;margin:8px;width:280px;"
            "vertical-align:top'>"
            "<img src='{rel}' style='width:280px;border:2px solid "
            "{c}'/><figcaption style='font:13px sans-serif'>"
            "#{i} &nbsp; sharp={s} &nbsp; {w}x{h}{d}</figcaption></figure>".format(
                rel=rel,
                c="#1a8" if i <= 3 else "#999",
                i=i,
                s=it["sharpness"],
                w=it["w"],
                h=it["h"],
                d=(" &nbsp; +{0} dupes".format(len(dupes)) if dupes else ""),
            )
        )
    html = (
        "<!doctype html><meta charset=utf-8>"
        "<body style='background:#111;color:#ddd'>"
        "<h2 style='font:18px sans-serif'>candidate curation — coarse pre-filter "
        "(sharpness+dedup). Human/MLLM pick the final from the top.</h2>"
        + "".join(rows)
        + "</body>"
    )
    p = os.path.join(out_dir, "contact_sheet.html")
    with open(p, "w", encoding="utf-8") as f:
        f.write(html)
    return p


def main() -> int:
    ap = argparse.ArgumentParser(description="Curate AI-art candidates (pre-filter).")
    ap.add_argument("--dir", required=True, help="directory of candidate images")
    ap.add_argument("--out", default=None, help="output dir (default <dir>/_curation)")
    ap.add_argument("--keep", type=int, default=3, help="flag top-N for human pick")
    ap.add_argument("--dupe-dist", type=int, default=6,
                    help="dHash Hamming distance treated as a near-duplicate")
    args = ap.parse_args()

    if not os.path.isdir(args.dir):
        print("not a directory: {0}".format(args.dir), file=sys.stderr)
        return 2
    paths = [
        os.path.join(args.dir, f)
        for f in sorted(os.listdir(args.dir))
        if f.lower().endswith(_EXTS) and not f.startswith("_")
    ]
    if not paths:
        print("no candidate images in {0}".format(args.dir), file=sys.stderr)
        return 1

    items = [analyse(p) for p in paths]
    kept = dedup(items, args.dupe_dist)
    ranked = sorted(kept, key=lambda x: -x["sharpness"])

    out = args.out or os.path.join(args.dir, "_curation")
    os.makedirs(out, exist_ok=True)
    manifest = {
        "candidates": len(items),
        "after_dedup": len(ranked),
        "keep": args.keep,
        "top": [
            {k: it[k] for k in ("name", "sharpness", "w", "h")}
            for it in ranked[: args.keep]
        ],
        "ranked": [
            {
                "rank": i + 1,
                "name": it["name"],
                "sharpness": it["sharpness"],
                "w": it["w"],
                "h": it["h"],
                "near_dupes": it.get("near_dupes", []),
            }
            for i, it in enumerate(ranked)
        ],
    }
    with open(os.path.join(out, "ranking.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    html = write_html(out, ranked)

    print(
        "[curate] {0} candidates -> {1} after dedup; top {2} flagged. "
        "manifest+sheet in {3}".format(len(items), len(ranked), args.keep, out)
    )
    print("[curate] open {0}".format(html))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Tests for P2.9 — word/category image placeholders.

Validates the generated category SVGs are well-formed, complete (one per vocab
category), wired into the live web app, and precached for offline use.
Run: python3 scripts/test_category_images.py
"""
import json
import os
import sys
import xml.dom.minidom as minidom

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOCAB = os.path.join(ROOT, "src", "data", "content_db", "vocab_a1_300.json")
WEB_OUT = os.path.join(ROOT, "web", "images", "categories")
FLUTTER_OUT = os.path.join(ROOT, "assets", "images", "categories")
INDEX = os.path.join(ROOT, "web", "index.html")
SW = os.path.join(ROOT, "web", "sw.js")

failures = []


def check(cond, msg):
    if cond:
        print(f"  PASS: {msg}")
    else:
        print(f"  FAIL: {msg}")
        failures.append(msg)


def main():
    with open(VOCAB, encoding="utf-8") as f:
        vocab = json.load(f)
    categories = list(vocab["categories"].keys())
    # categories from words must be a subset of declared categories
    word_cats = {w["category"] for w in vocab["words"]}

    print("== Vocab category coverage ==")
    check(word_cats.issubset(set(categories)),
          f"all {len(word_cats)} word categories are declared")

    print("== SVG files exist & are well-formed (web + flutter) ==")
    for out_dir, label in ((WEB_OUT, "web"), (FLUTTER_OUT, "flutter")):
        for cat in categories + ["_default"]:
            path = os.path.join(out_dir, f"{cat}.svg")
            exists = os.path.isfile(path)
            check(exists, f"[{label}] {cat}.svg exists")
            if exists:
                with open(path, encoding="utf-8") as fh:
                    content = fh.read()
                try:
                    minidom.parseString(content)
                    well_formed = "<svg" in content and "</svg>" in content
                except Exception as e:  # noqa: BLE001
                    well_formed = False
                    print(f"    XML error in {path}: {e}")
                check(well_formed, f"[{label}] {cat}.svg is well-formed XML")

    print("== Live web app wiring (index.html) ==")
    with open(INDEX, encoding="utf-8") as fh:
        html = fh.read()
    check('id="card-image"' in html, "card front has <img id=card-image>")
    check("images/categories/" in html, "loadCard references category image path")
    check(".card-image {" in html, "card-image CSS rule present")
    check("'images/categories/_default.svg'" in html,
          "loadCard has onerror fallback to _default.svg")

    print("== Service worker precache (sw.js) ==")
    with open(SW, encoding="utf-8") as fh:
        sw = fh.read()
    check("engquest-v2" in sw, "CACHE_VERSION bumped to v2 (invalidate old cache)")
    for cat in categories:
        check(f"images/categories/{cat}.svg" in sw,
              f"sw precaches {cat}.svg")
    check("images/categories/_default.svg" in sw, "sw precaches _default.svg")

    print()
    if failures:
        print(f"RESULT: {len(failures)} FAILED")
        return 1
    print("RESULT: ALL PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())

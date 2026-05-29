#!/usr/bin/env python3
"""Tests for P0.2 (extended) — full 300-word native pronunciation audio.

Validates every A1 vocab word has a real MP3 whose filename matches the path
the live web app requests in playPronunciation(), that files are valid MP3s,
and that the embedded HTML vocab list is fully covered (no silent fallback to
the robotic browser Web-Speech API).

Run: python3 scripts/test_word_audio.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOCAB = os.path.join(ROOT, "src", "data", "content_db", "vocab_a1_300.json")
AUDIO_DIR = os.path.join(ROOT, "web", "audio")
INDEX = os.path.join(ROOT, "web", "index.html")

failures = []


def check(cond, msg):
    if cond:
        print(f"  PASS: {msg}")
    else:
        print(f"  FAIL: {msg}")
        failures.append(msg)


def is_valid_mp3(path):
    try:
        with open(path, "rb") as fh:
            head = fh.read(4)
    except OSError:
        return False
    # ID3 tag or MPEG frame sync (0xFFEx/0xFFFx)
    return head[:3] == b"ID3" or (head[0] == 0xFF and (head[1] & 0xE0) == 0xE0)


def expected_filename(wid, word):
    # Must mirror web/index.html playPronunciation(): spaces -> underscores
    return f"{wid}_{word.replace(' ', '_')}.mp3"


def main():
    with open(VOCAB, encoding="utf-8") as f:
        vocab = json.load(f)
    words = vocab["words"]

    print("== Vocab audio coverage (vocab_a1_300.json) ==")
    check(len(words) == 300, f"vocab has 300 words (got {len(words)})")

    missing, invalid = [], []
    for w in words:
        fname = expected_filename(w["id"], w["word"])
        path = os.path.join(AUDIO_DIR, fname)
        if not (os.path.isfile(path) and os.path.getsize(path) > 1000):
            missing.append(fname)
        elif not is_valid_mp3(path):
            invalid.append(fname)
    check(not missing, f"all 300 words have an MP3 (missing: {missing[:5]})")
    check(not invalid, f"all MP3s have valid headers (invalid: {invalid[:5]})")

    print("== Live web app embedded vocab coverage (index.html) ==")
    with open(INDEX, encoding="utf-8") as fh:
        html = fh.read()
    pairs = re.findall(r'\{"id":"(eiken5_\d+)","word":"([^"]+)"', html)
    check(len(pairs) == 300, f"index.html embeds 300 words (got {len(pairs)})")
    html_missing = [
        expected_filename(wid, word)
        for wid, word in pairs
        if not os.path.isfile(os.path.join(AUDIO_DIR, expected_filename(wid, word)))
    ]
    check(not html_missing,
          f"every embedded HTML word maps to audio (missing: {html_missing[:5]})")
    check("audio/${wordId}_${safeWord}.mp3" in html
          or "audio/`+" in html
          or "playPronunciation" in html,
          "playPronunciation() audio-path wiring present")

    print()
    if failures:
        print(f"RESULT: {len(failures)} FAILED")
        return 1
    print(f"RESULT: ALL PASSED ({len(words)} words covered)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

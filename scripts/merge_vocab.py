#!/usr/bin/env python3
"""Merge all batch files into the main eiken2_vocab.json, deduplicating by word."""

import json
import os
import re
import glob

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPTS_DIR)
MAIN_FILE = os.path.join(REPO_ROOT, "assets", "data", "eiken2_vocab.json")
BATCH_PATTERN = os.path.join(SCRIPTS_DIR, "new_words_batch*.json")

def load_batch(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    # Try common keys
    for key in ("words", "vocabulary", "vocab", "entries"):
        if key in data:
            return data[key]
    raise ValueError(f"Unknown structure in {path}: keys={list(data.keys())}")

def main():
    # Load main file
    print(f"Loading {MAIN_FILE}")
    with open(MAIN_FILE, "r", encoding="utf-8") as f:
        main_data = json.load(f)

    words_key = "words"  # confirmed from structure check
    existing_words_list = main_data[words_key]

    existing_words = set()
    for entry in existing_words_list:
        existing_words.add(entry["word"].lower())

    print(f"Existing words: {len(existing_words)}")

    # Load all batch files sorted by batch number
    batch_files = sorted(
        glob.glob(BATCH_PATTERN),
        key=lambda p: int(re.search(r'batch(\d+)', p).group(1))
    )
    print(f"Found {len(batch_files)} batch files")

    new_entries = []
    seen_words = set(existing_words)
    duplicate_count = 0

    for bf in batch_files:
        batch_num = int(re.search(r'batch(\d+)', bf).group(1))
        entries = load_batch(bf)

        added = 0
        skipped = 0
        for entry in entries:
            word_lower = entry["word"].lower()
            if word_lower in seen_words:
                duplicate_count += 1
                skipped += 1
            else:
                seen_words.add(word_lower)
                # Ensure required fields exist
                entry.setdefault("audioUrl", "")
                entry.setdefault("imageUrl", "")
                entry.setdefault("fsrsState", "new")
                entry.setdefault("tags", [])
                new_entries.append(entry)
                added += 1

        print(f"  Batch {batch_num:2d}: {added} added, {skipped} skipped (duplicates)")

    print(f"\nTotal new unique entries: {len(new_entries)}")
    print(f"Total duplicates skipped: {duplicate_count}")

    # Re-assign IDs sequentially to avoid gaps
    base_count = len(existing_words_list)
    for i, entry in enumerate(new_entries):
        entry["id"] = f"eiken2_{base_count + i + 1:03d}"

    # Append to main vocabulary
    main_data[words_key].extend(new_entries)
    total = len(main_data[words_key])
    print(f"Total words after merge: {total}")

    # Update top-level metadata fields
    main_data["totalWords"] = total
    main_data["description"] = f"Eiken Grade 2 vocabulary list with {total} words for ENG Quest"

    # Write back
    with open(MAIN_FILE, "w", encoding="utf-8") as f:
        json.dump(main_data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"\nWritten to {MAIN_FILE}")
    print(f"Final word count: {total}")

if __name__ == "__main__":
    main()

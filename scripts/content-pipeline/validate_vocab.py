#!/usr/bin/env python3
"""
Validate vocabulary JSON files for ENG Quest / A-KEN Quest.

Usage:
    python3 scripts/content-pipeline/validate_vocab.py assets/data/eiken5_vocab.json
    python3 scripts/content-pipeline/validate_vocab.py assets/data/
"""

import json
import sys
import os
from pathlib import Path
from collections import Counter

REQUIRED_FIELDS = [
    "id", "word", "reading", "jpTranslation", "cefrLevel", "eikenLevel",
    "category", "pos", "exampleSentences", "audioUrl", "imageUrl",
    "fsrsState", "tags", "distractors"
]

VALID_CEFR_LEVELS = {"A1", "A1+", "A2", "A2+", "B1", "B1+", "B2", "B2+", "C1", "C2"}
VALID_FSRS_STATES = {"new", "learning", "review", "relearning"}


def validate_file(path: Path) -> tuple[bool, list[str], dict]:
    """
    Validate a single vocab JSON file.
    Returns (passed, errors, stats).
    """
    errors = []
    stats = {}

    # --- Load JSON ---
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return False, [f"Invalid JSON: {e}"], {}
    except OSError as e:
        return False, [f"Cannot open file: {e}"], {}

    # --- Top-level structure ---
    for top_field in ("version", "totalWords", "words"):
        if top_field not in data:
            errors.append(f"Missing top-level field: '{top_field}'")

    if "words" not in data or not isinstance(data["words"], list):
        errors.append("'words' must be a list")
        return False, errors, stats

    words = data["words"]
    declared_total = data.get("totalWords", None)
    actual_total = len(words)

    if declared_total is not None and declared_total != actual_total:
        errors.append(
            f"totalWords mismatch: declared {declared_total}, actual {actual_total}"
        )

    # --- Per-word validation ---
    seen_ids: dict[str, int] = {}           # id -> first occurrence index
    seen_words: dict[str, int] = {}         # word (lower) -> first occurrence index
    category_counter: Counter = Counter()

    for i, entry in enumerate(words):
        prefix = f"[word #{i+1}]"

        if not isinstance(entry, dict):
            errors.append(f"{prefix} Entry is not an object")
            continue

        word_label = entry.get("word", f"<index {i}>")

        # Required fields
        for field in REQUIRED_FIELDS:
            if field not in entry:
                errors.append(f"{prefix} '{word_label}' missing required field: '{field}'")

        # Duplicate ID within file
        entry_id = entry.get("id")
        if entry_id is not None:
            if entry_id in seen_ids:
                errors.append(
                    f"{prefix} Duplicate id '{entry_id}' "
                    f"(first seen at word #{seen_ids[entry_id]+1})"
                )
            else:
                seen_ids[entry_id] = i

        # Duplicate word (case-insensitive) within file
        word_lower = str(entry.get("word", "")).strip().lower()
        if word_lower:
            if word_lower in seen_words:
                errors.append(
                    f"{prefix} Duplicate word '{word_lower}' "
                    f"(first seen at word #{seen_words[word_lower]+1})"
                )
            else:
                seen_words[word_lower] = i

        # distractors count
        distractors = entry.get("distractors")
        if distractors is not None:
            if not isinstance(distractors, list):
                errors.append(f"{prefix} '{word_label}' distractors must be a list")
            elif len(distractors) != 3:
                errors.append(
                    f"{prefix} '{word_label}' distractors count = {len(distractors)}, expected 3"
                )

        # exampleSentences count
        examples = entry.get("exampleSentences")
        if examples is not None:
            if not isinstance(examples, list):
                errors.append(f"{prefix} '{word_label}' exampleSentences must be a list")
            elif len(examples) < 1:
                errors.append(f"{prefix} '{word_label}' exampleSentences must have >= 1 entry")

        # cefrLevel validity
        cefr = entry.get("cefrLevel")
        if cefr and cefr not in VALID_CEFR_LEVELS:
            errors.append(f"{prefix} '{word_label}' unknown cefrLevel '{cefr}'")

        # fsrsState validity
        fsrs = entry.get("fsrsState")
        if fsrs and fsrs not in VALID_FSRS_STATES:
            errors.append(f"{prefix} '{word_label}' unknown fsrsState '{fsrs}'")

        # pos must be a non-empty list
        pos = entry.get("pos")
        if pos is not None:
            if not isinstance(pos, list) or len(pos) == 0:
                errors.append(f"{prefix} '{word_label}' pos must be a non-empty list")

        # tags must be a list
        tags = entry.get("tags")
        if tags is not None and not isinstance(tags, list):
            errors.append(f"{prefix} '{word_label}' tags must be a list")

        # Accumulate category
        cat = entry.get("category", "Unknown")
        category_counter[cat] += 1

    # --- Stats ---
    stats = {
        "file": str(path),
        "total_words": actual_total,
        "unique_ids": len(seen_ids),
        "unique_words": len(seen_words),
        "categories": dict(category_counter),
    }

    passed = len(errors) == 0
    return passed, errors, stats


def print_stats(stats: dict) -> None:
    print(f"\n  Words: {stats['total_words']}")
    print(f"  Unique IDs: {stats['unique_ids']}")
    print(f"  Unique English words: {stats['unique_words']}")
    print(f"  Categories ({len(stats['categories'])}):")
    for cat, count in sorted(stats["categories"].items(), key=lambda x: -x[1]):
        print(f"    {cat}: {count}")


def validate_cross_file_duplicates(file_stats: list[dict]) -> list[str]:
    """Check for duplicate IDs and words across multiple files."""
    errors = []
    all_ids: dict[str, str] = {}      # id -> filename
    all_words: dict[str, str] = {}    # word -> filename

    for stats in file_stats:
        fname = stats["file"]
        # We need the raw data again — re-read
        try:
            with open(fname, encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            continue

        for entry in data.get("words", []):
            eid = entry.get("id")
            if eid:
                if eid in all_ids:
                    errors.append(
                        f"Duplicate id '{eid}' in '{fname}' "
                        f"(also in '{all_ids[eid]}')"
                    )
                else:
                    all_ids[eid] = fname

            word = str(entry.get("word", "")).strip().lower()
            if word:
                if word in all_words:
                    errors.append(
                        f"Duplicate word '{word}' in '{fname}' "
                        f"(also in '{all_words[word]}')"
                    )
                else:
                    all_words[word] = fname

    return errors


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: validate_vocab.py <file.json | directory>", file=sys.stderr)
        return 1

    target = Path(sys.argv[1])

    if target.is_dir():
        files = sorted(target.glob("eiken*.json")) + sorted(target.glob("vocab*.json"))
        if not files:
            print(f"No vocab JSON files found in {target}", file=sys.stderr)
            return 1
    elif target.is_file():
        files = [target]
    else:
        print(f"Path not found: {target}", file=sys.stderr)
        return 1

    all_passed = True
    all_stats = []

    for path in files:
        print(f"\n{'='*60}")
        print(f"Validating: {path.name}")
        print("="*60)

        passed, errors, stats = validate_file(path)
        all_stats.append(stats)

        if errors:
            print(f"  ERRORS ({len(errors)}):")
            for e in errors:
                print(f"    - {e}")
            all_passed = False
        else:
            print("  No errors found.")

        if stats:
            print_stats(stats)

        status = "PASS" if passed else "FAIL"
        print(f"\n  Result: {status}")

    # Cross-file duplicate check (only when validating a directory)
    if len(files) > 1:
        print(f"\n{'='*60}")
        print("Cross-file duplicate check")
        print("="*60)
        cross_errors = validate_cross_file_duplicates(all_stats)
        if cross_errors:
            print(f"  ERRORS ({len(cross_errors)}):")
            for e in cross_errors:
                print(f"    - {e}")
            all_passed = False
        else:
            print("  No cross-file duplicates found.")

    print(f"\n{'='*60}")
    print(f"Overall: {'PASS' if all_passed else 'FAIL'}")
    print("="*60)

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())

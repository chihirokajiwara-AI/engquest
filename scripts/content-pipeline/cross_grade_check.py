#!/usr/bin/env python3
"""
cross_grade_check.py — Validate no word or ID overlaps across grade files.

Usage:
    python3 scripts/content-pipeline/cross_grade_check.py [data_dir]

Reads all vocab JSON files from assets/data/ relative to the project root.
Optionally pass an explicit data directory as the first argument.
"""

import json
import sys
from pathlib import Path


def find_project_root() -> Path:
    """
    Walk up from script location to find project root.
    Prefers the candidate that actually has assets/data/.
    Falls back to the first directory with pubspec.yaml.
    """
    here = Path(__file__).resolve().parent
    # Search up to 6 levels to handle worktree nesting (e.g. .claude/worktrees/agent-xxx/scripts/…)
    candidates = [here]
    p = here
    for _ in range(6):
        p = p.parent
        candidates.append(p)
    first_pubspec = None
    for candidate in candidates:
        if (candidate / "pubspec.yaml").exists():
            if (candidate / "assets" / "data").exists():
                return candidate
            if first_pubspec is None:
                first_pubspec = candidate
    return first_pubspec or here.parent.parent


def load_all_files(data_dir: Path) -> list[tuple[str, list[dict]]]:
    """
    Returns list of (filename, words_list) for each JSON file found.
    """
    results = []
    if not data_dir.exists():
        print(f"ERROR: Data directory not found: {data_dir}", file=sys.stderr)
        return results

    json_files = sorted(data_dir.glob("*.json"))
    if not json_files:
        print(f"ERROR: No JSON files found in {data_dir}", file=sys.stderr)
        return results

    for path in json_files:
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            print(f"  WARNING: Cannot load {path.name}: {e}", file=sys.stderr)
            continue

        words = data.get("words")
        if not isinstance(words, list):
            print(f"  WARNING: {path.name} has no 'words' list, skipping.")
            continue

        results.append((path.name, words))

    return results


def check_cross_grade(files: list[tuple[str, list[dict]]]) -> tuple[list[str], list[str]]:
    """
    Check for duplicate IDs and duplicate English words across all files.
    Returns (id_errors, word_errors).
    """
    # id -> (filename, word)
    seen_ids: dict[str, tuple[str, str]] = {}
    # word_lower -> filename
    seen_words: dict[str, str] = {}

    id_errors: list[str] = []
    word_errors: list[str] = []

    for filename, words in files:
        for entry in words:
            if not isinstance(entry, dict):
                continue

            entry_id = entry.get("id")
            word = str(entry.get("word", "")).strip()
            word_lower = word.lower()

            # ID check
            if entry_id:
                if entry_id in seen_ids:
                    orig_file, orig_word = seen_ids[entry_id]
                    id_errors.append(
                        f"Duplicate id '{entry_id}':\n"
                        f"    First : {orig_file} ('{orig_word}')\n"
                        f"    Again : {filename} ('{word}')"
                    )
                else:
                    seen_ids[entry_id] = (filename, word)

            # Word check
            if word_lower:
                if word_lower in seen_words:
                    word_errors.append(
                        f"Duplicate word '{word}':\n"
                        f"    First : {seen_words[word_lower]}\n"
                        f"    Again : {filename}"
                    )
                else:
                    seen_words[word_lower] = filename

    return id_errors, word_errors


def main() -> int:
    if len(sys.argv) >= 2:
        data_dir = Path(sys.argv[1])
    else:
        project_root = find_project_root()
        data_dir = project_root / "assets" / "data"

    print(f"Data dir     : {data_dir}")
    print()

    files = load_all_files(data_dir)
    if not files:
        print("No files to check.", file=sys.stderr)
        return 1

    print(f"Files loaded ({len(files)}):")
    total_words = 0
    for fname, words in files:
        print(f"  {fname}: {len(words)} words")
        total_words += len(words)
    print(f"  Total: {total_words} words across {len(files)} files")
    print()

    print("=" * 60)
    print("Running cross-grade duplicate checks...")
    print("=" * 60)

    id_errors, word_errors = check_cross_grade(files)

    # ---------- ID duplicates ----------
    print(f"\nDuplicate IDs: {len(id_errors)}")
    if id_errors:
        for e in id_errors:
            print(f"  ERROR: {e}")
    else:
        print("  None found.")

    # ---------- Word duplicates ----------
    print(f"\nDuplicate words: {len(word_errors)}")
    if word_errors:
        for e in word_errors:
            print(f"  WARNING: {e}")
    else:
        print("  None found.")

    passed = len(id_errors) == 0 and len(word_errors) == 0

    print()
    print("=" * 60)
    print(f"Result: {'PASS' if passed else 'FAIL'}")
    print("=" * 60)

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())

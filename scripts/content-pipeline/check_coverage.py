#!/usr/bin/env python3
"""
check_coverage.py — Report content coverage vs. target for ENG Quest / A-KEN Quest.

Usage:
    python3 scripts/content-pipeline/check_coverage.py

Reads all vocab JSON files from assets/data/ relative to the project root
(two directories up from this script).
"""

import json
import sys
import os
from pathlib import Path
from collections import Counter

# ---------- Target numbers ----------
VOCAB_TARGETS = {
    "eiken5":   600,
    "eiken4":   700,
    "eiken3":   800,
    "eiken_pre2": 1500,
    "eiken2":   800,
    "eiken_pre1": 3000,
}

SUPPORTING_TARGETS = {
    "grammar_drills":   1290,
    "reading_passages":  240,
}

TOTAL_VOCAB_TARGET = sum(VOCAB_TARGETS.values())          # 7400
TOTAL_SUPPORTING_TARGET = sum(SUPPORTING_TARGETS.values())  # 1530
GRAND_TOTAL_TARGET = TOTAL_VOCAB_TARGET + TOTAL_SUPPORTING_TARGET  # 8930

# Mapping from JSON eikenLevel field -> target key
EIKEN_LEVEL_MAP = {
    "5":   "eiken5",
    "4":   "eiken4",
    "3":   "eiken3",
    "pre2": "eiken_pre2",
    "2":   "eiken2",
    "pre1": "eiken_pre1",
}

# Alternative: detect by filename
FILENAME_MAP = {
    "eiken5_vocab.json":    "eiken5",
    "eiken4_vocab.json":    "eiken4",
    "eiken3_vocab.json":    "eiken3",
    "eiken_pre2_vocab.json": "eiken_pre2",
    "eiken2_vocab.json":    "eiken2",
    "eiken_pre1_vocab.json": "eiken_pre1",
}


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


def load_vocab_files(data_dir: Path) -> dict[str, dict]:
    """Load all vocab JSON files. Returns {grade_key: data_dict}."""
    results = {}
    if not data_dir.exists():
        return results

    for json_file in sorted(data_dir.glob("*.json")):
        # Try filename map first
        grade_key = FILENAME_MAP.get(json_file.name)

        try:
            with open(json_file, encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            print(f"  WARNING: Could not load {json_file.name}: {e}", file=sys.stderr)
            continue

        # Fallback: detect by eikenLevel field in first word
        if grade_key is None:
            words = data.get("words", [])
            if words:
                eiken_level = words[0].get("eikenLevel", "")
                grade_key = EIKEN_LEVEL_MAP.get(str(eiken_level))

        if grade_key is None:
            print(f"  WARNING: Cannot identify grade for {json_file.name}, skipping.")
            continue

        results[grade_key] = data

    return results


def bar(current: int, target: int, width: int = 30) -> str:
    """ASCII progress bar."""
    ratio = min(current / target, 1.0) if target > 0 else 0
    filled = int(ratio * width)
    return "[" + "#" * filled + "-" * (width - filled) + "]"


def percent(current: int, target: int) -> str:
    if target == 0:
        return "N/A"
    return f"{100 * current / target:.1f}%"


def main() -> int:
    project_root = find_project_root()
    data_dir = project_root / "assets" / "data"

    print(f"Project root : {project_root}")
    print(f"Data dir     : {data_dir}")
    print()

    grade_data = load_vocab_files(data_dir)

    # ---------- Vocabulary coverage ----------
    print("=" * 65)
    print(f"{'VOCABULARY COVERAGE':^65}")
    print("=" * 65)
    print(f"{'Grade':<14} {'Have':>6} {'Target':>8} {'Coverage':>10}  Progress")
    print("-" * 65)

    total_have = 0
    missing_grades = []

    grade_order = ["eiken5", "eiken4", "eiken3", "eiken_pre2", "eiken2", "eiken_pre1"]
    grade_labels = {
        "eiken5": "Eiken 5",
        "eiken4": "Eiken 4",
        "eiken3": "Eiken 3",
        "eiken_pre2": "Eiken Pre-2",
        "eiken2": "Eiken 2",
        "eiken_pre1": "Eiken Pre-1",
    }

    for grade_key in grade_order:
        target = VOCAB_TARGETS[grade_key]
        label = grade_labels[grade_key]

        if grade_key in grade_data:
            data = grade_data[grade_key]
            have = len(data.get("words", []))
            total_have += have
            pct = percent(have, target)
            b = bar(have, target)
            print(f"{label:<14} {have:>6} {target:>8} {pct:>10}  {b}")
        else:
            missing_grades.append(label)
            print(f"{label:<14} {'--':>6} {target:>8} {'MISSING':>10}  {'[' + '-'*30 + ']'}")

    print("-" * 65)
    total_target = TOTAL_VOCAB_TARGET
    print(
        f"{'TOTAL VOCAB':<14} {total_have:>6} {total_target:>8} "
        f"{percent(total_have, total_target):>10}  {bar(total_have, total_target)}"
    )
    print()

    # ---------- Category breakdown per grade ----------
    for grade_key in grade_order:
        if grade_key not in grade_data:
            continue
        data = grade_data[grade_key]
        label = grade_labels[grade_key]
        words = data.get("words", [])
        cat_counter: Counter = Counter(w.get("category", "Unknown") for w in words)

        print(f"  {label} — category breakdown ({len(words)} words):")
        for cat, count in sorted(cat_counter.items(), key=lambda x: -x[1]):
            pct = 100 * count / len(words) if words else 0
            print(f"    {cat:<35} {count:>4}  ({pct:.1f}%)")
        print()

    # ---------- Supporting content ----------
    print("=" * 65)
    print(f"{'SUPPORTING CONTENT TARGETS':^65}")
    print("=" * 65)
    print(f"{'Content':<22} {'Target':>8}  Status")
    print("-" * 65)
    for key, target in SUPPORTING_TARGETS.items():
        label = key.replace("_", " ").title()
        print(f"{label:<22} {target:>8}  (not yet tracked — add JSON files to assets/data/)")
    print()

    # ---------- Grand total ----------
    print("=" * 65)
    print(f"{'OVERALL COMPLETION':^65}")
    print("=" * 65)
    print(f"  Vocab words:       {total_have:>5} / {TOTAL_VOCAB_TARGET}")
    print(f"  Supporting:        {'?':>5} / {TOTAL_SUPPORTING_TARGET}")
    print(f"  Grand total est:   {total_have:>5} / {GRAND_TOTAL_TARGET}  "
          f"({percent(total_have, GRAND_TOTAL_TARGET)} of final product)")
    print()

    # ---------- Missing grades warning ----------
    if missing_grades:
        print("MISSING GRADE FILES:")
        for g in missing_grades:
            print(f"  - {g}")
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())

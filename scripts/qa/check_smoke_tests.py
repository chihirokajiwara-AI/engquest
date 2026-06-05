#!/usr/bin/env python3
"""check_smoke_tests.py — R3 SMOKE-TEST PRESENCE audit.

For each feature screen widget under lib/features/**/*_screen.dart (and
named scene widgets), asserts that a corresponding widget test exists
somewhere under test/ that references that widget class by name.

v1: WARN only (does not hard-fail). Prints a backlog of screens lacking
smoke tests so the debt is visible.

Set HARD_FAIL=1 (env var) to make it exit non-zero on any gap — toggle for
when the backlog is cleared.

Exits 0 always in warn-only mode (unless HARD_FAIL=1 and gaps exist).
"""

import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
LIB_FEATURES = REPO_ROOT / 'lib' / 'features'
TEST_DIR = REPO_ROOT / 'test'

HARD_FAIL = os.environ.get('HARD_FAIL', '0') == '1'

# Class name pattern: 'class FooBarScreen extends ...'
CLASS_RE = re.compile(r'\bclass\s+(\w+Screen)\b')


def find_screen_classes():
    """Return dict of {ClassName: dart_file_path} for all *_screen.dart files."""
    screens = {}
    for f in LIB_FEATURES.rglob('*_screen.dart'):
        try:
            content = f.read_text(encoding='utf-8')
        except Exception:
            continue
        for m in CLASS_RE.finditer(content):
            screens[m.group(1)] = f
    return screens


def find_tested_classes():
    """Return set of widget class names referenced in any test file."""
    tested = set()
    for f in TEST_DIR.rglob('*.dart'):
        try:
            content = f.read_text(encoding='utf-8')
        except Exception:
            continue
        for m in re.finditer(r'\b(\w+Screen)\b', content):
            tested.add(m.group(1))
    return tested


def main():
    print('=== R3 SMOKE-TEST PRESENCE ===')
    print()

    screens = find_screen_classes()
    tested = find_tested_classes()

    print(f'  Screen widgets found in lib/features/: {len(screens)}')
    print(f'  Widget classes referenced in test/: {len(tested)}')
    print()

    covered = []
    missing = []
    for cls, dart_file in sorted(screens.items()):
        rel = dart_file.relative_to(REPO_ROOT)
        if cls in tested:
            covered.append((cls, rel))
        else:
            missing.append((cls, rel))

    if covered:
        print(f'  Covered ({len(covered)}):')
        for cls, path in covered:
            print(f'    [OK]   {cls}  ({path})')
        print()

    if missing:
        print(f'  MISSING smoke tests ({len(missing)}):')
        for cls, path in missing:
            print(f'    [WARN] {cls}  ({path})')
        print()
        print(f'R3 WARN: {len(missing)} screen(s) lack a smoke test.')
        print('  A screen is NOT done without a widget smoke test (QUALITY-CONSTITUTION R3).')
        print('  Add tests under test/features/ that pump the widget and assert no exception.')
        if HARD_FAIL:
            print('  (HARD_FAIL=1 — treating as failure)')
            return 1
        else:
            print('  (warn-only mode — set HARD_FAIL=1 to block on this)')
            return 0
    else:
        print('R3 PASSED: All screen widgets have corresponding smoke tests.')
        return 0


if __name__ == '__main__':
    sys.exit(main())

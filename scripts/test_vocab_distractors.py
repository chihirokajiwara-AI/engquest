#!/usr/bin/env python3
"""test_vocab_distractors.py — Regression test for English distractor correctness.

Asserts for every vocab JSON in assets/data/:
  1. Every distractor contains NO Japanese characters.
  2. Each item has exactly 3 distractors.
  3. All 3 distractors are unique.
  4. No distractor equals the word itself (case-insensitive).

Exits 0 on full pass, 1 on any failure.
"""

import json
import re
import sys
from pathlib import Path

JP_RE = re.compile(r'[ぁ-んァ-ヴ一-龠ー]')

VOCAB_FILES = [
    'eiken5_vocab.json',
    'eiken4_vocab.json',
    'eiken3_vocab.json',
    'eiken_pre2_vocab.json',
    'eiken2_vocab.json',
    'eiken_pre1_vocab.json',
]

DATA_DIR = Path(__file__).parent.parent / 'assets' / 'data'


def run_tests():
    failures = []
    total_items = 0
    total_files = 0

    for fname in VOCAB_FILES:
        path = DATA_DIR / fname
        if not path.exists():
            failures.append(f'MISSING FILE: {path}')
            continue

        with open(path, encoding='utf-8') as f:
            data = json.load(f)

        words = data.get('words', data.get('items', []))
        total_files += 1
        file_failures = []

        for entry in words:
            total_items += 1
            word = entry.get('word', '')
            entry_id = entry.get('id', word)
            distractors = entry.get('distractors', [])

            # Assertion 2: exactly 3
            if len(distractors) != 3:
                file_failures.append(
                    f'  [{entry_id}] Expected 3 distractors, got {len(distractors)}: {distractors}'
                )
                continue  # skip further checks if count wrong

            # Assertion 3: unique
            if len(set(d.lower() for d in distractors)) != 3:
                file_failures.append(
                    f'  [{entry_id}] Non-unique distractors: {distractors}'
                )

            for d in distractors:
                # Assertion 1: no Japanese
                if JP_RE.search(d):
                    file_failures.append(
                        f'  [{entry_id}] Japanese characters in distractor: '
                        f'word={word!r} distractor={d!r}'
                    )
                # Assertion 4: not equal to word
                if d.lower() == word.lower():
                    file_failures.append(
                        f'  [{entry_id}] Distractor equals word: {word!r}'
                    )

        status = 'PASS' if not file_failures else f'FAIL ({len(file_failures)} errors)'
        print(f'{fname}: {len(words)} items — {status}')
        if file_failures:
            for line in file_failures[:10]:  # show first 10
                print(line)
            if len(file_failures) > 10:
                print(f'  ... and {len(file_failures) - 10} more')
        failures.extend(file_failures)

    print()
    print(f'=== Results: {total_files} files, {total_items} items ===')
    if failures:
        print(f'FAILED: {len(failures)} assertion(s) failed.')
        return 1
    else:
        print('All assertions PASSED.')
        return 0


if __name__ == '__main__':
    sys.exit(run_tests())

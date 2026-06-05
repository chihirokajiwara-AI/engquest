#!/usr/bin/env python3
"""check_content_integrity.py — R1 CONTENT INTEGRITY gate.

Checks ALL content data:
  1. assets/data/eiken*_vocab.json: each item's distractors = exactly 3,
     unique, != word, contain ZERO Japanese chars.
  2. lib/features/quest/quest_data_test.dart runs via `flutter test` (delegated
     to verify_quality.sh's flutter test step — this script focuses on JSON).

Exits 0 on full pass, non-zero on any failure.
Prints a per-file summary and details for all violations.
"""

import json
import re
import sys
from pathlib import Path

JP_RE = re.compile(r'[ぁ-んァ-ヴ一-龠ー]')

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = REPO_ROOT / 'assets' / 'data'

VOCAB_FILES = [
    'eiken5_vocab.json',
    'eiken4_vocab.json',
    'eiken3_vocab.json',
    'eiken_pre2_vocab.json',
    'eiken2_vocab.json',
    'eiken_pre1_vocab.json',
]


def check_vocab_files():
    failures = []
    total_items = 0
    total_files = 0

    for fname in VOCAB_FILES:
        path = DATA_DIR / fname
        if not path.exists():
            print(f'  MISSING FILE: {path}')
            failures.append(f'MISSING FILE: {fname}')
            continue

        try:
            with open(path, encoding='utf-8') as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            failures.append(f'JSON PARSE ERROR in {fname}: {e}')
            print(f'  JSON PARSE ERROR in {fname}: {e}')
            continue

        words = data.get('words', data.get('items', []))
        total_files += 1
        file_failures = []

        for entry in words:
            total_items += 1
            word = entry.get('word', '')
            entry_id = entry.get('id', word)
            distractors = entry.get('distractors', [])

            # Check 1: exactly 3 distractors
            if len(distractors) != 3:
                file_failures.append(
                    f'  [{entry_id}] Expected exactly 3 distractors, got '
                    f'{len(distractors)}: {distractors}'
                )
                continue  # skip further checks if count wrong

            # Check 2: all unique (case-insensitive)
            lower_d = [d.lower() for d in distractors]
            if len(set(lower_d)) != 3:
                file_failures.append(
                    f'  [{entry_id}] Non-unique distractors: {distractors}'
                )

            for d in distractors:
                # Check 3: no Japanese characters
                if JP_RE.search(d):
                    file_failures.append(
                        f'  [{entry_id}] Japanese chars in distractor: '
                        f'word={word!r} distractor={d!r}'
                    )
                # Check 4: distractor != word
                if d.lower() == word.lower():
                    file_failures.append(
                        f'  [{entry_id}] Distractor equals word: {word!r}'
                    )

        status = 'PASS' if not file_failures else f'FAIL ({len(file_failures)} violations)'
        print(f'  {fname}: {len(words)} items — {status}')
        if file_failures:
            for line in file_failures[:10]:
                print(line)
            if len(file_failures) > 10:
                print(f'    ... and {len(file_failures) - 10} more')
        failures.extend(file_failures)

    print()
    print(f'  Vocab JSON totals: {total_files} files, {total_items} items checked')
    return failures


def main():
    print('=== R1 CONTENT INTEGRITY ===')
    print()
    print('[ Vocab JSON distractors ]')
    vocab_failures = check_vocab_files()

    print()
    if vocab_failures:
        print(f'R1 FAILED: {len(vocab_failures)} violation(s) found.')
        return 1
    else:
        print('R1 PASSED: All content integrity checks passed.')
        return 0


if __name__ == '__main__':
    sys.exit(main())

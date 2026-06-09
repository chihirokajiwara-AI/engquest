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
    'eiken_pre2plus_vocab.json',
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


# CEFR ceiling per 英検 grade — MUST stay in sync with kGradeCefrCeiling in
# lib/features/exam_practice/vocab_grammar_practice_screen.dart (#84). A 大問1
# GRADED ANSWER must not exceed its grade's CEFR band, or the child is measured
# on above-grade vocab. The Dart screen restricts the cloze TARGET pool to
# on-grade words, but FALLS BACK to the full (off-grade-inclusive) pool if a grade
# can't field enough on-grade items — so this gate fails when that fallback would
# silently re-admit off-grade answers.
CEFR_ORDER = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
GRADE_CEFR_CEILING = {
    'eiken5_vocab.json': 'A1',
    'eiken4_vocab.json': 'A2',
    'eiken3_vocab.json': 'B1',
    'eiken_pre2_vocab.json': 'B1',
    'eiken_pre2plus_vocab.json': 'B1',
    'eiken2_vocab.json': 'B2',
    'eiken_pre1_vocab.json': 'B2',
}
# Largest 大問1 question count across grades (準1=18). If a grade's on-grade
# target pool drops below this, the Dart fallback re-admits off-grade words.
MIN_ON_GRADE_TARGET_POOL = 18


def check_grade_cefr_ceiling():
    failures = []
    for fname, ceiling in GRADE_CEFR_CEILING.items():
        path = DATA_DIR / fname
        if not path.exists():
            continue  # already reported by check_vocab_files
        with open(path, encoding='utf-8') as f:
            words = json.load(f).get('words', [])
        cap = CEFR_ORDER.index(ceiling)
        on_grade = [w for w in words
                    if CEFR_ORDER.index(w.get('cefrLevel', 'A1')) <= cap]
        above = len(words) - len(on_grade)
        ok = len(on_grade) >= MIN_ON_GRADE_TARGET_POOL
        flag = 'PASS' if ok else 'FAIL'
        note = f' ({above} above-grade excluded as 大問1 answers)' if above else ''
        print(f'  {fname}: ceiling {ceiling}, on-grade target pool '
              f'{len(on_grade)}/{len(words)} — {flag}{note}')
        if not ok:
            failures.append(
                f'{fname}: only {len(on_grade)} on-grade target words '
                f'(< {MIN_ON_GRADE_TARGET_POOL}); Dart fallback would re-admit '
                f'off-grade answers')
    return failures


def main():
    print('=== R1 CONTENT INTEGRITY ===')
    print()
    print('[ Vocab JSON distractors ]')
    vocab_failures = check_vocab_files()

    print()
    print('[ 大問1 graded-answer on-grade CEFR ceiling (#84) ]')
    ceiling_failures = check_grade_cefr_ceiling()

    failures = vocab_failures + ceiling_failures
    print()
    if failures:
        print(f'R1 FAILED: {len(failures)} violation(s) found.')
        return 1
    else:
        print('R1 PASSED: All content integrity checks passed.')
        return 0


if __name__ == '__main__':
    sys.exit(main())

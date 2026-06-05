#!/usr/bin/env python3
"""fix_vocab_distractors_en.py — Idempotent fixer for vocab JSON distractor fields.

BUG: distractors were Japanese meaning-distractors (e.g. ['取り組み','血統','本能']).
FIX: replace with 3 English words from the same file, same primary POS,
     excluding the word itself and obvious synonyms (same jpTranslation).

Algorithm:
  - For each entry, build a candidate pool: other words in the same file sharing
    the primary POS, excluding exact word match and same jpTranslation.
  - Sort candidates deterministically, then pick 3 using index derived from
    hash(id) so re-runs produce identical output.
  - If same-POS pool < 3 candidates: fall back to relaxed-POS (any POS),
    still excluding self and same jpTranslation. This should only hit the
    tiny preposition groups (2 in eiken5, 1 in eiken2).

Content-QA assertions (fail loudly on violation):
  (a) No Japanese characters in any distractor
  (b) Exactly 3 unique distractors per entry
  (c) No distractor == word (case-insensitive)
  (d) Primary POS matches (or fallback is logged)
"""

import json
import re
import sys
import hashlib
from pathlib import Path
from collections import defaultdict
from typing import List, Dict, Any

# Regex to detect any Japanese character
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


def has_japanese(text: str) -> bool:
    return bool(JP_RE.search(text))


def primary_pos(word_entry: Dict[str, Any]) -> str:
    pos_list = word_entry.get('pos', [])
    return pos_list[0] if pos_list else 'unknown'


def deterministic_pick(candidates: List[str], n: int, seed_id: str) -> List[str]:
    """Pick n items from sorted candidates deterministically using hash(seed_id)."""
    sorted_cands = sorted(candidates)
    h = int(hashlib.sha256(seed_id.encode()).hexdigest(), 16)
    # Use the hash to select a starting offset, then wrap around
    start = h % len(sorted_cands)
    # Reorder: [start:] + [:start], take first n
    reordered = sorted_cands[start:] + sorted_cands[:start]
    return reordered[:n]


def fix_file(fname: str) -> Dict[str, Any]:
    """Fix distractors for one vocab JSON file. Returns stats dict."""
    path = DATA_DIR / fname
    if not path.exists():
        print(f'  SKIP (not found): {path}')
        return {}

    with open(path, encoding='utf-8') as f:
        data = json.load(f)

    words: List[Dict[str, Any]] = data.get('words', data.get('items', []))

    # Build POS → list of (word_str, jpTranslation) for lookup
    pos_to_candidates: Dict[str, List[Dict]] = defaultdict(list)
    for entry in words:
        pos_to_candidates[primary_pos(entry)].append(entry)

    # All words for fallback
    all_candidates = words

    stats = {
        'file': fname,
        'total': len(words),
        'fixed': 0,
        'already_english': 0,
        'fallback_used': 0,
        'fallback_words': [],
        'qa_errors': [],
        'before_after': [],
    }

    for entry in words:
        entry_id = entry.get('id', entry['word'])
        entry_word = entry['word']
        entry_jp = entry.get('jpTranslation', '')
        pos = primary_pos(entry)

        old_distractors = entry.get('distractors', [])

        # Check if already English (idempotency check)
        already_english = all(
            not has_japanese(d) for d in old_distractors
        ) and len(old_distractors) == 3

        # Build same-POS pool: exclude self (by word string, case-insensitive)
        # and obvious synonyms (same jpTranslation)
        same_pos_pool = [
            e['word'] for e in pos_to_candidates[pos]
            if e['word'].lower() != entry_word.lower()
            and e.get('jpTranslation', '') != entry_jp
        ]

        fallback_used = False
        if len(same_pos_pool) >= 3:
            chosen = deterministic_pick(same_pos_pool, 3, entry_id)
        else:
            # Fallback: all POS
            fallback_used = True
            fallback_pool = [
                e['word'] for e in all_candidates
                if e['word'].lower() != entry_word.lower()
                and e.get('jpTranslation', '') != entry_jp
            ]
            chosen = deterministic_pick(fallback_pool, 3, entry_id)
            stats['fallback_used'] += 1
            stats['fallback_words'].append(
                f'{entry_word} (pos={pos}, pool={len(same_pos_pool)})'
            )

        # --- Content-QA assertions ---
        # (a) No Japanese chars
        for d in chosen:
            if has_japanese(d):
                stats['qa_errors'].append(
                    f'QA-FAIL(a) Japanese in distractor: {entry_word!r} -> {d!r}'
                )
        # (b) Exactly 3 unique
        if len(set(chosen)) != 3:
            stats['qa_errors'].append(
                f'QA-FAIL(b) Not 3 unique distractors: {entry_word!r} -> {chosen}'
            )
        # (c) Not == word
        for d in chosen:
            if d.lower() == entry_word.lower():
                stats['qa_errors'].append(
                    f'QA-FAIL(c) Distractor == word: {entry_word!r} -> {d!r}'
                )
        # (d) Same POS (warn if fallback used, already logged)

        # Capture before/after for first 3 changes
        if len(stats['before_after']) < 3 and (
            old_distractors != chosen or not already_english
        ):
            stats['before_after'].append({
                'word': entry_word,
                'before': old_distractors,
                'after': chosen,
            })

        entry['distractors'] = chosen

        if already_english and old_distractors == chosen:
            stats['already_english'] += 1
        else:
            stats['fixed'] += 1

    # Abort on any QA failure before writing
    if stats['qa_errors']:
        print(f'\n!!! QA FAILURES in {fname} !!!')
        for err in stats['qa_errors']:
            print(f'  {err}')
        print('Aborting — file NOT written.')
        sys.exit(1)

    # Write back
    # Preserve the same top-level key ('words' or 'items')
    if 'words' in data:
        data['words'] = words
    else:
        data['items'] = words

    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')  # trailing newline

    return stats


def main():
    print('=== fix_vocab_distractors_en.py ===\n')

    total_fixed = 0
    total_words = 0
    all_fallback = []

    for fname in VOCAB_FILES:
        print(f'Processing {fname} ...')
        stats = fix_file(fname)
        if not stats:
            continue

        total_fixed += stats['fixed']
        total_words += stats['total']
        all_fallback.extend(stats['fallback_words'])

        print(f'  Words: {stats["total"]}')
        print(f'  Fixed:           {stats["fixed"]}')
        print(f'  Already English: {stats["already_english"]}')
        print(f'  Fallback used:   {stats["fallback_used"]}')
        if stats['fallback_words']:
            print(f'    Fallback items: {stats["fallback_words"]}')

        print('  Before/After examples:')
        for ex in stats['before_after']:
            print(f'    word="{ex["word"]}"')
            print(f'      before: {ex["before"]}')
            print(f'      after:  {ex["after"]}')

        print('  QA: PASS (0 errors)')
        print()

    print('=== SUMMARY ===')
    print(f'Total words processed: {total_words}')
    print(f'Total distractors fixed: {total_fixed}')
    print(f'Total fallback (cross-POS) items: {len(all_fallback)}')
    if all_fallback:
        print('Fallback items:')
        for item in all_fallback:
            print(f'  {item}')
    print('\nAll content-QA assertions: PASS')
    print('Done.')


if __name__ == '__main__':
    main()

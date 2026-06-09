#!/usr/bin/env python3
"""derive_pre2plus_vocab.py — build eiken_pre2plus_vocab.json (#34).

英検準2級プラス (2025新設) sits BETWEEN 準2級 (B1) and 2級 (B1–B2), bridging the
long-documented 準2→2 gap (eiken.or.jp 2025newgrade). Its 大問1 vocab was empty,
so the grade fell to an honest 準備中 placeholder.

Rather than fabricate words (the 7,923-distractor-corruption failure mode), this
DERIVES an on-band bank from already-QA'd content (PAID_ASSETS_FIRST):

  • 2級's B1-tagged words            — the 2級-side boundary of the bridge
  • 準2級's academic/abstract B1 set  — the abstract vocabulary that makes
    準2級プラス harder than everyday 準2級 (the "plus")

Result ≈ the size of 旺文社's official 準2級プラス パス単 (~1,200 単語), all words
carrying real jpTranslation + example sentences + (runtime-regenerated) distractors.
Every source word already passed the R1 content gate when 準2/2級 were built, and
the derived file is re-checked by check_content_integrity.py.

Output is DETERMINISTIC (sorted by source word) so re-runs produce no diff.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'

# 準2級 categories that are academic/abstract — these distinguish 準2級プラス from
# everyday 準2級 vocabulary (the "plus" is abstraction, not just more words).
PRE2_ACADEMIC_CATEGORIES = {
    'Academic', 'Abstract Concepts', 'Social Issues', 'Science & Research',
    'Economics & Business', 'Politics & Law', 'Medicine & Health',
    'Technology', 'Psychology & Behavior', 'Education',
    'Media & Communication', 'Environment',
}


def load(fname):
    with open(DATA / fname, encoding='utf-8') as f:
        return json.load(f)


def usable(entry):
    """On-band word with a clozable first example sentence and 3 distractors."""
    es = entry.get('exampleSentences') or []
    return (
        entry.get('word', '').strip()
        and es and isinstance(es[0], str) and es[0].strip()
        and entry.get('jpTranslation', '').strip()
        and len(entry.get('distractors', [])) == 3
    )


def main():
    pre2 = load('eiken_pre2_vocab.json')['words']
    grade2 = load('eiken2_vocab.json')['words']

    picked = {}  # lowercase word -> source entry (first writer wins)

    # 2級-side boundary: every B1-tagged 2級 word.
    for w in grade2:
        if w.get('cefrLevel') == 'B1' and usable(w):
            picked.setdefault(w['word'].lower(), w)

    # 準2級 academic/abstract B1 words — the "plus".
    for w in pre2:
        if (w.get('cefrLevel') == 'B1'
                and w.get('category') in PRE2_ACADEMIC_CATEGORIES
                and usable(w)):
            picked.setdefault(w['word'].lower(), w)

    words = sorted(picked.values(), key=lambda w: w['word'].lower())

    out_words = []
    categories = {}
    for i, w in enumerate(words, start=1):
        e = dict(w)  # shallow copy; we only retag identity fields
        e['id'] = f'pre2plus_{i:04d}'
        e['eikenLevel'] = 'pre2plus'
        e['cefrLevel'] = 'B1'  # 準2級プラス算出帯 = B1 (eiken_exam_config, 2026-06-07)
        cat = e.get('category', 'General')
        categories[cat] = categories.get(cat, 0) + 1
        out_words.append(e)

    out = {
        'version': '1.0.0',
        'created': '2026-06-10',
        'description': (
            '英検準2級プラス vocabulary — derived on-band (B1) from QA\'d 準2級 '
            'academic/abstract + 2級 B1 boundary words (#34). Interim until a '
            'bespoke 準2級プラス list is sourced.'),
        'totalWords': len(out_words),
        'cefrLevel': 'B1',
        'eikenLevel': 'pre2plus',
        'categories': categories,
        'words': out_words,
    }

    dest = DATA / 'eiken_pre2plus_vocab.json'
    with open(dest, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'Wrote {dest.name}: {len(out_words)} words across '
          f'{len(categories)} categories')


if __name__ == '__main__':
    main()

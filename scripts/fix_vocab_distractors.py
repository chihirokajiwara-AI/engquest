#!/usr/bin/env python3
"""Repair quiz distractors flagged by the Eiken-QA team.

The quiz asks for a word's Japanese meaning. A distractor is BROKEN when it is:
  - not Japanese (English strings — the 3級/2級/準1級 bug: answer is the lone JP option)
  - equal to the answer (eiken4's 109 / eiken5's 1 unanswerable items)
  - empty / not exactly 3 (準1級's 1025)
  - duplicated within the trio
For every broken entry we regenerate 3 Japanese distractors of the SAME part of
speech, drawn from other words in the same grade, never equal to the answer.
Entries whose distractors are already valid Japanese are left untouched.
Also removes duplicate headwords (準2級's 67).

Deterministic (seeded per id) so re-runs are stable. Pure data transform.
"""
import json, glob, random, re, sys

LATIN = re.compile(r'[A-Za-z]')
JP = re.compile(r'[぀-ヿ一-鿿]')

def is_japanese(s):
    s = str(s)
    return bool(JP.search(s)) and not LATIN.search(s)

def primary_pos(w):
    p = w.get('pos')
    if isinstance(p, list):
        return p[0] if p else ''
    return p or ''

def needs_regen(ans, dis):
    if not isinstance(dis, list) or len(dis) != 3:
        return True
    ds = [str(x).strip() for x in dis]
    if ans in ds: return True
    if len(set(ds)) != 3: return True
    if any(not is_japanese(x) for x in ds): return True
    return False

total_fixed = total_dedup = 0
for f in sorted(glob.glob('assets/data/eiken*_vocab.json')):
    d = json.load(open(f))
    words = d.get('words', [])
    # ---- dedup headwords (keep first) ----
    seen, deduped = set(), []
    for w in words:
        k = str(w.get('word', '')).strip().lower()
        if k and k in seen:
            total_dedup += 1; continue
        seen.add(k); deduped.append(w)
    words = deduped
    # ---- build same-POS Japanese meaning pool ----
    pool = {}
    alljp = []
    for w in words:
        jp = str(w.get('jpTranslation', '')).strip()
        if is_japanese(jp):
            pool.setdefault(primary_pos(w), []).append(jp)
            alljp.append(jp)
    fixed = 0
    for w in words:
        ans = str(w.get('jpTranslation', '')).strip()
        if needs_regen(ans, w.get('distractors')):
            cand = [x for x in pool.get(primary_pos(w), []) if x != ans]
            if len(set(cand)) < 3:
                cand = [x for x in alljp if x != ans]
            rng = random.Random(str(w.get('id', w.get('word', ''))))
            uniq = list(dict.fromkeys(cand))  # preserve, dedup
            rng.shuffle(uniq)
            new = uniq[:3]
            if len(new) == 3:
                w['distractors'] = new
                fixed += 1
    d['words'] = words
    if 'totalWords' in d:
        d['totalWords'] = len(words)
    json.dump(d, open(f, 'w'), ensure_ascii=False, indent=2)
    print(f"{f.split('/')[-1]}: words={len(words)} distractor_fixed={fixed}")
    total_fixed += fixed

print(f"\nTOTAL distractor entries repaired: {total_fixed} | duplicate rows removed: {total_dedup}")

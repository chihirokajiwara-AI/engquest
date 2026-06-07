#!/usr/bin/env python3
"""check_asset_contract.py — R2 ASSET CONTRACT gate.

Scans lib/, assets/data/, and quest_data for referenced asset keys. For each:
  - Checks that a matching file exists under assets/ (resolving the
    'audio/...' → 'assets/audio/...' convention used by AssetSource()).
  - Any missing key NOT in assets/ALLOWED_MISSING.txt FAILS the gate.
  - Keys in ALLOWED_MISSING print a WARN line but do not fail.

Exits 0 on full pass (all missing are in ALLOWED_MISSING), 1 on any
hard-failure (unreg'd missing asset).

Asset key conventions (based on codebase usage):
  - 'audio/phonics/x.mp3'  → assets/audio/phonics/x.mp3  (AssetSource prepends 'assets/')
  - 'audio/quiz/x.mp3'     → assets/audio/quiz/x.mp3
  - 'assets/art/x.png'     → assets/art/x.png (already has 'assets/' prefix)
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
LIB_DIR = REPO_ROOT / 'lib'
ASSETS_DIR = REPO_ROOT / 'assets'
ALLOWED_MISSING_PATH = ASSETS_DIR / 'ALLOWED_MISSING.txt'

# Dynamic scene assets — derived from kQuestTowns.eikenLevel values
TOWN_LEVELS = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1']


def load_allowed_missing():
    """Load the ALLOWED_MISSING registry. Returns a set of asset keys (normalized)."""
    allowed = {}
    if not ALLOWED_MISSING_PATH.exists():
        return allowed
    with open(ALLOWED_MISSING_PATH, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('|')
            key = parts[0].strip()
            reason = parts[2].strip() if len(parts) > 2 else '(no reason given)'
            date = parts[1].strip() if len(parts) > 1 else '(no date)'
            allowed[key] = f'{date}: {reason}'
    return allowed


def normalize_key(raw_key: str) -> str:
    """Normalize an asset key to always be relative to REPO_ROOT.

    'audio/phonics/x.mp3'  → 'assets/audio/phonics/x.mp3'
    'assets/art/x.png'     → 'assets/art/x.png'
    """
    if raw_key.startswith('assets/'):
        return raw_key
    return f'assets/{raw_key}'


def collect_referenced_keys():
    """Return set of normalized asset keys referenced in lib/ dart files."""
    # Patterns that yield literal string paths:
    #   audioAsset: 'audio/phonics/phoneme_s.mp3'
    #   autoPlayAudio: 'audio/phonics/blend_cat.mp3'
    #   backgroundAsset: 'assets/art/scenes_layton/town5_lane.webp'
    #   parallaxLayers: ['assets/...', 'assets/...']
    #   npcGreyAsset: 'assets/art/scenes_layton/npc_clockmaker_grey.webp'
    #   npcColorAsset: 'assets/art/scenes_layton/npc_clockmaker_color.webp'
    #   image: AssetImage('assets/art/crest.png')
    #   Image.asset('assets/art/title_bg.png')

    ASSET_STRING_RE = re.compile(
        r"""['"]((?:audio|assets)/[a-zA-Z0-9_./-]+\.(?:mp3|png|jpg|jpeg|webp|gif|wav))['"]"""
    )

    referenced = set()

    dart_files = list(LIB_DIR.rglob('*.dart'))
    for dart_file in dart_files:
        try:
            content = dart_file.read_text(encoding='utf-8')
        except Exception:
            continue
        for m in ASSET_STRING_RE.finditer(content):
            raw = m.group(1)
            # Skip template patterns like 'audio/quiz/$k.mp3'
            if '$' in raw:
                continue
            referenced.add(normalize_key(raw))

    # Also add dynamic scene assets (quest_screen.dart builds these from eikenLevel)
    for level in TOWN_LEVELS:
        referenced.add(f'assets/art/scenes/town_{level}.png')

    return referenced


def check_assets(referenced: set, allowed: dict):
    """Check each referenced key. Returns (missing_hard, missing_warned) lists."""
    missing_hard = []
    missing_warned = []

    for key in sorted(referenced):
        full_path = REPO_ROOT / key
        if full_path.exists():
            continue
        # Not on disk — check allowed_missing
        # The ALLOWED_MISSING keys may be relative to assets/ (like 'audio/phonics/...')
        # or full like 'assets/art/...' — normalize both for lookup
        raw_key_variants = [key, key.removeprefix('assets/')]
        in_allowed = False
        for variant in raw_key_variants:
            if variant in allowed:
                missing_warned.append((key, allowed[variant]))
                in_allowed = True
                break
        if not in_allowed:
            missing_hard.append(key)

    return missing_hard, missing_warned


def main():
    print('=== R2 ASSET CONTRACT ===')
    print()

    allowed = load_allowed_missing()
    print(f'  ALLOWED_MISSING registry: {len(allowed)} entries loaded')
    print()

    referenced = collect_referenced_keys()
    print(f'  Asset keys referenced in lib/ + dynamic scene keys: {len(referenced)}')
    print()

    missing_hard, missing_warned = check_assets(referenced, allowed)

    if missing_warned:
        print(f'  ALLOWED-MISSING (registered, not hard-fail): {len(missing_warned)}')
        for key, reason in missing_warned:
            print(f'    [WARN] {key}')
            print(f'           → {reason}')
        print()

    if missing_hard:
        print(f'  UNREGISTERED MISSING ASSETS: {len(missing_hard)} — HARD FAIL')
        for key in missing_hard:
            print(f'    [FAIL] {key}')
        print()
        print('R2 FAILED: Missing assets not in ALLOWED_MISSING registry.')
        print('  Fix: either add the file, or add an entry to assets/ALLOWED_MISSING.txt')
        return 1
    else:
        total_present = len(referenced) - len(missing_warned)
        print(f'  Present: {total_present} / {len(referenced)}  '
              f'Allowed-missing: {len(missing_warned)} / {len(referenced)}')
        print('R2 PASSED: All referenced assets either exist or are registered.')
        return 0


if __name__ == '__main__':
    sys.exit(main())

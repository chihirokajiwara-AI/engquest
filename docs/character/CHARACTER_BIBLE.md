# コトバ探偵 — Character Bible (LOCKED cast)

**Status:** mains LOCKED by CEO (Telegram 1173, 2026-06-10). This file is the
source of truth for the two protagonists' canonical look + the reproducible recipe
that produced them, so the look survives a `build/` wipe and any future
regeneration matches what the CEO approved.

Reference images (the approved look — DO NOT silently redraw):
- `reference/m5_street_male.png`
- `reference/m6_classic_female.png`

---

## M5 — 男メイン「ストリート」 (default male protagonist)

- **Read:** charismatic teen word-detective, ~16–18. Silver/white tousled hair,
  green eyes, cool & contemporary. Dusty-teal detective coat with a **bright
  orange accent** lining + brass-amber trim; holds a brass magnifying glass.
- **CEO note (1173):** 銀髪／差し色オレンジ／今っぽい現代的クール。最も2026トレンド寄り。
- **Palette anchors:** hair silver-white; eyes green; coat dusty teal (#2E6E6A-ish);
  accent orange (#E8853A-ish); trim brass-amber. Anchor these explicitly when
  regenerating (avoid lighting-driven colour drift, per the 2026 method below).

## M6 — 女メイン「クラシック」 (default female protagonist)

- **Read:** elegant young word-detective, intelligent **warm** smile — 本格 × 親しみ.
  Long brown hair (half-up), blue-green eyes, classic Inverness-style detective
  coat in teal with brass/gold trim; holds a brass magnifying glass.
- **CEO note (1173):** インバネス風コート／知的で温かい微笑み。本格と親しみの両立。
- **Palette anchors:** hair warm brown; eyes blue-green; coat teal; trim brass/gold.

Both sit on the shared コトバ探偵 brand: **dusty-teal detective coat, brass-amber
trim, brass magnifying glass** (the same brand string both were generated on).

---

## Reproduction recipe (LOCKED — reproduces the approved look)

`scripts/generate_protagonist_v3.py` (commit e4e968e), run via `scripts/safe-job.sh`
(MPS, heavy → never synchronous; 暴走防止):

| field | value |
|---|---|
| model | `cagliostrolab/animagine-xl-4.0` (SDXL anime; cached ~6.5G) |
| scheduler | DPMSolverMultistep, Karras sigmas, dpmsolver++ |
| size | 832 × 1216 |
| steps | 30 |
| guidance | 6.5 |
| **M5 seed** | **5555** (`v3_m5_streetwear`) |
| **M6 seed** | **6666** (`v3_m6_classic_sherlock`) |
| brand | `dusty teal detective coat, brass-amber trim, holding a brass magnifying glass` |
| tail | `refined detailed illustration, cinematic dramatic light, masterpiece, best quality` |
| negative | multiple views/sheet/grid, multiple characters, chibi, photo, 3d, flat vector, text, watermark, glossy, neon, lowres, bad anatomy, **white coat / lab coat** |

Same model + seed + prompt + size → reproduces the exact approved portrait.

---

## Next deliverables (folded into the autonomous loop, #58)

1. **Expression sheets** for M5 + M6 — neutral, 探偵-thinking, encouraging,
   合格-celebrate, gentle (もう少し), surprised. These power the result banners +
   dialogue beats.
2. **Grey → colour** dq progression (本格 grey base + colour payoff).
3. **Gender-select start** (#110): pick M5 or M6 as companion at start → wire into
   the existing 「仲間（なかま）を選ぼう」 onboarding step.
4. Consistent scene/onboarding integration; kimo-kawaii sidekick + supporting cast.

### Expression-sheet method (verified latest-first, 2026)

For anime-style *consistency across expressions* the 2026 consensus is **IP-Adapter
FaceID Plus v2** (reference face-lock from `reference/*.png`, no training, ~80–95%
consistent) + ControlNet for pose + ADetailer cleanup; a **character LoRA**
(Kohya, rank 16–32, ~1–3k steps) is the higher-fidelity (~95–100%) fallback if
IP-Adapter drift is too high. Anchor the palette explicitly (above) and generate
base expressions without heavy lighting descriptors to avoid colour drift, then
light separately. Sources (accessed 2026-06-10):
- Digital Zoom Studio, "Stable Diffusion – Character Consistency" (2026-02)
- RunComfy, "Consistent Characters with IPAdapter FaceID Plus"
- Stable Diffusion Art, "Consistent character from different viewing angles"

Run all generation via `scripts/safe-job.sh` (detached + timeout); SD venv at
`~/.venvs/sd`.

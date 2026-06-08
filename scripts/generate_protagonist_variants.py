#!/usr/bin/env python3
"""A-KEN Quest「コトバ探偵」— protagonist DESIGN VARIANTS (別パターン, CEO req 2026-06-09).

The live draft protagonist (build/char_drafts/protagonist_*.png) is the boy
word-detective "Variant A". The CEO asked for alternative protagonist patterns to
choose from. This renders 3 DISTINCT character designs in the SAME frozen
storybook STYLE_BIBLE (style is frozen — only the character design varies), so the
cast decision (#58) has real options.

Style suffix + negative are reused VERBATIM from generate_protagonist.py (frozen).
Each variant uses its own fixed seed so it is reproducible. One neutral upper-body
pose per variant keeps the heavy job within timeout.

Output → build/char_drafts/ (gitignored). DRAFTS for CEO approval — nothing is
committed to assets/ until the CEO locks the cast (#58). Heavy (MPS diffusion);
run via scripts/safe-job.sh with the SD venv python.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("OUT_DIR", ROOT / "build" / "char_drafts"))
OUT.mkdir(parents=True, exist_ok=True)

# FROZEN style + negative — copied verbatim from generate_protagonist.py.
POS_STYLE = ("soft watercolour gouache, warm muted palette, dusty teal and brass amber, "
             "painterly storybook illustration, soft rim light, no harsh outlines, masterpiece")
NEG = ("multiple views, character sheet, reference sheet, collage, grid, multiple characters, "
       "2boys, 2girls, crowd, chibi, photo, 3d, flat vector, textbox, ui, text, watermark, "
       "modern anime gloss, glossy, harsh black outlines, cel shading, neon, lowres, blurry, "
       "bad anatomy, extra limbs")

COMMON = ("solo, 1 child, a young word-detective, upper body, looking at viewer, "
          "simple soft cream background, gentle friendly expression")

# (filename, identity clause, seed) — 3 distinct designs, same frozen style.
VARIANTS = [
    # B — a girl detective (gender option for the cast).
    ("protagonist_varB_girl",
     "a girl, long auburn hair in a low braid, light freckles, dusty teal "
     "detective cape over a cream blouse, brass-amber buttons, small newsboy cap, "
     "holding a brass magnifying glass, warm clever bright eyes", 4242),
    # C — an older, scholarly apprentice-detective.
    ("protagonist_varC_scholar",
     "an older child about twelve, neat dark hair, round brass spectacles, dusty "
     "teal waistcoat over a rolled-sleeve cream shirt, brass-amber buttons, "
     "holding a small notebook and a brass magnifying glass, thoughtful kind", 5353),
    # D — a younger, eager kid (cuter, younger-appeal option).
    ("protagonist_varD_young",
     "a younger small child, round cheeks, big curious eyes, light freckles, an "
     "oversized dusty teal detective coat too big for them, brass-amber buttons, "
     "a large newsboy cap, holding a big brass magnifying glass, eager excited", 6464),
]


def main():
    import torch
    from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler

    model = "cagliostrolab/animagine-xl-4.0"
    print(f"Loading {model} on MPS…")
    pipe = StableDiffusionXLPipeline.from_pretrained(
        model, torch_dtype=torch.float16, use_safetensors=True)
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++")
    pipe.to("mps")
    pipe.set_progress_bar_config(disable=True)

    for fn, identity, seed in VARIANTS:
        out = OUT / f"{fn}.png"
        if out.exists():
            print(f"  skip {fn} (exists)")
            continue
        prompt = f"{COMMON}, {identity}, {POS_STYLE}"
        g = torch.Generator(device="mps").manual_seed(seed)
        print(f"  generating {fn}.png (832x1216, seed {seed})…")
        img = pipe(prompt=prompt, negative_prompt=NEG, width=832, height=1216,
                   num_inference_steps=28, guidance_scale=6.5, generator=g).images[0]
        img.save(out)
        print(f"  saved {out}")
    print("DONE. Variant drafts in", OUT, "— view + CEO-approve (cast lock #58).")


if __name__ == "__main__":
    main()

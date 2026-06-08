#!/usr/bin/env python3
"""A-KEN Quest「コトバ探偵」— protagonist expression sheet (Animagine XL 4.0, local MPS).

The character pillar (CEO 975 GO): the live hero.png is an off-brand glossy-anime
knight — NOT a word-detective and against the FROZEN storybook STYLE_BIBLE. This
designs the real コトバ探偵 protagonist in the frozen style and renders a 5-pose
EXPRESSION SHEET so the child sees one consistent, characterful guide.

Cohesion method (per STYLE_BIBLE): a verbatim identity phrase + a single fixed
seed across every expression → one recognizable character. FROZEN style suffix /
negative reused verbatim from generate_scene_art.py.

Output → build/char_drafts/ (gitignored). These are DRAFTS for CEO approval; the
cast is CEO-locked (#58) — nothing is committed to assets/ until approved.
Heavy (MPS diffusion); run via scripts/safe-job.sh.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("OUT_DIR", ROOT / "build" / "char_drafts"))
OUT.mkdir(parents=True, exist_ok=True)

# Style condensed to fit CLIP's 77-token budget alongside the identity (the full
# frozen STYLE_BIBLE suffix overflowed and was truncated). Same palette/feel words.
POS_STYLE = ("soft watercolour gouache, warm muted palette, dusty teal and brass amber, "
             "painterly storybook illustration, soft rim light, no harsh outlines, masterpiece")
# NEG keeps the frozen anti-gloss + ADDS anti-grid tags: the first pass produced a
# multi-character chibi sheet, so we forbid character-sheet / multi-character layouts.
NEG = ("multiple views, character sheet, reference sheet, collage, grid, multiple characters, "
       "2boys, 2girls, crowd, chibi, photo, 3d, flat vector, textbox, ui, text, watermark, "
       "modern anime gloss, glossy, harsh black outlines, cel shading, neon, lowres, blurry, "
       "bad anatomy, extra limbs")

# Identity, tag-led for Animagine XL 4.0 — "solo" forces ONE character.
PROTAG = ("solo, 1 child, a young word-detective, upper body, looking at viewer, "
          "short tidy brown hair, dusty teal detective coat, brass-amber buttons, "
          "newsboy cap, brass magnifying glass, warm kind clever")

SEED = 7777  # one fixed seed across the sheet → consistent character

# (filename, expression clause) — 3 poses to fit the heavy-job timeout.
POSES = [
    ("protagonist_neutral", "gentle friendly expression"),
    ("protagonist_smile", "warm encouraging smile"),
    ("protagonist_think", "thinking, finger to chin, curious"),
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

    for fn, expr in POSES:
        out = OUT / f"{fn}.png"
        if out.exists():
            print(f"  skip {fn} (exists)")
            continue
        prompt = f"{PROTAG}, {expr}, simple soft cream background, {POS_STYLE}"
        g = torch.Generator(device="mps").manual_seed(SEED)
        print(f"  generating {fn}.png (832x1216, seed {SEED})…")
        img = pipe(prompt=prompt, negative_prompt=NEG, width=832, height=1216,
                   num_inference_steps=28, guidance_scale=6.5, generator=g).images[0]
        img.save(out)
        print(f"  saved {out}")
    print("DONE. Drafts in", OUT, "— view + CEO-approve before committing (cast lock #58).")


if __name__ == "__main__":
    main()

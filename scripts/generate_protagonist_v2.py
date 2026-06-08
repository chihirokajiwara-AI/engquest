#!/usr/bin/env python3
"""コトバ探偵 protagonist — VISUAL exploration v2 (CEO 1040, 2026-06-09).

CEO feedback corrected the v1 direction on three points:
  1) "earnest rookie + cute" skews too YOUNG — 英検 spans 5級(age 6-9) → 準1級
     (high-schoolers/adults) who want 本格的 (serious/authentic). Cute-only loses
     the older paying learners.
  2) Balance 本格 × latest. Proposed: a protagonist that GROWS with the learner —
     approachable 見習い at low grades → sleek/intellectual/cool 名探偵 at 準1.
  3) Design VISUALLY, not from text. 2026 design principles (cbr 2026): silhouette
     -driven, "equal parts substance and style", design communicating growth and
     psychological depth.

This renders a MATURITY SPECTRUM of the SAME word-detective so the cast decision
(#58) can be made by LOOKING: young → mid → mature 本格 → a trend-forward 本格 alt.
Brand palette kept (dusty teal + brass amber, dark-RPG) for continuity; render
register sharpens with age (soft-warm for young → refined/本格 for older).

Output → build/char_drafts/ (gitignored). DRAFTS for CEO visual review; nothing
committed to assets/ until the CEO locks the cast. Heavy (MPS); run via safe-job.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("OUT_DIR", ROOT / "build" / "char_drafts"))
OUT.mkdir(parents=True, exist_ok=True)

NEG = ("multiple views, character sheet, reference sheet, collage, grid, multiple "
       "characters, 2boys, 2girls, crowd, chibi, photo, 3d, flat vector, textbox, "
       "ui, text, watermark, modern anime gloss, glossy, harsh black outlines, "
       "neon, lowres, blurry, bad anatomy, extra limbs, deformed")

# Common world identity: a word-detective in the dusty-teal/brass コトバ探偵 world.
WORLD = ("solo, 1 person, upper body, looking at viewer, a word-detective, dusty "
         "teal detective coat, brass-amber accents, holding a brass magnifying "
         "glass, simple soft cream background")

# (filename, age/maturity identity, render-register suffix, seed)
CANDIDATES = [
    # C1 — 見習い, for 5級/4級: approachable young kid, warm, clean (not babyish).
    ("v2_c1_young",
     "a young child about 9 years old, short tidy hair, big bright curious eyes, "
     "warm friendly half-smile, small newsboy cap, a little freckled",
     "soft watercolour gouache, warm muted palette, gentle rim light, painterly "
     "storybook illustration, no harsh outlines, charming, masterpiece", 4242),
    # C2 — 中堅, bridge for 3級/準2級: a capable young teen, a touch sharper.
    ("v2_c2_bridge",
     "a young teenager about 13 years old, neat hair, confident calm expression, "
     "a slightly more grown-up detective look, subtle determination",
     "semi-detailed painterly illustration, soft but cleaner linework, warm muted "
     "palette with teal and brass, cinematic soft light, masterpiece", 5353),
    # C3 — 名探偵 本格, for 2級/準1級: sleek, intellectual, cool teen detective.
    ("v2_c3_mature",
     "a stylish teenager about 17 years old, sharp intelligent eyes, composed cool "
     "confident expression, sleek tailored long detective coat, refined elegant "
     "silhouette, an air of quiet brilliance",
     "refined detailed illustration, clean confident linework, sophisticated muted "
     "palette, dramatic chiaroscuro lighting, substance and style, 本格 mystery "
     "atmosphere, masterpiece", 6464),
    # C4 — 本格 trend-forward alt: a more fashion-forward, contemporary mature take.
    ("v2_c4_trend",
     "a fashionable young adult detective, late teens, sharp modern haircut, "
     "stylish contemporary streetwear-meets-detective-coat, striking confident "
     "silhouette, charismatic, on-trend 2026 character design",
     "modern refined illustration, bold clean shapes, striking silhouette, muted "
     "teal and amber with one accent colour, editorial lighting, substance and "
     "style, masterpiece", 7777),
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

    for fn, identity, style, seed in CANDIDATES:
        out = OUT / f"{fn}.png"
        if out.exists():
            print(f"  skip {fn} (exists)")
            continue
        prompt = f"{WORLD}, {identity}, {style}"
        g = torch.Generator(device="mps").manual_seed(seed)
        print(f"  generating {fn}.png (832x1216, seed {seed})…")
        img = pipe(prompt=prompt, negative_prompt=NEG, width=832, height=1216,
                   num_inference_steps=30, guidance_scale=6.5, generator=g).images[0]
        img.save(out)
        print(f"  saved {out}")
    print("DONE. v2 maturity-spectrum drafts in", OUT, "— VISUAL review for CEO.")


if __name__ == "__main__":
    main()

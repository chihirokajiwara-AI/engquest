#!/usr/bin/env python3
"""A-KEN Quest「コトバ探偵」— Layton-class scene & character art (Animagine XL 4.0, local MPS).

Generates the Wave-1 vertical slice for the 英検5級 district from assets/art/STYLE_BIBLE.md:
  - one wide, people-free district plate (parallax background)
  - the clockmaker NPC in a grey (silenced) + colour (restored) pair

Cohesion comes from the FROZEN style suffix + a per-district master seed (see the bible).
Output → assets/art/scenes_layton/. Heavy (MPS diffusion); run via scripts/safe-job.sh.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "scenes_layton"
OUT.mkdir(parents=True, exist_ok=True)

POS = ("european storybook illustration, soft watercolour and gouache, warm muted palette, "
       "dusty teal and brass amber and cream and plum shadow, gentle steampunk-fairytale europe, "
       "ghibli howl's moving castle warmth, hand-painted texture, soft rim light, painterly depth "
       "of field, cozy, no harsh outlines, masterpiece, high score, great score, absurdres")
NEG = ("photo, 3d, 3dcg, flat vector, grey background, plain background, textbox, ui, hud, text, "
       "watermark, signature, sterile, modern anime gloss, glossy, harsh black outlines, cel shading, "
       "neon, lowres, blurry, jpeg artifacts, bad anatomy, extra limbs")

DISTRICT_SEED = 5050
CLOCKMAKER = "an elderly kind clockmaker, round spectacles, leather apron, white moustache, gentle"

# (filename, prompt, width, height, seed)
JOBS = [
    ("town5_lane.png",
     "a quiet european clocktower lane at soft morning, a great stopped clock tower, faded "
     "shopfronts, cobblestones, hanging lanterns, gentle haze, NO PEOPLE, empty street, "
     "wide establishing scene", 1216, 832, DISTRICT_SEED),
    ("npc_clockmaker_grey.png",
     f"{CLOCKMAKER}, standing in his clock shop doorway, desaturated muted greyscale, colour "
     "drained away, sorrowful quiet, single character, simple soft background", 832, 1216,
     DISTRICT_SEED + 11),
    ("npc_clockmaker_color.png",
     f"{CLOCKMAKER}, standing in his clock shop doorway, smiling warmly, full warm colour "
     "restored, hopeful, single character, simple soft background", 832, 1216,
     DISTRICT_SEED + 11),
    ("npc_slime_grey.png",
     "a small round cute friendly slime creature mascot, gentle face, desaturated muted "
     "greyscale, colour drained, sorrowful quiet, single character, simple soft background",
     832, 1216, DISTRICT_SEED + 22),
    ("npc_slime_color.png",
     "a small round cute friendly green slime creature mascot, happy gentle face, full warm "
     "colour restored, hopeful, single character, simple soft background", 832, 1216,
     DISTRICT_SEED + 22),
    ("npc_gatekeeper_grey.png",
     "a kind elderly town gatekeeper, simple cap and coat, lantern, desaturated muted "
     "greyscale, colour drained, sorrowful quiet, single character, simple soft background",
     832, 1216, DISTRICT_SEED + 33),
    ("npc_gatekeeper_color.png",
     "a kind elderly town gatekeeper, simple cap and coat, lantern, smiling warmly, full "
     "warm colour restored, hopeful, single character, simple soft background", 832, 1216,
     DISTRICT_SEED + 33),

    # ── 英検4級 district — 風（かぜ）の港町（みなとまち） ──────────────────────
    # The second コトバ探偵 district: a windy harbour town where the words for
    # places, directions and everyday actions were carried off by the サイレント.
    ("town4_harbor.png",
     "a quiet european harbour town at soft overcast morning, stone quay, moored sailing "
     "boats with furled sails, gulls, weathered warehouses, a tall lighthouse, hanging nets, "
     "gentle sea haze, NO PEOPLE, empty waterfront, wide establishing scene",
     1216, 832, DISTRICT_SEED + 1000),
    ("npc_fisher_grey.png",
     "a gentle young harbour fisherwoman in a knitted cap and oilskin coat, mending a net, "
     "desaturated muted greyscale, colour drained away, sorrowful quiet, single character, "
     "simple soft harbour background", 832, 1216, DISTRICT_SEED + 1011),
    ("npc_fisher_color.png",
     "a gentle young harbour fisherwoman in a knitted cap and oilskin coat, mending a net, "
     "smiling warmly, full warm colour restored, hopeful, single character, simple soft "
     "harbour background", 832, 1216, DISTRICT_SEED + 1011),
    ("npc_lampkeeper_grey.png",
     "a kind old lighthouse keeper in a heavy coat holding a brass lantern, desaturated "
     "muted greyscale, colour drained away, sorrowful quiet, single character, simple soft "
     "lighthouse background", 832, 1216, DISTRICT_SEED + 1022),
    ("npc_lampkeeper_color.png",
     "a kind old lighthouse keeper in a heavy coat holding a glowing brass lantern, smiling "
     "warmly, full warm colour restored, hopeful, single character, simple soft lighthouse "
     "background", 832, 1216, DISTRICT_SEED + 1022),
]


def main():
    import torch
    from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler

    model = "cagliostrolab/animagine-xl-4.0"
    print(f"Loading {model} on MPS…")
    pipe = StableDiffusionXLPipeline.from_pretrained(model, torch_dtype=torch.float16,
                                                     use_safetensors=True)
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++")
    pipe.to("mps")
    pipe.set_progress_bar_config(disable=True)

    for fn, subject, w, h, seed in JOBS:
        out = OUT / fn
        if out.exists():
            print(f"  skip {fn} (exists)")
            continue
        prompt = f"{subject}, {POS}"
        g = torch.Generator(device="mps").manual_seed(seed)
        print(f"  generating {fn} ({w}x{h}, seed {seed})…")
        img = pipe(prompt=prompt, negative_prompt=NEG, width=w, height=h,
                   num_inference_steps=28, guidance_scale=6.5, generator=g).images[0]
        img.save(out)
        print(f"  ok  {out}")
    print(f"DONE: {len(JOBS)} images → {OUT}")


if __name__ == "__main__":
    main()

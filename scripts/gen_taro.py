#!/usr/bin/env python3
# gen_taro.py — generate タロ candidates from the LOCKED spec (CEO 2063: drive,
# don't wait for the Grok render). Same animagine-xl-4.0 / MPS pipeline as
# generate_scene_art.py, but a self-contained タロ prompt so I control it exactly.
#
# Locked spec (docs/design/TARO-CHARACTER-DECISION.md + viral-IP studio):
#  - ONE signature = mismatched ears (one pricked UP, one folded DOWN) → survives
#    a hatless silhouette; cap is the SECOND read, tilted over one eye.
#  - deep saturated teal body (#1A7A78, "jewel teal"), cream belly, brass cap.
#  - big worried-hopeful eyes; refined detailed anime, flat cel, matte (mains' language).
#  - ONE creature, plain bg (anti-grid front-loaded for CLIP-77).
# Candidates are SCRATCH (art_candidates/taro/), reviewed by the character-producer
# agent + the 16px silhouette gate before anything is committed/wired.
import pathlib, torch
from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler

OUT = pathlib.Path(__file__).resolve().parent.parent / "art_candidates" / "taro"
OUT.mkdir(parents=True, exist_ok=True)

POS = ("masterpiece, best quality, 1 creature, solo, a single small mascot creature, "
       "one creature centered, full body, refined detailed anime, flat cel shading, "
       "clean bold ink linework, matte finish, "
       "a small soft round egg-shaped detective creature, "
       "TWO MISMATCHED ears, one ear pricked straight up and alert, one ear folded down, "
       "oversized round detective cap with a brass band tilted low over one eye, "
       "big round worried-hopeful eyes, small cream belly patch, "
       "deep saturated jewel teal green body, dusty teal and warm brass palette, "
       "warm and huggable, instantly lovable, plain pale cream background, premium, 4k")
NEG = ("grid, sprite sheet, sticker sheet, character sheet, multiple creatures, two creatures, "
       "duplicate, rows, tiled, collage, contact sheet, set of, pattern, "
       "symmetric matching ears, both ears identical, bunny, cat, human, person, clothes, robe, "
       "hands, fingers, crowd, border, frame, airbrushed, soft gradient bloom, glossy 3d render, "
       "photo, pastel washed-out, watermark, text, lowres, blurry, bad anatomy, deformed, extra limbs")

def main():
    pipe = StableDiffusionXLPipeline.from_pretrained(
        "cagliostrolab/animagine-xl-4.0", torch_dtype=torch.float16, use_safetensors=True)
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++")
    pipe.to("mps"); pipe.set_progress_bar_config(disable=True)
    for seed in range(6):
        out = OUT / f"taro_{seed:02d}.webp"
        if out.exists():
            print(f"skip {out.name}"); continue
        g = torch.Generator(device="mps").manual_seed(seed)
        print(f"generating {out.name} (seed {seed})…")
        img = pipe(prompt=POS, negative_prompt=NEG, width=1024, height=1024,
                   num_inference_steps=28, guidance_scale=6.5, generator=g).images[0]
        img.save(out, "WEBP", quality=92)
        print(f"  wrote {out}")
    print("DONE")

if __name__ == "__main__":
    main()

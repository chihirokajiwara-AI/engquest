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
PREFIX = "v2_"   # v1 batch REJECTED by character-producer QA (0/6 had the ears);
N = 3            # surgery pass: front-load the ear anatomy, fewer rolls (QA: ≤2-3).

# Surgery pass (v1 REJECTED: 0/6 had ears — SDXL omitted/symmetrized them). Per
# character-producer QA: front-load the EAR ANATOMY as the very first tokens (the
# failed gate), then cap-over-LEFT-eye as a hard positional command, deep teal
# (NOT mint), warm expression (NOT grumpy) — all within CLIP-77.
POS = ("1 creature, solo, ONE EAR STANDING STRAIGHT UP, ONE EAR FOLDED FLAT DOWN, "
       "asymmetric ears, a small round teal detective puppy-creature, "
       "deep jewel teal body, brass cap brim pulled low over the LEFT eye, "
       "right eye visible, worried-hopeful gentle face, cream belly, "
       "flat cel anime, bold clean ink linework, matte, plain background")
NEG = ("angular fins, spiky fins, symmetric ears, both ears the same, no ears, "
       "grumpy, angry brows, bared teeth, slime, blob, puddle, melting, ghost, robot, helmet, "
       "human, person, clothes, hands, two creatures, duplicate, grid, sticker sheet, "
       "mint green, pastel washed-out, airbrushed, glossy 3d, photo, border, frame, "
       "watermark, text, lowres, blurry, bad anatomy, deformed, extra limbs")

def main():
    pipe = StableDiffusionXLPipeline.from_pretrained(
        "cagliostrolab/animagine-xl-4.0", torch_dtype=torch.float16, use_safetensors=True)
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++")
    pipe.to("mps"); pipe.set_progress_bar_config(disable=True)
    for seed in range(N):
        out = OUT / f"{PREFIX}{seed:02d}.webp"
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

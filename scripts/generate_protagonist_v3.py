#!/usr/bin/env python3
"""コトバ探偵 protagonist — v3 mature/本格 register (CEO 1048, 2026-06-09).

CEO picked the C3/C4 direction (mature, sleek, 本格 × contemporary) and asked for
"several more in this value-set". This renders 6 more candidates in that register
— cool, intellectual, stylish, ~16-18 — all KEPT ON the dusty-teal + brass-amber
コトバ探偵 brand (correcting C3's drift to white/gold). Variations span gender,
hair, mood and a classic↔streetwear axis so the cast pick (#58) is made by LOOKING.

Prompts are kept tight (CLIP 77-token budget) so the brand + style actually apply
(v2 truncated the style tails). Output → build/char_drafts/ (gitignored DRAFTS for
CEO visual review). Heavy (MPS); run via safe-job.sh.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("OUT_DIR", ROOT / "build" / "char_drafts"))
OUT.mkdir(parents=True, exist_ok=True)

NEG = ("multiple views, character sheet, grid, multiple characters, 2boys, 2girls, "
       "crowd, chibi, photo, 3d, flat vector, text, watermark, glossy, neon, lowres, "
       "blurry, bad anatomy, extra limbs, deformed, white coat, lab coat")

# Tight prompt: identity + BRAND + register, all inside ~60 tokens so nothing key
# is truncated. (filename, subject clause, seed)
BRAND = "dusty teal detective coat, brass-amber trim, holding a brass magnifying glass"
TAIL = "refined detailed illustration, cinematic dramatic light, masterpiece, best quality"
CANDS = [
    ("v3_m1_male_sleek",
     f"solo, 1 boy, a cool teenage word-detective about 17, sharp eyes, calm "
     f"confident, dark tidy hair, {BRAND}, {TAIL}", 1111),
    ("v3_m2_female_cool",
     f"solo, 1 girl, a cool teenage word-detective about 17, sharp intelligent "
     f"eyes, long flowing hair, composed, {BRAND}, {TAIL}", 2222),
    ("v3_m3_short_modern",
     f"solo, 1 person, a stylish teenage word-detective, short modern undercut, "
     f"striking confident look, {BRAND}, {TAIL}", 3333),
    ("v3_m4_moody_honkaku",
     f"solo, 1 boy, a brilliant teenage word-detective, serious intense gaze, "
     f"messy hair, noir mood, {BRAND}, chiaroscuro, {TAIL}", 4444),
    ("v3_m5_streetwear",
     f"solo, 1 boy, a charismatic teen word-detective, trendy streetwear under a "
     f"{BRAND}, one bright accent colour, {TAIL}", 5555),
    ("v3_m6_classic_sherlock",
     f"solo, 1 girl, an elegant young word-detective, classic inverness-style "
     f"{BRAND}, refined vintage mystery mood, {TAIL}", 6666),
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

    for fn, prompt, seed in CANDS:
        out = OUT / f"{fn}.png"
        if out.exists():
            print(f"  skip {fn} (exists)")
            continue
        g = torch.Generator(device="mps").manual_seed(seed)
        print(f"  generating {fn}.png (832x1216, seed {seed})…")
        img = pipe(prompt=f"{prompt}, upper body, looking at viewer, "
                          "simple soft background",
                   negative_prompt=NEG, width=832, height=1216,
                   num_inference_steps=30, guidance_scale=6.5, generator=g).images[0]
        img.save(out)
        print(f"  saved {out}")
    print("DONE. v3 本格-register drafts in", OUT, "— VISUAL review for CEO.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""コトバ探偵 — M5/M6 expression sheets (#58, CEO 1173 locked cast).

Builds expression variants of the LOCKED mains by reusing their EXACT approved
recipe (model + seed + prompt from generate_protagonist_v3.py) and inserting only
an expression clause. Fixing the seed keeps the framing + the character's design
(hair / coat / colour) stable while the face changes — the highest-fidelity,
zero-new-tooling first pass for ANIME characters.

Why not IP-Adapter FaceID: FaceID uses insightface embeddings trained on real
photos and degrades on illustrated/anime faces. Same-seed prompt variation on the
already-approved generation is the anime-correct, reproducible first pass; if a
given expression drifts too far, escalate that one to a character LoRA (Kohya) per
the Character Bible. (latest-first, 2026-06-10.)

Heavy (MPS) → run ONLY via scripts/safe-job.sh. Output → build/char_drafts/
expressions/ (gitignored drafts for screenshot-audit; approved ones get promoted
into docs/character/reference/expressions/).
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("OUT_DIR", ROOT / "build" / "char_drafts" / "expressions"))
OUT.mkdir(parents=True, exist_ok=True)

NEG = ("multiple views, character sheet, grid, multiple characters, 2boys, 2girls, "
       "crowd, chibi, photo, 3d, flat vector, text, watermark, glossy, neon, lowres, "
       "blurry, bad anatomy, extra limbs, deformed, white coat, lab coat")

BRAND = "dusty teal detective coat, brass-amber trim, holding a brass magnifying glass"
TAIL = "refined detailed illustration, cinematic dramatic light, masterpiece, best quality"

# (key, expression clause inserted right after the identity so it is never
# truncated out of the 77-token CLIP budget).
EXPRESSIONS = [
    ("thinking", "deep in thought, focused intelligent gaze"),
    ("encourage", "warm encouraging smile, kind eyes"),
    ("celebrate", "bright joyful smile, eyes lit up, delighted"),
    ("gentle", "soft gentle reassuring expression, calm kind eyes"),
    ("surprised", "surprised, wide eyes, slightly open mouth"),
]

# Identity halves reuse the LOCKED v3 prompts (seeds preserved for max fidelity).
MAINS = [
    ("m5", 5555,
     "solo, 1 boy, a charismatic teen word-detective, silver hair, green eyes, {EXPR}, "
     f"trendy streetwear under a {BRAND}, one bright orange accent colour, {TAIL}"),
    ("m6", 6666,
     "solo, 1 girl, an elegant young word-detective, long brown hair, blue-green eyes, "
     f"{{EXPR}}, classic inverness-style {BRAND}, refined vintage mystery mood, {TAIL}"),
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

    for tag, seed, tmpl in MAINS:
        for ekey, eclause in EXPRESSIONS:
            out = OUT / f"{tag}_{ekey}.png"
            if out.exists():
                print(f"  skip {out.name} (exists)")
                continue
            prompt = tmpl.replace("{EXPR}", eclause)
            g = torch.Generator(device="mps").manual_seed(seed)
            print(f"  generating {out.name} (seed {seed}, '{ekey}')…")
            img = pipe(prompt=f"{prompt}, upper body, looking at viewer, "
                              "simple soft background",
                       negative_prompt=NEG, width=832, height=1216,
                       num_inference_steps=30, guidance_scale=6.5,
                       generator=g).images[0]
            img.save(out)
            print(f"  saved {out}")
    print("DONE. expression drafts in", OUT, "— screenshot-audit for CEO.")


if __name__ == "__main__":
    main()

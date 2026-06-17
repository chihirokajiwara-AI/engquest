#!/usr/bin/env python3
"""refine_art.py — the missing FINISH stage (#114 craft, CEO 1990「作り込みが足りなすぎる」).

The candidates so far were SINGLE-PASS SDXL @1024 = sketch-grade. 2026 SOTA for premium
character/mascot art is multi-stage: base → img2img REFINE pass → high-res detail. This
script adds stages 2-3 to ONE chosen base image (preserving its composition) so the
creature gains line/shading/detail "作り込み" instead of the flat single-pass look.

Pipeline (diffusers, MPS — the pragmatic local UltimateSDUpscale-equivalent):
  1. Upscale the base webp to a larger canvas (Lanczos) — gives the model room for detail.
  2. SDXL img2img refine at that size with the SAME frozen creature style suffix and a
     LOW-ish strength (default 0.42) so the composition is kept but線・陰影・質感 are
     re-painted in (the detail-injection the single pass skipped).
  3. Optional 2nd lighter pass (strength 0.28) for extra polish.

Style consistency: reuses CREATURE_POS/STYLE/NEG from generate_scene_art.py (the frozen
コトバ探偵 look) so a refined タロ stays cohesive with the locked mains (CEO 1294 整合ゲート).

HEAVY JOB — MPS img2img is minutes/pass. NEVER run inline; launch via scripts/safe-job.sh:
  scripts/safe-job.sh refine_taro 2400 \
    ~/.venvs/sd/bin/python scripts/refine_art.py \
      --input candidates/taro_lantern/cand_02_seed7002.webp \
      --subject "small round bronze lantern creature, warm cyan-gold flame face, little wings" \
      --out candidates/taro_refined --passes 2

--dry-run prints the plan WITHOUT importing torch (loop-safe arg check).
"""
from __future__ import annotations

import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> int:
    ap = argparse.ArgumentParser(description="Refine ONE base image to premium detail.")
    ap.add_argument("--input", required=True, help="base image (webp/png) to refine")
    ap.add_argument("--subject", required=True, help="creature subject (style added)")
    ap.add_argument("--out", default=None, help="output dir (default candidates/refined)")
    ap.add_argument("--scale", type=float, default=1.5, help="upscale factor before refine")
    ap.add_argument("--strength", type=float, default=0.42,
                    help="img2img strength for pass 1 (lower = keep composition)")
    ap.add_argument("--steps", type=int, default=44)
    ap.add_argument("--passes", type=int, default=2, choices=[1, 2],
                    help="2 = a second lighter polish pass (strength 0.28)")
    ap.add_argument("--seed", type=int, default=7000)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    out = args.out or os.path.join(ROOT, "candidates", "refined")
    base = os.path.basename(args.input).rsplit(".", 1)[0]

    if args.dry_run:
        print("[refine] PLAN: refine '{0}' x{1} → {2} pass(es) @strength {3}/{4}"
              .format(args.input, args.scale, args.passes, args.strength, 0.28))
        print("[refine] subject: {0}".format(args.subject))
        print("[refine] out: {0}/{1}_refined.webp".format(out, base))
        return 0

    os.makedirs(out, exist_ok=True)
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    import torch  # noqa: E402
    from PIL import Image  # noqa: E402
    from diffusers import (  # noqa: E402
        StableDiffusionXLImg2ImgPipeline,
        DPMSolverMultistepScheduler,
    )
    from generate_scene_art import CREATURE_NEG  # frozen neg gate  # noqa: E402

    # FRONT-LOAD the craft terms (CLIP truncates at 77 tokens — a long CREATURE_POS
    # prefix + subject pushed the detail terms off the end, so they did nothing the
    # first run). Lead with quality/detail + single-creature gate, THEN the subject,
    # THEN the short truncatable style tail. img2img preserves the base composition,
    # so the heavy anti-grid CREATURE_POS prefix isn't needed here.
    prompt = (
        "masterpiece, best quality, intricate detail, refined cel shading, "
        "clean confident linework, polished, single small mascot creature, "
        f"{args.subject}, refined detailed anime, soft glow, cinematic light"
    )
    neg = CREATURE_NEG

    img = Image.open(args.input).convert("RGB")
    w, h = img.size
    nw, nh = int(w * args.scale), int(h * args.scale)
    # round to multiples of 8 for the VAE
    nw, nh = nw - nw % 8, nh - nh % 8
    img = img.resize((nw, nh), Image.LANCZOS)
    print("[refine] upscaled {0}x{1} → {2}x{3}".format(w, h, nw, nh))

    model = "cagliostrolab/animagine-xl-4.0"
    print("[refine] loading {0} (img2img) on MPS…".format(model))
    pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained(
        model, torch_dtype=torch.float16, use_safetensors=True
    )
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++"
    )
    pipe.to("mps")
    pipe.set_progress_bar_config(disable=True)

    def refine(image, strength, tag):
        g = torch.Generator(device="mps").manual_seed(args.seed)
        print("[refine] {0}: strength {1}, steps {2}…".format(tag, strength, args.steps))
        return pipe(
            prompt=prompt, negative_prompt=neg, image=image,
            strength=strength, num_inference_steps=args.steps,
            guidance_scale=6.5, generator=g,
        ).images[0]

    img = refine(img, args.strength, "pass1")
    if args.passes == 2:
        img = refine(img, 0.28, "pass2")

    fp = os.path.join(out, "{0}_refined.webp".format(base))
    img.save(fp, format="WEBP", quality=92, method=6)
    print("[refine] DONE -> {0}".format(fp))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""generate_art_batch.py — the GENERATE half of generate-many → select-best (#1794).

Generates N candidate images of ONE asset (same subject, varied seeds) using the
EXACT frozen コトバ探偵 style + pipeline as generate_scene_art.py (animagine-xl-4.0
on MPS, DPMSolver-Karras, 28 steps, guidance 6.5, POS/NEG suffix) — so the candidates
stay style-cohesive with the existing 7 plates. The CEO's rule (1794): one shot is
never best — over-generate, then curate. Pipe the output dir into curate_candidates.py
to auto-dedupe + rank, then a human (and later an MLLM) picks the final 1.

HEAVY JOB — MPS generation is ~minutes/image. NEVER run inline in the agent loop;
launch via scripts/safe-job.sh with a timeout and poll:
  scripts/safe-job.sh gen_town5_square 2400 \
    ~/.venvs/sd/bin/python scripts/generate_art_batch.py \
      --name town5_square --count 6 \
      --subject "european village market square, empty wooden market stalls, a stone \
well, cobblestones, hanging lanterns, gentle haze, NO PEOPLE, empty square"
Then: python3 scripts/curate_candidates.py --dir candidates/town5_square

--dry-run prints the plan WITHOUT importing torch (so it is loop-safe to verify args).

Style consistency note: this is the frozen-suffix + curate approach that produced the
existing 7 plates. A shared style-LoRA (the research's deeper consistency lever) layers
on top later via the same pipeline.
"""
from __future__ import annotations

import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate N art candidates of one asset.")
    ap.add_argument("--name", required=True, help="asset id (output dir name)")
    ap.add_argument("--subject", required=True, help="subject prompt (style added)")
    ap.add_argument("--kind", choices=["scene", "npc"], default="scene",
                    help="scene plate (POS/NEG) or character portrait (NPC suffix)")
    ap.add_argument("--count", type=int, default=12)
    ap.add_argument("--base-seed", type=int, default=7000)
    ap.add_argument("--width", type=int, default=None, help="default by --kind")
    ap.add_argument("--height", type=int, default=None, help="default by --kind")
    ap.add_argument("--out", default=None, help="default candidates/<name>")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    out = args.out or os.path.join(ROOT, "candidates", args.name)
    seeds = [args.base_seed + i for i in range(args.count)]
    # Default dims by kind: scenes are tall plates, characters are portraits.
    w = args.width or (1024 if args.kind == "scene" else 832)
    h = args.height or (1536 if args.kind == "scene" else 1216)

    if args.dry_run:
        print("[gen-batch] PLAN: {0} {1} candidates of '{2}', seeds {3}..{4} @ {5}x{6}"
              .format(args.count, args.kind, args.name, seeds[0], seeds[-1], w, h))
        print("[gen-batch] out: {0}".format(out))
        print("[gen-batch] subject: {0}".format(args.subject))
        return 0

    os.makedirs(out, exist_ok=True)
    # Heavy imports only on the real run (kept out of the loop-safe dry-run path).
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    import torch  # noqa: E402
    from diffusers import (  # noqa: E402
        StableDiffusionXLPipeline,
        DPMSolverMultistepScheduler,
    )
    from generate_scene_art import (  # frozen style — no drift  # noqa: E402
        POS, NEG, NPC_POS, NPC_STYLE, NPC_NEG,
    )

    if args.kind == "npc":
        # CLIP-77 budget: full NPC_POS + NPC_STYLE alone nearly fills 77 tokens, so
        # either the palette OR the subject gets truncated. Pack BOTH critical
        # elements — palette AND subject AND single-character — into the first ~22
        # tokens, then the rest of the detail (which may safely truncate). Keeps the
        # frozen key terms (コトバ探偵 dusty-teal/brass, single character, refined
        # detailed anime, detailed eyes, fully clothed) so style stays cohesive.
        # (memory: art-gen-pipeline-realities — CLIP-77 front-load critical terms.)
        prompt = (
            "コトバ探偵 dusty-teal and brass-amber anime, single character, "
            f"{args.subject}, refined detailed anime, sharp clean linework, "
            "detailed eyes with dark pupils, kind mature face, fully clothed, "
            "simple background, warm even lighting, masterpiece, best quality"
        )
        neg = NPC_NEG
    else:
        prompt = "{0}, {1}".format(args.subject, POS)
        neg = NEG

    model = "cagliostrolab/animagine-xl-4.0"
    print("[gen-batch] loading {0} on MPS…".format(model))
    pipe = StableDiffusionXLPipeline.from_pretrained(
        model, torch_dtype=torch.float16, use_safetensors=True
    )
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++"
    )
    pipe.to("mps")
    pipe.set_progress_bar_config(disable=True)

    done = 0
    for i, seed in enumerate(seeds):
        g = torch.Generator(device="mps").manual_seed(seed)
        print("[gen-batch] {0}/{1} seed {2}…".format(i + 1, args.count, seed))
        img = pipe(
            prompt=prompt, negative_prompt=neg, width=w, height=h,
            num_inference_steps=28, guidance_scale=6.5, generator=g,
        ).images[0]
        fp = os.path.join(out, "cand_{0:02d}_seed{1}.webp".format(i, seed))
        img.save(fp, format="WEBP", quality=88, method=6)
        done += 1
        print("[gen-batch] ok {0}".format(fp))
    print("[gen-batch] DONE {0}/{1} -> {2}".format(done, args.count, out))
    print("[gen-batch] next: python3 scripts/curate_candidates.py --dir {0}".format(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

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

# NPC sprites render as a tiny (52–96px) circle-cropped hotspot, so each MUST be
# ONE centered character on a SIMPLE background. The storybook POS + the base
# NEG's "plain background"/"grey background" terms pushed the model toward busy
# multi-character town plates (visual audit 2026-06-11: gatekeeper=crowd poster,
# slime=4×4 sheet, chancellor=ensemble plate). For npc_* we PREPEND solo-portrait
# terms and use a NEG that drops the plain-background ban and adds crowd/sheet/
# frame negatives.
NPC_POS = ("solo, 1character, single character, upper body portrait bust, centered, "
           "facing viewer, modest wholesome storybook character for a children's book, "
           "fully clothed, simple soft uncluttered background, ")
# Child-safety negatives are NON-NEGOTIABLE for a kids' 英検 app: the anime base
# model (Animagine XL) defaults to young sexualized female figures and ignores
# "elderly/old man" age cues, so we hard-negative sexualization AND the default
# young-woman bias (per-character subjects still carry the intended age/sex).
NPC_NEG = ("photo, 3d, 3dcg, flat vector, textbox, ui, hud, text, watermark, signature, "
           "sterile, modern anime gloss, glossy, harsh black outlines, cel shading, neon, "
           "lowres, blurry, jpeg artifacts, bad anatomy, extra limbs, "
           "multiple people, crowd, group, 2girls, 2boys, multiple views, character sheet, "
           "reference sheet, model sheet, grid, collage, montage, border, frame, ornate frame, "
           "many faces, busy background, town full of people, "
           "cleavage, large breasts, breasts, sexualized, sexy, fanservice, revealing clothing, "
           "bare skin, midriff, suggestive, swimsuit, lingerie, gravure")

# Optional overrides (used for verified test runs before touching committed art):
#   ART_FILTER  — only generate jobs whose filename contains this substring
#   ART_OUTDIR  — write to this dir instead of assets/art/scenes_layton
#   ART_FORCE   — regenerate even if the output file already exists
FILTER = os.environ.get("ART_FILTER", "")
OUTDIR = Path(os.environ["ART_OUTDIR"]) if os.environ.get("ART_OUTDIR") else OUT
FORCE = os.environ.get("ART_FORCE", "") not in ("", "0", "false")

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

    # ── 英検3級 district — 学（まな）びの都（みやこ） ──────────────────────────
    # The third コトバ探偵 district: a scholarly old university quarter where the
    # words of study and travel — past/future, comparison, the infinitive — were
    # carried off, leaving the great library silent.
    ("town3_academy.png",
     "a quiet european old university quarter at soft golden afternoon, a grand stone library "
     "with tall arched windows, a clocktower spire, ivy on weathered walls, stone staircases, "
     "lecture halls, scattered open books, gentle haze, NO PEOPLE, empty courtyard, wide "
     "establishing scene", 1216, 832, DISTRICT_SEED + 2000),
    ("npc_librarian_grey.png",
     "a gentle middle-aged librarian in a long cardigan holding a stack of books, round "
     "spectacles, desaturated muted greyscale, colour drained away, sorrowful quiet, single "
     "character, simple soft library background", 832, 1216, DISTRICT_SEED + 2011),
    ("npc_librarian_color.png",
     "a gentle middle-aged librarian in a long cardigan holding a stack of books, round "
     "spectacles, smiling warmly, full warm colour restored, hopeful, single character, "
     "simple soft library background", 832, 1216, DISTRICT_SEED + 2011),
    ("npc_scholar_grey.png",
     "a young earnest student scholar with a satchel and an open notebook, tousled hair, "
     "desaturated muted greyscale, colour drained away, sorrowful quiet, single character, "
     "simple soft courtyard background", 832, 1216, DISTRICT_SEED + 2022),
    ("npc_scholar_color.png",
     "a young earnest student scholar with a satchel and an open notebook, tousled hair, "
     "smiling brightly, full warm colour restored, hopeful, single character, simple soft "
     "courtyard background", 832, 1216, DISTRICT_SEED + 2022),

    # ── 英検準2級 district — 社会（しゃかい）の港町（みなとまち） ────────────────
    # The fourth コトバ探偵 district: a GRAND trade-port city (distinct from 4級's
    # small fishing harbour by scale) — a great customs hall, tall merchant ships,
    # quayside market — where the words of society (passive voice, relative
    # clauses, opinion) were carried off, stilling all public commerce.
    # とうだいもり (lighthouse keeper) reuses 4級's npc_lampkeeper art.
    ("town_pre2_port.png",
     "a grand european trade-port city at soft afternoon, a great stone customs hall with "
     "flags and a clocktower, tall three-masted merchant sailing ships at a busy stone quay, "
     "warehouses, quayside market stalls with striped awnings, gulls, gentle sea haze, NO "
     "PEOPLE, empty waterfront, wide establishing scene", 1216, 832, DISTRICT_SEED + 3000),
    ("npc_captain_grey.png",
     "a weathered sea captain in a long coat and captain's hat with a spyglass, dignified, "
     "desaturated muted greyscale, colour drained away, sorrowful quiet, single character, "
     "simple soft harbour background", 832, 1216, DISTRICT_SEED + 3011),
    ("npc_captain_color.png",
     "a weathered sea captain in a long coat and captain's hat with a spyglass, dignified, "
     "smiling warmly, full warm colour restored, hopeful, single character, simple soft "
     "harbour background", 832, 1216, DISTRICT_SEED + 3011),
    ("npc_merchant_grey.png",
     "a lively quayside market merchant in an apron behind a stall of fruit and cloth, "
     "desaturated muted greyscale, colour drained away, sorrowful quiet, single character, "
     "simple soft market background", 832, 1216, DISTRICT_SEED + 3022),
    ("npc_merchant_color.png",
     "a lively quayside market merchant in an apron behind a stall of fruit and cloth, "
     "smiling warmly, full warm colour restored, hopeful, single character, simple soft "
     "market background", 832, 1216, DISTRICT_SEED + 3022),

    # ── 英検準2級プラス district — 試練（しれん）の橋（はし） ───────────────────
    # The bridge between 準2級 and 2級. Reuses gatekeeper (はしの番人) + fisher
    # (渡し守) NPC art; only the background is new.
    ("town_pre2plus_bridge.png",
     "a great ancient stone bridge with tall arched spans crossing a deep misty river "
     "ravine, a stone gatehouse tower, hanging lanterns, distant mountains, gentle haze, NO "
     "PEOPLE, empty bridge, wide establishing scene", 1216, 832, DISTRICT_SEED + 4000),

    # ── 英検2級 district — 学者（がくしゃ）の城下町（じょうかまち） ──────────────
    # Reuses librarian (せんせい) + scholar (がくせい) + captain (やくにん) art;
    # only the background is new.
    ("town_2_castle.png",
     "a european castle town at soft afternoon below a great castle on a hill, scholarly "
     "stone halls with banners, a market street, stone staircases climbing toward the "
     "castle, gentle haze, NO PEOPLE, empty street, wide establishing scene",
     1216, 832, DISTRICT_SEED + 5000),

    # ── 英検準1級 district — 灰色（はいいろ）の ひろば / The Grey Square ─────────
    # The CLIMAX district: the heart of the サイレント. The square itself stays
    # colour-drained grey — colour returns only as the player restores its NPCs.
    ("town_pre1_grey_square.png",
     "a grand stone city square drained of all colour, desaturated grey and ash, a great "
     "silent hall, weathered statues, a dry stone fountain, overcast melancholy light, "
     "stillness, NO PEOPLE, empty square, wide establishing scene",
     1216, 832, DISTRICT_SEED + 6000),
    ("npc_chancellor_grey.png",
     "a dignified elderly former chancellor in formal layered robes and chain of office, "
     "weary and sorrowful, desaturated muted greyscale, colour drained away, single "
     "character, simple soft grand-hall background", 832, 1216, DISTRICT_SEED + 6011),
    ("npc_chancellor_color.png",
     "a dignified elderly former chancellor in formal layered robes and chain of office, "
     "standing tall with quiet hope, full warm colour restored, single character, simple "
     "soft grand-hall background", 832, 1216, DISTRICT_SEED + 6011),
    ("npc_healer_grey.png",
     "a gentle city healer in flowing robes holding a small lantern and herbs, kind, "
     "desaturated muted greyscale, colour drained away, single character, simple soft "
     "background", 832, 1216, DISTRICT_SEED + 6022),
    ("npc_healer_color.png",
     "a gentle city healer in flowing robes holding a glowing lantern and herbs, kind and "
     "hopeful, full warm colour restored, single character, simple soft background",
     832, 1216, DISTRICT_SEED + 6022),
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

    OUTDIR.mkdir(parents=True, exist_ok=True)
    for fn, subject, w, h, seed in JOBS:
        if FILTER and FILTER not in fn:
            continue
        # The app bundles WebP, not PNG: full-size painted PNGs were 54MB (a
        # heavy web/app payload). We emit .webp (RGB; sprites are circle-masked
        # in-app so no alpha is needed) at ~93% smaller. NPC sprites display at
        # most ~0.20*480px (a small hotspot), so 768px max-dim is still
        # oversized-safe — town plates keep native size.
        webp = fn[:-4] + ".webp" if fn.endswith(".png") else fn
        out = OUTDIR / webp
        if out.exists() and not FORCE:
            print(f"  skip {webp} (exists)")
            continue
        is_npc = fn.startswith("npc_")
        prompt = f"{NPC_POS if is_npc else ''}{subject}, {POS}"
        neg = NPC_NEG if is_npc else NEG
        g = torch.Generator(device="mps").manual_seed(seed)
        print(f"  generating {webp} ({w}x{h}, seed {seed})…")
        img = pipe(prompt=prompt, negative_prompt=neg, width=w, height=h,
                   num_inference_steps=28, guidance_scale=6.5, generator=g).images[0]
        if fn.startswith("npc_"):
            from PIL import Image
            scale = min(768 / max(img.size), 1.0)
            if scale < 1.0:
                img = img.resize(
                    (round(img.width * scale), round(img.height * scale)),
                    Image.LANCZOS,
                )
        # Pass format explicitly: PIL's lazy extension registry may not be
        # initialised in a fresh process, so inferring the format from the
        # suffix can raise "unknown file extension".
        img.save(out, format="WEBP", quality=85, method=6)
        print(f"  ok  {out}")
    print(f"DONE: {len(JOBS)} images → {OUT}")


if __name__ == "__main__":
    main()

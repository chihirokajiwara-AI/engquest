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
# CLIP TRUNCATION FIX (2026-06-12, CEO 本格 check): the pipeline hard-truncates the
# positive prompt at 77 tokens. The old NPC_POS + subject + NPC_STYLE ran to ~166
# tokens, so the STYLE-coherence tail ("refined detailed anime, sharp linework") was
# SILENTLY DROPPED — which is why NPCs never matched the mains' crisp-anime look.
# Fix: FRONT-LOAD the non-negotiable terms (anti-crowd + sharp anime + detailed
# coloured eyes + mature face) into NPC_POS so they always survive; keep NPC_STYLE a
# short tail. Combined frame ≈ 31 + subject ≈ 30 + tail ≈ 10 ≈ 71 < 77.
NPC_POS = ("solo, 1character, single character, upper body portrait, centered, "
           "refined detailed anime, sharp clean linework, "
           "detailed eyes with dark pupils and warm coloured irises, "
           "kind mature face, fully clothed, simple background, ")
# STYLE COHERENCE (CEO 1294): match the LOCKED M5/M6 mains (Animagine-XL, コトバ探偵
# world). Kept short so it fits inside the 77-token window after the subject.
NPC_STYLE = ("コトバ探偵 dusty-teal and brass-amber palette, warm even lighting, "
             "masterpiece, best quality")
# Child-safety negatives are NON-NEGOTIABLE for a kids' 英検 app: the anime base
# model defaults to young sexualized female figures and ignores age cues, so we
# hard-negative sexualization AND the young-woman bias. Mirrors the mains' NEG
# (crowd/chibi/glossy) — note we do NOT negate sharp outlines/cel shading (that
# pushed the first batch soft); we ADD anti-watercolour/storybook to lock the
# mains' crisp look, plus crowd/sheet/frame and child-safety terms.
NPC_NEG = (  # The TWO gates that MUST survive CLIP's 77-token negative truncation are
           # front-loaded: SINGULARITY (the checkpoint is grid/model-sheet-prone — the
           # character-producer caught 6/6 as multi-figure grids once the anti-grid
           # terms got pushed past 77) and CHILD-SAFETY (4/6 were sexualized when these
           # sat past 77). Singularity leads because it is the current blocker.
           "multiple views, character sheet, reference sheet, model sheet, turnaround, "
           "grid, collage, montage, contact sheet, multiple panels, multiple people, "
           "two people, group, crowd, duplicate, many faces, full body, "
           "sexualized, sexy, sultry, cleavage, large breasts, bust emphasis, "
           "young, youthful, young woman, teen, attractive woman, smirk, glare, scowl, "
           "fanservice, pin-up, revealing clothing, bare shoulders, suggestive, lingerie, "
           "seductive, busty, hourglass figure, swimsuit, midriff, bare skin, "
           "chibi, 2girls, 2boys, border, frame, ornate frame, busy background, "
           "watercolour, gouache, storybook illustration, soft painterly, washed out, "
           "photo, 3d, 3dcg, flat vector, textbox, ui, hud, text, watermark, signature, "
           "glossy, neon, lowres, blurry, jpeg artifacts, bad anatomy, extra limbs, deformed, "
           "white coat, lab coat, "
           "shadowed face, hidden eyes, eyes covered by shadow, face in shadow, dark face, "
           # 2026-06-12 (CEO 本格 check): the prior batch output blank glowing-white
           # pupilless eyes (eerie, off the mains' detailed coloured eyes + the
           # opening bible's no-creepy rule). Hard-negate them + the chibi/childish lean.
           "blank eyes, white eyes, all-white eyes, glowing eyes, glowing white eyes, "
           "pupilless, no pupils, empty eyes, blank stare, soulless eyes, dead eyes, "
           "childish, infantile, cutesy, baby face, deformed eyes, asymmetrical eyes")

# ── Non-humanoid MASCOT / creature path (#114 タロ) ──────────────────────────
# The NPC_* prompts above are tuned for HUMAN characters (mature face, dark
# pupils, fully clothed) and even hard-NEGATE glowing eyes — all WRONG for a
# small mascot creature like タロ (a bronze automaton with ONE glowing cyan eye,
# no human face / clothes). This path keeps the singularity + grid + crisp-anime
# gates but drops the human-face/clothing requirement and the anti-glow negatives,
# so the subject's own creature design (bronze body + cyan glow) survives. The
# PALETTE comes from the SUBJECT (each タロ concept carries its own), not the
# dusty-teal detective brand. Square canvas (set by --kind) avoids the grid lean.
CREATURE_POS = ("masterpiece, best quality, solo, single small mascot creature, "
                "one creature, centered, full shot, refined detailed anime, "
                "sharp clean linework, cute, plain simple background, ")
CREATURE_STYLE = "refined detailed anime, soft glow, cinematic light, best quality"
CREATURE_NEG = (  # singularity (grid-prone checkpoint) front-loaded; NO anti-glow /
                # human-face terms (a glowing-eyed automaton needs them ALLOWED)
                "multiple views, character sheet, model sheet, turnaround, grid, "
                "collage, contact sheet, multiple panels, two creatures, duplicate, "
                "human, person, realistic human, human face, girl, boy, child, "
                "clothing, clothes, slime, blob, gel, "
                "border, frame, busy background, watercolour, storybook, soft painterly, "
                "photo, 3d, flat vector, text, ui, watermark, signature, "
                "lowres, blurry, jpeg artifacts, bad anatomy, extra limbs, deformed")

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
        # Creature mascots (slime) are NOT humanoid — the "fully-clothed upper-body
        # bust" framing malforms them (a slime grew a second face + a robed body,
        # QA 2026-06-12). Give creatures a body-appropriate POS/NEG; keep the
        # crisp-anime コトバ探偵 STYLE so they still cohere with the M5/M6 mains.
        is_creature = is_npc and "slime" in fn
        if is_creature:
            # FRONT-LOAD singularity (CLIP-77 + grid-prone, QA 2026-06-12: the model
            # output a 24-slime sticker grid). One large centred slime filling the
            # frame, anti-grid terms first so they survive truncation.
            prompt = (f"1 slime, solo, a single whole slime creature, one large round "
                      f"blob filling the frame, one gentle face, centered closeup, "
                      f"plain background, {subject}, {NPC_STYLE}")
            neg = ("grid, sprite sheet, character sheet, sticker sheet, multiple slimes, "
                   "many slimes, rows of slimes, tiled, repeated, collection, set of, "
                   "pattern, two faces, multiple faces, double face, humanoid, human, "
                   "person, girl, boy, clothes, robe, arms, hands, crowd, multiple, "
                   "border, frame, watercolour, storybook, photo, 3d, text, watermark, "
                   "lowres, blurry, bad anatomy, deformed")
        elif is_npc:
            prompt = f"{NPC_POS}{subject}, {NPC_STYLE}"
            neg = NPC_NEG
        else:
            prompt = f"{subject}, {POS}"
            neg = NEG
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

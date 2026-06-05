# A-KEN Quest「コトバ探偵」— Art Style Bible (FROZEN)

One storybook style-lock prepended to EVERY Animagine XL 4.0 generation so the whole
world reads as a single hand-painted book. Cohesion is the immersion (Layton's lesson) —
NOT budget. Escapes the rejected "昭和" grey-portrait + textbox look.

## Frozen prompt blocks
POSITIVE (suffix on every prompt):
`european storybook illustration, soft watercolour and gouache, warm muted palette,
dusty teal and brass amber and cream and plum shadow, gentle steampunk-fairytale europe,
ghibli howl's moving castle warmth, hand-painted texture, soft rim light, painterly depth
of field, cozy, no harsh outlines, masterpiece, high score, great score, absurdres`

NEGATIVE (on every prompt):
`photo, 3d, 3dcg, flat vector, grey background, plain background, textbox, ui, hud, text,
watermark, signature, sterile, modern anime gloss, glossy, harsh black outlines, cel
shading, neon, lowres, blurry, jpeg artifacts, bad anatomy, extra limbs`

## Palette (hex)
dusty teal #5DA9E9 · brass amber #E0A458 · cream #F5EFE0 · plum shadow #4A3B52

## Generation determinism (cohesion)
- Sampler: DPM++ 2M Karras · CFG 6.5 · 28 steps · SDXL bucket 1216×832 (wide scenes).
- ONE master seed per DISTRICT → a town keeps consistent architecture/lighting.
- Recurring NPCs: a verbatim-reused identity phrase + a fixed per-character seed so the
  cast is recognizable across every appearance.
- Backgrounds are generated EMPTY OF PEOPLE and wide → NPC sprites + tap-hotspots
  composite on top in Flutter (this is what makes a flat PNG an explorable place).

## Districts (master seeds)
- 英検5級 / ことばを失った村 → seed 5050 — a quiet clocktower lane, stopped clock, faded
  shopfronts, soft morning haze.

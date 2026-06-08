# ART DIRECTION — Painted Storybook for Flutter Web (perf-aware)

**Status:** BINDING art spec. Extends the frozen `assets/art/STYLE_BIBLE.md` (do not
contradict its prompt blocks/palette/seeds) and serves lean-Layton
(`COMPOSITION-ARCHITECTURE.md`): the painted **static scene IS the landing and the spine**,
so the title/first plate must load **fast** (web load speed is P0). Grounded in
`Painted2DGameArtDire.json`, `GameHistoryProfessor.json`, `NarrativeWorldDesign.json`.
Cross-refs: `WORLD-BIBLE.md` (per-case motifs), `CHARACTER-BIBLE.md` (per-character hue/seed).

---

## 1. The look (one hand-painted book, cohesion = immersion)

European **watercolour/gouache storybook**, Ghibli (Howl's) warmth + Golden-Age
illustrators (Rackham/Dulac/Bauer — *literary*, not anime-gloss; Child of Light's anchor).
The frozen `STYLE_BIBLE.md` positive/negative prompt blocks and palette are law:

- **Palette:** dusty teal #5DA9E9 · brass amber #E0A458 · cream #F5EFE0 · plum #4A3B52.
  5–7 colours per scene max; any colour outside the four (plus a character's single accent)
  must be explicitly forbidden in the prompt.
- **Depth via atmospheric perspective, not line weight:** three planes — foreground (warm,
  saturated, sharp), midground (cooled, less detail), far (desaturated, blue-shifted, near-
  white horizon). Add to prompts: *"atmospheric perspective, desaturated blue-shifted
  distance, warm saturated foreground, soft depth-of-field."*
- **Colour temperature tells time/mood:** warm amber key = daytime safety; cool teal key =
  mystery/night; plum only in shadow, never as fill.
- **Character–background light match:** every NPC sprite's rim-light + cast-shadow drop on
  the **same side** as the scene's key light (add a per-case lighting-direction note to
  `STYLE_BIBLE.md`). This is what stops sprites reading as "pasted on."
- **Shape language encodes role before the name is read** (warm round allies vs. angular
  Silence; see `CHARACTER-BIBLE.md`).

### 1.1 The colour script (binding, author before any new art)
One row of **7 thumbnail paintings**, one per 事件簿, fixing dominant hue / value-key /
emotional temperature across the whole arc (`Painted2DGameArtDire.json`, Pixar/Eggleston):
**5級 = near-monochrome ash + one warm lamp → … → 準1級 = full rich palette** as words
return. This is the highest-leverage art investment: one session, gates all future
generation ("matching the [case] colour-script node" becomes a hard prompt constraint), and
makes the grey→colour mechanic coherent across all seven cases. Add it to `STYLE_BIBLE.md`.

### 1.2 The grey→colour mechanic is the art's core verb
Every plate ships in **two states**: a desaturated `_grey` and a saturated `_color` — for
**scenes**, not just NPCs. On chapter clear, animate `_grey → _color` via Flutter
`ColorFiltered` saturation tween (0→1 over ~2s). Zero extra art (reuse the colour plate),
maximum emotional payoff. NPC pairs already exist (`npc_*_grey/_color.webp`); extend the
pattern to backgrounds and to the 4 core characters.

### 1.3 UI is part of the painted world
The flat navy `dqBox` (#101A33) breaks immersion every time a dialog appears. Replace its
fill with a **64–128px tiling ink-wash / parchment texture** (WebP lossless, ~2–4KB) +
a dark cream-tinted overlay, used consistently across `DqDialogBox`, command window, and the
解決 reward frame. Highest visual-quality-per-byte change available (`Painted2DGameArtDire.json`).

---

## 2. PERF-AWARE ASSET PIPELINE (Flutter web / CanvasKit, web load = P0)

Context: MEMORY.md flags a **925MB audio web-bundle** as a load root-cause. The art
pipeline must not repeat that mistake. **Rule: nothing is eager-bundled except the title
hero + the first 5級 chapter plate.** Everything else is deferred / lazy.

### 2.1 Formats & compression contract (document in `STYLE_BIBLE.md`)
| Asset class | Format | Quality | Target size | Why |
|---|---|---|---|---|
| **Title hero / first plate** | WebP lossy | Q82–85 | **≤120 KB** | first paint must be fast; large gradients tolerate lossy |
| Scene plates (other chapters) | WebP lossy | Q85 | ≤150 KB each | rich at low size; lazy-loaded |
| Scene `_grey` variant | WebP lossy | Q82 | ≤90 KB | lower-info; some can be a runtime desaturation of `_color` instead of a separate file |
| NPC sprites (transparent) | WebP **lossless** | — | 100–150 KB | lossy VP8 chroma-shifts at transparent edges → colour fringe over plates |
| UI tiles (parchment/ink) | WebP lossless | Q100 | ~2–4 KB | tiny, tiled, reused everywhere |
| Overworld/事件簿-index composite | WebP lossy | Q80 | **≤80 KB** | one low-res painting; tiles swap to hi-res only on tap |

Authoring res per `STYLE_BIBLE.md`: SDXL bucket 1216×832 (wide plates); export/downscale to
the display target (plates ~1536×640 display) before compression — never ship the raw gen.

### 2.2 Loading strategy (the actual perf wins)
1. **Eager:** title hero + 5級 chapter-1 plate + UI tiles only. Cold-start weight stays tiny
   (new players always start at 5級).
2. **Deferred per case:** only the **current and next** case's plates are kept in memory.
   Use route-gated `precacheImage()` on case entry (and Flutter `deferred`/`loadLibrary()`
   for grouped assets). Drop far cases. (`Painted2DGameArtDire.json`.)
3. **Placeholders:** every `Image.asset` keeps its `errorBuilder` → painted `dq` gradient
   fallback (already in `SceneView`); add a low-res blur-up placeholder for plates so a slow
   plate never shows a blank.
4. **Grey from colour at runtime where possible:** prefer a `ColorFiltered` desaturation of
   the `_color` plate over shipping a second `_grey` file — halves scene bytes. Ship a
   separate `_grey` plate only when the art needs hand-painted grey (e.g. the prologue
   desaturation sweep).
5. **drawAtlas for repeated sprites:** if a chapter shows many small repeated elements
   (coins, sparks), batch via `Canvas.drawAtlas` rather than N `Image` widgets.

### 2.3 Renderer / headers (highest-leverage perf, no art cost)
- Build target: **Skwasm (`--wasm`)** for production — ~2–3× graphics throughput vs JS-
  CanvasKit, render off the main thread (smoother grey→colour tweens + parallax)
  (`Painted2DGameArtDire.json`, Flutter docs 2025). Verify against current Flutter 3.44+.
- Add **COOP/COEP headers** in nginx so SharedArrayBuffer multithreading is enabled
  (two lines). Keep the existing CanvasKit path as fallback.

### 2.4 Determinism (cohesion governance)
- ONE master seed per case (`STYLE_BIBLE.md`); plates regenerated only from that seed.
- Recurring characters: verbatim **identity phrase** + fixed **per-character seed** (locked
  in `assets/art/CHARACTER_SHEET.md`; see `CHARACTER-BIBLE.md`).
- Backgrounds generated **EMPTY OF PEOPLE** + wide; NPC sprites + tap-hotspots composite on
  top in Flutter (this is what turns a flat PNG into an explorable scene — already the
  `SceneView`/`Hotspot` model).
- **Identity gate (measurable):** ArcFace cos-sim vs the character's R1 master ≥0.70 for all
  assets (≥0.80 inside the reference set); clothing CLIP ≥0.85; hair/eye ΔE<8. Fail → regen
  (≤3×, then fallback generator). **Fail-closed: below threshold never ships** (per
  `A-KEN-QUEST-DESIGN-BIBLE.md §3`).
- **Heavy jobs (generation/downscale/ArcFace) NEVER in the agent loop** — detached +
  timeout + poll via `scripts/safe-job.sh` (CLAUDE.md enforced).

---

## 3. What exists vs. what to make
- **Exists:** `STYLE_BIBLE.md` (style-lock + 5級 seed 5050), `assets/art/scenes_layton/`
  (plates for most cases + 11 NPC grey/color pairs), masters (hero/prince/princess/slime),
  `SceneView` compositor, `dq_ui.dart`. **Build on these.**
- **Make (priority):** (1) the **7-node colour script** + per-case lighting table in
  `STYLE_BIBLE.md`; (2) the **parchment UI tile**; (3) **scene `_grey`/colour-tween** on
  clear; (4) visual designs + grey/color pairs for the **4 core characters** (きみ, ライラ先生,
  スラ, サイレント) which currently have none; (5) the `assets/art/CHARACTER_SHEET.md` lock.

## Cross-references
`STYLE_BIBLE.md` (FROZEN base) · `COMPOSITION-ARCHITECTURE.md` · `WORLD-BIBLE.md`
· `CHARACTER-BIBLE.md` · MEMORY.md (audio bundle perf root-cause).

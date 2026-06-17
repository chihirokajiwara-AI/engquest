# Layton-quality redesign — buildable spec (CEO 1904)

Team-decided (wf layton-quality-redesign, latest-first) + adversarial-critic-refined.
Goal: close the quality gap the CEO flagged with real Layton screens. See memory
`layton-quality-bar`, `layton-is-the-lodestar`. Real-render every step via
`scripts/render_nazo.mjs` (explore→NPC→ナゾ screenshot) — the critic's #1 point:
"NO REAL RENDER YET; the CEO's complaint was about what he SEES."

## Palette decision = HYBRID (critic-confirmed sound; Phase-3 CEO gate to make default)
Keep the dark-navy/gold ATMOSPHERIC SCENE backdrop + painterly town art (947 honored —
the world stays a 本格 dark RPG). Re-base the ナゾ/puzzle CONTENT PANELS (header, info,
options, hints, buttons, framed preview) onto a warm parchment "casebook" surface —
exactly like Layton (dark town exploration + warm puzzle screens). Reconciles 947:
its real intent was 本物/anti-candy-bright, NOT literally navy; parchment is a
low-saturation antique-storybook palette, the OPPOSITE of the #4FC3F7 candy 947 rejected.

## Palette tokens (ADD to dq_ui.dart ALONGSIDE navy — never delete navy)
- pcParchment0 #F3E3C0 (page/tile base) · pcParchment1 #EBD9B8 (panel fill) ·
  pcSepiaPanel #E1C9A2 (raised card / preview mat)
- pcInk #3B2417 (primary text, ~9:1 AAA on parchment) · pcInkSoft #5B3B1F (labels, AA) ·
  pcFrameBrown #7A5A2E (outer rule) · pcFrameGold #B8923C (inner gilt rule)
- dqInkText() helper = dqText but pcInk + NO black shadow (ink on paper has no glow)

## Reusable widgets (Phase 1, pure-code, additive, NO CEO gate)
- **DqParchPanel** — the core craft primitive (biggest gap): Container pcParchment1,
  radius 10, DOUBLE border (outer Border.all(pcFrameBrown,2.5) + inset nested
  Border.all(pcFrameGold,1.2) at margin 3), soft warm shadow (0x33000000, blur8, y3).
- **DqFramedPreview** — the Layton gold-framed puzzle thumbnail (currently MISSING — the
  single most Layton-defining element): sepia mat + art inset + double frame + caption strip.
- **surface enum (navy|parchment)** on AudioOptionButton + DqChoice so the SAME widget
  renders cream tiles (keep all logic/anim/a11y verbatim — restyle only).
- Hint tiles [1][2][3] horizontal row (44px parch squares, numeral pcInk, cost badge).
- PcInfoPanel (ナゾのジャンル/ばしょ rows) absorbing the framing box (げんば→ようす row).

## Build order (critic's revised — execute in order, each real-rendered)
1. **Phase 1** (no gate): pc* tokens + dqInkText() + DqParchPanel + DqFramedPreview shells.
2. **Phase 1b** (no gate, NOT optional — the CEO LED with the title): TITLE SCREEN using
   EXISTING assets/art/title_bg.png + crest.png + three parchment menu buttons w/ icons.
3. **Phase 2a** (behind `const kNazoWarmTheme` flag, reversible): re-skin nazo_screen
   _header → numbered+named case plate 「ナゾ001 ○○のナゾ」 (zero-pad the index) + parchment.
4. **Phase 2b** (flag): hint tiles [1][2][3] — RESOLVE the [S] contradiction first
   (HintCoinService is 3-tier; either wire a 4th スーパーヒント or drop [S]); PcInfoPanel
   replacing the teal #4FC3F7 _wrongMeaningBanner + _framingBox; restyle options/buttons.
5. **Phase 2c** (NEW — close the structural gap): the 事件簿 selectable CASE-LIST on
   scene_view (numbered ナゾ001/002/003 tiles, checkboxes ☑/☐, red dot unattempted,
   すべて/おきにいり tabs, 「このナゾをとく」/「とじる」book-icon, ▲▼). Data exists (hotspots+solved).
6. **Phase 3 (CEO GATE)**: build→serve:8099→render_nazo.mjs screenshots of warm ナゾ +
   case-list + title → escalate for the palette sign-off BEFORE making warm default / app-wide.
7. **Phase 4 (defer, gate on P3)**: paper-grain texture (procedural fractal-noise CustomPainter
   ~5% opacity, payload-free) + hand-painted gilt CORNER FLOURISHES (the casebook-vs-box
   difference — try a procedural corner-bracket CustomPainter first, else art).

## Guards (all phases)
- a11y contrast ≥4.5:1 (pcInk/pcInkSoft verified AAA/AA on parchment); reduced-motion-safe
  (frames are static); keep notoSerifJp (the antique serif IS right — NO glyph risk);
  jpBreak() on new long JP lines; preserve all Semantics labels + 英検 question rigor.
- NO new art required for v1 of any craft win (title art + scene art for preview exist).

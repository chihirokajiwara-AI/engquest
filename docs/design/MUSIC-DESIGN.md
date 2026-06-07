# A-KEN Quest — Music & Audio Design (for CEO approval BEFORE production)

**Status: DESIGN ONLY — not a single note has been produced. Approve/adjust this
before any music is sourced or made (spec-freeze).**
Compiled 2026-06-07 from a 5-angle expert research panel (iconic game music,
children's/educational audio, interactive/adaptive audio, web/Flutter tech,
sourcing/licensing) — every panelist worked from the same dated, cited research.
Full sources live in each panel brief; key ones cited inline.

---

## 0. The one big idea — make music the SAME mechanic as the art

The world lost its words to **the サイレント (the Silence)**; restoring words turns
scenes grey→colour. **The score must mirror that exactly: a district starts
near-silent (a lone drone), and each restored word adds one musical layer until
the district plays its full, colourful theme.** Silence is the antagonist;
music returning *is* defeating it. This is our differentiator — no competitor's
music is wired to its narrative this tightly.

Rule: **never snap music on** — build it up gradually (layered reintroduction).
(Wayline, "Power of Silence," 2025-04-03.)

Implementation knob: gate the BGM layer-stack on the SAME
`wordsRestored / total` percentage that already drives the grey→colour shader.
0% = drone only (the Silence wins) · 100% = full theme + colour (banished).

---

## 1. The two non-negotiables (evidence-based)

1. **Instrumental only, app-wide.** Lyrics — especially *English* lyrics — badly
   hurt reading/listening in an English app (irrelevant-speech effect; worst when
   lyric language = task language). (Vasilev 2023; Zhang 2024.)
2. **Quiet or silent during any reading / listening / timed task.** BGM harms
   hard verbal tasks; the timed mock must mirror real 英検 silence. Music earns
   its place on *engagement* screens, not *test* screens. (Cheah et al. 2022.)

The "Mozart effect" is a myth — we design around evidence, not it. (Oviedo-Caro 2023.)

---

## 2. Per-screen music ruleset

| Screen | Music? | Style | Notes |
|---|---|---|---|
| Title / opening | **Yes** | One warm, singable **title theme** (the leitmotif, full) | starts on the Start-button tap (autoplay rule) |
| World map / hub | Yes (default on) | Instrumental, calm→mid, **anti-fatigue** | "safe" feeling; vary loops |
| Town / district explore | Yes | District arrangement of the leitmotif; **layered by restoration %** | the silence→music mechanic lives here |
| NPC dialog (ナゾ) | Low bed or none | very low instrumental | TTS/voice takes priority — duck hard |
| Vocab battle / flashcards | Low or none | sparse, very low | verbal task; SFX feedback OK |
| Reading / listening practice | **No** | — | high verbal load; lyrics catastrophic |
| **Timed mock exam** | **No (default off)** | optional neutral ambient only | mirror real 英検 silence |
| Reward / level-up / streak | Yes (short) | **stinger** from the leitmotif | brief, bright, not startling |
| District-restored (climax) | Yes | full restored theme blooms from silence | the silence→colour payoff |
| Settings | — | — | Music / SFX / Voice sliders + global mute + sensory-friendly mode |

Defaults: music **ON** on engagement screens (lifts motivation — Carlier 2024),
**OFF** on quiz/reading/listening/timed-exam. One-tap mute, **persisted**
(SharedPreferences), with **independent Music/SFX/Voice** channels so muting
music never mutes the learning cues (TTS pronunciation, answer feedback).
Accessibility/neurodiversity: a low-stimulation mode is mandatory, not optional.
(Game Accessibility Guidelines.)

---

## 3. The composition plan — one motif, many arrangements (how a tiny budget sounds rich)

- **Write ONE 3–4 note signature motif first** (the "word/hero" theme). Derive the
  title theme, victory jingle, and level-up sting from it → a unified audio-logo a
  child will hum. (Zelda/Kondo motif-cell method; UNDERTALE reuses its theme in 13
  tracks.)
- **Palette (the "fingerprint"):** accordion + marimba + French horn + light
  piano/strings — Layton's storybook colour (Nishiura) with **Hisaishi-style
  simplicity and space** (a melody a 6-year-old sings back after one listen).
- **Per district = re-instrument the same motif** (key/tempo/instrument) so each
  zone feels distinct yet unified. Greyed = motif stripped to one ghost layer;
  restored = motif fully voiced. Same notes, opposite emotional state.
- **DQ 8-slot map** onto our screens: Title(overture) · World-map(field) ·
  Town(warm) · Quiz(sparse "puzzle" tension — the *quietest* track) · Battle ·
  Boss/サイレント · Clear/Ending. Each gets a distinct *texture*, not just a tune.

### Minimum viable audio set (the whole game)
- 1 leitmotif authored in **3–4 stem layers** (drone / pad / rhythm / melody).
- Per district: re-instrument those stems (~5–7 districts × 4 stems = the only
  "big" cost — arrangements, not new compositions).
- ~6 stingers: correct · wrong · level-up · quest-complete · district-restored ·
  world-map fanfare. (0.5–2 s; **rising = good, falling = gentle "not quite"** —
  no harsh buzzer for kids.)
- 1 world-map track + 1 menu/paywall bed.

### Anti-fatigue (kids grind the same screen a long time)
Map/town loops 90 s–3 min **plus** at least one of: melody-toggle · 2–3 track
shuffle · fade-after-~3-loops. Keep repeats under ~3 before something changes.
(Game Developer 2012; Pokémon ≤90 s loops stay fresh via harmony.)

---

## 4. Technical plan (Flutter web + mobile)

- **Format:** primary **AAC/.m4a** (only lossy codec with universal support incl.
  Safari/iOS); optional Opus for Chrome/FF/modern-Safari with .m4a fallback.
  **Avoid MP3 for loops** (encoder padding → audible gap); **avoid Ogg/Vorbis**
  (no Safari). (MDN codec guide.)
- **Bitrate:** 96–128 kbps stereo @48 kHz for music (vs current 64 kbps mono speech).
  ~2-min loop ≈ 1.7 MB.
- **Autoplay:** cannot start audible BGM on load — **start on the title Start-button
  tap** (resume the AudioContext in that gesture). (MDN/Chrome 2026.)
- **Gapless loop:** just_audio's file loop has a *slight gap on web*; for perfect
  seams use the Web Audio decoded-buffer path (`AudioBufferSourceNode.loop`).
  Author loops with wrapping tails (no fade-to-silence). (just_audio docs; MDN.)
- **Packages:** keep **audioplayers** for SFX; add **just_audio** for BGM (real
  LoopMode + multiple simultaneous players). No web crossfade in just_audio → ramp
  volume manually for the layer fades.
- **Ducking (manual on Flutter):** mix priority **TTS/word > UI stingers > BGM >
  ambience**. On TTS, ramp BGM down ~-9 dB over ~400 ms, recover ~1 s. The spoken
  English word is the product — it must always cut through.
- **Loudness:** mobile-weighted ≈ -16 LUFS overall; music bed ~ -23 LUFS, SFX ~ -30.
- **Perf:** decode/preload off the render path (don't block first frame); pause BGM
  + AudioContext when the tab is hidden. Audio is cheap vs CanvasKit.

---

## 5. Sourcing & licensing (¥0 launch → owned-theme later)

- **Launch ¥0:** backbone = **CC0** tracks (OpenGameArt CC0, Pixabay) — no
  attribution, cleanest posture; optional **incompetech CC-BY** with an in-app
  Music-Credits screen. Keep a per-track license log in the repo.
- **AI music = disposable filler only, NEVER the theme.** Post-2025 Suno/Udio give
  a *license, not ownership*, no indemnity, and AI output is likely uncopyrightable
  → a competitor could copy your "iconic" theme. If used at all, prefer Apache-2.0
  open models (ACE-Step/YuE) for ambient loops; avoid MP3/NC-trained outputs.
- **Brand upgrade (post-revenue):** commission ONE original theme + a few
  loops/stingers, **work-for-hire full buyout** (~$1.5k–$5k). Only this yields an
  ownable, defensible iconic theme (the thing that makes Layton/DQ memorable).
- **Japan/JASRAC:** original/CC0/CC-BY not entrusted to a CMO → JASRAC irrelevant.
  In any composer contract, require "not entrusted to JASRAC/NexTone."
- **Verify before commit:** read Pixabay's license page directly (no standalone
  resale clause); filter OpenGameArt to **CC0/CC-BY only** (no NC/SA).

---

## 6. Recommended decision for the CEO

1. **Approve the design** above (or adjust the per-screen ruleset / the
   silence→music mechanic).
2. **Sourcing for launch:** approve the **CC0-backbone, ¥0** path now, with an
   **owned original theme commissioned post-revenue** (the iconic-theme upgrade).
   — This is the safe, world-class trajectory: real immersion at launch, an
   ownable signature theme when revenue justifies it.
3. Then (and only then) the loop will: build the audio bus + ducking + layered
   BGM engine, wire the silence→music mechanic, and integrate the chosen tracks —
   each step gate + audit as usual.

Nothing is produced until you approve §2 (the sourcing/cost decision is yours).

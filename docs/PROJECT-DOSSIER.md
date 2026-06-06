# A-KEN Quest — Project Dossier (for the Opus senior reviewer / 最高責任者)

Complete, evidence-grounded brief. All facts below were verified by inspecting the repo
on 2026-06-06 (pubspec, lib tree, backend, git log, deployed demo). Treat this as the
single onboarding context for a top-tier reviewer (the R8 intervention role in
docs/governance/QUALITY-CONSTITUTION.md). Repo: `~/dev/engquest-flutter` (git, branch main).

---
## 1. PRODUCT & STRATEGY (locked)
- **What:** A-KEN Quest — an 英検 (Eiken) learning app for Japanese children ~6–15. A
  Professor-Layton-style painted point-and-click adventure ("コトバ探偵 / Word-Detective")
  where 英検 items are ナゾ (puzzles) thrown by voiced NPCs in an AI-generated storybook
  world; wrapped in a gentle, async, gacha-free Duolingo-style retention spine.
- **Moat (sole KPI):** a kid genuinely **PASSES 英検**. Total 英検-pass specialization is
  the differentiation. "English is fun" is owned by free competitors (マグナ); "reliably
  passes 英検" is an open quadrant (スタディサプリ for kids exits 2026-06-30 for lacking it).
- **Form:** "Layton soul + Duolingo engine" (see docs/design/STRATEGY-LAYTON-VS-HYBRID).
  NO gacha, real-time PvP, kid chat, energy/heart paywalls, or child-buyable currency
  (Japan minor-monetization law + parent-trust + premium-calm differentiation). Retention
  is diegetic & gentle (streak = a detective's case-log; FSRS review = "a new ナゾ at the 館").
- **Market (verified):** ~4.5M 英検 applicants/yr; 小学生 ~376k (growing); 517 universities
  use 英検 in 入試; 90% of external-test 入試 students choose 英検; 3×/yr cadence + S-CBT.
- **Pricing:** target ¥1,480/mo (strategy doc). ⚠️ DISCREPANCY: the aken flavor code comment
  still says ¥999/month — needs reconciling to ¥1,480 (a tracked cleanup).
- **Story canon:** docs/design/STORY-BIBLE-KOTOBA-TANTEI.json — サイレント = アイラ (the first
  storyteller, きみ's mirror, lost her voice among everyone's); restoration not conquest;
  the 7 声の石 = fragments of the first word; the 準1級 reading-inference items ARE the
  mystery's final clues (英検 mastery = story completion).

## 2. CURRENT STATE
**Shipped + live on the demo (verified, demo HTTP 200):**
- コトバ探偵 Wave-1 explorable painted scene (5級 district, AI-generated) — `69f8676`
- Adaptive 5級→準1級 placement diagnostic (CAT engine + 35-item bank; fixed the
  result-dropped bug) — `d0a9429`
- 英検 Writing engine (Claude-graded rubric, API-degradation-safe) + Listening (52-item
  player, Kokoro audio live) — `d35de7e`
- Enforced Quality Constitution gate (verify_quality.sh) — `d085ebb`
- P0 fix: 10,531 vocab distractors were Japanese → regenerated English same-POS — `c882035`
- Prior: opening PROLOGUE, サイレントバトル (Wave-1, since RETIRED as a front mode — its FSRS
  engine repurposed for the spaced-review 館), narrative recast (魔王 purged), clean audio.
**Building now (parallel, new-files-scoped):** 合格率 meter + per-skill CSE + mock-exam;
二次 (speaking) scaffold (UI + capture + consent notice + stubbed scorer).
**Deferred per CEO:** parental-consent gate (a simple notices+checkbox screen, do at
pre-launch); 17-screen smoke-test backlog; distractor *contextual* quality polish.

## 3. TECH STACK & ARCHITECTURE (verified)
- **Frontend:** Flutter **3.44.0** / Dart **3.12.0**, web + mobile. Web renderer CanvasKit.
  Constraint: **NO `dart:io` in lib/** (web-safe); const-correctness; --fatal-infos clean.
- **Key deps:** firebase_core ^4.9 / firebase_auth ^6.5 / cloud_firestore ^6.4 /
  firebase_analytics ^12.4 / firebase_messaging ^16.2; shared_preferences ^2.2; http ^1.1;
  audioplayers ^5.2; **speech_to_text ^7.0** (the 二次 capture path); purchases_flutter
  ^8.11 (RevenueCat, mobile IAP); google_fonts ^8.0; crypto ^3.
- **Backend:** `backend/server.js` (Node) — a proxy that holds server-side keys: **Claude
  API** (rate-limited 10/min/IP, 60/hr/UID) and **Stripe** (checkout sessions + a Map-based
  subscriptions store — ⚠️ in-memory, not a real DB yet). This is where the planned
  `/v1/pronounce` (Azure) endpoint will live.
- **SRS:** custom **FSRS-4.5** in lib/core/fsrs (schedule/Grade{again,hard,good,easy}). Now
  load-bearing via the 館 design; per-word keying + read-back is the efficacy spine.
- **AI / local (¥0):** **Kokoro TTS** (venv `~/.venvs/kokoro`) for all generated speech
  (vocab/quiz/phrase/listening); **Animagine XL 4.0** image-gen (venv `/tmp/sd-venv`, model
  cached) for the storybook world — frozen style in `assets/art/STYLE_BIBLE.md`. **Claude**
  for writing-rubric grading + (planned) 二次 rubric mapping.
- **Flavors:** `edilab` (free, all unlocked) + `aken` (commercial). Entry points
  lib/main.dart / main_aken.dart / main_edilab.dart.

## 4. REPO STRUCTURE
- `lib/features/`: quest, **explore** (コトバ探偵 scene/ナゾ), exam_practice (vocab/listening/
  writing/reading + the new pass/ meter), onboarding (placement), **speaking** (二次, new),
  battle, paywall, parent_dashboard, home, achievements, voice, legal, dialog, crafting/
  guild/world_map (older/stub).
- `lib/core/`: fsrs, gamification (XP/streak), audio + sound, dialog (ClaudeClient),
  firebase (Auth), storage (PreferencesService), billing, cefr, ui (dq_ui kit), models, data.
- `assets/data/`: 英検 vocab JSONs (5級 600 / 4級 700 / 3級 1300 / 準2級 1431 / 2級 2000 /
  準1級 4500 = **10,531 words**). `lib/features/quest/quest_data.dart`: **154 authored
  quest/ナゾ nodes** across 7 grades.
- `docs/design/` (12 docs): the design canon — DESIGN-BIBLE, STRATEGY, LAYTON-CLASS-
  REDESIGN, STORY-BIBLE, EIKEN-MASTERY-AND-GAPS, COMPETITIVE-AUDIT, WAVE1-HARSH-AUDIT,
  ASR-SPEAKING-RESEARCH, PLACEMENT-DIAGNOSTIC-PLAN, WORLD-CLASS-BUILD-PLAN, OPENING-
  NARRATIVE-BIBLE, EIKEN5-PHONICS-STAGE. `docs/governance/QUALITY-CONSTITUTION.md`.
- Tests: 46 test files, **586 tests** green. Scripts: generate_*_audio.py (Kokoro),
  generate_scene_art.py (Animagine), verify_quality.sh + scripts/qa/, safe-job.sh.

## 5. 英検 CONTENT — coverage vs gaps (from EIKEN-MASTERY-AND-GAPS)
- **Have:** full vocab DBs (10,531), 154 quest nodes, placement bank (35), writing (12-prompt
  seed + Claude grading), listening (52-item seed + audio). Verified current 英検 spec (8
  grades incl. 準2級プラス, CSE/合格点, 2024 reform) is documented.
- **Gaps (ranked):** distractor *contextual* quality (P0 trivial-bug fixed, premium polish
  pending); 二次 speaking (scaffold building; needs Azure); 合格率/mock (building); item
  banks are demo-sized (need dozens/大問/grade for real coverage + re-attempts); 準2級プラス
  absent from kEikenExams config; per-word FSRS keying + read-back (館) not yet wired.

## 6. INFRA, DEPLOY & COST
- **Hosting:** Hetzner VPS `178.105.113.79` (also reachable as ssh `root@178.105.113.79`;
  note: the alias `vps-edilab` is a DIFFERENT box `46.225.27.98` — do not confuse). nginx.
- **Demo:** `http://178.105.113.79:8088` → `/srv/engquest-web` (no-cache + service-worker
  DISABLED so reloads always show latest; production `:80` serves other edilab sites,
  untouched). Deploy = `flutter build web --release --pwa-strategy=none` then
  `rsync -az --delete build/web/ root@178.105.113.79:/srv/engquest-web/`.
- **Cost model:** runs within the flat-rate Claude subscription (Claude Code; no per-token
  API billing). Image/voice gen = local ¥0 (Animagine/Kokoro). VPS = existing. Only
  per-usage cost on the horizon = Azure Pronunciation (~$0.006/min, ~5% of revenue at 5k
  users) for 二次 — needs an Azure account/key (CEO to provide).

## 7. GOVERNANCE & QUALITY (read docs/governance/QUALITY-CONSTITUTION.md)
- **R1–R9 enforced rules** + `scripts/verify_quality.sh` (content-integrity / asset-contract
  / smoke-test audit / leakage grep / analyze / test) — the root-cause fix for "gates were
  conventions, never enforced". Run it before commit/deploy.
- **Heavy-job guard:** `scripts/safe-job.sh` + a PreToolUse(Bash) hook (`.claude/settings.json`)
  — ML/gen/long-builds MUST run detached+timeout (a 16-hr hang once occurred). Do NOT modify
  the guard.
- **Discipline:** R3 render-proof (smoke test + a `?preview=<screen>` Playwright screenshot
  LOOKED AT) and R6 evidence-over-claim are mandatory — green unit tests ≠ a working screen
  (a battle screen once passed 22 tests and rendered a blank crash).

## 8. KNOWN RISKS / DEBT / LAUNCH-BLOCKERS
- 🔴 **二次 scoring has NO published JP-child-L2 benchmark** → calibrate lenient on real audio
  in closed beta; treat as formative coaching, not hard pass/fail.
- 🔴 **保護者同意 consent gate** before any cloud voice send (COPPA-2025 deadline 2026-04-22 /
  APPI-2026) — simple to build, but a hard LAUNCH BLOCKER. Deferred to pre-launch by CEO.
- 🟠 backend subscriptions are an in-memory Map (not a real DB) — must persist before billing
  real customers. RevenueCat (mobile) + Stripe (web) split.
- 🟠 17 screens lack widget smoke tests (R3 backlog); distractor contextual quality; ¥999↔¥1,480
  flavor/strategy mismatch; 準2級プラス missing from exam config.
- 🟠 concurrent CODE agents collide on shared files → use new-files-only scoping or git worktrees.

## 9. KEY DECISION HISTORY (why the product looks like it does)
MVP (battle-flashcard quiz) → harsh competitive audit scored it 3/10 ("quiz in a costume")
→ pivot to a real RPG verb (サイレントバトル, Wave-1) → CEO rejected as still shallow/dated
(昭和) → pivot to the **Professor-Layton コトバ探偵** model with full AI-generated world →
strategy locked as **Layton soul + Duolingo async engine + total 英検-pass specialization**.
The battle is retired front-facing; its FSRS engine powers the spaced-review 館.

## 10. WHAT THE OPUS REVIEWER SHOULD DO (R8 role)
Adversarially review each work stream BEFORE integration against: (a) this dossier + the
constitution; (b) the sole KPI (a kid passes 英検); (c) the premium-calm Layton soul (don't
let retention become a guilt treadmill); (d) child-safety/COPPA + Japan minor law; (e)
solo-AI-dev sustainability (content-rich single-player, NOT live-ops). Verify by MEASUREMENT
(run the demo, the gate, read the screenshots), never by claim. Open questions worth a
senior call: the ¥999↔¥1,480 reconciliation; the per-word-FSRS + mock + 合格率 efficacy spine;
the item-volume scale-up plan; the Azure-vs-self-hosted 二次 timing.

## 11. HOW TO VERIFY (don't trust this doc — measure)
- Play the demo: `http://178.105.113.79:8088` (Start → placement → コトバ探偵 5級 scene).
- Run the gate: `bash scripts/verify_quality.sh`. Build: via `scripts/safe-job.sh`.
- Screens in isolation: `?preview=explore|prologue|placement|writing|listening|questmap|…`.
- The design canon is in `docs/design/`; the verified 英検 spec in EIKEN-MASTERY-AND-GAPS.json.

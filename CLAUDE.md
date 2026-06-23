# ENG Quest — Flutter Web App

## RULE #0 — TEAM-FIRST (MECHANICALLY ENFORCED — DO NOT EDIT TO WEAKEN)

**Before ANY substantive product / design / direction / architecture / "what is
world-class / what do we build next" CONCLUSION, the order is TEAM → DECIDE →
EXECUTE — never the reverse.** The main loop may NOT conclude solo. It MUST first
convene a STANDING multi-expert team (≥5 diverse, latest-2026-grounded value/craft
lenses) via a Workflow — `diverse-values-council` for product/direction/cast/art,
`game-studio-panel` for game×英検 quality, `world-studio`/`character-studio` for
world/cast — let the team reach the collective conclusion, then EXECUTE it. The
loop SURFACES value-conflicts to the CEO; it never overrides the team with its own
taste. "This one is simple / I already know" IS the narrowness this rule exists to
stop — when unsure whether something is substantive, **it is**: run the team.

This is NOT willpower. It is enforced by a blocking hook (`scripts/guard-team-first.sh`,
PreToolUse): a substantive git commit / new lib file / Telegram direction-message is
**physically blocked (exit 2)** unless a fresh team-clearance token exists — and that
token is written ONLY by the PostToolUse hook on a REAL team-Workflow completion
(`scripts/record-team-convened.sh`). There is NO self-serve skip; the gate classifies
by the STAGED GIT DIFF, not the commit message. Tier-2 mechanical execution (read-only
Bash, tests, edits to existing non-design files, applying an already-team-decided plan)
runs freely. Canonical spec + 3-tier decision rights: `docs/governance/DECISION-GATE.md`.
Anti-revert: `scripts/test-team-first-gate.sh` (run in pre-push/CI) asserts the gate +
this rule still exist; editing the guard or settings.json is itself gated. Why Rule #0:
solo-deciding caused a 16h hang, red code shipped, 7,923 corrupted items, false "solid"
verification, exists-mis-scored-as-quality — and text rules alone failed 15+ times.

## Project Overview
English learning RPG for Japanese children (ages 4-18). Target: 英検準1級 / CEFR B2 by high school at ¥3,000/month.
Flutter web app with FSRS-4.5 spaced repetition, Claude AI dialog, Google TTS audio, Firebase backend.

**Live**: http://178.105.113.79 (Hetzner VPS, nginx)
**Repo**: ~/dev/engquest-flutter

## Architecture
- **Frontend**: Flutter Web (Dart)
- **Backend**: Firebase (Auth, Firestore, Hosting)
- **SRS**: FSRS-4.5 custom Dart implementation
- **AI Dialog**: Claude API (haiku, ~$0.0001/turn)
- **Audio**: Google Cloud TTS Neural2-C + bundled MP3s
- **Deploy**: nginx on Hetzner VPS (178.105.113.79)

## Key Directories
```
lib/
├── core/
│   ├── analytics/     # AnalyticsService, AB framework, Firestore progress
│   ├── audio/         # TtsService, WordAudioPlayerService
│   ├── config/        # app_config.dart (API keys)
│   ├── dialog/        # ClaudeClient, DialogService, SuggestionEngine
│   ├── firebase/      # FirebaseConfig, AuthService
│   ├── fsrs/          # FSRS-4.5 algorithm, card repository
│   ├── gamification/  # XP/Level system
│   ├── notifications/ # Web-safe stub (no dart:io)
│   └── storage/       # PreferencesService (SharedPreferences)
├── data/content/      # vocab_a1.dart (300 words)
├── features/
│   ├── battle/        # Flashcard retrieval practice (FSRS)
│   ├── crafting/      # Grammar module (v2 — stub)
│   ├── dialog/        # NPC conversations (Claude API)
│   ├── guild/         # Extended communication (v2 — stub)
│   ├── onboarding/    # Age/level/avatar selection
│   ├── parent_dashboard/ # Progress tracking for parents
│   ├── voice/         # Pronunciation coach (demo mode)
│   └── world_map/     # Main navigation hub
├── app.dart           # App entry, routing
└── main.dart          # Bootstrap
```

## Build & Deploy
```bash
# Local dev
flutter run -d chrome

# Production build (on VPS via Docker)
docker run --rm -v $(pwd):/app cirrusci/flutter:latest bash -c \
  "cd /app && flutter build web --release --web-renderer canvaskit"

# Deploy to VPS
rsync -avz build/web/ root@178.105.113.79:/srv/engquest-web/
ssh root@178.105.113.79 "nginx -t && systemctl reload nginx"
```

## Critical Constraints

### Web Compatibility (MANDATORY)
- **NEVER import dart:io** — breaks web compilation
- Use `package:http/http.dart` for HTTP requests
- Use `kIsWeb` from `package:flutter/foundation.dart` for platform checks
- Firebase packages must be latest versions compatible with Flutter 3.44+
- No flutter_local_notifications on web — use stub/no-op pattern
- No path_provider filesystem access on web — use in-memory cache

### Code Style
- Dart const constructors where possible
- Japanese UI text for child-facing screens (ひらがな preferred for young children)
- English comments and variable names
- No unnecessary abstractions — direct implementation preferred
- Tests in test/ mirroring lib/ structure

### Firebase
- Firestore security rules in firestore.rules (user-isolated data)
- Anonymous auth (COPPA compliant — no PII)
- Offline persistence enabled (CACHE_SIZE_UNLIMITED)

## MVP Status: COMPLETE (19/19 components)
All core components C01-C19 are implemented. See docs/spec/mvp.md for details.

## Task Queue (Post-MVP)

### Priority 0 — Hermes Debt Cleanup (CRITICAL)
- [x] T00a: Fix WordAudioPlayerService — replace stub with real audioplayers playback (currently just debugPrint)
- [x] T00b: Fix SoundService — implement real sound effects (flip, correct, wrong, level-up) — synthesized WAV playback via audioplayers
- [x] T00c: Fix AnalyticsService — wire Firebase Analytics (logEvent, setUserId, setUserProperty are no-ops)
- [x] T00d: Production logging cleanup — gate 27 debugPrint calls behind kDebugMode, remove bare print() in analytics
- [x] T00e: Remove web_static/ — duplicates Flutter app (1,600-line standalone HTML), no longer needed

### Priority 1 — Trial Readiness
- [x] T01: Mobile build (iOS/Android) — resolve Firebase package versions for mobile
- [x] T02: Real speech recognition — replace demo VoiceService with cross-platform speech_to_text (Web Speech API / Apple Speech / Google Speech)
- [x] T03: App Store / Play Store preparation — COPPA compliance review, screenshots, listing
- [x] T04: Parent onboarding flow — email signup for parents, child account linking

### Priority 2 — Content & Engagement
- [x] T05: A2 content expansion — 300 more words (英検4級), new world zone
- [x] T06: Achievement/badge system — milestone rewards (10-day streak, 100 words mastered)
- [x] T07: Sound effects & haptics — battle card flip sounds, XP gain chime, level-up fanfare
- [x] T08: Animated transitions — world map zone entry, battle start/end, dialog NPC appear

### Priority 2.5 — A-KEN Quest (Commercial Product)
- [x] T17: Flutter flavors — edilab (free) + aken (¥999/month) dual-product build
- [x] T18: Bright theme — dark→bright fantasy RPG (#F5F7FA, #4FC3F7 sky blue)
- [x] T19: Eiken grade selector — 5級〜準1級 picker + multi-grade VocabRepository
- [x] T20: Paywall gate — premium upsell screen for locked grades
- [x] T21: Exam practice mode — full Eiken exam structure (2024 reform)
- [x] T22: Part 1 vocab/grammar cloze questions from vocab DB
- [x] T23: Part 2 conversation completion practice
- [x] T24: Part 3 word ordering (語句の並びかえ) practice
- [x] T25: Content pipeline scripts — validation, cross-grade check, audio gen
- [x] T26: Eiken 3級 vocabulary — 1,300 words
- [x] T27: Eiken 2級 vocabulary — 800 words
- [x] T28: Eiken 準1級 vocabulary — 3,000 words
- [x] T29: Part 4 reading comprehension passages + questions
- [x] T30: Stripe billing integration + backend proxy
- [ ] T31: AI character generation — player/monster/world assets
- [x] T32: Backend proxy for Claude API key security

### Priority 3 — v2 Features
- [ ] T09: Crafting module (grammar) — sentence construction puzzles
- [ ] T10: Guild module (discourse) — cooperative story writing
- [ ] T11: Multi-device sync — Firestore real-time sync across devices
- [ ] T12: Adaptive difficulty — FSRS parameter personalization per child

### Priority 4 — Scale & Polish
- [ ] T13: Performance profiling — Canvas/WebGL rendering, memory usage
- [ ] T14: Accessibility — screen reader support, high contrast mode
- [ ] T15: Localization framework — parent UI in Japanese, future expansion
- [ ] T16: Analytics dashboard — Firebase Analytics + BigQuery export

### Priority 0.5 — Discovered Debt (2026-06-01 audit)
- [x] T33: Fix 14 failing tests at root cause (consent-gate overflow, reminders
  default stub, FSRS test self-contradiction, vocab enum-vs-string) — suite now
  437 green; `flutter analyze --fatal-infos --fatal-warnings` fully clean.
- [x] T34: Commit wired-in files left untracked (content_filter, terms_of_service)
  that committed code referenced — a clean checkout previously failed to compile.
- [x] T35: Audio asset contract — RESOLVED (verified 2026-06-11, this note was stale).
  `assets/audio/a1` AND `web/audio/a1` each contain 300 `eiken5_*` MP3s;
  `verify_audio_assets.py` PASSES (300/300 ready, a1 pair byte-identical,
  manifest-consistent). Playback DOES use bundled assets: `tts_service.dart:243,365`
  tries `_loadBundledAsset` → `rootBundle.load('assets/audio/a1/…')` FIRST, before the
  Google-TTS fallback — so the a1 batch is the live 英検5級 offline source. The dirs
  are no longer empty and CI is green on audio. (Optional micro-cleanup: drop the
  vestigial flat `web/audio` presence check in the verifier — guards the removed
  standalone demo — not urgent since the gate is green.) Decided autonomously via
  agent research + empirical re-verification.
- [x] T36: Align CI Flutter to 3.44.x (currently 3.22.x, vs project requirement
  3.44+); resolve the 3.44↔3.22 formatter drift (59 files) so CI format is green.
- [ ] T37: Re-enable autonomous loop ONLY behind a hard gate (analyze 0 + test 0
  failures + clean-checkout compile + untracked-file handling); it was archived
  2026-06-01 after committing red tests and leaving the tree non-compiling.

## Hermes Audit Summary (2026-05-30)
Hermes (hermes-engquest) built the MVP in 4 days (39 commits, 9,200 LOC).
Velocity was excellent but left significant technical debt:
- 14 unresolved TODOs across audio, analytics, and sound services
- 3 critical stub services (SoundService, WordAudioPlayerService, AnalyticsService)
- 27 ungated debugPrint calls that spam production console
- web_static/ directory with 1,600-line duplicate HTML app
- VPS: broken rebuild cron (removed), idle Hermes process (380MB RAM)
All issues are captured in Priority 0 tasks above.

## Agent Rules

### Session Protocol
1. Read this CLAUDE.md first
2. Pick the highest-priority unchecked task from the queue
3. Implement in a single focused session
4. Run `flutter analyze` — zero errors required
5. Run `flutter test` — all tests must pass
6. Mark task complete: change `[ ]` to `[x]` in this file
7. Commit with descriptive message

### Commit Format
```
feat(module): short description

- detail 1
- detail 2
```
Prefix: feat, fix, refactor, test, docs, chore

### Safety
- Never modify app_config.dart API keys
- Never commit .env files or secrets
- Never force-push
- Always verify `flutter analyze` passes before committing
- If a task requires architectural decisions, document the decision in a comment and move on

### Heavy jobs — NEVER run in the agent loop (enforced)
Heavy/long work (ML training, model downloads, image/audio generation, long
builds) must NEVER run synchronously in the tool loop. On 2026-06-03 this caused
a 16-hour hang with the CEO unreachable. Root-cause fix, enforced by a
PreToolUse(Bash) hook (`scripts/guard-heavy-jobs.sh`, registered in
`.claude/settings.json`):
- The hook **blocks** such commands unless routed through the sanctioned wrapper.
- Run them only via: `scripts/safe-job.sh <name> <timeout_seconds> <command...>`
  — detached + hard timeout + `logs/jobs/<name>.{log,status}`.
- Poll status; **stop on `FAILED`/`TIMEOUT`** — never re-loop a failed job.
- The hook is a backstop, not a sandbox: default to `safe-job.sh` for anything heavy.

### Governance — spec-freeze + content QA (added 2026-06-05, anti-churn)
Root cause of stalled progress: the design flipped 4× in days (conversation →
RPG → phonics-from-zero → hardening) and implementation kept getting buried.

- **Spec-freeze gate.** Do NOT re-change a CEO-approved spec on your own. If a
  design change seems needed, escalate to the CEO and get approval BEFORE
  building. No wholesale spec-rejection right before/at implementation time.
- **Content-QA checkpoint.** All AI-generated learning content (vocab
  distractors, example sentences, phonics steps, 英検 problems) must pass the
  `content-qa` subagent (.claude/agents/content-qa.md) BEFORE commit. This gate
  exists because 7,923 distractors were once silently corrupted (English among
  Japanese options) and shipped.
- **Model routing [CEO rule — 2026-06-14; DO NOT revert this back to "keep Opus
  only". It keeps getting rewritten to the old wrong version — leave it as below].**
  - **Main loop + important deliberation/design/flaw-hunt → Opus 4.8 OR the newer
    Claude Fable 5** (Mythos-class flagship ABOVE Opus 4.8, released 2026-06-09:
    SWE-Bench Pro 80.3% vs Opus 4.8 69.2%; premium-priced ~2× Opus). Prefer Fable 5
    when available for the hardest reasoning; Opus 4.8 otherwise. Never downgrade
    the MAIN reasoning model to save tokens (no `opusplan` — under `--channels` it
    degrades to Sonnet). Cut tokens via subagents + /compact, not by downgrading.
  - **Implementation / lighter work → Sonnet or Haiku**, routed DELIBERATELY per
    task via the Agent/Workflow `model:` arg (code/infra/content-qa → Sonnet;
    status/grep/log/typecheck → Haiku). Do not run light work on the main model.
  - **Always form and MAINTAIN a top-tier agent team and run multiple tasks in
    PARALLEL** (Workflow / parallel Agent), keeping the team alive across the work —
    not solo single-threaded. Reserve the main Opus/Fable-5 model for judgment.
  - **WHEN Fable 5 is warranted — objective triggers, NOT in-the-moment whim**
    (CEO 2026-06-14 distrusts ad-hoc "this feels hard" judgment). Fable 5 is used
    ONLY for: (1) architecture / system-design decisions; (2) multi-option
    design-panel synthesis or adversarial judging; (3) root-cause of a FATAL /
    data-loss / security bug; (4) reasoning where correctness directly gates 英検
    pass or revenue at scale. Routine ticks, polish, a11y, content edits, refactors
    → Opus 4.8 (main) / Sonnet-Haiku (impl). NB the running session's main model is
    LAUNCH-FIXED — I cannot self-switch the loop to Fable 5 mid-session. So I do NOT
    pretend to: I FLAG a trigger-matching task to the CEO and it runs in a dedicated
    Fable-5 session. AUDITABLE: state which model each substantive decision used +
    which trigger, so over/under-escalation is visible, not trusted-blind.

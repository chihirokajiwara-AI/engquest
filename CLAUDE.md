# ENG Quest — Flutter Web App

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
- [ ] T00a: Fix WordAudioPlayerService — replace stub with real audioplayers playback (currently just debugPrint)
- [ ] T00b: Fix SoundService — implement real sound effects (flip, correct, wrong, level-up) — currently 100% no-op
- [ ] T00c: Fix AnalyticsService — wire Firebase Analytics (logEvent, setUserId, setUserProperty are no-ops)
- [ ] T00d: Production logging cleanup — gate 27 debugPrint calls behind kDebugMode, remove bare print() in analytics
- [ ] T00e: Remove web_static/ — duplicates Flutter app (1,600-line standalone HTML), no longer needed

### Priority 1 — Trial Readiness
- [ ] T01: Mobile build (iOS/Android) — resolve Firebase package versions for mobile
- [ ] T02: Real Whisper integration — replace demo VoiceService with whisper_ggml_plus (iOS) / cloud (Android)
- [ ] T03: App Store / Play Store preparation — COPPA compliance review, screenshots, listing
- [ ] T04: Parent onboarding flow — email signup for parents, child account linking

### Priority 2 — Content & Engagement
- [ ] T05: A2 content expansion — 300 more words (英検4級), new world zone
- [ ] T06: Achievement/badge system — milestone rewards (10-day streak, 100 words mastered)
- [ ] T07: Sound effects & haptics — battle card flip sounds, XP gain chime, level-up fanfare
- [ ] T08: Animated transitions — world map zone entry, battle start/end, dialog NPC appear

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

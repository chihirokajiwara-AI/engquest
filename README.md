# ENG Quest

**英語学習RPGプラットフォーム** — Native-equivalent English cognition for Japanese children, age 4–18, at 1/100th of international school cost.

> **Vision**: 英検準1級 / TOEFL iBT 80+ / CEFR B2 by high school — ~¥3,000/month vs ¥300,000/month international school fees — by eliminating the L1-L2 boundary through immersive RPG gameplay that makes English the *medium*, not the subject.

---

## Quick Start

### Prerequisites

| Tool | Minimum Version | Notes |
|------|----------------|-------|
| Flutter | **3.22+** | `flutter --version` |
| Dart | **3.4+** | bundled with Flutter |
| Xcode | **15+** | macOS only, for iOS builds |
| Android Studio | **Hedgehog (2023.1.1)+** | for Android builds |
| CocoaPods | **1.14+** | `sudo gem install cocoapods` |
| Firebase CLI | **13+** | `npm install -g firebase-tools` |

### 1. Clone & Install

```bash
git clone https://github.com/chihirokajiwara-AI/engquest.git
cd engquest
flutter pub get
cd ios && pod install && cd ..
```

### 2. Firebase Setup

Firebase credentials are **not** included in the repo. Follow [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) to:
- Create the `engquest-mvp` Firebase project
- Download `GoogleService-Info.plist` → `ios/Runner/`
- Download `google-services.json` → `android/app/`
- Replace placeholder API keys in `lib/core/firebase/firebase_config.dart`

### 3. Environment Variables / Secrets

Copy the example env file and fill in your keys:

```bash
cp .env.example .env
```

Required secrets (see [Environment Variables](#environment-variables--secrets) section below):

```
ANTHROPIC_API_KEY=sk-ant-...
```

### 4. Run

```bash
# iOS Simulator
flutter run -d iPhone

# Android Emulator
flutter run -d emulator

# Physical device (after Firebase setup)
flutter run --release
```

---

## Architecture

### RPG → Linguistics Mapping

| RPG Element | Linguistic Function | CEFR Focus | Module |
|-------------|---------------------|------------|--------|
| ⚔️ **Battle** | Retrieval practice (active recall) | Vocabulary A1–B2 | `features/battle` |
| 💬 **Dialog** | Pragmatics (social language use) | Fluency, discourse | `features/dialog` |
| 🎤 **Voice** | Phonological awareness (pronunciation) | Phonics, intonation | `features/voice` |
| 🔨 **Crafting** | Grammar (rule construction) | Morphology, syntax | `features/crafting` |
| 🏰 **Guild** | Discourse (extended communication) | Cohesion, register | `features/guild` |
| 🗺️ **World Map** | Curriculum progression | CEFR level gates | `features/world_map` |
| 📊 **Parent Dashboard** | Learning analytics | KPI visibility | `features/parent_dashboard` |

### Directory Structure

```
engquest/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # MaterialApp + routing
│   ├── core/
│   │   ├── fsrs/                    # FSRS-4.5 SRS algorithm (pure Dart)
│   │   ├── cefr/                    # CEFR placement engine
│   │   ├── audio/                   # Whisper ASR service (on-device, stubbed)
│   │   ├── dialog/                  # Claude haiku API dialog service
│   │   ├── firebase/                # Firebase config + initialization
│   │   ├── analytics/               # Firebase Analytics wrapper
│   │   ├── config/                  # App constants, feature flags
│   │   ├── models/                  # Shared domain models
│   │   └── voice/                   # Pronunciation scoring
│   ├── features/
│   │   ├── battle/                  # ⚔️ Retrieval practice battle loop
│   │   ├── dialog/                  # 💬 Conversational AI scenes
│   │   ├── voice/                   # 🎤 Pronunciation coaching
│   │   ├── crafting/                # 🔨 Grammar construction (v2)
│   │   ├── guild/                   # 🏰 Discourse challenges (v2)
│   │   ├── onboarding/              # 4-step CEFR placement flow
│   │   ├── parent_dashboard/        # 📊 KPI dashboard for parents
│   │   └── world_map/               # 🗺️ Curriculum world map
│   └── data/
│       ├── models/                  # Data transfer objects (Firestore)
│       ├── repositories/            # Firebase data access layer
│       └── content/                 # CEFR-tagged vocabulary SQLite DB
├── test/
│   ├── unit/                        # Unit tests (FSRS, CEFR, models)
│   └── integration/                 # Widget + integration tests
├── assets/
│   ├── audio/                       # Sound effects, BGM
│   └── images/                      # Sprites, UI assets
├── docs/
│   ├── FIREBASE_SETUP.md            # Firebase project creation guide
│   ├── TESTFLIGHT_SETUP.md          # Firebase App Distribution guide
│   ├── CLOSED_ALPHA_CHECKLIST.md    # Alpha gating criteria
│   └── spec/mvp.md                  # Full MVP specification
├── .github/
│   └── workflows/ci.yml             # GitHub Actions CI
└── pubspec.yaml
```

### Key Algorithms

#### FSRS-4.5 (Free Spaced Repetition Scheduler)

Located in `lib/core/fsrs/`

```dart
// Core constants
const double FACTOR = 19.0 / 81.0;   // ≈ 0.2346
const double DECAY  = -0.5;           // Power-law forgetting curve exponent

// Retrievability (probability of recall)
// R(t, S) = (1 + FACTOR * t/S) ^ DECAY
// where t = days since last review, S = stability (days to 90% R)

// After each grade (1=Again, 2=Hard, 3=Good, 4=Easy):
// - Stability S updated via grade-specific multipliers
// - Next review interval = S * ln(target_R) / ln(0.9)
```

See [src/spikes/fsrs_research.md](src/spikes/) for full algorithm derivation and Anki comparison benchmarks.

#### CEFR Placement Engine

Located in `lib/core/cefr/`

- 10-item adaptive placement test (binary search on CEFR scale)
- Bayesian ability estimation (IRT 1-PL model)
- Maps A1→B2 vocabulary bands to battle card difficulty tiers
- Placement saved to Firestore + local SQLite

#### A/B Testing Framework

Located in `lib/core/analytics/` + `lib/core/config/`

- Firebase Remote Config drives variant assignment
- Variants: ENG Quest (treatment) vs Anki-style (control)
- Primary metric: 30-day vocabulary retention rate
- Secondary: DAU, session length, parent NPS

---

## Running Tests

```bash
# All tests (unit + widget)
flutter test

# With coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Specific test file
flutter test test/unit/fsrs_test.dart

# Integration tests (requires device/emulator)
flutter test integration_test/
```

**Expected**: 100+ test cases covering:
- FSRS scheduling correctness (grade transitions, stability decay)
- CEFR placement accuracy (boundary cases)
- Battle card state machine
- Onboarding flow completion
- Repository CRUD operations

---

## Environment Variables / Secrets

### Required Secrets

| Variable | Description | Where to set |
|----------|-------------|--------------|
| `ANTHROPIC_API_KEY` | Claude haiku API key (dialog module) | `.env` file + Xcode scheme |
| Firebase credentials | Auto-loaded from plist/json files | See [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) |

### iOS (Xcode)

Add to `ios/Runner/Info.plist` (build-time injection) or Xcode scheme environment:

```
ANTHROPIC_API_KEY = sk-ant-...
```

### Android

Add to `android/local.properties` (git-ignored):

```
anthropicApiKey=sk-ant-...
```

### CI/CD (GitHub Actions)

Add secrets in GitHub repo settings → **Secrets and variables → Actions**:

```
ANTHROPIC_API_KEY
GOOGLE_SERVICES_JSON     # base64-encoded google-services.json
GOOGLE_SERVICE_INFO_PLIST # base64-encoded GoogleService-Info.plist
```

---

## Current Status — Phase 0 (MVP)

| Component | Status | Sprint | Notes |
|-----------|--------|--------|-------|
| C01 · Project scaffold | ✅ Done | W1 | Flutter + Firebase deps |
| C02 · FSRS-4.5 engine | ✅ Done | W1 | Pure Dart, 100% unit tested |
| C03 · Firebase auth (anonymous) | ✅ Done | W1 | Needs real Firebase project |
| C04 · Firestore repositories | ✅ Done | W2 | CRUD + offline cache |
| C05 · CEFR placement | ✅ Done | W2 | 10-item adaptive test |
| C06 · Battle module | ✅ Done | W2 | Card flip + FSRS grading |
| C07 · Onboarding flow | ✅ Done | W3 | 4-step, saves CEFR result |
| C08 · Voice (Whisper stub) | ✅ Done | W3 | On-device ASR stubbed |
| C09 · Dialog (Claude haiku) | ✅ Done | W3 | Conversational AI scenes |
| C10 · Parent dashboard | ✅ Done | W4 | KPIs + progress charts |
| C11 · Analytics pipeline | ✅ Done | W4 | Firebase Analytics events |
| C12 · Push notifications | ✅ Done | W4 | FCM daily reminders |
| C13 · Firebase project (real) | ⏳ Pending | — | CEO to create `engquest-mvp` |
| C14 · Closed alpha distribution | ⏳ Pending | — | After C13 complete |
| C15 · A/B trial launch | ⏳ Pending | — | 5-10 families, 30 days |

---

## Contributing

### Branch Naming

```
feat/c13-firebase-project      # New feature (cNN = component number)
fix/battle-card-flip-android   # Bug fix
chore/update-dependencies      # Maintenance
docs/firebase-setup-guide      # Documentation
test/fsrs-edge-cases           # Test additions
```

### Commit Convention (Conventional Commits)

```
feat(battle): add card flip animation with FSRS grade selection
fix(fsrs): correct stability decay for Again grade
docs(readme): add Firebase setup prerequisites
test(cefr): add boundary cases for A1/A2 transition
chore(deps): bump firebase_core to 2.24.2
```

### Pull Request Process

1. Branch from `main`
2. All tests pass: `flutter test` + `flutter analyze`
3. No new lint warnings
4. PR description references component (e.g. `Closes #C13`)
5. One reviewer approval required

### Code Style

```bash
# Format all Dart files
dart format .

# Analyze (must pass before merge)
flutter analyze

# Fix auto-fixable issues
dart fix --apply
```

---

## License

Proprietary — © 2024 Aesthetic AI K.K. All rights reserved.

---

*Built with ❤️ for Japanese families who want their children to think in English.*

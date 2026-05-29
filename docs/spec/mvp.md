# ENG Quest MVP Specification
**Version**: 0.1.0  
**Last Updated**: 2026-05-29  
**Status**: In Progress

---

## Vision

Native-equivalent English cognition in Japanese children, age 4–18.  
**Target outcome**: 英検準1級 / TOEFL iBT 80+ / CEFR B2 by high school, at 1/100th of international school cost (~¥3,000/month vs ¥300,000/month).

---

## MVP Scope: 30-Day A/B Trial (vs Anki)

### Trial Design
- **Duration**: 30 days
- **Control group**: Anki flashcard deck (英検5級 300 words, standard settings)
- **Treatment group**: ENG Quest A1 World (same 300 words, FSRS + game loop)
- **Primary metric**: Retention rate at day 30 (spaced repetition test)
- **Secondary metrics**: Daily engagement rate, session length, parent NPS

### MVP Scope Boundaries
- **In scope**: A1 world, 300 words (英検5級 + FSRS), Battle + Voice + Dialog modules, Parent Dashboard
- **Out of scope (v2)**: A2+ worlds, crafting system, guild system, full CEFR tag DB, multi-player

---

## Architecture

### Platform
- **Frontend**: Flutter (iOS + Android, single codebase)
- **Backend**: Firebase (Auth, Firestore, Functions, Hosting)
- **Audio**: On-device Whisper (openai/whisper via whisper.cpp WASM or platform binary)
- **AI/Dialog**: Claude API (Anthropic claude-3-haiku for cost, sonnet for quality gates)
- **SRS Algorithm**: Custom FSRS-4.5 implementation in Dart
- **Content DB**: CEFR-tagged vocabulary + sentence corpus (sqlite + Firebase sync)

### RPG → Linguistics Mapping
| RPG Element | Linguistic Function | MVP Status |
|-------------|--------------------|----|
| **Battle** | Retrieval practice (active recall) | 🎯 MVP |
| **Dialog** | Pragmatics (social language use) | 🎯 MVP |
| **Voice** | Phonological awareness (pronunciation) | 🎯 MVP |
| **Crafting** | Grammar (rule construction) | v2 |
| **Guild** | Discourse (extended communication) | v2 |

---

## Progress Tracker

### Components (ordered by dependency)

| ID | Component | Status | Last Updated | Notes |
|----|-----------|--------|--------------|-------|
| C01 | FSRS-4.5 Dart Implementation | `delegated` | 2026-05-27 | Spike S02 COMPLETE. Delegated to Claude Code (engquest-20260527-001.json). Branch: feat/c01-fsrs-dart |
| C02 | CEFR-Tagged Content DB (300 words, A1) | `done` | 2026-05-29 | lib/data/content/vocab_a1.dart — 300語 const List, JSON + Dart model + repository + unit tests |
| C03 | Firebase Project Setup + Auth | `done` | 2026-05-29 | lib/core/firebase/ — FirebaseConfig.initialize() + AuthService (anonymous auth, COPPA準拠) |
| C04 | Flutter App Scaffold + Navigation | `done` | 2026-05-29 | lib/main.dart + app.dart + world_map_screen.dart — 3ゾーンナビゲーション実装済み |
| C05 | Battle Module (Retrieval Loop) | `done` | 2026-05-29 | FSRS-4.5 Dart全公式実装 + カードフリップUI + 4段階評価 + セッションサマリー |
| C06 | Voice Module (Pronunciation Coach) | `done` | 2026-05-29 | VoiceService + Levenshtein評価 + PlatformChannel stub + デモモード完全動作 |
| C07 | Dialog Module (Conversational AI) | `done` | 2026-05-29 | ClaudeClient (haiku) + DialogService (3シナリオ) + オフラインフォールバック |
| C08 | Parent Dashboard | `done` | 2026-05-29 | 4タブ (Home/Progress/Schedule/Settings) + MockData完全表示 + ストリーク/英検準備度 |
| C09 | Analytics + A/B Framework | `done` | 2026-05-29 | lib/core/analytics/analytics_service.dart — AnalyticsSink interface + FirebaseAnalyticsAdapter + AbFramework (FNV-1a 50/50 deterministic split) + AnalyticsService facade + unit tests |
| C10 | Onboarding Flow | `done` | 2026-05-29 | lib/features/onboarding/onboarding_flow.dart — 4ステップ: 年齢スライダー + CEFRミニテスト3問 + アバター選択5体 + 目標設定 + OnboardingResult model |
| C11 | App Entry Wiring | `done` | 2026-05-29 | lib/app.dart — OnboardingStorage + _AppEntryPoint: onboarding_complete flag check → OnboardingFlow or WorldMapScreen |
| C12 | FSRS Card Repository | `done` | 2026-05-29 | lib/core/fsrs/fsrs_card_repository.dart — FsrsCardRepository interface + InMemoryFsrsCardRepository (JSON round-trip stub, sqflite schema documented) |
| C13 | SharedPreferences Real Integration | `done` | 2026-05-29 | lib/core/storage/preferences_service.dart — PreferencesService singleton wrapping SharedPreferences with in-memory graceful fallback; OnboardingStorage migrated from _MemStore; unit tests in test/core/storage/preferences_service_test.dart |
| C14 | FCM Push Notifications (Daily Review Reminders) | `done` | 2026-05-29 | lib/core/notifications/notification_service.dart — firebase_messaging ^14.7.6 + flutter_local_notifications ^16.3.0 + timezone; scheduleDailyReminder(TimeOfDay) default 19:00 JST; '今日の復習 5枚が待っています！⚔️'; requestPermission() iOS/Android; cancelAll() for settings; FCM token retrieval; graceful no-op with placeholder Firebase keys |
| C15 | Firestore FSRS Persistence | `done` | 2026-05-29 | lib/core/fsrs/firestore_card_repository.dart — FirestoreFsrsCardRepository with offline persistence (persistenceEnabled=true, CACHE_SIZE_UNLIMITED), upsert via SetOptions(merge:true), batch writes (500-doc limit), InMemory fallback on errors; BattleScreen wired to real repo — loads deck on init, saves each card after grade, async loading spinner (カードを読み込んでいます…), progress persists across restarts; 20 tests (fake_cloud_firestore) |

### Spike Backlog

| Spike | Question | Status |
|-------|----------|--------|
| S01 | on-device-whisper | ✅ COMPLETE 2026-05-26 — whisper_ggml_plus base.en, hybrid on-device+cloud arch. See src/spikes/on-device-whisper/README.md |
| S02 | fsrs-dart | ✅ COMPLETE 2026-05-27 — FSRS-4.5 viable in Dart. FACTOR=19/81, DECAY=-0.5. 88.8% retention. C01 delegated to Claude Code. See src/spikes/fsrs-dart/README.md |
| S03 | claude-haiku-dialog | ✅ COMPLETE 2026-05-29 — p50=1411ms, p95=3141ms (✅ <5000ms). Cost $0.0001/turn. 206K turns/month at ¥3000 budget. VIABLE. See src/spikes/claude-haiku-dialog/README.md |
| S04 | firebase-offline | Does Firebase Firestore offline mode handle FSRS scheduling without connectivity? | 🟢 LOW |

---

## Technical Specifications

### C01: FSRS-4.5 Dart Implementation

FSRS (Free Spaced Repetition Scheduler) v4.5 — the state-of-the-art open source SRS algorithm.  
Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm

#### Algorithm Parameters
```
w = [0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0589, 
     1.5330, 0.1544, 1.0070, 1.9290, 0.1100, 0.2900, 2.2700, 0.2500, 
     2.9898, 0.5100, 0.3400]  // default FSRS-4.5 parameters
```

#### Card States
- `New` → `Learning` → `Review` → `Relearning`
- Grade input: Again(1), Hard(2), Good(3), Easy(4)

#### Key Formulas
- D₀(G) = w₄ - exp(w₅ * (G-1)) + 1  // initial difficulty
- S₀(G) = w[G-1]                       // initial stability
- R(t,S) = (1 + FACTOR * t/S)^DECAY    // retrievability
- Next interval = S * ln(R) / ln(0.9)  // target 90% retention

#### Dart Implementation Target
```dart
// lib/core/fsrs/fsrs_algorithm.dart
class FSRSAlgorithm {
  final FSRSParameters params;
  
  FSRSSchedule schedule(FSRSCard card, Grade grade, DateTime now);
  double retrievability(FSRSCard card, DateTime now);
  List<FSRSCard> getDueCards(List<FSRSCard> deck, DateTime now);
}
```

### C02: Content DB — 300 A1 Words (英検5級)

#### Word Structure
```dart
class VocabItem {
  final String id;           // "eiken5_001"
  final String word;         // "apple"
  final String reading;      // "アップル" (katakana)
  final String jpTranslation; // "りんご"
  final String cefrLevel;    // "A1"
  final String eikenLevel;   // "5"
  final List<String> pos;    // ["noun"]
  final List<String> exampleSentences; // ["I eat an apple."]
  final String audioUrl;     // Firebase Storage path
  final String imageUrl;     // Firebase Storage path
}
```

#### Content Sources
- 英検5級 公式語彙リスト (300 words)
- CEFR-J wordlist (A1 band mapping)
- Tatoeba sentences (CC-BY license) for examples

### C06: Voice Module (on-device Whisper)

#### Requirements
- Latency: <3 seconds end-to-end (record → transcribe → feedback)
- Binary size: <50MB model (whisper.cpp tiny.en or base)
- Offline: must work without network
- Platform: iOS 14+ (Flutter plugin), Android 8+ (Flutter plugin)

#### Open Questions (→ Spike S01)
1. Which Whisper model size balances accuracy vs size for child speech?
2. Best Flutter plugin: `whisper_flutter_new` vs `flutter_whisper` vs custom FFI?
3. iOS CoreML acceleration vs raw CoreAudio?
4. Word Error Rate on Japanese-accented child English?

### C07: Dialog Module (Claude API)

#### Conversation Templates (MVP)
- `greet_npc`: Basic greeting exchange (Hello/Goodbye/How are you)
- `shop_dialog`: Simple transaction (I want/How much/Thank you)
- `battle_intro`: Challenge/accept/good luck exchange

#### API Pattern
```dart
// lib/core/dialog/dialog_service.dart
class DialogService {
  // Claude haiku: ~$0.00025/1K input tokens, ~$0.00125/1K output
  // Target: <100 tokens per turn = ~$0.0001 per exchange
  // Budget: ¥3,000/month plan → ~5,000 dialog turns/month per user
  
  Future<DialogResponse> chat(
    String systemPrompt,
    List<Message> history,
    String userInput,
  );
}
```

---

## MVP Content Plan

### A1 World Map
```
[Village Square]
  ├── [Blacksmith] → Battle Module (Retrieval)
  ├── [Town Crier]  → Dialog Module (Pragmatics)  
  └── [Echo Cave]  → Voice Module (Phonological)
```

### 300-Word Seed List Categories
| Category | Count | Examples |
|----------|-------|---------|
| Animals | 30 | cat, dog, fish, bird, rabbit |
| Food | 30 | apple, rice, water, bread, milk |
| Family | 20 | mother, father, sister, brother |
| Colors | 15 | red, blue, green, yellow, white |
| Numbers | 20 | one→twenty |
| Actions (basic) | 40 | run, eat, sleep, play, read, write |
| Adjectives (basic) | 30 | big, small, happy, sad, hot, cold |
| School | 25 | pencil, book, teacher, desk, class |
| Time/Weather | 25 | today, morning, sunny, rain, winter |
| Greetings/Social | 25 | hello, please, thank you, sorry, yes |
| Body | 20 | head, hand, eye, ear, nose, mouth |
| Places | 20 | home, school, park, shop, hospital |

---

## Parent Dashboard Spec

### Data Points
- Daily streak (consecutive days)
- Words practiced today / total
- Mastery % by CEFR level
- Time spent (minutes/day, last 7 days)
- Estimated 英検 readiness (A1 = 5級 preparation)

### Views
1. **Home**: Today's summary card + streak
2. **Progress**: Word mastery heatmap + level chart
3. **Schedule**: Upcoming review due dates (FSRS)
4. **Settings**: Daily goal, notification time, difficulty

---

## Engineering Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-26 | Flutter over React Native | Single team, easier Firebase integration, stronger animation support for RPG UI |
| 2026-05-26 | FSRS-4.5 over SM-2 | 20%+ retention improvement at same review count; Anki now ships FSRS default |
| 2026-05-26 | Claude haiku for dialog | 10x cheaper than GPT-4o; sufficient for A1 English dialog; latency acceptable |
| 2026-05-26 | On-device Whisper | No network cost; privacy; offline support; requires spike to validate feasibility |
| 2026-05-26 | Firebase over custom backend | Fastest path to MVP; real-time sync for parent dashboard; built-in auth |

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Whisper latency too high on-device | Medium | High | Fallback to cloud Whisper API; or remove Voice from MVP |
| Claude API cost exceeds budget at scale | Low | Medium | Rate limit + caching; use haiku not sonnet |
| FSRS Dart port bugs | Low | High | Port unit tests from reference Python implementation |
| App Store review rejection (child privacy) | Low | High | COPPA/COPPA-J compliance from day 1; no PII collection |
| Low A/B trial engagement | Medium | High | Daily push notifications; parent accountability loop |

---

## Next Actions

1. **[IMMEDIATE]** Complete Spike S01 (on-device-whisper) — highest technical risk
2. Implement FSRS-4.5 in Dart with unit tests (C01)
3. Build 300-word content DB with metadata (C02)
4. Firebase project setup + Flutter scaffold (C03 + C04)

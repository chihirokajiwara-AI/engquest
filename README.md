# ENG Quest

**L1-L2境界を消す英語学習プラットフォーム** — Native-equivalent English cognition for Japanese children, age 4–18.

## Vision

> 英検準1級 / TOEFL iBT 80+ / CEFR B2 by high school, at **1/100th of international school cost** (~¥3,000/month vs ¥300,000/month)

## Architecture

RPG → Linguistics mapping:
| RPG Element | Linguistic Function |
|-------------|---------------------|
| **Battle** | Retrieval practice (active recall) |
| **Dialog** | Pragmatics (social language use) |
| **Voice** | Phonological awareness (pronunciation) |
| **Crafting** | Grammar (rule construction) |
| **Guild** | Discourse (extended communication) |

## Tech Stack

- **Frontend**: Flutter (iOS + Android)
- **Backend**: Firebase (Firestore, Auth, Functions)
- **Audio/ASR**: whisper_ggml_plus (on-device Whisper, hybrid cloud fallback)
- **AI/Dialog**: Claude API (haiku for cost, sonnet for quality)
- **SRS**: Custom FSRS-4.5 Dart implementation
- **Content**: CEFR-tagged vocabulary DB (SQLite + Firebase sync)

## MVP

30-day A/B trial vs Anki:
- A1 World, 300 words (英検5級 + FSRS)
- Battle + Voice + Dialog modules
- Parent Dashboard

## Project Structure

```
lib/
  core/
    fsrs/          # FSRS-4.5 SRS algorithm
    audio/         # Whisper ASR service  
    dialog/        # Claude API dialog service
    analytics/     # Firebase Analytics
  features/
    battle/        # Retrieval practice loop
    voice/         # Pronunciation coach
    dialog/        # Conversational AI
    crafting/      # Grammar (v2)
    guild/         # Discourse (v2)
  data/
    models/        # Dart data classes
    repositories/  # Firebase data access
    content/       # CEFR vocab DB
docs/
  spec/mvp.md     # Full MVP specification + progress tracker
src/
  spikes/         # Technical feasibility research
```

## Development

See [docs/spec/mvp.md](docs/spec/mvp.md) for full specification and progress tracker.

### Setup

```bash
flutter pub get
flutter run
```

### Testing

```bash
flutter test
```

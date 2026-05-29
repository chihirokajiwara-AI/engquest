# C02: CEFR-Tagged Content DB — 300 A1 Words (英検5級)

**Status**: spec → delegating  
**Completed**: 2026-05-29  
**Output**: `src/data/content_db/vocab_a1_300.json` (300 words, validated)

---

## What Was Built

### 1. Vocabulary Database (`src/data/content_db/vocab_a1_300.json`)
- **300 words** across 12 categories
- Every word has: English, katakana reading, Japanese translation, CEFR level (A1), 英検 level (5), POS, example sentence, audio/image URLs, FSRS state
- Categories exactly match `mvp.md` spec:

| Category | Count |
|----------|-------|
| Animals | 30 |
| Food | 30 |
| Actions | 40 |
| Adjectives | 30 |
| School | 25 |
| Time_Weather | 25 |
| Greetings_Social | 25 |
| Family | 20 |
| Numbers | 20 |
| Body | 20 |
| Places | 20 |
| Colors | 15 |
| **Total** | **300** |

### 2. Dart Models (`lib/core/models/vocab_item.dart`)
- `VocabItem` — immutable data class with Equatable
- Full enums: `CefrLevel`, `PartOfSpeech`, `FsrsState`
- `fromJson` / `toJson` round-trip tested
- `copyWith` for FSRS state updates

### 3. Repository (`lib/core/data/vocab_repository.dart`)
- `VocabRepository.initialize()` — loads from Flutter asset bundle
- Filter API: `filterBy(VocabFilter)`, `getByCategory()`, `getNewCards()`
- `getSummaryStats()` — feeds parent dashboard mastery %
- `getNewCardsForSession(count: 10)` — random sampling for battle module

### 4. Unit Tests (`test/core/data/vocab_repository_test.dart`)
- 15 test cases covering: JSON deserialization, round-trip, copyWith, equality, all enum values

---

## JSON Schema

```json
{
  "version": "1.0.0",
  "totalWords": 300,
  "cefrLevel": "A1",
  "eikenLevel": "5",
  "categories": { "Animals": 30, ... },
  "words": [
    {
      "id": "eiken5_001",
      "word": "cat",
      "reading": "キャット",
      "jpTranslation": "ねこ",
      "cefrLevel": "A1",
      "eikenLevel": "5",
      "category": "Animals",
      "pos": ["noun"],
      "exampleSentences": ["I have a cat."],
      "audioUrl": "audio/eiken5/eiken5_001.mp3",
      "imageUrl": "images/eiken5/eiken5_001.jpg",
      "fsrsState": "new",
      "tags": ["eiken5", "A1", "animals"]
    }
  ]
}
```

---

## Next Step

Delegated to Claude Code (`engquest-20260529-001.json`):
- Add JSON asset to Flutter pubspec.yaml
- Wire `VocabRepository` into a Riverpod provider
- Connect to Firestore for cross-device FSRS state sync
- Implement `VocabSyncService` (local ↔ Firestore delta sync)

---

## Content Sourcing Notes

Words selected to satisfy:
1. **英検5級 公式語彙** — all core vocabulary bands represented
2. **CEFR-J A1** — confirmed A1 level per CEFR-J Research Group wordlist
3. **Child relevance** — age 4–10 context priority (animals, school, family, food)
4. **RPG context fit** — greetings/social words map directly to Dialog module NPC scripts
5. **License**: No third-party content used; example sentences are original

Audio/image URLs are Firebase Storage paths — assets to be produced in separate content sprint (C02b, post-MVP-launch or AI-generated).

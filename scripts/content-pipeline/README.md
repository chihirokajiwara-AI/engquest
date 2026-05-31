# Content Pipeline — ENG Quest / A-KEN Quest

Scripts for validating, generating, and auditing vocabulary content.

## Scripts

### `validate_vocab.py`
Validates one or more vocabulary JSON files against the expected schema.

**Checks:**
- All required fields present (`id`, `word`, `reading`, `jpTranslation`, `cefrLevel`, `eikenLevel`, `category`, `pos`, `exampleSentences`, `audioUrl`, `imageUrl`, `fsrsState`, `tags`, `distractors`)
- No duplicate IDs within a file
- No duplicate English words within a file
- `distractors` count == 3
- `exampleSentences` count >= 1
- `cefrLevel` is a known value (A1, A1+, A2, ... C2)
- `fsrsState` is one of `new / learning / review / relearning`
- `totalWords` header matches actual count
- When validating a directory: cross-file duplicate IDs and words

**Usage:**
```bash
# Single file
python3 scripts/content-pipeline/validate_vocab.py assets/data/eiken5_vocab.json

# All files in directory
python3 scripts/content-pipeline/validate_vocab.py assets/data/
```

Exit code 0 = all checks passed. Exit code 1 = failures found.

---

### `generate_audio.sh`
Generates MP3 audio files for vocabulary words using Google Cloud Text-to-Speech.

**Requirements:**
- `GOOGLE_CLOUD_API_KEY` environment variable set
- `jq` installed (`brew install jq`)
- `curl` installed (standard on macOS/Linux)

**Behavior:**
- Reads `audioUrl` from each word entry to determine output path
- Skips words whose audio file already exists
- Uses voice `en-US-Neural2-C`, speaking rate 0.9
- Rate-limited to ~5 requests/second to stay within quota

**Usage:**
```bash
export GOOGLE_CLOUD_API_KEY="your_key_here"
./scripts/content-pipeline/generate_audio.sh assets/data/eiken5_vocab.json
./scripts/content-pipeline/generate_audio.sh assets/data/eiken4_vocab.json
```

Audio files are written to `assets/audio/a1/`, `assets/audio/a2/`, `assets/audio/b1/` etc.

---

### `check_coverage.py`
Reports overall content coverage vs. targets for the final product.

**Target numbers:**
| Grade         | Target |
|---------------|--------|
| Eiken 5       | 600    |
| Eiken 4       | 700    |
| Eiken 3       | 800    |
| Eiken Pre-2   | 1,500  |
| Eiken 2       | 800    |
| Eiken Pre-1   | 3,000  |
| Grammar drills| 1,290  |
| Reading passages | 240 |
| **Total**     | ~8,930 |

**Usage:**
```bash
python3 scripts/content-pipeline/check_coverage.py
```

No arguments needed — reads all files in `assets/data/` automatically.

---

### `cross_grade_check.py`
Checks for duplicate word IDs and duplicate English words across all grade files.

**Usage:**
```bash
python3 scripts/content-pipeline/cross_grade_check.py
```

No arguments needed — reads all files in `assets/data/` automatically.

---

## Running the full pipeline

```bash
# 1. Validate each file
python3 scripts/content-pipeline/validate_vocab.py assets/data/

# 2. Check cross-grade overlaps
python3 scripts/content-pipeline/cross_grade_check.py

# 3. Check overall coverage
python3 scripts/content-pipeline/check_coverage.py

# 4. Generate missing audio (requires GOOGLE_CLOUD_API_KEY)
export GOOGLE_CLOUD_API_KEY="..."
for f in assets/data/eiken*.json; do
  ./scripts/content-pipeline/generate_audio.sh "$f"
done
```

## Dependencies

| Tool         | Purpose           | Install             |
|--------------|-------------------|---------------------|
| Python 3.9+  | All .py scripts   | Pre-installed macOS |
| bash 3.2+    | generate_audio.sh | Pre-installed macOS |
| jq           | JSON parsing in sh | `brew install jq`  |
| curl         | HTTP requests      | Pre-installed macOS |

No pip dependencies — all Python scripts use the standard library only.

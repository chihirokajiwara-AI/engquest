#!/usr/bin/env bash
# generate_audio.sh — Generate TTS audio files via Google Cloud TTS API.
#
# Usage:
#   ./scripts/content-pipeline/generate_audio.sh assets/data/eiken5_vocab.json
#
# Requirements:
#   - GOOGLE_CLOUD_API_KEY env var set
#   - jq installed (brew install jq)
#   - curl installed (standard on macOS/Linux)
#
# Output files are saved to:
#   assets/audio/a1/  (CEFR A1, A1+)
#   assets/audio/a2/  (CEFR A2, A2+)
#   assets/audio/b1/  (CEFR B1, B1+)

set -euo pipefail

# ---------- Config ----------
VOICE_NAME="en-US-Neural2-C"
VOICE_LANG="en-US"
AUDIO_ENCODING="MP3"
REQUESTS_PER_SECOND=5      # Google TTS free tier: 300 requests/min
SLEEP_BETWEEN="0.2"        # seconds between requests
TTS_API_URL="https://texttospeech.googleapis.com/v1/text:synthesize"

# ---------- Helpers ----------
die() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed."
}

cefr_to_dir() {
    local level="$1"
    case "$level" in
        A1|A1+) echo "a1" ;;
        A2|A2+) echo "a2" ;;
        B1|B1+) echo "b1" ;;
        B2|B2+) echo "b2" ;;
        C1|C2)  echo "c1" ;;
        *)       echo "misc" ;;
    esac
}

# ---------- Checks ----------
require_cmd jq
require_cmd curl

[[ -z "${GOOGLE_CLOUD_API_KEY:-}" ]] && die "GOOGLE_CLOUD_API_KEY environment variable is not set."
[[ $# -lt 1 ]] && die "Usage: $0 <vocab_json_file>"

INPUT_FILE="$1"
[[ -f "$INPUT_FILE" ]] || die "File not found: $INPUT_FILE"

# Determine project root (scripts are in scripts/content-pipeline/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIO_BASE="$PROJECT_ROOT/assets/audio"

echo "Project root : $PROJECT_ROOT"
echo "Audio base   : $AUDIO_BASE"
echo "Input file   : $INPUT_FILE"
echo "Voice        : $VOICE_NAME"
echo ""

# ---------- Parse JSON and generate audio ----------
total=$(jq '.words | length' "$INPUT_FILE")
generated=0
skipped=0
errors=0

echo "Total words in file: $total"
echo "Processing..."
echo ""

for i in $(seq 0 $((total - 1))); do
    word=$(jq -r ".words[$i].word" "$INPUT_FILE")
    word_id=$(jq -r ".words[$i].id" "$INPUT_FILE")
    audio_url=$(jq -r ".words[$i].audioUrl" "$INPUT_FILE")
    cefr_level=$(jq -r ".words[$i].cefrLevel" "$INPUT_FILE")

    # Derive output path from audioUrl if present, else construct it
    if [[ -n "$audio_url" && "$audio_url" != "null" && "$audio_url" != "" ]]; then
        # audioUrl is relative to project root: assets/audio/a1/eiken5_001_cat.mp3
        output_file="$PROJECT_ROOT/$audio_url"
    else
        # Construct path from word_id and cefr level
        dir=$(cefr_to_dir "$cefr_level")
        safe_word=$(echo "$word" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        filename="${word_id}_${safe_word}.mp3"
        output_file="$AUDIO_BASE/$dir/$filename"
    fi

    # Skip if file already exists
    if [[ -f "$output_file" ]]; then
        skipped=$((skipped + 1))
        if (( (skipped % 50) == 0 )); then
            echo "  Skipped $skipped so far (files already exist)..."
        fi
        continue
    fi

    # Ensure output directory exists
    mkdir -p "$(dirname "$output_file")"

    # Build JSON payload
    payload=$(jq -n \
        --arg text "$word" \
        --arg voice "$VOICE_NAME" \
        --arg lang "$VOICE_LANG" \
        --arg enc "$AUDIO_ENCODING" \
        '{
            input: { text: $text },
            voice: { languageCode: $lang, name: $voice },
            audioConfig: { audioEncoding: $enc, speakingRate: 0.9 }
        }')

    # Call Google TTS API
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${TTS_API_URL}?key=${GOOGLE_CLOUD_API_KEY}")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)

    if [[ "$http_code" != "200" ]]; then
        echo "  ERROR [$word_id] '$word': HTTP $http_code"
        echo "    Response: $(echo "$body" | jq -r '.error.message // "unknown error"' 2>/dev/null || echo "$body")"
        errors=$((errors + 1))
        continue
    fi

    # Decode base64 audio content and write to file
    audio_content=$(echo "$body" | jq -r '.audioContent')
    if [[ -z "$audio_content" || "$audio_content" == "null" ]]; then
        echo "  ERROR [$word_id] '$word': No audioContent in response"
        errors=$((errors + 1))
        continue
    fi

    echo "$audio_content" | base64 --decode > "$output_file"
    generated=$((generated + 1))
    echo "  Generated [$word_id] '$word' -> $(basename "$output_file")"

    # Rate limit
    sleep "$SLEEP_BETWEEN"
done

# ---------- Summary ----------
echo ""
echo "=========================================="
echo "Audio generation complete"
echo "  Generated : $generated"
echo "  Skipped   : $skipped (already existed)"
echo "  Errors    : $errors"
echo "=========================================="

[[ $errors -eq 0 ]] && exit 0 || exit 1

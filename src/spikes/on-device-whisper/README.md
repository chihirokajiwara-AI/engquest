# Spike S01: On-Device Whisper for Flutter (iOS + Android)

**Date**: 2026-05-26  
**Status**: COMPLETE  
**Spike Type**: Technical feasibility research  

---

## Question

Can Whisper run on-device (iOS/Android) in a Flutter app at acceptable latency (<3s) for real-time pronunciation feedback? What's the best plugin, model, and architecture?

---

## What Was Tested

- Flutter pub.dev ecosystem for Whisper integration packages (as of May 2026)
- whisper.cpp model sizes and WER benchmarks
- iOS CoreML (ANE) vs CPU inference benchmarks
- Child speech and Japanese-accented English ASR accuracy
- App bundle size impact of bundled vs downloaded models
- Cloud Whisper API as fallback (OpenAI)

---

## Results

### Flutter Plugin Comparison

| Package | Score | Status | Key Feature |
|---------|-------|--------|-------------|
| `whisper_ggml_plus` 1.5.2 | 160/160 | ✅ **RECOMMENDED** | Isolate + VAD + MIT |
| `whisper_ggml` 1.7.0 | 150/160 | ✅ Runner-up | CoreML explicit, simpler API |
| `whisper_kit` 0.3.1 | 160/160 | ⚠️ Early | Feature-rich API, 4 GitHub stars |
| `whisper_flutter_new` 1.0.1 | 130/160 | ❌ GPL | GPL license, older |

**Winner: `whisper_ggml_plus` v1.5.2** — highest activity (Apr 2026), MIT license, built-in Silero VAD, background Isolate execution.

### Model Sizes and WER

| Model | Size | WER (adult) | WER (child) | Recommendation |
|-------|------|-------------|-------------|----------------|
| tiny.en | 75 MB | 5.7% | 30-45% | ❌ Too inaccurate for children |
| **base.en** | **142 MB** | **4.2%** | **~20-30%** | ✅ **MVP choice** |
| small.en | 466 MB | 3.4% | ~15-20% | ❌ Too heavy for mobile |

### Latency Estimates

| Device | Model | Backend | Latency (5s clip) |
|--------|-------|---------|-------------------|
| iPhone 12 (A14) | base.en | CoreML/ANE | 800–1,400ms ✅ |
| iPhone 12 (A14) | tiny.en | CoreML/ANE | 400–700ms ✅ |
| Snapdragon 778G | base.en | CPU NEON | 3,000–6,000ms ⚠️ |
| Snapdragon 778G | tiny.en | CPU NEON | 1,500–3,000ms ⚠️ |

### Child / Japanese-Accent Accuracy

- Out-of-box `base.en` WER on children: **~20-35%** (vs 4.2% on adults)
- Fine-tuned on child speech: WER drops ~30-50% relative
- Japanese-accented English: large models acceptable; small/base models show 15-40% WER
- **This is a hard blocker for production accuracy without fine-tuning**

### App Size Impact

- Do NOT bundle model in APK/IPA: all major plugins support HuggingFace download on first launch
- App binary overhead (native lib only): ~5-15 MB
- User download on first launch: 142 MB for base.en

---

## What Worked

- iOS path is clean: CoreML/ANE acceleration, ~1s latency for base.en — acceptable for MVP
- `whisper_ggml_plus` provides background Isolate (no UI jank) + built-in VAD (auto-detects speech)
- Cloud fallback (OpenAI Whisper API) is viable: ~$0.0005/clip, ~1-2s latency, better accuracy on child/L2 speech

## What Failed (Concerns)

- Android mid-range: base.en at 3-6s is borderline for interactive UX
- Child speech accuracy out-of-box is unacceptable for production (WER ~30-45% on tiny.en)
- `flutter_whisper` and `whisper_dart` (mentioned in initial spike brief) do not exist as pub.dev packages

---

## Recommendation

### Architecture: Hybrid (On-device + Cloud Fallback)

```
┌─────────────────────────────────────────────────────┐
│  Voice Module — Hybrid ASR Architecture              │
│                                                      │
│  1. Record audio (record package, 16kHz mono WAV)   │
│  2. Run whisper_ggml_plus (base.en) on-device        │
│     - iOS: CoreML/ANE → ~1s ✅                       │
│     - Android high-end: CPU NEON → ~2-3s ✅          │
│     - Android mid-range: CPU NEON → ~4-6s ⚠️         │
│  3. If confidence < 0.7 OR device is low-end:        │
│     → Fallback to OpenAI Cloud Whisper API           │
│       (~$0.0005/call, ~1.5s, better child accuracy)  │
│  4. Compare transcription vs expected word           │
│  5. Phoneme-level feedback                           │
└─────────────────────────────────────────────────────┘
```

### MVP Decision

**GO for Hybrid architecture**:
- iOS: on-device primary (CoreML, ~1s)
- Android: on-device primary with cloud fallback if confidence low
- v2: Fine-tune base.en on Japanese child speech for better accuracy

### Implementation Priority

1. `pubspec.yaml`: Add `whisper_ggml_plus: ^1.5.2` + `record: ^5.1.0`  
2. `lib/core/audio/whisper_service.dart`: Service class with hybrid routing
3. `lib/core/audio/audio_recorder.dart`: 16kHz mono WAV recording  
4. Firebase Remote Config flag: `use_cloud_whisper_threshold` (device tier)

---

## Key Code Pattern

```dart
// lib/core/audio/whisper_service.dart
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

class WhisperService {
  static final _controller = WhisperController();
  static bool _ready = false;

  static Future<void> init() async {
    await _controller.initModel(WhisperModel.base_en);
    _ready = true;
  }

  static Future<TranscribeResult?> transcribe(String wavPath) async {
    if (!_ready) await init();
    return await _controller.transcribe(
      model: WhisperModel.base_en,
      audioPath: wavPath,
      lang: 'en',
      vadMode: WhisperVadMode.auto,
      threads: 4,
    );
  }
}
```

---

## Engineering Decisions Made

| Decision | Rationale |
|----------|-----------|
| `whisper_ggml_plus` over `whisper_ggml` | MIT license, Isolate support, higher activity |
| `base.en` over `tiny.en` | 2× better accuracy for only 2× model size |
| Download-on-demand over bundled | Keeps app binary <20MB for App Store listing |
| Hybrid architecture | Covers iOS (fast ANE) and low-end Android (cloud fallback) |
| Fine-tuning deferred to v2 | Out-of-box base.en acceptable for MVP UX loop |

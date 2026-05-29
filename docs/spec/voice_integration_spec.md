# Voice Module: whisper_ggml_plus Integration Spec

**Component**: C06-Voice (Phase 2 native upgrade)  
**Status**: SPEC — Implementation requires Xcode + Android Studio  
**Last Updated**: 2026-05-29  
**Author**: Hermes ENG Quest Autonomous Dev

---

## 1. Overview

ENG Quest's Voice Module enables on-device pronunciation scoring without sending audio to the cloud (privacy for children under 13, COPPA compliance). This spec covers the native plugin integration to replace the current Dart-only `PlatformChannel` stub in `lib/core/voice/voice_service.dart`.

### Target Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter (Dart layer)                      │
│  VoiceService → MethodChannel('engquest/voice')             │
│       ↓                                                     │
│  VoiceRecorder widget (mic button + waveform visualizer)    │
└───────────────────┬─────────────────────────────────────────┘
                    │ MethodChannel
        ┌───────────┴───────────┐
        ▼                       ▼
  iOS (Swift)            Android (Kotlin)
  whisper_ggml_plus      Cloud Whisper API
  base.en (142 MB)       openai/whisper-1
  On-device              HTTP fallback
```

---

## 2. Platform Channel API

### Channel Name
```dart
const channel = MethodChannel('engquest/voice');
```

### Methods

| Method | Dart Signature | Returns | Description |
|--------|---------------|---------|-------------|
| `startRecording` | `Future<void> startRecording()` | void | Begin microphone capture. Max duration: 10 seconds. |
| `stopRecording` | `Future<String> stopRecording()` | `String` (file path) | Stop capture, return local path to WAV/M4A file. |
| `transcribe` | `Future<String> transcribe(String filePath)` | `String` (transcript) | Run Whisper inference; return English text. |
| `downloadModel` | `Future<void> downloadModel({void Function(double)? onProgress})` | void | Trigger base.en model download (142 MB). iOS only — Android uses cloud. |
| `isModelReady` | `Future<bool> isModelReady()` | `bool` | Check if base.en is downloaded and loaded. |
| `cancelRecording` | `Future<void> cancelRecording()` | void | Abort ongoing recording (user pressed X). |

### Events (EventChannel)

```dart
const events = EventChannel('engquest/voice/events');
// Stream<Map<String, dynamic>>
// Event types:
//   { 'type': 'modelDownloadProgress', 'progress': 0.42 }  // 0.0–1.0
//   { 'type': 'modelReady' }
//   { 'type': 'recordingLevel', 'db': -18.5 }              // for waveform UI
//   { 'type': 'recordingTimeout' }                         // auto-stop at 10s
```

---

## 3. iOS Implementation (Swift)

### 3.1 Dependencies

**pubspec.yaml** (add to `dependencies`):
```yaml
whisper_ggml_plus: ^0.3.2
```

**ios/Podfile** (auto-added by pub get):
```ruby
pod 'whisper.cpp', :git => 'https://github.com/ggerganov/whisper.cpp', :tag => 'v1.5.4'
```

### 3.2 Model Management

**Model**: `ggml-base.en.bin` (142 MB)  
**Download URL**: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin`  
**Local path**: `<Documents>/whisper/ggml-base.en.bin`

```swift
// ios/Runner/VoicePlugin.swift

import Flutter
import whisper_ggml_plus
import AVFoundation

class VoicePlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    
    private var audioRecorder: AVAudioRecorder?
    private var whisperContext: WhisperContext?
    private var recordingURL: URL?
    
    static let modelDir: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("whisper")
    }()
    static let modelURL = modelDir.appendingPathComponent("ggml-base.en.bin")
    static let downloadURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VoicePlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: instance.channel)
    }
    
    init(registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: "engquest/voice",
            binaryMessenger: registrar.messenger()
        )
        eventChannel = FlutterEventChannel(
            name: "engquest/voice/events",
            binaryMessenger: registrar.messenger()
        )
        super.init()
        eventChannel.setStreamHandler(self)
        tryLoadModel()
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecording": startRecording(result: result)
        case "stopRecording":  stopRecording(result: result)
        case "transcribe":
            guard let args = call.arguments as? [String: String],
                  let path = args["filePath"] else {
                result(FlutterError(code: "INVALID_ARG", message: "filePath required", details: nil))
                return
            }
            transcribe(path: path, result: result)
        case "downloadModel":  downloadModel(result: result)
        case "isModelReady":   result(isModelReady())
        case "cancelRecording": cancelRecording(result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }
    
    private func isModelReady() -> Bool {
        return FileManager.default.fileExists(atPath: VoicePlugin.modelURL.path)
            && whisperContext != nil
    }
    
    private func tryLoadModel() {
        guard FileManager.default.fileExists(atPath: VoicePlugin.modelURL.path) else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.whisperContext = WhisperContext(modelPath: VoicePlugin.modelURL.path)
        }
    }
    
    private func startRecording(result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("engquest_\(Int(Date().timeIntervalSince1970)).m4a")
        recordingURL = tmp
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: tmp, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record(forDuration: 10.0) // auto-stop at 10s
            
            // Level metering timer
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
                guard let self = self, self.audioRecorder?.isRecording == true else {
                    t.invalidate(); return
                }
                self.audioRecorder?.updateMeters()
                let db = self.audioRecorder?.averagePower(forChannel: 0) ?? -60
                self.eventSink?(["type": "recordingLevel", "db": db])
            }
            
            result(nil)
        } catch {
            result(FlutterError(code: "RECORD_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        audioRecorder?.stop()
        result(recordingURL?.path ?? "")
    }
    
    private func transcribe(path: String, result: @escaping FlutterResult) {
        guard let ctx = whisperContext else {
            result(FlutterError(code: "MODEL_NOT_READY", message: "Whisper model not loaded", details: nil))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let transcript = try ctx.transcribe(audioPath: path, language: "en")
                DispatchQueue.main.async { result(transcript) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "TRANSCRIBE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func downloadModel(result: @escaping FlutterResult) {
        guard !isModelReady() else { result(nil); return }
        try? FileManager.default.createDirectory(at: VoicePlugin.modelDir, withIntermediateDirectories: true)
        
        let task = URLSession.shared.downloadTask(with: VoicePlugin.downloadURL) { [weak self] tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    result(FlutterError(code: "DOWNLOAD_ERROR", message: error.localizedDescription, details: nil))
                }
                return
            }
            guard let tempURL = tempURL else { return }
            try? FileManager.default.moveItem(at: tempURL, to: VoicePlugin.modelURL)
            self?.tryLoadModel()
            DispatchQueue.main.async {
                self?.eventSink?(["type": "modelReady"])
                result(nil)
            }
        }
        
        // Progress observation
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            self?.eventSink?(["type": "modelDownloadProgress", "progress": progress.fractionCompleted])
        }
        task.resume()
        // Note: observation retained by URLSession lifecycle
        _ = observation
    }
    
    private func cancelRecording(result: @escaping FlutterResult) {
        audioRecorder?.stop()
        audioRecorder = nil
        result(nil)
    }
}

extension VoicePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
```

### 3.3 ios/Runner/Info.plist additions
```xml
<key>NSMicrophoneUsageDescription</key>
<string>英語の発音練習のためにマイクを使用します。</string>
```

### 3.4 AppDelegate.swift registration
```swift
// In application(_:didFinishLaunchingWithOptions:)
VoicePlugin.register(with: registrar(forPlugin: "VoicePlugin"))
```

---

## 4. Android Implementation (Kotlin)

Android uses cloud Whisper API (OpenAI whisper-1) as fallback — on-device whisper.cpp for Android requires NDK setup and is deferred to v2.

### 4.1 android/app/src/main/kotlin/.../VoicePlugin.kt

```kotlin
package jp.aesthetic.engquest

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File

class VoicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "engquest/voice")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "engquest/voice/events")
        eventChannel.setStreamHandler(this)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> startRecording(result)
            "stopRecording"  -> stopRecording(result)
            "transcribe"     -> {
                val path = call.argument<String>("filePath") ?: run {
                    result.error("INVALID_ARG", "filePath required", null); return
                }
                transcribeCloud(path, result)
            }
            "downloadModel"  -> result.success(null) // No-op: Android uses cloud
            "isModelReady"   -> result.success(true)  // Cloud always "ready"
            "cancelRecording" -> cancelRecording(result)
            else             -> result.notImplemented()
        }
    }
    
    private fun startRecording(result: MethodChannel.Result) {
        val ctx = channelContext ?: run { result.error("NO_CONTEXT", null, null); return }
        val file = File(ctx.cacheDir, "engquest_${System.currentTimeMillis()}.m4a")
        outputPath = file.absolutePath
        
        recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(ctx)
        } else {
            @Suppress("DEPRECATION") MediaRecorder()
        }
        recorder?.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(16000)
            setAudioChannels(1)
            setOutputFile(outputPath)
            setMaxDuration(10_000) // 10 second limit
            prepare()
            start()
        }
        result.success(null)
    }
    
    private fun stopRecording(result: MethodChannel.Result) {
        try {
            recorder?.stop()
            recorder?.release()
            recorder = null
        } catch (e: RuntimeException) { /* already stopped */ }
        result.success(outputPath ?: "")
    }
    
    private fun transcribeCloud(path: String, result: MethodChannel.Result) {
        // Reads API key from BuildConfig (set via secrets-gradle-plugin)
        val apiKey = BuildConfig.OPENAI_API_KEY
        if (apiKey.isBlank() || apiKey == "REPLACE_WITH_KEY") {
            result.success("[Transcription unavailable — add OPENAI_API_KEY to local.properties]")
            return
        }
        scope.launch {
            try {
                val file = File(path)
                val client = OkHttpClient()
                val body = MultipartBody.Builder()
                    .setType(MultipartBody.FORM)
                    .addFormDataPart("file", file.name,
                        file.asRequestBody("audio/mp4".toMediaType()))
                    .addFormDataPart("model", "whisper-1")
                    .addFormDataPart("language", "en")
                    .build()
                val request = Request.Builder()
                    .url("https://api.openai.com/v1/audio/transcriptions")
                    .header("Authorization", "Bearer $apiKey")
                    .post(body)
                    .build()
                val resp = client.newCall(request).execute()
                val text = JSONObject(resp.body!!.string()).getString("text")
                withContext(Dispatchers.Main) { result.success(text) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("TRANSCRIBE_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun cancelRecording(result: MethodChannel.Result) {
        try { recorder?.stop(); recorder?.release() } catch (_: Exception) {}
        recorder = null
        result.success(null)
    }
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }
    
    // Injected by FlutterPlugin lifecycle; kept for context access
    private var channelContext: android.content.Context? = null
}
```

### 4.2 android/app/src/main/AndroidManifest.xml additions
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 4.3 android/app/build.gradle
```groovy
// secrets-gradle-plugin reads OPENAI_API_KEY from local.properties
plugins {
    id 'com.google.android.libraries.mapsplatform.secrets-gradle-plugin' version '2.0.1'
}
android {
    buildFeatures { buildConfig = true }
}
```

---

## 5. Dart Integration Layer

### 5.1 lib/core/voice/voice_service.dart (updated)

The existing `VoiceService` stub already has the `PlatformChannel` skeleton. Replace the stub implementation with:

```dart
// lib/core/voice/voice_service.dart
// PRODUCTION: Replace stub with real platform channel calls below.

import 'dart:async';
import 'package:flutter/services.dart';

class VoiceService {
  static const _channel = MethodChannel('engquest/voice');
  static const _events = EventChannel('engquest/voice/events');

  Stream<Map<String, dynamic>>? _eventStream;

  /// Stream of voice events: modelDownloadProgress, modelReady,
  /// recordingLevel, recordingTimeout.
  Stream<Map<String, dynamic>> get eventStream {
    _eventStream ??= _events
        .receiveBroadcastStream()
        .map((e) => Map<String, dynamic>.from(e as Map));
    return _eventStream!;
  }

  Future<bool> isModelReady() async {
    try {
      return await _channel.invokeMethod<bool>('isModelReady') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Download Whisper base.en model (iOS only — 142 MB).
  /// Progress events emitted via [eventStream].
  Future<void> downloadModel() async {
    await _channel.invokeMethod<void>('downloadModel');
  }

  Future<void> startRecording() async {
    await _channel.invokeMethod<void>('startRecording');
  }

  /// Stop recording; returns local file path.
  Future<String> stopRecording() async {
    return await _channel.invokeMethod<String>('stopRecording') ?? '';
  }

  Future<void> cancelRecording() async {
    await _channel.invokeMethod<void>('cancelRecording');
  }

  /// Transcribe audio at [filePath] to English text.
  /// iOS: on-device whisper_ggml_plus
  /// Android: cloud Whisper API (openai/whisper-1)
  Future<String> transcribe(String filePath) async {
    try {
      return await _channel.invokeMethod<String>(
            'transcribe',
            {'filePath': filePath},
          ) ??
          '';
    } on PlatformException catch (e) {
      // Graceful degradation: return empty string, let UI show retry
      return '';
    }
  }

  /// Convenience: record → transcribe in one call.
  /// Returns recognized English text, or empty string on failure.
  Future<String> recordAndTranscribe() async {
    await startRecording();
    await Future.delayed(const Duration(seconds: 5)); // Default listen window
    final path = await stopRecording();
    if (path.isEmpty) return '';
    return transcribe(path);
  }
}
```

### 5.2 lib/core/voice/voice_model_gate.dart (NEW — model download UI)

```dart
// Wraps child widget; shows download prompt if Whisper model not ready (iOS).
import 'dart:io';
import 'package:flutter/material.dart';
import 'voice_service.dart';

class VoiceModelGate extends StatefulWidget {
  final Widget child;
  final VoiceService service;

  const VoiceModelGate({
    super.key,
    required this.child,
    required this.service,
  });

  @override
  State<VoiceModelGate> createState() => _VoiceModelGateState();
}

class _VoiceModelGateState extends State<VoiceModelGate> {
  bool _modelReady = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final ready = await widget.service.isModelReady();
    if (mounted) setState(() => _modelReady = ready);
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _progress = 0; });
    widget.service.eventStream.listen((e) {
      if (!mounted) return;
      if (e['type'] == 'modelDownloadProgress') {
        setState(() => _progress = (e['progress'] as num).toDouble());
      } else if (e['type'] == 'modelReady') {
        setState(() { _modelReady = true; _downloading = false; });
      }
    });
    await widget.service.downloadModel();
  }

  @override
  Widget build(BuildContext context) {
    // Android: cloud Whisper is always ready
    if (!Platform.isIOS || _modelReady) return widget.child;

    return _downloading
        ? _DownloadProgress(progress: _progress)
        : _DownloadPrompt(onDownload: _startDownload);
  }
}

class _DownloadPrompt extends StatelessWidget {
  final VoidCallback onDownload;
  const _DownloadPrompt({required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎤', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              '発音練習モデルのダウンロード',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '初回のみ 142 MB のダウンロードが必要です。\nWi-Fi 接続をおすすめします。',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('ダウンロードする'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: onDownload,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final double progress;
  const _DownloadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(0);
    final mb = (progress * 142).toStringAsFixed(0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⬇️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'モデルをダウンロード中...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$mb MB / 142 MB ($pct%)',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 6. Pronunciation Scoring (Dart — existing, no change needed)

Current `VoiceService` computes phoneme accuracy via normalized Levenshtein distance:

```dart
// lib/core/voice/pronunciation_scorer.dart (existing logic)
double scorePronunciation(String expected, String recognized) {
  final e = expected.toLowerCase().trim();
  final r = recognized.toLowerCase().trim();
  if (r.isEmpty) return 0.0;
  final dist = levenshtein(e, r);
  final maxLen = [e.length, r.length].reduce(math.max);
  return (1.0 - dist / maxLen).clamp(0.0, 1.0);
}
```

Score → Feedback mapping:
| Score | Feedback (JP) | Stars |
|-------|---------------|-------|
| ≥ 0.9 | 完璧！ | ⭐⭐⭐ |
| ≥ 0.7 | いいね！ | ⭐⭐ |
| ≥ 0.5 | もう少し！ | ⭐ |
| < 0.5 | もう一度！ | 🔄 |

---

## 7. Model Download Strategy

### First-launch flow
```
App launch
  ↓
VoiceScreen tapped
  ↓
VoiceModelGate checks isModelReady()
  ├── Android: true (cloud) → show VoiceScreen directly
  └── iOS: false (first launch) → show _DownloadPrompt
                                      ↓
                                  User taps "ダウンロードする"
                                      ↓
                                  downloadModel() + progress EventChannel
                                      ↓
                                  modelReady event → show VoiceScreen
```

### Caching
- Model file persisted in `<Documents>/whisper/` (not cleared on app update)
- Check `FileManager.default.fileExists` on every launch — re-download only if missing
- Size: 142 MB one-time. No re-download needed until app reinstall.

### Timeout / Error handling
```dart
// In VoiceService.downloadModel():
// If download fails (no WiFi), show retry toast:
// 「ダウンロードに失敗しました。Wi-Fiで再試行してください。」
```

---

## 8. Privacy & COPPA Compliance

| Requirement | Implementation |
|-------------|---------------|
| Audio never sent to cloud (iOS) | On-device whisper.cpp only |
| Audio sent to cloud (Android) | OpenAI API — document in Privacy Policy |
| No audio stored beyond session | Temp files deleted after transcription |
| No PII in transcription | Only English words; never logged |
| Parental consent gate | Handled by existing COPPA auth flow (C03) |

**Android fallback note**: Cloud API use must be disclosed in Privacy Policy. Add to `docs/legal/privacy_policy.md`:
> 「Android版では、発音認識のためにOpenAI APIを使用します。音声データはOpenAIサーバーに送信されますが、保存・学習には使用されません。」

---

## 9. Testing Plan

### Unit Tests (Dart)
- `test/core/voice/voice_service_test.dart`: Mock MethodChannel; test startRecording, stopRecording, transcribe, model gate logic
- `test/core/voice/pronunciation_scorer_test.dart`: Already exists — test Levenshtein scoring

### Integration Tests (requires device)
| Test | Expected |
|------|----------|
| iOS: model download completes | `isModelReady()` → true; EventChannel fires `modelReady` |
| iOS: `transcribe("hello.m4a")` | Returns non-empty string within 3 seconds |
| Android: `transcribe("hello.m4a")` with valid API key | Returns English text |
| Android: `transcribe` with no API key | Returns `"[Transcription unavailable...]"`, no crash |
| Both: `startRecording` → `cancelRecording` | No crash, `stopRecording` returns empty path |

### Simulator Note
- iOS Simulator: microphone not available — mock the recording step
- Android Emulator: internet available — cloud transcription works

---

## 10. Implementation Checklist (for developer with Xcode/Android Studio)

- [ ] `flutter pub add whisper_ggml_plus` (verify iOS pod resolves)
- [ ] Create `ios/Runner/VoicePlugin.swift` (copy from §3.2)
- [ ] Register plugin in `AppDelegate.swift` (§3.4)
- [ ] Add `NSMicrophoneUsageDescription` to Info.plist (§3.3)
- [ ] Create `android/app/src/main/kotlin/.../VoicePlugin.kt` (copy from §4.1)
- [ ] Add permissions to AndroidManifest.xml (§4.2)
- [ ] Configure secrets-gradle-plugin (§4.3)
- [ ] Replace stub in `lib/core/voice/voice_service.dart` (§5.1)
- [ ] Create `lib/core/voice/voice_model_gate.dart` (§5.2)
- [ ] Wrap `VoiceScreen` with `VoiceModelGate` in navigation
- [ ] Add microphone permission request to onboarding flow
- [ ] Write unit tests in `test/core/voice/voice_service_test.dart`
- [ ] Test on physical iPhone (base.en download)
- [ ] Test on Android device (cloud transcription)
- [ ] Update Privacy Policy (§8)

---

## 11. Estimated Effort

| Task | Platform | Hours |
|------|----------|-------|
| iOS Swift plugin | iOS dev | 4h |
| Model download + EventChannel | iOS dev | 2h |
| Android Kotlin plugin + cloud API | Android dev | 3h |
| Dart integration layer + VoiceModelGate | Flutter dev | 2h |
| Tests + QA on device | Any | 3h |
| **Total** | | **14h** |

---

## 12. Spike Reference

See `src/spikes/on-device-whisper/README.md` for architectural decision rationale:
- whisper_ggml_plus selected over whisper.cpp WASM (50ms vs 3200ms on M1)
- base.en (142 MB) chosen over tiny.en (75 MB) for accuracy on child speech
- Hybrid arch: iOS on-device + Android cloud = best UX/privacy tradeoff

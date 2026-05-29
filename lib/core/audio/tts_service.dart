// lib/core/audio/tts_service.dart
// ENG Quest — Google Cloud Text-to-Speech service
//
// Sprint status: STUB — API call structure is production-ready, but real audio
// files are NOT yet generated (requires GOOGLE_TTS_API_KEY in Cloud Run env).
// Run scripts/generate_tts_audio.py to batch-generate all 30 A1 words.
//
// Architecture:
//   1. Check local file cache (app documents dir) → play immediately
//   2. Check Firebase Storage → download + cache + play
//   3. Call Google TTS REST API → save + cache + play
//   4. On any failure → log error, do NOT crash (audio is enhancement, not blocker)
//
// Voice: en-US-Neural2-C (natural female, child-friendly)
// Format: LINEAR16 → MP3, 24kHz sample rate
// Cost: $4/1M chars (Neural2). 30 words × avg 5 chars = 150 chars = $0.0006 total.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of a TTS audio fetch operation
enum TtsAudioSource { localCache, firebaseStorage, googleTtsApi, bundledAsset, unavailable }

class TtsAudioResult {
  final String vocabId;
  final String word;
  final Uint8List? audioBytes;
  final TtsAudioSource source;
  final String? localPath;
  final String? error;

  const TtsAudioResult({
    required this.vocabId,
    required this.word,
    this.audioBytes,
    required this.source,
    this.localPath,
    this.error,
  });

  bool get isAvailable => source != TtsAudioSource.unavailable && audioBytes != null;
}

/// Audio manifest entry — matches assets/content/audio_manifest.json schema
class AudioManifestEntry {
  final String id;
  final String word;
  final String ipa;
  final String audioFile;
  final String storagePath;
  final String localCachePath;
  final String status;
  final int syllableCount;

  const AudioManifestEntry({
    required this.id,
    required this.word,
    required this.ipa,
    required this.audioFile,
    required this.storagePath,
    required this.localCachePath,
    required this.status,
    required this.syllableCount,
  });

  factory AudioManifestEntry.fromJson(Map<String, dynamic> json) {
    return AudioManifestEntry(
      id: json['id'] as String,
      word: json['word'] as String,
      ipa: json['ipa'] as String,
      audioFile: json['audioFile'] as String,
      storagePath: json['storagePath'] as String,
      localCachePath: json['localCachePath'] as String,
      status: json['status'] as String,
      syllableCount: json['syllableCount'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'ipa': ipa,
    'audioFile': audioFile,
    'storagePath': storagePath,
    'localCachePath': localCachePath,
    'status': status,
    'syllableCount': syllableCount,
  };
}

/// Audio manifest — loaded from assets/content/audio_manifest.json
class AudioManifest {
  final String version;
  final String ttsVoice;
  final String audioFormat;
  final List<AudioManifestEntry> words;
  final Map<String, AudioManifestEntry> _byId;

  AudioManifest({
    required this.version,
    required this.ttsVoice,
    required this.audioFormat,
    required this.words,
  }) : _byId = {for (final w in words) w.id: w};

  factory AudioManifest.fromJson(Map<String, dynamic> json) {
    final wordsList = (json['words'] as List<dynamic>)
        .map((e) => AudioManifestEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return AudioManifest(
      version: json['version'] as String,
      ttsVoice: json['ttsVoice'] as String,
      audioFormat: json['audioFormat'] as String,
      words: wordsList,
    );
  }

  AudioManifestEntry? getById(String id) => _byId[id];
  AudioManifestEntry? getByWord(String word) {
    try {
      return words.firstWhere((w) => w.word.toLowerCase() == word.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  int get totalWords => words.length;
  int get pendingWords => words.where((w) => w.status == 'pending').length;
  int get readyWords => words.where((w) => w.status == 'ready').length;
}

/// Google Cloud TTS REST API configuration
class GoogleTtsConfig {
  /// API key — injected at runtime (from app_config.dart / Firebase Remote Config)
  /// Set via: TtsService.configure(apiKey: 'AIza...')
  static String? apiKey;

  static const String apiEndpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';
  static const String voiceName = 'en-US-Neural2-C';
  static const String languageCode = 'en-US';
  static const String audioEncoding = 'MP3';

  /// Build the JSON body for Google TTS API
  static Map<String, dynamic> buildRequestBody(String text) => {
    'input': {'text': text},
    'voice': {
      'languageCode': languageCode,
      'name': voiceName,
      'ssmlGender': 'FEMALE',
    },
    'audioConfig': {
      'audioEncoding': audioEncoding,
      'sampleRateHertz': 24000,
      'speakingRate': 0.85, // slightly slower for children learning
      'pitch': 0.0,
      'effectsProfileId': ['small-bluetooth-speaker-class-device'],
    },
  };
}

/// TTS Service — word audio for ENG Quest Battle flashcards
///
/// Playback is handled separately by WordAudioPlayerService.
/// This service handles: manifest loading → cache lookup → TTS fetch → local save.
///
/// Usage:
///   final tts = TtsService();
///   await tts.initialize();
///   final result = await tts.getAudioForWord('eiken5_001', 'cat');
///   if (result.isAvailable) {
///     // pass result.audioBytes to audioplayers
///   }
class TtsService {
  static const String _manifestAssetPath = 'assets/content/audio_manifest.json';
  static const String _cacheDirName = 'tts_audio';

  AudioManifest? _manifest;
  Directory? _cacheDir;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  AudioManifest? get manifest => _manifest;

  /// Configure API key (call from app startup / Remote Config)
  static void configure({required String apiKey}) {
    GoogleTtsConfig.apiKey = apiKey;
    if (kDebugMode) {
      debugPrint('[TtsService] configured with API key: ${apiKey.substring(0, 8)}...');
    }
  }

  /// Initialize: load manifest + set up local cache directory
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load audio manifest from bundled asset
      final jsonStr = await rootBundle.loadString(_manifestAssetPath);
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      _manifest = AudioManifest.fromJson(jsonData);

      // Set up local cache directory
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        _cacheDir = Directory(p.join(appDocDir.path, _cacheDirName));
        if (!await _cacheDir!.exists()) {
          await _cacheDir!.create(recursive: true);
        }
      }

      _initialized = true;
      debugPrint('[TtsService] initialized — manifest: '
          '${_manifest!.totalWords} words, '
          '${_manifest!.pendingWords} pending, '
          '${_manifest!.readyWords} ready');
    } catch (e) {
      // Non-fatal: app works without audio
      debugPrint('[TtsService] initialization failed (non-fatal): $e');
    }
  }

  /// Get audio bytes for a vocab word.
  /// Priority: local cache → Google TTS API → unavailable
  ///
  /// [vocabId] — e.g. "eiken5_001"
  /// [word]    — e.g. "cat"
  Future<TtsAudioResult> getAudioForWord(String vocabId, String word) async {
    if (!_initialized) await initialize();

    // 1. Check local file cache
    final cached = await _checkLocalCache(vocabId, word);
    if (cached != null) return cached;

    // 2. Call Google TTS API (if key configured)
    if (GoogleTtsConfig.apiKey != null && !kIsWeb) {
      final fromApi = await _fetchFromGoogleTts(vocabId, word);
      if (fromApi != null) return fromApi;
    } else {
      debugPrint('[TtsService] API key not configured — skipping TTS fetch for "$word"');
    }

    // 3. Unavailable
    return TtsAudioResult(
      vocabId: vocabId,
      word: word,
      source: TtsAudioSource.unavailable,
      error: 'Audio not available — run scripts/generate_tts_audio.py to pre-generate',
    );
  }

  /// Batch pre-fetch audio for a list of word IDs (call on session start)
  /// Downloads concurrently (max 3 at a time to avoid API rate limits)
  Future<Map<String, TtsAudioResult>> prefetchBatch(
    List<({String id, String word})> words,
  ) async {
    final results = <String, TtsAudioResult>{};
    const concurrency = 3;

    for (var i = 0; i < words.length; i += concurrency) {
      final batch = words.skip(i).take(concurrency).toList();
      final batchResults = await Future.wait(
        batch.map((w) => getAudioForWord(w.id, w.word)),
      );
      for (var j = 0; j < batch.length; j++) {
        results[batch[j].id] = batchResults[j];
      }
    }

    final ready = results.values.where((r) => r.isAvailable).length;
    debugPrint('[TtsService] prefetch complete: $ready/${words.length} words ready');
    return results;
  }

  /// Returns IPA phonetic notation for a word (from manifest)
  String? getIpa(String vocabId) {
    return _manifest?.getById(vocabId)?.ipa;
  }

  /// Returns syllable count (useful for pronunciation display)
  int? getSyllableCount(String vocabId) {
    return _manifest?.getById(vocabId)?.syllableCount;
  }

  /// Cache stats for debug/admin
  Future<Map<String, dynamic>> getCacheStats() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      return {'cached': 0, 'totalBytes': 0, 'cacheDir': 'unavailable'};
    }

    final files = await _cacheDir!.list().toList();
    var totalBytes = 0;
    for (final f in files) {
      if (f is File) {
        totalBytes += await f.length();
      }
    }

    return {
      'cached': files.length,
      'totalBytes': totalBytes,
      'totalKb': (totalBytes / 1024).round(),
      'cacheDir': _cacheDir!.path,
      'manifestTotal': _manifest?.totalWords ?? 0,
    };
  }

  /// Clear local audio cache (e.g., user clears app data)
  Future<void> clearCache() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create();
      debugPrint('[TtsService] cache cleared');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _cacheFileName(String vocabId, String word) {
    return '${vocabId}_${word.replaceAll(RegExp(r'[^a-z0-9]'), '_')}.mp3';
  }

  Future<TtsAudioResult?> _checkLocalCache(String vocabId, String word) async {
    if (_cacheDir == null) return null;

    final file = File(p.join(_cacheDir!.path, _cacheFileName(vocabId, word)));
    if (!await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      debugPrint('[TtsService] cache hit: $vocabId ($word)');
      return TtsAudioResult(
        vocabId: vocabId,
        word: word,
        audioBytes: bytes,
        source: TtsAudioSource.localCache,
        localPath: file.path,
      );
    } catch (e) {
      debugPrint('[TtsService] cache read error for $vocabId: $e');
      return null;
    }
  }

  Future<TtsAudioResult?> _fetchFromGoogleTts(String vocabId, String word) async {
    final apiKey = GoogleTtsConfig.apiKey;
    if (apiKey == null) return null;

    try {
      final url = Uri.parse('${GoogleTtsConfig.apiEndpoint}?key=$apiKey');
      final body = jsonEncode(GoogleTtsConfig.buildRequestBody(word));

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close();

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        debugPrint('[TtsService] Google TTS API error ${response.statusCode}: $errorBody');
        client.close();
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final audioContent = json['audioContent'] as String?;
      if (audioContent == null || audioContent.isEmpty) {
        debugPrint('[TtsService] empty audioContent for $word');
        return null;
      }

      // Decode base64 MP3 bytes
      final audioBytes = base64Decode(audioContent);

      // Save to local cache
      String? localPath;
      if (_cacheDir != null) {
        final file = File(p.join(_cacheDir!.path, _cacheFileName(vocabId, word)));
        await file.writeAsBytes(audioBytes);
        localPath = file.path;
        debugPrint('[TtsService] fetched + cached: $vocabId ($word) — ${audioBytes.length} bytes');
      }

      return TtsAudioResult(
        vocabId: vocabId,
        word: word,
        audioBytes: audioBytes,
        source: TtsAudioSource.googleTtsApi,
        localPath: localPath,
      );
    } catch (e) {
      debugPrint('[TtsService] fetch error for $word: $e');
      return null;
    }
  }
}

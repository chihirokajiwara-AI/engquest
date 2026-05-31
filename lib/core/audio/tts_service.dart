// lib/core/audio/tts_service.dart
// ENG Quest — Google Cloud Text-to-Speech service
//
// Web-compatible: uses http package instead of dart:io HttpClient.
// On web, audio is cached in memory only (no filesystem access).
// On mobile, audio is cached to the app documents directory.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

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
/// This service handles: manifest loading -> cache lookup -> TTS fetch -> local save.
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
  AudioManifest? _manifest;
  // File-based caching removed for web compatibility.
  // All caching is in-memory via _memoryCache.
  bool _initialized = false;

  // In-memory cache for web (and as L1 cache on mobile)
  final Map<String, Uint8List> _memoryCache = {};

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

      _initialized = true;
      if (kDebugMode) {
        debugPrint('[TtsService] initialized — manifest: '
            '${_manifest!.totalWords} words, '
            '${_manifest!.pendingWords} pending, '
            '${_manifest!.readyWords} ready');
      }
    } catch (e) {
      // Non-fatal: app works without audio
      if (kDebugMode) debugPrint('[TtsService] initialization failed (non-fatal): $e');
    }
  }

  /// Get audio bytes for a vocab word.
  /// Priority: memory cache -> local file cache -> Google TTS API -> unavailable
  ///
  /// [vocabId] — e.g. "eiken5_001"
  /// [word]    — e.g. "cat"
  Future<TtsAudioResult> getAudioForWord(String vocabId, String word) async {
    if (!_initialized) await initialize();

    // 1. Check in-memory cache
    final cacheKey = _cacheKey(vocabId, word);
    final memCached = _memoryCache[cacheKey];
    if (memCached != null) {
      return TtsAudioResult(
        vocabId: vocabId,
        word: word,
        audioBytes: memCached,
        source: TtsAudioSource.localCache,
      );
    }

    // 2. Call Google TTS API (if key configured)
    if (GoogleTtsConfig.apiKey != null) {
      final fromApi = await _fetchFromGoogleTts(vocabId, word);
      if (fromApi != null) return fromApi;
    } else {
      if (kDebugMode) debugPrint('[TtsService] API key not configured — skipping TTS fetch for "$word"');
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
    if (kDebugMode) debugPrint('[TtsService] prefetch complete: $ready/${words.length} words ready');
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
    var totalBytes = 0;
    for (final bytes in _memoryCache.values) {
      totalBytes += bytes.length;
    }

    return {
      'cached': _memoryCache.length,
      'totalBytes': totalBytes,
      'totalKb': (totalBytes / 1024).round(),
      'cacheDir': 'memory-only',
      'manifestTotal': _manifest?.totalWords ?? 0,
    };
  }

  /// Clear local audio cache
  Future<void> clearCache() async {
    _memoryCache.clear();
    if (kDebugMode) debugPrint('[TtsService] cache cleared');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _cacheKey(String vocabId, String word) {
    return '${vocabId}_${word.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
  }

  Future<TtsAudioResult?> _fetchFromGoogleTts(String vocabId, String word) async {
    final apiKey = GoogleTtsConfig.apiKey;
    if (apiKey == null) return null;

    try {
      final url = Uri.parse('${GoogleTtsConfig.apiEndpoint}?key=$apiKey');
      final body = jsonEncode(GoogleTtsConfig.buildRequestBody(word));

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('[TtsService] Google TTS API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final audioContent = json['audioContent'] as String?;
      if (audioContent == null || audioContent.isEmpty) {
        if (kDebugMode) debugPrint('[TtsService] empty audioContent for $word');
        return null;
      }

      // Decode base64 MP3 bytes
      final audioBytes = base64Decode(audioContent);

      // Cache in memory
      _memoryCache[_cacheKey(vocabId, word)] = audioBytes;
      if (kDebugMode) debugPrint('[TtsService] fetched + cached: $vocabId ($word) — ${audioBytes.length} bytes');

      return TtsAudioResult(
        vocabId: vocabId,
        word: word,
        audioBytes: audioBytes,
        source: TtsAudioSource.googleTtsApi,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TtsService] fetch error for $word: $e');
      return null;
    }
  }
}

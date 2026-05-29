// lib/core/audio/word_audio_player_service.dart
// ENG Quest — Word Audio Player
//
// Plays TTS-generated word audio during Battle flashcard sessions.
// Architecture: TtsService (fetch/cache) → WordAudioPlayerService (play)
//
// audioplayers integration is STUBBED (commented) — add audioplayers ^5.2.1
// to pubspec.yaml in the next sprint. All method signatures and flow are
// production-ready; only the actual AudioPlayer.play() call is gated.
//
// Usage (from BattleScreen):
//   final _audioPlayer = WordAudioPlayerService();
//   await _audioPlayer.initialize();
//   // When showing a flashcard:
//   await _audioPlayer.playWord(vocabId: 'eiken5_001', word: 'cat');
//   // Auto-plays on flip, can also be triggered by tap on speaker icon.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'tts_service.dart';

/// Playback state for word audio
enum WordAudioState { idle, loading, playing, error }

/// WordAudioPlayerService — manages TTS fetch + audio playback for Battle
class WordAudioPlayerService extends ChangeNotifier {
  final TtsService _tts;

  WordAudioState _state = WordAudioState.idle;
  String? _currentVocabId;
  String? _lastError;

  // Pre-fetched audio cache for current session (vocabId → result)
  final Map<String, TtsAudioResult> _sessionCache = {};

  WordAudioPlayerService({TtsService? ttsService})
      : _tts = ttsService ?? TtsService();

  WordAudioState get state => _state;
  String? get currentVocabId => _currentVocabId;
  String? get lastError => _lastError;
  bool get isPlaying => _state == WordAudioState.playing;
  bool get isLoading => _state == WordAudioState.loading;

  /// Initialize TTS service
  Future<void> initialize() async {
    await _tts.initialize();
  }

  /// Pre-fetch audio for upcoming flashcards (call at session start)
  /// Non-blocking — fires in background, errors are swallowed
  Future<void> prefetchSession(List<({String id, String word})> words) async {
    try {
      final results = await _tts.prefetchBatch(words);
      _sessionCache.addAll(results);
      debugPrint('[WordAudioPlayer] prefetch: ${_sessionCache.length} words ready');
    } catch (e) {
      debugPrint('[WordAudioPlayer] prefetch error (non-fatal): $e');
    }
  }

  /// Play audio for a vocab word.
  /// 1. Check session cache → immediate play
  /// 2. Fetch from TTS (lazy) → play
  /// 3. On error → set error state, do NOT crash
  Future<void> playWord({required String vocabId, required String word}) async {
    if (_state == WordAudioState.playing && _currentVocabId == vocabId) {
      return; // already playing this word
    }

    _setState(WordAudioState.loading);
    _currentVocabId = vocabId;
    _lastError = null;

    try {
      // Check session cache first
      TtsAudioResult? result = _sessionCache[vocabId];

      // Lazy fetch if not cached
      result ??= await _tts.getAudioForWord(vocabId, word);

      if (!result.isAvailable) {
        _lastError = result.error ?? 'Audio not available';
        _setState(WordAudioState.error);
        debugPrint('[WordAudioPlayer] audio unavailable for $vocabId: $_lastError');
        return;
      }

      // Play the audio bytes
      await _playAudioBytes(result.audioBytes!);
      _setState(WordAudioState.playing);
    } catch (e) {
      _lastError = e.toString();
      _setState(WordAudioState.error);
      debugPrint('[WordAudioPlayer] playback error for $vocabId: $e');
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    if (_state == WordAudioState.idle) return;
    // TODO: await _audioPlayer.stop();
    _setState(WordAudioState.idle);
    _currentVocabId = null;
  }

  /// Get IPA for display (e.g., "/kæt/" under the word on flash card)
  String? getIpa(String vocabId) => _tts.getIpa(vocabId);

  /// Get syllable count for display
  int? getSyllableCount(String vocabId) => _tts.getSyllableCount(vocabId);

  /// Clear session cache between sessions
  void clearSessionCache() {
    _sessionCache.clear();
  }

  @override
  void dispose() {
    // TODO: _audioPlayer.dispose();
    super.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setState(WordAudioState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Play raw audio bytes via audioplayers package
  /// STUB: audioplayers ^5.2.1 not yet added to pubspec.yaml
  /// When adding: uncomment + add dependency
  Future<void> _playAudioBytes(Uint8List bytes) async {
    // TODO (next sprint — add audioplayers ^5.2.1):
    //
    // final source = BytesSource(bytes);
    // await _audioPlayer.play(source);
    // await _audioPlayer.onPlayerComplete.first; // wait for completion
    //
    // For now: simulate 300ms playback delay as UX placeholder
    if (kDebugMode) {
      debugPrint('[WordAudioPlayer] STUB: would play ${bytes.length} bytes of audio');
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}

/// Lightweight widget helper — plays word audio automatically when a new
/// vocab ID is presented (e.g., on card flip in BattleScreen).
///
/// Usage:
///   WordAudioAutoPlay(
///     vocabId: card.vocabId,
///     word: card.word,
///     player: _audioPlayer,
///     child: FlashCard(...),
///   )
class WordAudioAutoPlay {
  /// Trigger auto-play for a word (call from BattleScreen._onCardFlipped)
  static void trigger({
    required WordAudioPlayerService player,
    required String vocabId,
    required String word,
    bool autoPlay = true,
  }) {
    if (!autoPlay) return;
    // Fire-and-forget: audio is enhancement, not blocker
    player.playWord(vocabId: vocabId, word: word).catchError((e) {
      debugPrint('[WordAudioAutoPlay] error: $e');
      return; // suppress
    });
  }
}

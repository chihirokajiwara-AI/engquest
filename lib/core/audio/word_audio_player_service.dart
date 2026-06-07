// lib/core/audio/word_audio_player_service.dart
// ENG Quest — Word Audio Player
//
// Plays TTS-generated word audio during Battle flashcard sessions.
// Architecture: TtsService (fetch/cache) → WordAudioPlayerService (play)
//
// Usage (from BattleScreen):
//   final _audioPlayer = WordAudioPlayerService();
//   await _audioPlayer.initialize();
//   // When showing a flashcard:
//   await _audioPlayer.playWord(vocabId: 'eiken5_001', word: 'cat');
//   // Auto-plays on flip, can also be triggered by tap on speaker icon.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_mute.dart';
import 'tts_service.dart';

/// Playback state for word audio
enum WordAudioState { idle, loading, playing, error }

/// WordAudioPlayerService — manages TTS fetch + audio playback for Battle
class WordAudioPlayerService extends ChangeNotifier {
  final TtsService _tts;
  // Lazily created (like SoundService) so constructing the service never touches
  // the audio platform — important when the Voice channel is muted (the player
  // is never built) and for tests.
  final AudioPlayer? _injectedPlayer;
  AudioPlayer? _playerInstance;
  AudioPlayer get _audioPlayer =>
      _playerInstance ??= (_injectedPlayer ?? AudioPlayer());

  WordAudioState _state = WordAudioState.idle;
  String? _currentVocabId;
  String? _lastError;

  // Pre-fetched audio cache for current session (vocabId → result)
  final Map<String, TtsAudioResult> _sessionCache = {};

  WordAudioPlayerService({TtsService? ttsService, AudioPlayer? audioPlayer})
      : _tts = ttsService ?? TtsService(),
        _injectedPlayer = audioPlayer;

  // The Voice-channel mute lives in [AudioMute] (shared with AudioCueService)
  // so one Settings toggle silences every voice/word-audio path.

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
      if (kDebugMode) {
        debugPrint(
            '[WordAudioPlayer] prefetch: ${_sessionCache.length} words ready');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WordAudioPlayer] prefetch error (non-fatal): $e');
      }
    }
  }

  /// Play audio for a vocab word.
  /// 1. Check session cache → immediate play
  /// 2. Fetch from TTS (lazy) → play
  /// 3. On error → set error state, do NOT crash
  Future<void> playWord({required String vocabId, required String word}) async {
    // Voice channel muted in Settings → do not fetch or play anything.
    if (AudioMute.voiceMuted) return;
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
        if (kDebugMode) {
          debugPrint(
              '[WordAudioPlayer] audio unavailable for $vocabId: $_lastError');
        }
        return;
      }

      // Play the audio bytes (sets state to playing, then idle on completion)
      _setState(WordAudioState.playing);
      await _playAudioBytes(result.audioBytes!);
    } catch (e) {
      _lastError = e.toString();
      _setState(WordAudioState.error);
      if (kDebugMode) {
        debugPrint('[WordAudioPlayer] playback error for $vocabId: $e');
      }
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    if (_state == WordAudioState.idle) return;
    await _audioPlayer.stop();
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
    _playerInstance?.dispose(); // only if one was ever created
    super.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _setState(WordAudioState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Play raw MP3 audio bytes via audioplayers
  Future<void> _playAudioBytes(Uint8List bytes) async {
    final source = BytesSource(bytes);
    await _audioPlayer.play(source);
    // Wait for playback to complete before transitioning state
    await _audioPlayer.onPlayerComplete.first;
    if (_state == WordAudioState.playing) {
      _setState(WordAudioState.idle);
      _currentVocabId = null;
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
      if (kDebugMode) debugPrint('[WordAudioAutoPlay] error: $e');
      return; // suppress
    });
  }
}

// lib/features/voice/voice_screen.dart
// ENG Quest — C06 Voice Module: Pronunciation Coach
//
// Game flow:
//   1. Word displayed in large text with illustrative emoji.
//   2. "🎤 Tap to Speak" button → starts 3-second countdown recording.
//   3. Recording ends → Whisper transcription → result feedback:
//        ✅  correct   → card turns green + star burst animation
//        ⚠️  close     → orange + pronunciation hint
//        ❌  incorrect → red   + retry button
//   4. "Next →" advances to the next word.
//   5. After 10 words: session summary with accuracy score.
//
// Demo mode: PlatformVoiceChannel.demoMode = true (default).
//   Recording is simulated with a 3-second Timer; VoiceService.transcribeAudio
//   cycles through a mock word pool, producing a realistic mix of results.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/voice/platform_voice_channel.dart';
import '../../core/voice/voice_service.dart';

// ── Vocabulary word list (10 A1 words for the session) ────────────────────────

class _VoiceWord {
  final String word;
  final String emoji;
  final String phonetic; // rough pronunciation hint shown on "close" result

  const _VoiceWord(this.word, this.emoji, this.phonetic);
}

const List<_VoiceWord> _kWordList = [
  _VoiceWord('cat',    '🐱', '/kæt/'),
  _VoiceWord('dog',    '🐶', '/dɒɡ/'),
  _VoiceWord('apple',  '🍎', '/ˈæp.əl/'),
  _VoiceWord('book',   '📚', '/bʊk/'),
  _VoiceWord('bird',   '🐦', '/bɜːrd/'),
  _VoiceWord('fish',   '🐟', '/fɪʃ/'),
  _VoiceWord('tree',   '🌳', '/triː/'),
  _VoiceWord('milk',   '🥛', '/mɪlk/'),
  _VoiceWord('park',   '🏞️', '/pɑːrk/'),
  _VoiceWord('school', '🏫', '/skuːl/'),
];

// ── Screen state machine ──────────────────────────────────────────────────────

enum _ScreenState {
  idle,        // waiting for tap
  countdown,   // recording in progress, countdown shown
  evaluating,  // waiting for Whisper result
  result,      // result displayed (correct / close / incorrect)
  summary,     // session complete
}

// ── VoiceScreen ───────────────────────────────────────────────────────────────

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with TickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────
  final VoiceService _voice = VoiceService();

  // ── Session state ──────────────────────────────────────────────────────────
  int _wordIndex = 0;                      // current word index (0–9)
  _ScreenState _state = _ScreenState.idle;
  PronunciationResult? _lastResult;

  // Per-word attempt tracking
  final List<VoiceResult> _sessionResults = [];

  // ── Countdown timer ────────────────────────────────────────────────────────
  static const int _recordSeconds = 3;
  int _countdown = _recordSeconds;
  Timer? _countdownTimer;

  // ── Star burst animation ───────────────────────────────────────────────────
  late AnimationController _starCtrl;
  late Animation<double>    _starAnim;

  // ── Mic pulse animation ────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulseAnim;

  // ── Colours ────────────────────────────────────────────────────────────────
  static const _bgColor      = Color(0xFFF5F7FA);
  static const _accentGold   = Color(0xFFFFC107);
  static const _colorCorrect = Color(0xFF66BB6A);   // bright green
  static const _colorClose   = Color(0xFFFF9800);   // amber orange
  static const _colorWrong   = Color(0xFFEF5350);   // bright red
  static const _colorIdle    = Color(0xFFFFFFFF);   // card background

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Ensure demo mode is active (no native plugin wired in Flutter web/tests).
    PlatformVoiceChannel.demoMode = true;

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _starAnim = CurvedAnimation(parent: _starCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _starCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  _VoiceWord get _currentWord => _kWordList[_wordIndex % _kWordList.length];

  bool get _isLastWord => _wordIndex >= _kWordList.length - 1;

  // ── Recording flow ─────────────────────────────────────────────────────────

  void _startRecording() {
    if (_state != _ScreenState.idle) return;
    _beginRecordingCycle();
  }

  void _retryRecording() {
    _beginRecordingCycle();
  }

  void _beginRecordingCycle() {
    setState(() {
      _state     = _ScreenState.countdown;
      _countdown = _recordSeconds;
      _lastResult = null;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _evaluate();
      }
    });
  }

  Future<void> _evaluate() async {
    if (!mounted) return;
    setState(() => _state = _ScreenState.evaluating);

    final result = await _voice.evaluatePronunciation(
      targetWord: _currentWord.word,
      recordingDuration: const Duration(seconds: _recordSeconds),
    );

    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _state      = _ScreenState.result;
    });

    if (result.result == VoiceResult.correct) {
      _starCtrl.forward(from: 0);
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _advance() {
    final r = _lastResult;
    if (r != null) {
      _sessionResults.add(r.result);
    }

    if (_isLastWord || _sessionResults.length >= _kWordList.length) {
      setState(() => _state = _ScreenState.summary);
      return;
    }

    setState(() {
      _wordIndex++;
      _state      = _ScreenState.idle;
      _lastResult = null;
    });
  }

  void _restartSession() {
    setState(() {
      _wordIndex     = 0;
      _state         = _ScreenState.idle;
      _lastResult    = null;
      _sessionResults.clear();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: _state == _ScreenState.summary
          ? _buildSummary()
          : _buildSessionBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text(
        '🗣️ Echo Cave',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        if (_state != _ScreenState.summary)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '${_wordIndex + 1} / ${_kWordList.length}',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ),
      ],
    );
  }

  // ── Session body ───────────────────────────────────────────────────────────

  Widget _buildSessionBody() {
    return Column(
      children: [
        _buildProgressBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildWordCard(),
                const SizedBox(height: 24),
                _buildResultArea(),
                const SizedBox(height: 24),
                _buildActionButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final progress = _kWordList.isEmpty
        ? 0.0
        : _wordIndex / _kWordList.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: const Color(0xFFE0E0E0),
          valueColor: const AlwaysStoppedAnimation<Color>(_accentGold),
        ),
      ),
    );
  }

  // ── Word card ──────────────────────────────────────────────────────────────

  Widget _buildWordCard() {
    Color cardColor = _colorIdle;
    if (_state == _ScreenState.result && _lastResult != null) {
      switch (_lastResult!.result) {
        case VoiceResult.correct:
          cardColor = _colorCorrect;
          break;
        case VoiceResult.close:
          cardColor = _colorClose;
          break;
        default:
          cardColor = _colorWrong;
          break;
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE0E0E0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4FC3F7).withAlpha(40),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Emoji illustration
              Text(
                _currentWord.emoji,
                style: const TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 16),
              // Target word
              Text(
                _currentWord.word.toUpperCase(),
                style: TextStyle(
                  color: cardColor == _colorIdle
                      ? const Color(0xFF263238)
                      : Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              // Phonetic hint (always shown)
              Text(
                _currentWord.phonetic,
                style: TextStyle(
                  color: cardColor == _colorIdle
                      ? const Color(0xFF607D8B)
                      : Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        // Star burst overlay on correct
        if (_state == _ScreenState.result &&
            _lastResult?.result == VoiceResult.correct)
          AnimatedBuilder(
            animation: _starAnim,
            builder: (ctx, _) => _StarBurst(progress: _starAnim.value),
          ),
      ],
    );
  }

  // ── Result area ────────────────────────────────────────────────────────────

  Widget _buildResultArea() {
    switch (_state) {
      case _ScreenState.idle:
        return _buildIdleHint();
      case _ScreenState.countdown:
        return _buildCountdown();
      case _ScreenState.evaluating:
        return _buildEvaluating();
      case _ScreenState.result:
        return _buildResultFeedback();
      case _ScreenState.summary:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIdleHint() {
    return const Text(
      'タップして発音しよう！\nSay the word!',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF607D8B), fontSize: 15, height: 1.6),
    );
  }

  Widget _buildCountdown() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (ctx, child) => Transform.scale(
            scale: _pulseAnim.value,
            child: child,
          ),
          child: const Text('🎤', style: TextStyle(fontSize: 56)),
        ),
        const SizedBox(height: 12),
        Text(
          '$_countdown',
          style: const TextStyle(
            color: _accentGold,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '録音中… Recording…',
          style: TextStyle(color: Color(0xFF607D8B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEvaluating() {
    return const Column(
      children: [
        SizedBox(height: 8),
        CircularProgressIndicator(color: _accentGold),
        SizedBox(height: 16),
        Text(
          '認識中… Analysing…',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildResultFeedback() {
    final res = _lastResult;
    if (res == null) return const SizedBox.shrink();

    switch (res.result) {
      case VoiceResult.correct:
        return _buildCorrectFeedback(res);
      case VoiceResult.close:
        return _buildCloseFeedback(res);
      case VoiceResult.incorrect:
      case VoiceResult.timeout:
      case VoiceResult.error:
        return _buildIncorrectFeedback(res);
    }
  }

  Widget _buildCorrectFeedback(PronunciationResult res) {
    return Column(
      children: [
        const Text('✅', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        const Text(
          'すごい！ Great job!',
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '"${res.transcribed}"',
          style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          '${res.latencyMs} ms',
          style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCloseFeedback(PronunciationResult res) {
    return Column(
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        const Text(
          'もう少し！ Almost there!',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'You said: "${res.transcribed}"',
          style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Correct pronunciation: ${_currentWord.phonetic}',
          style: const TextStyle(color: Color(0xFF607D8B), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildIncorrectFeedback(PronunciationResult res) {
    final heard = res.transcribed.isEmpty ? '(silence)' : '"${res.transcribed}"';
    return Column(
      children: [
        const Text('❌', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        const Text(
          'もう一度！ Try again!',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Heard: $heard',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Target: ${_currentWord.phonetic}',
          style: const TextStyle(color: Color(0xFF607D8B), fontSize: 13),
        ),
        const SizedBox(height: 16),
        // Retry button (only for incorrect/error)
        ElevatedButton.icon(
          onPressed: _retryRecording,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('もう一度 / Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF5350).withAlpha(180),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
        ),
      ],
    );
  }

  // ── Action button (mic / next) ─────────────────────────────────────────────

  Widget _buildActionButton() {
    switch (_state) {
      case _ScreenState.idle:
        return _buildMicButton();
      case _ScreenState.countdown:
      case _ScreenState.evaluating:
        return const SizedBox.shrink(); // no button while recording/analysing
      case _ScreenState.result:
        // Show "Next" (skip retry in incorrect — retry button is above)
        if (_lastResult?.result == VoiceResult.incorrect ||
            _lastResult?.result == VoiceResult.error) {
          // Show a "skip" button below the retry button
          return TextButton(
            onPressed: _advance,
            child: const Text(
              'スキップ / Skip →',
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            ),
          );
        }
        return _buildNextButton();
      case _ScreenState.summary:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (ctx, child) => Transform.scale(
        scale: _state == _ScreenState.idle ? 1.0 : _pulseAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTap: _startRecording,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF3D1A8C)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withAlpha(120),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎤', style: TextStyle(fontSize: 40)),
              SizedBox(height: 4),
              Text(
                'Tap to\nSpeak',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _isLastWord;
    return ElevatedButton(
      onPressed: _advance,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentGold,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(isLast ? '結果を見る / Results 🏆' : '次の単語 / Next →'),
    );
  }

  // ── Session summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final total   = _sessionResults.length;
    final correct = _sessionResults.where((r) => r == VoiceResult.correct).length;
    final close   = _sessionResults.where((r) => r == VoiceResult.close).length;
    final wrong   = total - correct - close;
    final accuracy = total == 0 ? 0.0 : (correct + close * 0.5) / total;

    String grade;
    String gradeEmoji;
    if (accuracy >= 0.9) {
      grade = 'Excellent!';
      gradeEmoji = '🌟';
    } else if (accuracy >= 0.7) {
      grade = 'Great!';
      gradeEmoji = '⭐';
    } else if (accuracy >= 0.5) {
      grade = 'Good try!';
      gradeEmoji = '👍';
    } else {
      grade = 'Keep practising!';
      gradeEmoji = '💪';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(gradeEmoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              grade,
              style: const TextStyle(
                color: _accentGold,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Accuracy ring
            _AccuracyRing(accuracy: accuracy),
            const SizedBox(height: 24),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(label: 'Correct',   value: '$correct', color: const Color(0xFF66BB6A)),
                _StatChip(label: 'Close',     value: '$close',   color: const Color(0xFFFF9800)),
                _StatChip(label: 'Incorrect', value: '$wrong',   color: const Color(0xFFEF5350)),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _restartSession,
              icon: const Icon(Icons.replay),
              label: const Text('もう一度 / Play again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text(
                '← ワールドマップに戻る / Back to Map',
                style: TextStyle(color: Color(0xFF607D8B), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Star burst widget ─────────────────────────────────────────────────────────

class _StarBurst extends StatelessWidget {
  final double progress; // 0.0 → 1.0

  const _StarBurst({required this.progress});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size(260, 260),
        painter: _StarBurstPainter(progress: progress),
      ),
    );
  }
}

class _StarBurstPainter extends CustomPainter {
  final double progress;
  _StarBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Colors.yellow.withAlpha((opacity * 200).round())
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final r = maxRadius * progress;
      final dx = centre.dx + r * math.cos(angle);
      final dy = centre.dy + r * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 10 * (1 - progress) + 3, paint);
    }
  }

  @override
  bool shouldRepaint(_StarBurstPainter old) => old.progress != progress;
}

// ── Accuracy ring widget ──────────────────────────────────────────────────────

class _AccuracyRing extends StatelessWidget {
  final double accuracy; // 0.0 – 1.0

  const _AccuracyRing({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final pct = (accuracy * 100).round();
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: accuracy,
            strokeWidth: 12,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(
              accuracy >= 0.7
                  ? const Color(0xFF66BB6A)
                  : accuracy >= 0.5
                      ? const Color(0xFFFF9800)
                      : const Color(0xFFEF5350),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'accuracy',
                style: TextStyle(color: Color(0xFF607D8B), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat chip widget ──────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF607D8B), fontSize: 12),
        ),
      ],
    );
  }
}

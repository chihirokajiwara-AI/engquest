// lib/features/voice/voice_screen.dart
// ENG Quest — C06 Voice Module: Pronunciation Coach (発音 / Pronounce)
//
// Game flow:
//   1. Word displayed in a DQ command-window panel with illustrative emoji.
//   2. "発音する / Speak" record control → starts 3-second countdown recording.
//   3. Recording ends → Whisper transcription → result feedback:
//        ✅  correct   → gold "すごい！" + gold star burst animation
//        ⚠️  close     → "もう少し！" + pronunciation hint
//        ❌  incorrect → "もう一度！" + retry control
//   4. "次の単語 / Next" advances to the next word.
//   5. After 10 words: session summary with accuracy ring.
//
// Demo mode: PlatformVoiceChannel.demoMode = true (default).
//   Recording is simulated with a 3-second Timer; VoiceService.transcribeAudio
//   cycles through a mock word pool, producing a realistic mix of results.
//
// 本格 Dragon-Quest HD-2D styling via lib/features/quest/ui/dq_ui.dart:
//   dark atmospheric DqScene root, navy+cream DqPanel / DqDialogBox, gold
//   DqButton record control, serif bilingual labels. No bright pastel.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/voice/platform_voice_channel.dart';
import '../../core/voice/voice_service.dart';
import '../quest/ui/dq_ui.dart';

// ── Vocabulary word list (10 A1 words for the session) ────────────────────────

class _VoiceWord {
  final String word;
  final String emoji;
  final String phonetic; // rough pronunciation hint shown on "close" result

  const _VoiceWord(this.word, this.emoji, this.phonetic);
}

const List<_VoiceWord> _kWordList = [
  _VoiceWord('cat', '🐱', '/kæt/'),
  _VoiceWord('dog', '🐶', '/dɒɡ/'),
  _VoiceWord('apple', '🍎', '/ˈæp.əl/'),
  _VoiceWord('book', '📚', '/bʊk/'),
  _VoiceWord('bird', '🐦', '/bɜːrd/'),
  _VoiceWord('fish', '🐟', '/fɪʃ/'),
  _VoiceWord('tree', '🌳', '/triː/'),
  _VoiceWord('milk', '🥛', '/mɪlk/'),
  _VoiceWord('park', '🏞️', '/pɑːrk/'),
  _VoiceWord('school', '🏫', '/skuːl/'),
];

// ── Screen state machine ──────────────────────────────────────────────────────

enum _ScreenState {
  idle, // waiting for tap
  countdown, // recording in progress, countdown shown
  evaluating, // waiting for Whisper result
  result, // result displayed (correct / close / incorrect)
  summary, // session complete
}

// ── DQ result accents (frame/ink only — kept within the dark palette) ─────────
const _dqCorrect = Color(0xFF8BE08B);
const _dqClose = dqGold;
const _dqWrong = Color(0xFFE89090);

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
  int _wordIndex = 0; // current word index (0–9)
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
  late Animation<double> _starAnim;

  // ── Mic pulse animation ────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

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
      _state = _ScreenState.countdown;
      _countdown = _recordSeconds;
      _lastResult = null;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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
      _state = _ScreenState.result;
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
      _state = _ScreenState.idle;
      _lastResult = null;
    });
  }

  void _restartSession() {
    setState(() {
      _wordIndex = 0;
      _state = _ScreenState.idle;
      _lastResult = null;
      _sessionResults.clear();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _state == _ScreenState.summary
                ? _buildSummary()
                : _buildSessionBody(),
          ),
        ],
      ),
    );
  }

  // ── Dark header (back arrow + gold serif title + progress count) ────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'もどる / Back',
            icon: const Icon(Icons.arrow_back, color: dqInk),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: dqBilingual('発音', 'Pronounce', jpSize: 20, stacked: true),
          ),
          if (_state != _ScreenState.summary)
            Text(
              '${_wordIndex + 1} / ${_kWordList.length}',
              style: dqText(size: 14, color: dqGold, spacing: 1),
            ),
        ],
      ),
    );
  }

  // ── Session body ───────────────────────────────────────────────────────────

  Widget _buildSessionBody() {
    return Column(
      children: [
        _buildProgressBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildWordCard(),
                const SizedBox(height: 22),
                _buildResultArea(),
                const SizedBox(height: 22),
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
    final progress = _kWordList.isEmpty ? 0.0 : _wordIndex / _kWordList.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: dqNight1,
          valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
        ),
      ),
    );
  }

  // ── Word card (DQ command window) ──────────────────────────────────────────

  Widget _buildWordCard() {
    // Result-state accent tints the cream frame only — fill stays dark navy.
    Color frame = dqBorder;
    if (_state == _ScreenState.result && _lastResult != null) {
      switch (_lastResult!.result) {
        case VoiceResult.correct:
          frame = _dqCorrect;
          break;
        case VoiceResult.close:
          frame = _dqClose;
          break;
        default:
          frame = _dqWrong;
          break;
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: dqBox.withAlpha(235),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: frame, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            children: [
              // Emoji illustration
              Text(
                _currentWord.emoji,
                style: const TextStyle(fontSize: 68),
              ),
              const SizedBox(height: 14),
              // Target word
              Text(
                _currentWord.word.toUpperCase(),
                style: dqText(
                  size: 48,
                  w: FontWeight.w800,
                  color: dqInk,
                  spacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              // Phonetic hint (always shown)
              Text(
                _currentWord.phonetic,
                style: dqText(size: 16, color: dqGold, spacing: 1),
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
    return DqDialogBox(
      child: Text(
        'タップして発音しよう！\nTap the button and say the word aloud.',
        textAlign: TextAlign.center,
        style: dqText(size: 15, color: dqInk),
      ),
    );
  }

  Widget _buildCountdown() {
    return DqPanel(
      child: Center(
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (ctx, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
              child: const Icon(Icons.mic, color: dqGold, size: 52),
            ),
            const SizedBox(height: 12),
            Text(
              '$_countdown',
              style: dqText(size: 48, w: FontWeight.w800, color: dqGold),
            ),
            const SizedBox(height: 4),
            dqBilingual('録音中…', 'Recording…',
                jpSize: 14, align: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluating() {
    return DqPanel(
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 4),
            const CircularProgressIndicator(color: dqGold),
            const SizedBox(height: 16),
            dqBilingual('認識中…', 'Analysing…',
                jpSize: 14, align: TextAlign.center),
          ],
        ),
      ),
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
    return DqPanel(
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: _dqCorrect, size: 40),
            const SizedBox(height: 8),
            dqBilingual('すごい！', 'Perfect!',
                jpSize: 22, jpColor: _dqCorrect, align: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '"${res.transcribed}"',
              style: dqText(size: 14, color: dqInk),
            ),
            const SizedBox(height: 2),
            Text(
              '${res.latencyMs} ms',
              style: dqText(size: 11, color: dqGoldDeep),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseFeedback(PronunciationResult res) {
    return DqPanel(
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: _dqClose, size: 40),
            const SizedBox(height: 8),
            dqBilingual('もう少し！', 'Almost there!',
                jpSize: 20, jpColor: _dqClose, align: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'You said: "${res.transcribed}"',
              textAlign: TextAlign.center,
              style: dqText(size: 14, color: dqInk),
            ),
            const SizedBox(height: 4),
            Text(
              'Correct pronunciation: ${_currentWord.phonetic}',
              textAlign: TextAlign.center,
              style: dqText(size: 13, color: dqGold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncorrectFeedback(PronunciationResult res) {
    final heard =
        res.transcribed.isEmpty ? '(silence)' : '"${res.transcribed}"';
    return DqPanel(
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cancel_outlined, color: _dqWrong, size: 40),
            const SizedBox(height: 8),
            dqBilingual('もう一度！', 'Try again!',
                jpSize: 20, jpColor: _dqWrong, align: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Heard: $heard',
              textAlign: TextAlign.center,
              style: dqText(size: 13, color: dqInk),
            ),
            const SizedBox(height: 4),
            Text(
              'Target: ${_currentWord.phonetic}',
              textAlign: TextAlign.center,
              style: dqText(size: 13, color: dqGold),
            ),
            const SizedBox(height: 16),
            // Retry button (only for incorrect/error)
            DqButton(
              label: 'もう一度 / Retry',
              onTap: _retryRecording,
            ),
          ],
        ),
      ),
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
          // Show a "skip" control below the retry button
          return TextButton(
            onPressed: _advance,
            child: Text(
              'スキップ / Skip →',
              style: dqText(size: 13, color: dqGoldDeep),
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
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [dqNight1, dqNight0],
            ),
            border: Border.all(color: dqGold, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: dqGold.withAlpha(90),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic, color: dqGold, size: 42),
              const SizedBox(height: 4),
              Text(
                '発音する\nSpeak',
                textAlign: TextAlign.center,
                style: dqText(size: 13, w: FontWeight.w700, color: dqInk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _isLastWord;
    return DqButton(
      label: isLast ? '結果を見る / Results' : '次の単語 / Next',
      onTap: _advance,
    );
  }

  // ── Session summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final total = _sessionResults.length;
    final correct =
        _sessionResults.where((r) => r == VoiceResult.correct).length;
    final close = _sessionResults.where((r) => r == VoiceResult.close).length;
    final wrong = total - correct - close;
    final accuracy = total == 0 ? 0.0 : (correct + close * 0.5) / total;

    String gradeJp;
    String gradeEn;
    if (accuracy >= 0.9) {
      gradeJp = 'おみごと！';
      gradeEn = 'Excellent!';
    } else if (accuracy >= 0.7) {
      gradeJp = 'すばらしい！';
      gradeEn = 'Great!';
    } else if (accuracy >= 0.5) {
      gradeJp = 'よくやった！';
      gradeEn = 'Good try!';
    } else {
      gradeJp = 'れんしゅうしよう！';
      gradeEn = 'Keep practising!';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DqPanel(
              title: 'けっか / Result',
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    dqBilingual(gradeJp, gradeEn,
                        jpSize: 26, jpColor: dqGold, align: TextAlign.center),
                    const SizedBox(height: 22),
                    // Accuracy ring
                    _AccuracyRing(accuracy: accuracy),
                    const SizedBox(height: 24),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatChip(
                            label: 'Correct',
                            value: '$correct',
                            color: _dqCorrect),
                        _StatChip(
                            label: 'Close', value: '$close', color: _dqClose),
                        _StatChip(
                            label: 'Incorrect',
                            value: '$wrong',
                            color: _dqWrong),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            DqButton(
              label: 'もう一度 / Play again',
              onTap: _restartSession,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: Text(
                '← はじまりの村にもどる / Back to Village',
                style: dqText(size: 13, color: dqGoldDeep),
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
      ..color = dqGold.withAlpha((opacity * 220).round())
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
            backgroundColor: dqNight1,
            valueColor: AlwaysStoppedAnimation<Color>(
              accuracy >= 0.7
                  ? _dqCorrect
                  : accuracy >= 0.5
                      ? _dqClose
                      : _dqWrong,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: dqText(size: 32, w: FontWeight.w800, color: dqInk),
              ),
              Text(
                'accuracy',
                style: dqText(size: 12, color: dqGold, spacing: 1),
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
  final Color color;

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
          style: dqText(size: 28, w: FontWeight.w800, color: color),
        ),
        Text(
          label,
          style: dqText(size: 12, color: dqInk),
        ),
      ],
    );
  }
}

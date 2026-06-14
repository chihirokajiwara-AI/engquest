// lib/features/speaking/speaking_screen.dart
// A-KEN Quest — 英検 二次 Speaking Practice Screen
//
// DQ-style 二次試験 simulator: shows the passage/question, a 🎤 record button
// that uses the EXISTING VoiceService / speech_to_text infrastructure, then
// renders formative feedback via PronunciationScorer.
//
// SCAFFOLD STATUS:
//   Capture:  SpeechRecognitionService (speech_to_text package, T02 existing infra)
//             in demo mode when the platform does not grant mic access.
//   Scoring:  StubPronunciationScorer (pure-Dart, no network).
//             TODO: swap in AzurePronunciationScorer once /v1/pronounce is wired.
//
// R4 COMPLIANCE:
//   - No Firebase / network calls in build() or initState().
//   - VoiceService + SpeakingSession are instantiated lazily / in the State
//     constructor; no heavy work fires before the first frame.
//   - SpeechRecognitionService.initialize() is called only on the FIRST tap
//     of the record button (gesture-gated, safe for web autoplay policy).
//
// R3: smoke test in test/features/speaking/speaking_smoke_test.dart.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/voice/speech_recognition_service.dart';
import '../../core/voice/voice_service.dart';
import '../quest/ui/dq_ui.dart';
import '../exam_practice/eiken_exam_config.dart';
import 'pronunciation_scorer.dart';
import 'speaking_session.dart';

// ── Child-facing practice-guide copy (NO engineering jargon) ────────────────────
//
// Shown with the formative score in the result state. Honest framing: this
// score is a practice guide, and the real 二次 (interview) is human-scored —
// without exposing internal implementation details. Kept as named constants so
// a CI test can assert the copy stays jargon-free + honest. Furigana is applied
// consistently to every non-trivial 漢字 for young (6+) readers.
const String kSpeakingPracticeNoteJa = 'このスコアは れんしゅうの めやすだよ。本番（ほんばん）の 二次（にじ）'
    'しけんでは、しけんかんの 先生（せんせい）が きみの 話（はな）す えいごを '
    '聞（き）いて さいてんします。たくさん 声（こえ）に出（だ）して れんしゅうしよう！';
const String kSpeakingPracticeNoteEn =
    'This score is a practice guide — in the real interview a teacher listens '
    'and scores your speaking. Keep practising out loud!';

// ── Screen state ──────────────────────────────────────────────────────────────

enum _ScreenState {
  prep, // showing prep time countdown (for steps that have prepSeconds > 0)
  idle, // waiting for user to tap the record button
  recording, // VoiceService is listening
  evaluating, // waiting for SpeechRecognitionService result
  result, // showing formative feedback
  complete, // all steps done — session summary
}

// ── Colours (reuse dq_ui palette; avoid new constants) ────────────────────────
const _colGood = Color(0xFF8BE08B);
const _colCoach = Color(0xFFF0D080); // dqGold
const _colSilence = Color(0xFFE89090);

// ── SpeakingScreen ────────────────────────────────────────────────────────────

class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({
    super.key,
    required this.eikenGrade,
    this.scorer = const StubPronunciationScorer(),
  });

  /// The 英検 grade being practiced (e.g. '3', 'pre2', '2', 'pre1').
  final String eikenGrade;

  /// Pluggable scorer — defaults to the stub; inject AzurePronunciationScorer
  /// once the /v1/pronounce endpoint is available.
  final PronunciationScorer scorer;

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen>
    with TickerProviderStateMixin {
  // ── Session model ──────────────────────────────────────────────────────────
  late final SpeakingSession _session;

  // ── Voice infra (existing, T02) ────────────────────────────────────────────
  // We keep SpeechRecognitionService separately so we can call initialize()
  // lazily on the first gesture (web autoplay / mic permission safety).
  final SpeechRecognitionService _srs = SpeechRecognitionService();
  late final VoiceService _voice;
  bool _voiceInitialized = false;

  // ── Screen state ───────────────────────────────────────────────────────────
  _ScreenState _state = _ScreenState.idle;
  SpeakingScore? _lastScore;
  // True when this device has NO real speech recognition (#124): we then show an
  // HONEST shadowing-practice result with NO score, instead of fabricating a
  // pronunciation score from a mock word the child never said.
  bool _demoPractice = false;
  String _transcript = '';

  // ── Prep countdown ─────────────────────────────────────────────────────────
  int _prepRemaining = 0;
  Timer? _prepTimer;

  // ── Pulse animation (mic) ──────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Recording timer ────────────────────────────────────────────────────────
  static const int _maxRecordSeconds = 60; // generous window for narration
  int _recordElapsed = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _session = SpeakingSession(eikenGrade: widget.eikenGrade);
    // VoiceService: inject the SRS instance; falls back to demo if unavailable.
    _voice = VoiceService(speechRecognition: _srs);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Start prep timer if the first step has prep time.
    _maybeStartPrep();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect OS reduce-motion: stop the repeating mic pulse (continuous motion
    // is worst for vestibular/seizure sensitivity). The mic still records — it
    // simply sits steady instead of pulsing. (#76)
    if (prefersReducedMotion(context) && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.5; // settle at the neutral (scale ≈1.0) state
    }
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _recordTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Step helpers ───────────────────────────────────────────────────────────

  SpeakingStep get _current => _session.currentStep;

  // ── Prep countdown ─────────────────────────────────────────────────────────

  void _maybeStartPrep() {
    if (_session.isComplete) return;
    final secs = _current.prepSeconds;
    if (secs > 0) {
      setState(() {
        _state = _ScreenState.prep;
        _prepRemaining = secs;
      });
      _prepTimer?.cancel();
      _prepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _prepRemaining--);
        if (_prepRemaining <= 0) {
          t.cancel();
          setState(() => _state = _ScreenState.idle);
        }
      });
    }
  }

  // ── Voice initialisation (gesture-gated) ───────────────────────────────────

  Future<void> _ensureVoiceInit() async {
    if (_voiceInitialized) return;
    await _srs.initialize();
    _voiceInitialized = true;
  }

  // ── Recording flow ─────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_state != _ScreenState.idle) return;

    // Initialise mic permission on first tap (R4: gesture-gated).
    await _ensureVoiceInit();

    setState(() {
      _state = _ScreenState.recording;
      _recordElapsed = 0;
      _transcript = '';
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _recordElapsed++);
    });

    // Use VoiceService for capture; it delegates to SRS if available,
    // else demo mode (mock transcript).
    final duration = Duration(seconds: _maxRecordSeconds);
    final result = await _voice.evaluatePronunciation(
      targetWord: _current.referenceText,
      recordingDuration: duration,
    );

    _recordTimer?.cancel();
    if (!mounted) return;

    _transcript = result.transcribed;
    setState(() => _state = _ScreenState.evaluating);
    await _evaluate();
  }

  Future<void> _stopRecordingEarly() async {
    // User taps the mic button again to stop early.
    await _voice.stopListening();
    // The evaluatePronunciation future will resolve with whatever was heard.
    // We just update the UI to "evaluating" state.
    _recordTimer?.cancel();
    if (!mounted) return;
    setState(() => _state = _ScreenState.evaluating);
  }

  Future<void> _evaluate() async {
    // HONESTY (#124): with no real speech recognition we cannot judge the child's
    // pronunciation — so we DON'T. Show an honest shadowing-practice result (no
    // score) rather than scoring a mock word the child never said.
    if (_voice.isDemoMode) {
      if (!mounted) return;
      setState(() {
        _transcript = ''; // never surface a mock word as "what you said"
        _lastScore = null;
        _demoPractice = true;
        _state = _ScreenState.result;
      });
      return;
    }

    final scored = widget.scorer.score(
      referenceText: _current.referenceText,
      transcript: _transcript,
      eikenGrade: widget.eikenGrade,
    );

    if (!mounted) return;
    setState(() {
      _lastScore = scored;
      _demoPractice = false;
      _state = _ScreenState.result;
    });

    if (kDebugMode) {
      debugPrint(
        '[SpeakingScreen] step=${_current.label} '
        'transcript="$_transcript" score=${scored.score}',
      );
    }
  }

  // ── Advance / complete ─────────────────────────────────────────────────────

  void _advance() {
    _session.advance(transcript: _transcript);

    if (_session.isComplete) {
      setState(() => _state = _ScreenState.complete);
      return;
    }

    setState(() {
      _state = _ScreenState.idle;
      _lastScore = null;
      _demoPractice = false;
      _transcript = '';
    });
    _maybeStartPrep();
  }

  void _restart() {
    _session.restart();
    setState(() {
      _state = _ScreenState.idle;
      _lastScore = null;
      _demoPractice = false;
      _transcript = '';
    });
    _maybeStartPrep();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DqScene(
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: Column(
        children: [
          _buildHeader(context),
          _buildProgressBar(),
          Expanded(
            child: _state == _ScreenState.complete
                ? _buildSummary(context)
                : _buildSessionBody(),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    // Canonical label (the old map was missing pre2plus, which has a 二次).
    final gradeLabel = gradeLabelJa(widget.eikenGrade);

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
            child: dqBilingual(
              '$gradeLabel 二次練習',
              'Speaking Practice',
              jpSize: 17,
              stacked: true,
            ),
          ),
          if (!_session.isComplete)
            Text(
              '${_session.currentIndex + 1} / ${_session.totalSteps}',
              style: dqText(size: 13, color: dqGold, spacing: 1),
            ),
        ],
      ),
    );
  }

  // ── Progress bar ────────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final progress = _session.totalSteps == 0
        ? 0.0
        : _session.currentIndex / _session.totalSteps;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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

  // ── Session body ────────────────────────────────────────────────────────────

  Widget _buildSessionBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepLabel(),
          const SizedBox(height: 12),
          _buildContentPanel(),
          const SizedBox(height: 16),
          if (_session.attitudeCoachMessage != null) _buildAttitudeCoach(),
          if (_state == _ScreenState.prep) _buildPrepCountdown(),
          if (_state == _ScreenState.idle) _buildIdleArea(),
          if (_state == _ScreenState.recording) _buildRecordingArea(),
          if (_state == _ScreenState.evaluating) _buildEvaluatingArea(),
          if (_state == _ScreenState.result) _buildResultArea(),
          // Honest practice-guide note, shown only WITH a score (result state),
          // so the child sees it in context and is never shown internal
          // engineering details (no "Azure", "/v1/...", "開発中").
          // The "this score is a practice guide" note belongs only WITH a score;
          // the demo no-score result carries its own honest copy (#124).
          if (_state == _ScreenState.result && !_demoPractice) ...[
            const SizedBox(height: 10),
            _buildPracticeNote(),
          ],
        ],
      ),
    );
  }

  // ── Step label ──────────────────────────────────────────────────────────────

  Widget _buildStepLabel() {
    final typeLabel = {
          SpeakingStepType.ondo: '音読 / Read Aloud',
          SpeakingStepType.passageQuestion: '質問 / Passage Question',
          SpeakingStepType.illustrationNarration: 'イラスト / Illustration',
          SpeakingStepType.opinionQuestion: '意見 / Opinion',
          SpeakingStepType.freeConversation: '自由会話 / Free Talk',
        }[_current.type] ??
        '';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _current.label,
            style: const TextStyle(
              color: Color(0xFF2A1C00),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(typeLabel, style: dqText(size: 13, color: dqGoldDeep)),
        ),
      ],
    );
  }

  // ── Content panel (passage / question / illustration) ───────────────────────

  Widget _buildContentPanel() {
    return DqDialogBox(
      speaker: '試験官 / Examiner',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _current.referenceText,
            style: dqText(size: 15, color: dqInk),
          ),
          if (_current.illustrationPlaceholder != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dqNight1.withAlpha(200),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dqBorder, width: 1),
              ),
              child: Text(
                _current.illustrationPlaceholder!,
                style: dqText(
                  size: 13,
                  color: dqGold,
                  spacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Attitude coach ──────────────────────────────────────────────────────────

  Widget _buildAttitudeCoach() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DqPanel(
        child: Row(
          children: [
            const Text('💬', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _session.attitudeCoachMessage!,
                style: dqText(size: 14, color: _colCoach),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Prep countdown ──────────────────────────────────────────────────────────

  Widget _buildPrepCountdown() {
    return DqPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: dqGold, size: 28),
          const SizedBox(width: 10),
          Text(
            '準備: $_prepRemaining 秒',
            style: dqText(size: 18, w: FontWeight.w800, color: dqGold),
          ),
        ],
      ),
    );
  }

  // ── Idle area ────────────────────────────────────────────────────────────────

  Widget _buildIdleArea() {
    return Column(
      children: [
        DqDialogBox(
          child: Text(
            _current.type == SpeakingStepType.ondo
                ? 'パッセージを声に出して読んでみよう！\nRead the passage aloud.'
                : 'マイクボタンをタップして答えてみよう！\nTap the mic and give your answer.',
            textAlign: TextAlign.center,
            style: dqText(size: 14, color: dqInk),
          ),
        ),
        const SizedBox(height: 20),
        _buildMicButton(),
      ],
    );
  }

  // ── Mic button ───────────────────────────────────────────────────────────────

  Widget _buildMicButton() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (ctx, child) => Transform.scale(
          scale: _state == _ScreenState.recording ? _pulseAnim.value : 1.0,
          child: child,
        ),
        child: GestureDetector(
          onTap: _state == _ScreenState.idle ? _startRecording : null,
          child: Container(
            width: 120,
            height: 120,
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
                const Icon(Icons.mic, color: dqGold, size: 40),
                const SizedBox(height: 4),
                Text(
                  '話す\nSpeak',
                  textAlign: TextAlign.center,
                  style: dqText(
                    size: 13,
                    w: FontWeight.w700,
                    color: dqInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Recording area ──────────────────────────────────────────────────────────

  Widget _buildRecordingArea() {
    return Column(
      children: [
        DqPanel(
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (ctx, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: child,
                ),
                child: const Icon(Icons.mic, color: dqGold, size: 48),
              ),
              const SizedBox(height: 8),
              dqBilingual(
                '録音中...',
                'Recording…',
                jpSize: 16,
                align: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$_recordElapsed 秒',
                style: dqText(size: 14, color: dqGold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Allow early stop
        DqButton(
          label: '話し終わった / Done Speaking',
          onTap: _stopRecordingEarly,
        ),
      ],
    );
  }

  // ── Evaluating area ─────────────────────────────────────────────────────────

  Widget _buildEvaluatingArea() {
    return DqPanel(
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: dqGold),
            const SizedBox(height: 14),
            dqBilingual(
              '採点中...',
              'Scoring…',
              jpSize: 15,
              align: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Result area ─────────────────────────────────────────────────────────────

  Widget _buildResultArea() {
    if (_demoPractice) return _buildDemoPracticeResult();
    final s = _lastScore;
    if (s == null) return const SizedBox.shrink();

    final isGood = s.score >= 0.6;
    final accent = s.showAttitudeCoach
        ? _colSilence
        : isGood
            ? _colGood
            : _colCoach;

    return Column(
      children: [
        // Feedback panel
        DqPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    s.showAttitudeCoach
                        ? Icons.tips_and_updates_outlined
                        : isGood
                            ? Icons.check_circle_outline
                            : Icons.lightbulb_outline,
                    color: accent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.feedbackJa,
                      style: dqText(size: 16, color: accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.feedbackEn,
                style: dqText(size: 12, color: dqGoldDeep, spacing: 0.3),
              ),
              if (_transcript.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'あなたが言ったこと:',
                  style: dqText(size: 11, color: dqGold, spacing: 0.5),
                ),
                Text(
                  '"$_transcript"',
                  style: dqText(size: 13, color: dqInk),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Next / finish button
        DqButton(
          label: _session.currentIndex >= _session.totalSteps - 1
              ? 'けっかを見る / See Results'
              : '次へ / Next Question',
          onTap: _advance,
        ),
      ],
    );
  }

  /// Honest result when there is NO real speech recognition (#124): NO score,
  /// no fake praise — just acknowledge the child spoke and steer them to
  /// shadow the model aloud. The real 二次 is human-scored.
  Widget _buildDemoPracticeResult() {
    return Column(
      children: [
        DqPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.record_voice_over_outlined,
                      color: dqGold, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'こえに だして いえたかな？',
                      style: dqText(size: 16, color: dqGold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'この きしゅ（たんまつ）では はつおんの 点数（てんすう）は つけられません。'
                'おてほんを もういちど きいて、こえに だして まねしてみよう。',
                style: dqText(size: 13, color: dqInk).copyWith(height: 1.6),
              ),
              const SizedBox(height: 6),
              Text(
                '本番（ほんばん）の二次（にじ）は、先生（せんせい）が じっさいに きいて 採点（さいてん）します。',
                style: dqText(size: 11, color: dqGoldDeep, spacing: 0.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DqButton(
          label: _session.currentIndex >= _session.totalSteps - 1
              ? 'れんしゅう おわり / Done'
              : '次へ / Next',
          onTap: _advance,
        ),
      ],
    );
  }

  // ── Practice-guide note (child-facing, honest, no engineering jargon) ───────
  //
  // Replaces the old "[Dev] … Azure … /v1/pronounce" banner that was shown to
  // children. It stays HONEST — the score here is a practice guide, and the real
  // 二次 (interview) is scored by a human examiner — without exposing internal
  // implementation details. (How the real Azure scorer wires in is documented
  // in pronunciation_scorer.dart, not on a child's screen.)
  Widget _buildPracticeNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dqNight1.withAlpha(160),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGoldDeep.withAlpha(90), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: dqGold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$kSpeakingPracticeNoteJa\n$kSpeakingPracticeNoteEn',
              style: dqText(size: 11, color: dqInk, spacing: 0.2)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Session summary ─────────────────────────────────────────────────────────

  Widget _buildSummary(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DqPanel(
              title: 'けっか / Session Complete',
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    dqBilingual(
                      'お疲れさまでした！',
                      'Well done!',
                      jpSize: 24,
                      jpColor: dqGold,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '全 ${_session.totalSteps} 問を練習しました。\n'
                      'You practised all ${_session.totalSteps} steps.',
                      textAlign: TextAlign.center,
                      style: dqText(size: 15, color: dqInk),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'アティチュード（態度点）: 何か言おうとするだけで点数がもらえます！\n'
                      'Attitude points: just attempting any answer earns marks!',
                      textAlign: TextAlign.center,
                      style: dqText(size: 13, color: dqGoldDeep, spacing: 0.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            DqButton(label: 'もう一度 / Practice Again', onTap: _restart),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: Text(
                '← もどる / Back',
                style: dqText(size: 13, color: dqGoldDeep),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

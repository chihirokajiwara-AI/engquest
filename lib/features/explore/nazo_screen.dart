// lib/features/explore/nazo_screen.dart
// Wave 1 — ナゾ screen: presents a QuestStep as a Layton-style ナゾ puzzle.
//
// REUSES quest_screen's _quizPrompt/_options rendering via the shared widgets
// in dq_ui.dart (DqPortrait, DqDialogBox, AudioOptionButton, DqChoiceState).
// Does NOT duplicate quiz rendering logic.
//
// Added envelope:
//   • Optional [framingJa] line above the stem (in-world flavour, exam unchanged).
//   • ミノス decay display (MinosController) — wrong tap decays, no fail.
//   • 3-tier ひらめきコイン hint ladder (HintCoinService + NazoHint) — teaches,
//     never reveals the answer.
//   • On correct: reports [NazoResult] with earned ミノス + solved flag back
//     to the caller (SceneView cross-fades grey→color).
//
// NO dart:io. Firebase is never touched here.

import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/audio_assets.dart';
import '../../core/audio/audio_cue_service.dart';
import '../../core/audio/audio_mute.dart';
import '../../core/gamification/hint_coin_service.dart';
import '../../core/gamification/minos_controller.dart';
import '../../core/sound/sound_service.dart';
import '../exam_practice/eiken_exam_config.dart' show gradeLabelJa;
import '../quest/quest_data.dart';
import '../quest/quest_screen.dart' show QuestScreen;
import '../quest/ui/dq_ui.dart';
import '../quest/ui/muted_voice_banner.dart';
import 'hotspot.dart';

// ── Result returned to the caller on dismiss ─────────────────────────────────

class NazoResult {
  final bool solved;
  final int minosEarned;

  /// Whether the learner's FIRST answer was correct. Feeds 合格率 honestly: a
  /// ナゾ can be retried until solved, so [solved] alone would record every
  /// puzzle as 100% and inflate the pass meter — first-try correctness is the
  /// real comprehension signal. Defaults to false (e.g. an abandoned puzzle).
  final bool firstTryCorrect;

  /// Highest hint tier the learner unlocked in this ナゾ. Hint reveals are PAID
  /// (coins spent durably) but were in-memory only, so closing an unsolved puzzle
  /// and reopening it relocked the paid hint and demanded payment again. The
  /// caller (scene_view) carries this back so a reopened ナゾ restores what was
  /// already bought.
  final int hintsShown;

  /// English strings the learner produced correctly on the FIRST tap during the
  /// cued-production recall phase. Populated from [_NazoScreenState._knewCues]
  /// (only first-tap correct cues are counted). Defaults to {} so existing callers
  /// that do not consume this field compile unchanged. FSRS wiring is out-of-scope
  /// for this change — the data is available for future integration.
  final Set<String> knewWords;

  const NazoResult({
    required this.solved,
    required this.minosEarned,
    this.firstTryCorrect = false,
    this.hintsShown = 0,
    this.knewWords = const {},
  });
}

// ── NazoScreen ────────────────────────────────────────────────────────────────

/// Casebook "framed ledger" re-skin flag (CEO 1904 craft bar + 1933/1934 de-Layton).
/// When true the ナゾ screen renders the premium FRAMED craft (double-rule panels,
/// framed preview, structured case layout) on OUR distinct dark navy+gold "ink
/// ledger" — NOT Layton's signature parchment (which "世界観を寄せすぎ"). The pc*
/// tokens in dq_ui.dart now resolve to dark navy/cream/gold. Const so it tree-shakes;
/// flip to false to A/B back to the plain navy boxes (loses the framed craft).
const bool kNazoWarmTheme = true;

/// Retrieval-gap duration (seconds) between teach and quiz (game-studio director
/// #1 — genuine cued-recall instead of recognition). Tunable here; the screen
/// auto-advances to the quiz when the countdown completes (or the child skips).
const int kRecallGapSeconds = 8;

/// Three-phase state machine that replaces the old boolean [_teaching] flag.
/// • [teach]  — show the TeachCard (teach-first, pre-quiz)
/// • [recall] — closed casebook gap: child recalls without seeing the words
/// • [quiz]   — the actual ナゾ quiz (existing behaviour)
enum _NazoPhase { teach, recall, quiz }

class NazoScreen extends StatefulWidget {
  final Hotspot hotspot;

  /// The 英検 level string for the town (drives hint text + ミノス max).
  final String eikenLevel;

  /// Hint coin service (injected for testability; defaults to shared instance).
  final HintCoinService? hintCoinService;

  /// Hint tier already unlocked for this hotspot (paid for earlier in the scene
  /// session). Seeds [_NazoScreenState._hintsShown] so a reopened ナゾ shows the
  /// hints the child already bought instead of relocking them. Defaults to 0.
  final int initialHintsShown;

  /// The scene's painted background plate (e.g. 'assets/art/scenes_layton/town5_lane.webp').
  /// When provided, DqScene renders it blurred + scrimed behind the ナゾ cards so
  /// the puzzle "surfaces inside the world" instead of floating on a navy void.
  /// Null (the default) keeps the existing flat-gradient behaviour — tests and any
  /// callers that don't supply a plate are unaffected.
  final String? sceneBackgroundAsset;

  /// Gathered observation clue lines for the FINAL ナゾ (対決 confrontation).
  ///
  /// When non-null and non-empty, a 探偵メモ block is rendered above the stem so
  /// the confrontation reads as deduction from collected evidence rather than an
  /// anonymous quiz. Format: pre-built JP string with header + '・' bullet lines,
  /// constructed by scene_view._openNazo for the final ナゾ only. Null (default)
  /// for all other ナゾ — the block is simply absent.
  final String? gatheredCluesJa;

  const NazoScreen({
    super.key,
    required this.hotspot,
    required this.eikenLevel,
    this.hintCoinService,
    this.initialHintsShown = 0,
    this.sceneBackgroundAsset,
    this.gatheredCluesJa,
  });

  @override
  State<NazoScreen> createState() => _NazoScreenState();
}

class _NazoScreenState extends State<NazoScreen> with TickerProviderStateMixin {
  late final MinosController _minos;
  late final HintCoinService _coins;
  final _cue = AudioCueService();
  final _sound = SoundService();

  int? _picked;
  bool _revealed = false;
  // Indices the child tapped WRONG on a non-penalizing ナゾ. The 320ms shake
  // vanishes, so without a durable mark a 6yo re-taps a tile they already tried.
  // These stay struck-out (DqChoiceState.wrong) for the life of the question
  // (#113 re-score #2). Reset per ナゾ in _finish.
  final Set<int> _triedWrong = {};
  // Choreographed reward (studio #1 + panel game-feel): on a correct answer the
  // learning text shows FIRST (_revealed). Two SEPARATE beats then follow:
  //  • _burstReady (~90ms) — the gold burst glow. It fires almost immediately so
  //    the celebration is felt as ONE kinetic moment with the tap (game-feel: a
  //    550ms gap read as a freeze to a 6yo). Safe to fire early because the burst
  //    sits BEHIND the content (studio #2), so it glows behind the lesson, never
  //    buries it.
  //  • _readWindowDone (~550ms) — gates the 「ナゾ、解けた！」 CTA + auto-advance, so a
  //    child still cannot skip past reading WHY it was right before the window.
  // Reduced-motion collapses both to the old instant.
  bool _burstReady = false;
  bool _readWindowDone = false;
  Timer? _burstTimer;
  Timer? _readWindowTimer;
  Timer? _finishTimer;
  bool _finished = false;
  // Teach at the error moment (studio #3): a wrong tap briefly surfaces the tapped
  // word's meaning (from the TeachCard) under the options, so the same tap that is
  // the game's "wrong" beat also teaches. Null = nothing shown.
  String? _wrongMeaning;
  Timer? _wrongMeaningTimer;
  // Anchors the wrong-answer teach banner so a wrong tap can scroll it into view
  // (#100): on a phone the banner sits below the option tiles, so the child who
  // taps wrong never sees the teaching — the actual learning moment — unless we
  // bring it on-screen.
  final GlobalKey _wrongBannerKey = GlobalKey();
  // First-answer tracking for an honest 合格率 signal (#89): record whether the
  // child's very first choice was correct, regardless of later retries.
  bool _firstAttempted = false;
  bool _firstTryCorrect = false;
  int _coinBalance = 0;
  int _hintsShown = 0; // 0 = none; 1/2/3 = tiers revealed so far
  bool _coinLoading = false;
  bool _autoHintGiven = false;
  // True when this ナゾ references an audio clip that isn't bundled (e.g. the
  // founder-pending 5級 phonemes). We then hide the dead 🔊 button + show an
  // honest "準備中" note instead of leaving the child with silence (#43).
  bool _audioMissing = false;

  // Three-phase state machine (teach → recall gap → quiz). Replaces the old
  // bool _teaching so the retrieval gap can be inserted between teach and quiz
  // without duplicating the quiz scaffold. quiz is the only phase with tappable
  // options, so _firstAttempted/_firstTryCorrect cannot be set prematurely.
  late _NazoPhase _phase;

  // Discrete recall-gap countdown: decrements once per second via a periodic
  // Timer. kRecallGapSeconds → 0; at 0 fires _phase = _NazoPhase.quiz.
  // A discrete per-second update (vs a continuous AnimationController) keeps
  // pumpAndSettle() in tests stable — each Timer tick is one pump call, and
  // after the last tick pumpAndSettle() sees no pending frames and returns.
  // Null in reduced-motion mode (no auto-advance).
  int _recallSecondsLeft = kRecallGapSeconds;

  // Fires _phase = _NazoPhase.quiz after kRecallGapSeconds (real wall time).
  // Not started in reduced-motion mode (no auto-advance, skip btn only).
  Timer? _recallTimer;

  // Cover-reveal cued-retrieval recall (studio #1 — replaces tile-grid):
  // The child sees the JA cue LARGE + a masked '？？？' EN panel. One tap reveals
  // the EN word; a two-button self-assessment row then appears:
  //   'おぼえてた！' → adds cue idx to _knewCues (honest 合格率) + advances
  //   'もう1かい'   → does NOT add to _knewCues + advances
  // Always adds idx to _producedCues. advanceCue() resets _recallRevealed.
  // The kRecallGapSeconds Timer stays as the switch-access escape hatch (8s).
  int _recallCueIdx = 0;
  // _revealedCues kept for backward compat with callers; not used in cover-reveal.
  final Set<int> _revealedCues = {};
  final Set<int> _knewCues = {};
  final Set<int> _producedCues = {};
  // Whether the current cue's EN word has been revealed (cover → reveal state).
  // Reset to false in advanceCue() per-cue branch.
  bool _recallRevealed = false;
  // Pop-hold timer: after the child chooses, hold for ~600ms (feel of "I got it")
  // before auto-advancing. Reduced-motion: instant advance (no hold).
  Timer? _recallPopTimer;

  QuestStep get _step => widget.hotspot.step!;
  TeachCard? get _teachCard => widget.hotspot.teachCard;

  // One key per option so a WRONG tap can shake exactly that tile (#59). Built
  // once from the (fixed) option count for this ナゾ instance.
  late final List<GlobalKey<AudioOptionButtonState>> _optionKeys = [
    for (var i = 0; i < _step.options.length; i++)
      GlobalKey<AudioOptionButtonState>(),
  ];

  @override
  void initState() {
    super.initState();
    _phase = (_teachCard != null) ? _NazoPhase.teach : _NazoPhase.quiz;
    // Restore the hint tier the child already paid for (relocking it on reopen
    // would charge them twice for the same hint — the spend is durable).
    _hintsShown = widget.initialHintsShown;
    _minos = MinosController(
      maxValue: minosMaxForGrade(widget.eikenLevel),
    );
    _coins = widget.hintCoinService ?? HintCoinService();
    _loadCoinBalance();
    final audio = _step.autoPlayAudio;
    if (audio != null && audio.isNotEmpty) {
      AudioAssets.exists(audio).then((ok) {
        if (mounted && !ok) setState(() => _audioMissing = true);
      });
    }
  }

  Future<void> _loadCoinBalance() async {
    final b = await _coins.balance();
    if (mounted) setState(() => _coinBalance = b);
  }

  @override
  void dispose() {
    _burstTimer?.cancel();
    _readWindowTimer?.cancel();
    _finishTimer?.cancel();
    _wrongMeaningTimer?.cancel();
    _recallTimer?.cancel();
    _recallPopTimer?.cancel();
    _cue.dispose();
    super.dispose();
  }

  // ── Choice handling ───────────────────────────────────────────────────────

  void _choose(int i) {
    if (_revealed) return;
    final correct = i == _step.correctIndex;
    // Capture the FIRST answer for the 合格率 signal, before any early return.
    if (!_firstAttempted) {
      _firstAttempted = true;
      _firstTryCorrect = correct;
    }
    if (!correct) _showWrongMeaning(i); // teach at the error moment (studio #3)
    if (!correct && !_step.penalizeWrong) {
      // No-scold: replay the audio without advancing. The wrong-chime + haptic
      // CONFIRM the tap registered — this default path (TeachSound/BlendWord/
      // TeachWord/Phrase all land here) used to fire only a silent shake + voice
      // replay, so a wrong tap felt broken/unregistered on a phone. Mirrors the
      // penalizeWrong path's feedback below; both respect the SFX mute.
      _sound.playWrong();
      HapticFeedback.selectionClick();
      _optionKeys[i].currentState?.triggerShake();
      // Durable wrong-scar (#113 re-score #2): mark this tile so it stays
      // struck-out and the child's eye skips it instead of re-tapping it.
      setState(() => _triedWrong.add(i));
      _cue.play(_step.autoPlayAudio);
      return;
    }
    if (!correct) {
      _minos.onWrong();
      _sound.playWrong();
      // Pair the chime with a haptic tick — the ナゾ is the core loop (英検
      // question == puzzle) yet it was the ONLY answer path firing sound with no
      // haptic, while exam/battle/level-up all pair them (PracticeFeedback). On a
      // phone/tablet the tick is a primary "registered" signal. No-op on web/desktop.
      HapticFeedback.selectionClick();
      _optionKeys[i].currentState?.triggerShake();
      _autoRevealFirstWrongHint();
    }
    setState(() {
      _picked = i;
      _revealed = correct;
      if (_revealed) {
        _sound.playCorrect();
        HapticFeedback.lightImpact();
      }
    });
    if (!correct) return;
    // Read FIRST, celebrate SECOND. After a short window the burst + continue
    // appear; the moment also auto-advances so a non-reader is carried to the
    // restoration. Reduced-motion shows everything at once (old behaviour).
    if (prefersReducedMotion(context)) {
      setState(() {
        _burstReady = true;
        _readWindowDone = true;
      });
      _scheduleAutoFinish();
    } else {
      // Burst glow fires almost immediately so the win is felt with the tap
      // (panel game-feel): it blooms BEHIND the lesson, never burying it.
      _burstTimer = Timer(const Duration(milliseconds: 90), () {
        if (!mounted) return;
        setState(() => _burstReady = true);
      });
      // The read-window CTA + auto-advance stay gated to ~550ms so a child can't
      // skip past the WHY before reading it.
      _readWindowTimer = Timer(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() => _readWindowDone = true);
        _scheduleAutoFinish();
      });
    }
  }

  /// The Japanese meaning of an option's word from the TeachCard, or null if this
  /// ナゾ has no card or the word isn't taught. Tolerant match (case/punctuation).
  String? _meaningFor(String label) {
    final card = _teachCard;
    if (card == null) return null;
    String norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    final key = norm(label);
    if (key.isEmpty) return null;
    for (final it in card.items) {
      if (norm(it.en) == key) return it.ja;
    }
    return null;
  }

  /// The solve-moment victory stamp body (studio panel #3 — fuse the won English
  /// word into the highest-arousal beat). Test-potentiated-encoding research: the
  /// strongest memory trace is form-specific feedback at the arousal spike, so the
  /// burst moment should NAME the word the child just restored — not a generic
  /// 'ことばが ひびいた！'. When the correct option has a teach-card meaning we show
  /// 「word = いみ」 as the hero line with the resonance flavour beneath; for grammar
  /// ナゾ with no clean word=meaning match we fall back to the original flavour line.
  Widget _victoryStampBody() {
    final word = _step.options[_step.correctIndex].label;
    final meaning = _meaningFor(word);
    const flavour = 'ことばが ひびいた！ ―― 色（いろ）が もどる。';
    if (meaning == null) {
      return Text(flavour,
          style: dqText(size: 14, w: FontWeight.w800, color: dqGold));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$word = $meaning',
            style: dqText(size: 17, w: FontWeight.w900, color: dqGold)),
        const SizedBox(height: 2),
        Text(flavour,
            style: dqText(
                size: 12, w: FontWeight.w700, color: dqGold.withAlpha(205))),
      ],
    );
  }

  /// Surface the tapped wrong word's meaning for ~2.4s (studio #3 — the error
  /// moment is the highest-salience encoding moment; teach, don't just shake).
  void _showWrongMeaning(int i) {
    final word = _step.options[i].label;
    final meaning = _meaningFor(word);
    final String banner;
    if (meaning != null) {
      banner = '$word = $meaning';
    } else {
      // #4 (studio): ナゾ without a teach-card meaning — notably a penalising
      // QuestEncounter, the HIGHEST-stakes wrong-tap — used to shake silently with
      // zero explanation (error-consolidation risk per 2025-26 retrieval-practice
      // research). Teach at the error spike from the step's own data: name the
      // correct answer + its JA gloss (npcLineJa/teachJa) if the step carries one.
      final correct = _step.options[_step.correctIndex].label;
      final gloss = _step.teachJa?.trim();
      banner = (gloss != null && gloss.isNotEmpty)
          ? 'せいかいは「$correct」 ― $gloss'
          : 'せいかいは「$correct」';
    }
    _wrongMeaningTimer?.cancel();
    setState(() => _wrongMeaning = banner);
    // Bring the teach on-screen — it renders below the tiles, so on a phone the
    // child who just tapped wrong wouldn't otherwise see it (#100). Post-frame so
    // the banner is laid out before we scroll. Reduced-motion-safe: a near-instant
    // scroll when the OS asks for less motion, a gentle ease otherwise.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _wrongBannerKey.currentContext;
      if (ctx == null) return;
      final reduceMotion = MediaQuery.maybeOf(ctx)?.disableAnimations ?? false;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
    _wrongMeaningTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _wrongMeaning = null);
    });
  }

  void _scheduleAutoFinish() {
    // When the reveal carries a grammar RULE to READ (onCorrectJa rule-card), do
    // NOT auto-dismiss — a 6yo needs time to read it, and 1.4s is far too short.
    // The "▶ ナゾ、解けた！" CTA (shown once _burstReady) lets the child advance at
    // their own pace. Auto-advance stays for story-only reveals, where it carries
    // a non-reader to the colour-restoration without stranding them on a read.
    if (_step.onCorrectJa != null) return;
    // 2400ms (was 1400): the gold burst peaks ~650-1100ms post-tap, so 1400ms
    // auto-popped the screen before a young reader could register the win AND read
    // the 「ことばがひびいた」/why-correct reveal. 2400ms leaves a ~1s read window
    // after the burst peak before auto-advance (game-studio rank-2; child can also
    // tap 「ナゾ、解けた！」 to advance sooner). onCorrectJa ナゾ still suppress auto-advance.
    _finishTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) _finish();
    });
  }

  // Gentle teaching note (info teal, NOT a red scold) — surfaces the tapped wrong
  // word's meaning at the error moment. liveRegion so a screen-reader child hears
  // the teaching, not just feels the shake.
  Widget _wrongMeaningBanner() {
    const warm = kNazoWarmTheme;
    // Casebook note: warm amber accent on our dark navy ledger (#114 de-Layton),
    // not the cold teal. Still a gentle teach, not a scold.
    final accent = warm ? const Color(0xFFB5683C) : const Color(0xFF4FC3F7);
    return Semantics(
      liveRegion: true,
      label: 'ヒント。${_wrongMeaning ?? ''}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: warm ? pcParchment0 : accent.withAlpha(28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withAlpha(warm ? 170 : 150)),
        ),
        child: Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_wrongMeaning ?? '',
                  style: warm
                      ? dqInkText(size: 14, w: FontWeight.w700, color: pcInk)
                      : dqText(size: 14, w: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _finish() {
    if (_finished) return; // idempotent: the auto-timer and the CTA can race
    _finished = true;
    _triedWrong.clear(); // wrong-scars are per-ナゾ (#113 re-score #2)
    _burstTimer?.cancel();
    _readWindowTimer?.cancel();
    _finishTimer?.cancel();
    final earned = _minos.earn();
    // Build the knewWords set from the cue indices produced correctly on the
    // FIRST tap. _knewCues may be empty when recall was skipped via the timer.
    final card = _teachCard;
    final knewWords = <String>{};
    if (card != null) {
      for (final idx in _knewCues) {
        if (idx < card.items.length) knewWords.add(card.items[idx].en);
      }
    }
    Navigator.of(context).pop(NazoResult(
      solved: true,
      minosEarned: earned,
      firstTryCorrect: _firstTryCorrect,
      hintsShown: _hintsShown,
      knewWords: knewWords,
    ));
  }

  void _dismiss() {
    // Carry the unlocked hint tier back so reopening this unsolved ナゾ restores
    // the hints the child already paid for (the coin spend is durable).
    Navigator.of(context).pop(
      NazoResult(solved: false, minosEarned: 0, hintsShown: _hintsShown),
    );
  }

  // ── Hint ladder ───────────────────────────────────────────────────────────

  void _autoRevealFirstWrongHint() {
    if (_autoHintGiven || _hintsShown >= 1) return;
    setState(() {
      _autoHintGiven = true;
      _hintsShown = 1;
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content:
              Text('タロがヒントをくれた。', style: dqText(size: 14, w: FontWeight.w600)),
          backgroundColor: const Color(0xFF2A5A3A).withAlpha(210),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _tryUnlockHint(int tier) async {
    if (_hintsShown >= tier) return; // already shown
    final cost = HintCoinService.costForTier(tier);
    setState(() => _coinLoading = true);
    final result = await _coins.spend(cost);
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _hintsShown = tier;
        _coinBalance = result.balance;
        _coinLoading = false;
      });
    } else {
      setState(() => _coinLoading = false);
      _showInsufficientCoins(cost, result.balance);
    }
  }

  void _showInsufficientCoins(int cost, int have) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ひらめきコインが足（た）りない！（必要（ひつよう）: $cost、持（も）っているコイン: $have）',
          style: dqText(size: 13),
        ),
        backgroundColor: dqBox,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Phase child — computed into a local var so AnimatedSwitcher can wrap it.
    // The quiz block (DqScene) is UNCHANGED; only the assignment form differs.
    final Widget phaseChild;
    if (_phase == _NazoPhase.teach) {
      phaseChild = _teachScaffold();
    } else if (_phase == _NazoPhase.recall) {
      phaseChild = _recallScaffold();
    } else {
      phaseChild = DqScene(
        warm: kNazoWarmTheme,
        backgroundAsset: widget.sceneBackgroundAsset,
        contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
        child: Stack(
          children: [
            SafeArea(
              // FIX 2: add bottom padding so the last answer option clears the
              // safe-area / home-indicator bar and never gets clipped.
              bottom: true,
              child: Padding(
                // FIX 2: outer horizontal margin (20 instead of 16) so the dimmed
                // plate is visible at the left/right margins — the world FRAMES the
                // column rather than being completely hidden behind it.
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    // FIX 2: inter-panel gap so the plate shows between header and ミノス.
                    const SizedBox(height: 14),
                    _minosRow(),
                    const SizedBox(height: 14),
                    // Body CENTRES in the remaining space (scrolls when tall) so a
                    // short ナゾ fills the screen instead of clinging to the top over
                    // a dead navy void (#112 / EIKEN5-LAYTON-NAZO-PLAN.md #4).
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => SingleChildScrollView(
                          // FIX 2: bottom padding inside the scroll so the last
                          // option tile is never flush against the safe-area edge.
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: c.maxHeight),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // This ナゾ plays a phoneme/word the child must HEAR to answer —
                                // if Voice is muted, warn + offer a one-tap unmute. Suppressed when
                                // the clip is missing (unmuting wouldn't help → show 準備中 instead).
                                if (AudioMute.voiceMuted &&
                                    _step.autoPlayAudio != null &&
                                    !_audioMissing) ...[
                                  MutedVoiceBanner(
                                    onUnmute: () => setState(() {}),
                                    message: kPhonicsMutedMessage,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (widget.gatheredCluesJa != null &&
                                    widget.gatheredCluesJa!.isNotEmpty) ...[
                                  _gatheredCluesBox(),
                                  const SizedBox(height: 14),
                                ],
                                if (widget.hotspot.framingJa != null) ...[
                                  _framingBox(),
                                  // FIX 2: larger inter-panel gap so the plate reads between
                                  // the framing box and the quiz card.
                                  const SizedBox(height: 14),
                                ],
                                _quizCard(),
                                const SizedBox(height: 16),
                                _promptLabel(),
                                const SizedBox(height: 10),
                                ..._optionTiles(),
                                // Teach at the error moment (studio #3): the tapped word's
                                // meaning, shown gently (info, not a scold) for ~2.4s.
                                if (_wrongMeaning != null) ...[
                                  const SizedBox(height: 10),
                                  KeyedSubtree(
                                    key: _wrongBannerKey,
                                    child: _wrongMeaningBanner(),
                                  ),
                                ],
                                if (_revealed) ...[
                                  const SizedBox(height: 12),
                                  // Solve-moment reward (game-feel #51): a detective-register
                                  // "the word resonated" stamp acknowledges the win BEFORE the
                                  // restoration dialog — so solving feels like a victory, not just
                                  // a correct/next. Static (no animation → reduced-motion-safe).
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: dqGold.withAlpha(34),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: dqGold.withAlpha(140)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('✦',
                                            style: TextStyle(fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Expanded(child: _victoryStampBody()),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Announce the win + the teach-why 解説 to a
                                  // screen-reader / low-vision child. Without this
                                  // live region the most-frequent learning moment
                                  // (a correct answer) delivered its explanation to
                                  // sighted children only — the wrong-answer banner
                                  // already announces (see _wrongMeaningBanner), so
                                  // the correct path was the one inverted-learning
                                  // gap. excludeSemantics so the inner Text is not
                                  // read twice. (WCAG 2.2 status-message guidance.)
                                  // The 英検 learning payload (WHY the answer is
                                  // right) as a distinct gold-accented rule-card,
                                  // visually SEPARATE from the story beat below so a
                                  // 6yo can tell the rule apart from the narrative
                                  // (Layton-style: deduction, THEN explanation).
                                  if (_step.onCorrectJa != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(
                                          14, 12, 14, 12),
                                      decoration: BoxDecoration(
                                        color: pcParchment1,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: dqGold.withAlpha(120),
                                            width: 1.5),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            const Icon(Icons.lightbulb_outline,
                                                color: dqGold, size: 16),
                                            const SizedBox(width: 6),
                                            Text('なぜ せいかい？',
                                                style: dqInkText(
                                                    size: 12,
                                                    w: FontWeight.w800,
                                                    color: dqGold,
                                                    spacing: 1)),
                                          ]),
                                          const SizedBox(height: 6),
                                          Text(_step.onCorrectJa!,
                                              style: dqInkText(
                                                  size: 15,
                                                  w: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Semantics(
                                    liveRegion: true,
                                    label: _step.onCorrectJa != null
                                        ? 'せいかい！ ${_step.onCorrectJa} ${_step.onCorrect}'
                                        : 'せいかい！ ${_step.onCorrect}',
                                    excludeSemantics: true,
                                    child: DqDialogBox(
                                      speaker: _step.npcName,
                                      child: Text(_step.onCorrect,
                                          style: dqText(size: 15)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Gated on _readWindowDone (~550ms) so a child cannot skip
                                  // past reading WHY it was right — even though the burst glow
                                  // already fired at ~90ms. Auto-advance also fires, so this is
                                  // an optional early-skip, not the only exit.
                                  if (_readWindowDone)
                                    DqButton(
                                        label: '▶ ナゾ、解（と）けた！', onTap: _finish),
                                ] else ...[
                                  const SizedBox(height: 16),
                                  _hintLadder(),
                                ],
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Solve climax — TOPMOST Stack child so the burst renders ABOVE the
            // dark-navy casebook panels and is actually visible. IgnorePointer so
            // it never intercepts taps on tiles/buttons below. Reduced-motion and
            // the 90ms onset (_burstReady) are gated by the parent condition.
            // Four-corner perimeter burst: the painter intentionally leaves the
            // centre ≥50% deadzone clear, so lesson text / 解説 / victory stamp
            // remain fully readable even though the burst is now on top.
            if (_burstReady && !prefersReducedMotion(context))
              const Positioned.fill(
                child: IgnorePointer(child: _SolveBurst()),
              ),
          ],
        ),
      ); // end DqScene (quiz phaseChild)
    } // end else (quiz branch)

    // Key by phase so AnimatedSwitcher detects the phase change and crossfades.
    final keyed = KeyedSubtree(key: ValueKey(_phase), child: phaseChild);

    // Reduced-motion (OS accessibility): return instantly, no transition.
    if (prefersReducedMotion(context)) return keyed;

    // Normal motion: 320ms crossfade between teach / recall / quiz phases.
    // Cognitive-load research: a soft fade makes the phase change intentional
    // and premium — the transition IS the beat (studio finding #5).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: keyed,
    );
  }

  /// Honest stand-in when this step's audio clip isn't bundled yet (e.g. the
  /// founder-pending 5級 phonemes, #45) — better than a dead 🔊 button + silence.
  Widget _comingSoonNote() => Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: dqBox.withAlpha(200),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dqGoldDeep.withAlpha(120)),
        ),
        child: Text(
          '🔇 おとは じゅんびちゅう / Sound coming soon',
          textAlign: TextAlign.center,
          style: dqText(size: 12, w: FontWeight.w600, color: dqInk),
        ),
      );

  // ── Recall gap ────────────────────────────────────────────────────────────────

  /// Transitions from the teach phase to the recall phase and starts the
  /// countdown (unless the OS requests reduced motion, in which case no
  /// auto-advance fires — the child taps 「つぎへ ▶」 to proceed through each cue).
  ///
  /// If the TeachCard has no items (empty list), skip straight to quiz so an
  /// empty card cannot crash or strand the child in a blank recall screen.
  void _startRecall() {
    final card = _teachCard;
    if (card == null || card.items.isEmpty) {
      setState(() => _phase = _NazoPhase.quiz);
      return;
    }
    final reduceMotion = prefersReducedMotion(context);
    _recallPopTimer?.cancel();
    setState(() {
      _phase = _NazoPhase.recall;
      _recallSecondsLeft = kRecallGapSeconds;
      _recallCueIdx = 0;
      _recallRevealed = false;
      _revealedCues.clear();
      _knewCues.clear();
      _producedCues.clear();
    });
    if (!reduceMotion) {
      // Discrete per-second tick: decrements the counter and rebuilds the ring
      // digit once per second. This is intentionally NOT a continuous
      // AnimationController — a continuous animation would keep pumping frames
      // and cause pumpAndSettle() in widget tests to run the full 8 seconds and
      // auto-advance past the recall phase before tests can assert on it.
      _recallTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _recallSecondsLeft -= 1;
          if (_recallSecondsLeft <= 0) {
            t.cancel();
            _recallTimer = null;
            _phase = _NazoPhase.quiz;
          }
        });
      });
    }
    // Reduced motion: no auto-advance; child steps through cues manually.
  }

  /// COVER-REVEAL cued-retrieval recall shown between teach and quiz.
  ///
  /// Each cue: the JA meaning is shown LARGE (the cue). Below it a masked '？？？'
  /// EN panel invites the child to recall the English word before seeing it.
  /// One tap on the panel REVEALS the EN word (gold, 28sp). A two-button
  /// self-assessment row then appears:
  ///
  ///   'おぼえてた！' → genuine retrieval success: add cue idx to _knewCues → advance
  ///   'もう1かい'   → did not recall: do NOT add to _knewCues → advance
  ///
  /// Both buttons always add idx to _producedCues and call advanceCue().
  /// Reveal: instant on first tap (reduced-motion: same behaviour).
  /// Hold before advance: ~600ms (reduced-motion: instant advance, no hold).
  /// Skip button: cancels timers + jumps straight to quiz in ≤ 1 tap from recall.
  ///
  /// The kRecallGapSeconds countdown ring (visible) auto-advances to quiz when it
  /// drains — the switch-access escape hatch, now legible. Timer stays active.
  /// No shake can fire in recall (tiles removed → zero ambiguity on practice-safety).
  Widget _recallScaffold() {
    final reduceMotion = prefersReducedMotion(context);
    final card = _teachCard!; // guarded: null-card → quiz in _startRecall()
    final totalItems = card.items.length;

    // Safety: if items somehow empty, fall through to quiz immediately.
    if (totalItems == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _phase = _NazoPhase.quiz);
      });
      return const SizedBox.shrink();
    }

    // Clamp index to valid range in case timer fires concurrently.
    final idx = _recallCueIdx.clamp(0, totalItems - 1);
    final item = card.items[idx];
    final isLast = idx >= totalItems - 1;

    // advanceCue: cancel timers, reset cover state, move to next cue or quiz.
    void advanceCue() {
      _recallTimer?.cancel();
      _recallTimer = null;
      _recallPopTimer?.cancel();
      _recallPopTimer = null;
      if (isLast) {
        setState(() {
          _recallRevealed = false;
          _phase = _NazoPhase.quiz;
        });
      } else {
        setState(() {
          _recallRevealed = false;
          _recallCueIdx++;
        });
      }
    }

    // onAssess: called by 'おぼえてた！' (knew=true) or 'もう1かい' (knew=false).
    // Always advances after a ~600ms hold so the child has a felt "I did it" beat.
    // Reduced-motion: immediate advance.
    void onAssess(bool knew) {
      // Idempotent: if pop timer already running (race), ignore.
      if (_recallPopTimer != null && _recallPopTimer!.isActive) return;
      // Wire _knewCues ONLY when 'おぼえてた！' AND this is the first reveal
      // (not already in _producedCues). This is the honest 合格率 signal.
      if (knew && !_producedCues.contains(idx)) {
        _knewCues.add(idx);
      }
      _producedCues.add(idx);
      if (!reduceMotion) HapticFeedback.lightImpact();
      // Cancel the wall-clock fallback so it can't race.
      _recallTimer?.cancel();
      _recallTimer = null;
      if (reduceMotion) {
        advanceCue();
      } else {
        _recallPopTimer = Timer(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          advanceCue();
        });
      }
    }

    // skipToQuiz: DqButton 'スキップ ▶' — cancel recall timers, go to quiz.
    void skipToQuiz() {
      _recallTimer?.cancel();
      _recallTimer = null;
      _recallPopTimer?.cancel();
      _recallPopTimer = null;
      setState(() {
        _recallRevealed = false;
        _phase = _NazoPhase.quiz;
      });
    }

    // onReveal: first tap on the covered panel → show EN word.
    // Reduced-motion: same (reveal is always instant; no animation involved).
    void onReveal() {
      if (_recallRevealed) return; // idempotent
      HapticFeedback.lightImpact();
      setState(() => _recallRevealed = true);
    }

    // Countdown ring value: drains from 1 → 0 over kRecallGapSeconds.
    final ringValue = (_recallSecondsLeft / kRecallGapSeconds).clamp(0.0, 1.0);

    return DqScene(
      warm: kNazoWarmTheme,
      backgroundAsset: widget.sceneBackgroundAsset,
      contentMaxWidth: 600,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Safety eyebrow: this is practice, not scored ────────
                    // Teal one-liner above the cue card so the child reads
                    // "exploration-safe" before even seeing the cover panel.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'れんしゅう — おもいだしてみよう',
                        textAlign: TextAlign.center,
                        style: dqInkText(
                            size: 12,
                            w: FontWeight.w700,
                            color: const Color(0xFF4FC3F7)),
                      ),
                    ),
                    // ── JA cue card — the question the child must recall ─────
                    Semantics(
                      liveRegion: true,
                      label: _recallRevealed
                          ? 'えいごは ${item.en}。おぼえてた？'
                          : 'えいごで こたえよう。${item.ja}。えいごは？',
                      child: DqPanel(
                        warm: kNazoWarmTheme,
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'えいごで いうと？',
                                  textAlign: TextAlign.center,
                                  style: dqInkText(
                                      size: 13,
                                      w: FontWeight.w700,
                                      color: pcInk),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.ja,
                                  textAlign: TextAlign.center,
                                  style: dqInkText(
                                      size: 34,
                                      w: FontWeight.w800,
                                      color: pcInk),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${idx + 1} / $totalItems',
                                  style: dqInkText(
                                      size: 11,
                                      w: FontWeight.w600,
                                      color: pcInkSoft),
                                ),
                              ],
                            ),
                            // Countdown ring in the top-right corner of the cue
                            // card. Drains from full→empty over kRecallGapSeconds.
                            // Gives the child legible urgency + replaces the old
                            // silent backstop. Hidden when auto-advance is off
                            // (reduced-motion) to avoid a frozen ring read as a bug.
                            if (!reduceMotion)
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  value: ringValue,
                                  strokeWidth: 3,
                                  backgroundColor: pcFrameGold.withAlpha(50),
                                  color: pcFrameGold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Cover-reveal EN panel ───────────────────────────────
                    // Before reveal: '？？？' mask invites retrieval attempt.
                    // After reveal: EN word in gold (28sp) + self-assessment row.
                    GestureDetector(
                      onTap: _recallRevealed ? null : onReveal,
                      child: DqPanel(
                        warm: kNazoWarmTheme,
                        child: _recallRevealed
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    item.en,
                                    textAlign: TextAlign.center,
                                    style: dqInkText(
                                        size: 28,
                                        w: FontWeight.w800,
                                        color: pcFrameGold),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '？？？',
                                    textAlign: TextAlign.center,
                                    style: dqInkText(
                                        size: 22,
                                        w: FontWeight.w800,
                                        color: pcInkSoft),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'タップして おもいだそう',
                                    textAlign: TextAlign.center,
                                    style: dqInkText(
                                        size: 11,
                                        w: FontWeight.w600,
                                        color: pcInkSoft),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    // ── Self-assessment row (shown only after reveal) ────────
                    if (_recallRevealed) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DqButton(
                              label: 'おぼえてた！',
                              onTap: _recallPopTimer != null &&
                                      _recallPopTimer!.isActive
                                  ? null
                                  : () => onAssess(true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DqButton(
                              label: 'もう1かい',
                              onTap: _recallPopTimer != null &&
                                      _recallPopTimer!.isActive
                                  ? null
                                  : () => onAssess(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    // ── Skip button — jump straight to quiz in ≤ 1 tap ─────
                    // Reachable within 1 tap from recall start (no compulsory
                    // multi-tile gate). Cancels both recall timers cleanly.
                    DqButton(
                      label: 'スキップ ▶',
                      onTap: skipToQuiz,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Teach-first view (shown BEFORE the quiz when a TeachCard is present) ─────

  Widget _teachScaffold() {
    final card = _teachCard!;
    const warm = kNazoWarmTheme;
    return DqScene(
      warm: kNazoWarmTheme,
      backgroundAsset: widget.sceneBackgroundAsset,
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'とじる / Close',
                    onPressed: _dismiss,
                    icon: Icon(warm ? Icons.menu_book : Icons.close,
                        color: warm ? pcInkSoft : dqInk),
                  ),
                  Expanded(
                    child: Text(
                      'まなびのとき',
                      textAlign: TextAlign.center,
                      style: warm
                          ? dqInkText(
                              size: 16, w: FontWeight.w800, color: pcInk)
                          : dqText(size: 16, w: FontWeight.w800, color: dqGold),
                    ),
                  ),
                  const SizedBox(width: 48), // balance the close button
                ],
              ),
              const SizedBox(height: 8),
              // Card + CTA CENTRE in the remaining space (scrolls when tall) so
              // the teach card sits balanced instead of clinging to the top over
              // a dead navy void (render audit 2026-06-17; mirrors the quiz body
              // — #112 plan item 4 / #113).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── CEO 2147 studio run-3 #2: "who you're rescuing" ──
                          // Show the silenced NPC BEFORE the word-list so the ナゾ
                          // has a subject and learning ties to the world (Layton
                          // subject-before-puzzle first-contact convention).
                          // Guard: only rendered when the hotspot has a name or
                          // grey portrait asset; ordinary teach cards are unchanged.
                          if (widget.hotspot.npcGreyAsset != null ||
                              (widget.hotspot.step?.npcName ?? '').isNotEmpty)
                            _rescueSubjectRow(),
                          if (widget.hotspot.npcGreyAsset != null ||
                              (widget.hotspot.step?.npcName ?? '').isNotEmpty)
                            const SizedBox(height: 12),
                          DqPanel(
                            warm: warm,
                            title: card.titleJa,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (card.leadJa != null) ...[
                                  Text(
                                    card.leadJa!,
                                    style: (warm
                                            ? dqInkText(
                                                size: 13,
                                                color: pcInk,
                                                w: FontWeight.w500)
                                            : dqText(
                                                size: 13,
                                                color: dqInk,
                                                w: FontWeight.w500))
                                        .copyWith(height: 1.6),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                for (var i = 0; i < card.items.length; i++)
                                  _teachItemTile(card.items[i], i),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          DqButton(
                            label: 'おぼえた！ ナゾへ ▶',
                            onTap: _startRecall,
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'おぼえてから、こたえよう。',
                              style: warm
                                  ? dqInkText(
                                      size: 11,
                                      w: FontWeight.w600,
                                      color: pcInkSoft)
                                  : dqText(size: 11, color: dqGold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CEO 2147 studio run-3 #2: compact "who you're rescuing" row ─────────────
  // Shown at the TOP of the teach card content (above the DqPanel word-list) when
  // the hotspot has an NPC name or grey portrait — so the ナゾ has a subject and
  // the learning ties to the story world (Layton subject-before-puzzle convention).
  //
  // Layout: [DqPortrait grey 60px] [gold nameplate + 1-line diegetic hint]
  // The row sits in a warm parchment container matching the teach-card palette.
  Widget _rescueSubjectRow() {
    const warm = kNazoWarmTheme;
    final greyAsset = widget.hotspot.npcGreyAsset;
    final npcName = widget.hotspot.step?.npcName.trim() ?? '';
    // Prefer the authored clue; fall back to the generic rescue prompt.
    final hintLine = (widget.hotspot.clueLineJa?.trim().isNotEmpty ?? false)
        ? widget.hotspot.clueLineJa!.trim()
        : 'この ひとは ことばを なくしている。ことばを おぼえて、たすけよう。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: warm ? pcParchment0 : dqBox.withAlpha(200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warm ? pcFrameBrown : dqGoldDeep.withAlpha(100),
          width: warm ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Grey portrait — still silenced, colour not yet restored.
          DqPortrait(
            imageAsset: greyAsset,
            emoji: '🧑',
            size: 60,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (npcName.isNotEmpty)
                  Text(
                    npcName,
                    style: warm
                        ? dqInkText(size: 13, w: FontWeight.w800, color: dqGold)
                        : dqText(size: 13, w: FontWeight.w800, color: dqGold),
                  ),
                if (npcName.isNotEmpty) const SizedBox(height: 4),
                Text(
                  hintLine,
                  style: (warm
                          ? dqInkText(
                              size: 12, w: FontWeight.w500, color: pcInkSoft)
                          : dqText(size: 12, w: FontWeight.w500, color: dqInk))
                      .copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a single teach item tile using the reusable [DetectiveCaseFrame]
  /// premium card widget (#113/#159 — cohesion fix: the flat navy boxes made the
  /// teach card look like a different product from the crafted explore/title
  /// screens). [index] is 0-based; index==0 gets the [highlighted] frame (brighter
  /// gold rules + soft glow) so the eye lands on the first word to learn first.
  Widget _teachItemTile(TeachItem it, int index) {
    // Non-warm path stays as flat Container (kNazoWarmTheme is the only shipped
    // variant; this guard means the flag is still reversible for A/B testing).
    const warm = kNazoWarmTheme;
    if (!warm) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: dqBox.withAlpha(230),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dqGoldDeep.withAlpha(120)),
        ),
        child: _teachItemContent(it, warm: false),
      );
    }
    // Warm path: route through DetectiveCaseFrame (#113/#159).
    // index==0 → highlighted (eye-entry point for the child learning the list).
    // caseLabel shows the 1-based item number so the child knows "word 1 of 4".
    final itemNum = index + 1;
    final total = _teachCard?.items.length ?? 1;
    final caseLabel = 'ことば $itemNum / $total';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DetectiveCaseFrame(
        highlighted: index == 0,
        caseLabel: caseLabel,
        child: _teachItemContent(it, warm: true),
      ),
    );
  }

  /// The inner content of a teach item (EN headword + JA meaning + optional rule).
  /// Extracted so both the warm and non-warm paths share the same content layout.
  Widget _teachItemContent(TeachItem it, {required bool warm}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          it.en,
          style: warm
              ? dqInkText(size: 22, w: FontWeight.w800, color: pcInk)
              : dqText(size: 22, w: FontWeight.w800, color: dqGold),
        ),
        const SizedBox(height: 2),
        Text(
          it.ja,
          // pcInk (full cream ~9:1), not pcInkSoft (~3.5:1): this is the word's
          // MEANING — the child must read it. Hierarchy below the headword is
          // carried by size (18 vs 22), not by dimming it under WCAG (the same
          // pcInkSoft→pcInk contrast fix dq_ui already applies to panel titles).
          style: warm
              ? dqInkText(size: 18, w: FontWeight.w700, color: pcInk)
              : dqText(size: 18, w: FontWeight.w700, color: dqInk),
        ),
        if (it.whenJa != null) ...[
          const SizedBox(height: 4),
          Text(
            '・${it.whenJa!}',
            // The RULE line IS the lesson ("next sound is a consonant → a"),
            // yet it was the dimmest/smallest text — pcInkSoft size 12 (~3.5:1)
            // fails WCAG 4.5:1 for normal text (visual-auditor, CEO 2132). Lift
            // to pcInk + 13 + medium weight so the teaching is actually legible.
            style: warm
                ? dqInkText(size: 13, color: pcInk, w: FontWeight.w500)
                : dqText(size: 13, color: dqInk, w: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _header() {
    // Case-identity plate (#61): every ナゾ now opens with a NAMED identity — whose
    // mystery + which 英検 grade — at the moment of truth, replacing the generic
    // 「？」ナゾが あらわれた！ shown identically for every puzzle. This is the Layton /
    // Golden-Idol "named case" convention + surfaces the commercial 英検 promise
    // where it matters. framingJa stays in the body (it is multi-line flavour, not
    // a title). Falls back to the generic line when an NPC has no name.
    final npc = _step.npcName.trim();
    final title = npc.isNotEmpty ? '$npc の ナゾ' : '「？」ナゾが あらわれた！';
    const warm = kNazoWarmTheme;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'とじる / Close',
              onPressed: _dismiss,
              icon: Icon(warm ? Icons.menu_book : Icons.close,
                  color: warm ? pcInkSoft : dqInk),
            ),
            const Spacer(),
            const Text('✦',
                style: TextStyle(color: Color(0xFFE0A030), fontSize: 16)),
            const SizedBox(width: 3),
            Text('$_coinBalance',
                style: warm
                    ? dqInkText(size: 14, w: FontWeight.w800, color: pcInkSoft)
                    : dqText(size: 14, color: dqGold)),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: BoxDecoration(
            color: warm ? pcParchment1 : dqBox.withAlpha(150),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: warm ? pcFrameBrown : dqGoldDeep, width: warm ? 2 : 1.5),
          ),
          child: Column(
            children: [
              Text(
                gradeLabelJa(widget.eikenLevel),
                textAlign: TextAlign.center,
                style: warm
                    ? dqInkText(
                        size: 11,
                        w: FontWeight.w700,
                        color: pcInkSoft,
                        spacing: 1.5)
                    : dqText(
                        size: 11,
                        w: FontWeight.w600,
                        color: dqGold.withAlpha(205),
                        spacing: 1.5),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                textAlign: TextAlign.center,
                style: warm
                    ? dqInkText(size: 17, w: FontWeight.w800, color: pcInk)
                    : dqText(size: 16, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(height: 6),
              Container(
                  height: 1,
                  width: 60,
                  color: warm ? pcFrameGold : dqGoldDeep.withAlpha(160)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _minosRow() {
    final current = _minos.currentValue;
    final max = minosMaxForGrade(widget.eikenLevel);
    final isFull = _minos.wrongCount == 0;
    const warm = kNazoWarmTheme;
    return DqPanel(
      warm: warm,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          const Text('💎', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ミノス',
                  style: warm
                      ? dqInkText(
                          size: 11,
                          color: pcInkSoft,
                          w: FontWeight.w800,
                          spacing: 1)
                      : dqText(
                          size: 11,
                          color: dqGold,
                          w: FontWeight.w800,
                          spacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  '$current / $max',
                  style: warm
                      ? dqInkText(
                          size: 18,
                          w: FontWeight.w800,
                          color: isFull ? pcInk : pcInkSoft)
                      : dqText(
                          size: 18,
                          w: FontWeight.w800,
                          color: isFull ? dqGold : const Color(0xFFE89090)),
                ),
              ],
            ),
          ),
          if (_minos.wrongCount > 0)
            Text(
              '↓ まちがい × ${_minos.wrongCount}',
              style: warm
                  ? dqInkText(size: 11, color: pcInkSoft)
                  : dqText(size: 11, color: const Color(0xFFE89090)),
            ),
        ],
      ),
    );
  }

  /// In-world framing line above the stem — exam content is UNCHANGED below it.
  Widget _framingBox() => DqPanel(
        // #52 diegetic bridge: this case-briefing turns the 英検 stem into a
        // detective scene. 15sp = clear hierarchy below the stem; 🔍 marks it as
        // on-scene investigation. Warm = the Layton casebook "現場" note (#113).
        warm: kNazoWarmTheme,
        title: '🔍 げんば / The Scene',
        child: Text(
          widget.hotspot.framingJa!,
          style: (kNazoWarmTheme
                  ? dqInkText(size: 15, w: FontWeight.w500, color: pcInk)
                  : dqText(size: 15, w: FontWeight.w500, color: dqInk))
              .copyWith(height: 1.7),
        ),
      );

  /// 探偵メモ block for the FINAL ナゾ (対決 confrontation): renders the observation
  /// clues the child gathered, so the accusation reads as deduction from evidence
  /// rather than an anonymous quiz.  Only rendered when [widget.gatheredCluesJa]
  /// is non-null and non-empty (i.e. only the final ナゾ in a scene with read obs).
  /// Reuses the same DqPanel(warm: kNazoWarmTheme) styling as [_framingBox].
  Widget _gatheredCluesBox() => DqPanel(
        warm: kNazoWarmTheme,
        title: '📖 たんていメモを よみかえす',
        child: Text(
          widget.gatheredCluesJa!,
          style: (kNazoWarmTheme
                  ? dqInkText(size: 14, w: FontWeight.w500, color: pcInk)
                  : dqText(size: 14, w: FontWeight.w500, color: dqInk))
              .copyWith(height: 1.8),
        ),
      );

  // Reuses the same quiz-card layout as quest_screen's _quizPrompt.
  Widget _quizCard() {
    final step = _step;
    if (step is QuestEncounter) {
      return Column(
        children: [
          DqPortrait(
            imageAsset: widget.hotspot.npcColorAsset ??
                QuestScreen.npcImage(step.npcName),
            emoji: step.npcEmoji,
            size: 76,
          ),
          const SizedBox(height: 16),
          DqDialogBox(
            warm: kNazoWarmTheme,
            speaker: step.npcName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.npcLine,
                    style: kNazoWarmTheme
                        ? dqInkText(size: 19, w: FontWeight.w700, color: pcInk)
                        : dqText(size: 19, w: FontWeight.w700)),
                if (step.npcLineJa != null) ...[
                  const SizedBox(height: 8),
                  Text(step.npcLineJa!,
                      style: kNazoWarmTheme
                          ? dqInkText(
                              size: 12, color: pcInkSoft, w: FontWeight.w500)
                          : dqText(size: 12, color: dqInk, w: FontWeight.w400)),
                ],
              ],
            ),
          ),
          if (step.autoPlayAudio != null) ...[
            const SizedBox(height: 12),
            if (_audioMissing)
              _comingSoonNote()
            else
              DqReplayButton(
                onTap: () => _cue.play(step.autoPlayAudio),
                label: '🔊 もういちど きく',
              ),
          ],
        ],
      );
    }
    // Phonics teach steps (TeachSound, BlendWord, TeachWord, Phrase)
    final glyph = switch (step) {
      TeachSound s => s.glyph,
      BlendWord s => s.letters.join('·'),
      TeachWord s => s.word,
      Phrase s => s.text,
      _ => '?',
    };
    return Column(
      children: [
        DqPortrait(
          imageAsset: widget.hotspot.npcColorAsset ??
              QuestScreen.npcImage(step.npcName),
          emoji: step.npcEmoji,
          size: 72,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: dqBox.withAlpha(235),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: dqGold, width: 3),
            boxShadow: [BoxShadow(color: dqGold.withAlpha(80), blurRadius: 18)],
          ),
          child: Text(glyph, style: dqText(size: 64, w: FontWeight.w800)),
        ),
        if (step.autoPlayAudio != null) ...[
          const SizedBox(height: 12),
          if (_audioMissing)
            _comingSoonNote()
          else
            DqReplayButton(
                onTap: () => _cue.play(step.autoPlayAudio), label: '🔊 おとを きく'),
        ],
        if (step.teachJa != null) ...[
          const SizedBox(height: 14),
          DqDialogBox(
              speaker: step.npcName,
              child: Text(step.teachJa!, style: dqText(size: 15))),
        ],
      ],
    );
  }

  Widget _promptLabel() => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _step.practicePromptJa ?? '正（ただ）しい答（こた）えをえらぼう',
          style: kNazoWarmTheme
              ? dqInkText(size: 12, w: FontWeight.w700, color: pcInkSoft)
              : dqText(size: 12, color: dqGold),
        ),
      );

  List<Widget> _optionTiles() {
    final opts = _step.options;
    return List.generate(opts.length, (i) {
      final o = opts[i];
      final correct = i == _step.correctIndex;
      DqChoiceState st = DqChoiceState.normal;
      if (_revealed && correct) {
        st = DqChoiceState.correct;
      } else if (_step.penalizeWrong && _picked == i && !correct) {
        st = DqChoiceState.wrong;
      } else if (_triedWrong.contains(i)) {
        // #113 re-score #2: a previously-tried wrong tile stays struck-out so the
        // child doesn't re-tap it (the 320ms shake left no durable mark).
        st = DqChoiceState.wrong;
      }
      final audioKey = o.audioAsset ?? quizAudioAsset(o.label);
      // When this step's audio isn't bundled (founder-pending phonemes), the
      // per-option 🔊 would be dead too — drop it so options aren't a silent
      // guessing trap; the glyph on the teach card keeps them answerable. (#43)
      final onAudio = (audioKey == null || _audioMissing)
          ? null
          : () => _cue.play(audioKey);
      return AudioOptionButton(
        key: _optionKeys[i],
        label: o.label,
        state: st,
        warm: kNazoWarmTheme,
        index: i + 1, // #115: numbered answer tiles vs the ✦-coin hint rows
        onAudio: onAudio,
        onChoose: _revealed ? null : () => _choose(i),
      );
    });
  }

  // ── Hint ladder ───────────────────────────────────────────────────────────

  Widget _hintLadder() {
    // Use per-hotspot authored hints when present (sorted by tier so authoring
    // order doesn't matter); fall back to the generic level hints otherwise.
    // All existing hotspots have hints == null → identical fallback behaviour.
    final authoredHints = widget.hotspot.hints;
    final hints = (authoredHints != null && authoredHints.isNotEmpty)
        ? (List<NazoHint>.from(authoredHints)
          ..sort((a, b) => a.tier.compareTo(b.tier)))
        : defaultHintsForLevel(widget.eikenLevel);

    return DqPanel(
      warm: kNazoWarmTheme,
      title: 'ひらめきコイン ヒント',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int tier = 1; tier <= 3; tier++) ...[
            _hintTile(
                tier,
                hints.firstWhere((h) => h.tier == tier,
                    orElse: () => hints.last)),
            if (tier < 3) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _hintTile(int tier, NazoHint hint) {
    final unlocked = _hintsShown >= tier;
    final cost = HintCoinService.costForTier(tier);
    const warm = kNazoWarmTheme;
    return GestureDetector(
      onTap: (unlocked || _coinLoading || _revealed)
          ? null
          : () => _tryUnlockHint(tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: unlocked
              ? (warm
                  ? const Color(0xFF14361F)
                  : const Color(0xFF1A3522).withAlpha(210))
              : (warm ? pcParchment0 : dqBox.withAlpha(200)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: unlocked
                ? (warm ? const Color(0xFF7BD08B) : const Color(0xFF8BE08B))
                : (warm ? pcFrameBrown : dqGoldDeep),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              unlocked ? '💡' : '✦',
              style: TextStyle(
                fontSize: 18,
                color: unlocked
                    ? const Color(0xFFE0A030)
                    : (warm ? pcFrameGold : const Color(0xFFB8923C)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: unlocked
                  ? Text(hint.textJa,
                      style: (warm
                              ? dqInkText(
                                  size: 13, w: FontWeight.w500, color: pcInk)
                              : dqText(
                                  size: 13, w: FontWeight.w500, color: dqInk))
                          .copyWith(height: 1.6))
                  : Text(
                      'T$tier ヒント — コイン $cost 枚（まい）',
                      style: warm
                          ? dqInkText(
                              size: 13, w: FontWeight.w600, color: pcInkSoft)
                          : dqText(size: 13, color: dqGold),
                    ),
            ),
            if (!unlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✦',
                      style: TextStyle(
                          color: warm ? pcFrameGold : const Color(0xFFE0A030),
                          fontSize: 13)),
                  const SizedBox(width: 2),
                  Text('$cost',
                      style: warm
                          ? dqInkText(size: 13, color: pcInkSoft)
                          : dqText(size: 13, color: dqGold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The solve-moment climax: a one-shot full-screen gold radial bloom that scales
/// up and fades out (~680ms) the instant a ナゾ is answered correctly — the
/// visceral "you cracked it" flash the game's core verb was missing. IgnorePointer
/// so it never eats the continue tap; only mounted when motion is allowed.
class _SolveBurst extends StatefulWidget {
  const _SolveBurst();

  @override
  State<_SolveBurst> createState() => _SolveBurstState();
}

class _SolveBurstState extends State<_SolveBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      // 680→900ms: the burst RAMPS to peak then fades (see painter envelope), so
      // it needs to live long enough to fill the post-solve read window instead
      // of strobing once and leaving dead air before auto-advance (game-studio
      // game-feel + pedagogy experts, team #4).
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _SolveBurstPainter(Curves.easeOut.transform(_c.value)),
        ),
      ),
    );
  }
}

/// Four-corner perimeter burst: gold radial blooms + inward fan-rays from each
/// corner, keeping the centre ≥50% deadzone completely unpainted so the 解説
/// rule card + 「ことばが ひびいた！」 stamp remain fully readable while the burst is
/// topmost. Pure CustomPaint; one-shot (parent gates on reduced-motion).
class _SolveBurstPainter extends CustomPainter {
  final double t; // 0 → 1, eased
  const _SolveBurstPainter(this.t);

  int _a(double o) => (o.clamp(0.0, 1.0) * 255).round();

  @override
  void paint(Canvas canvas, Size size) {
    // Front-loaded envelope: ramp to peak over the first 8% then ease out, so
    // the burst brightens into a peak the eye catches as it blooms with the
    // ~90ms onset tap, then gently recedes (game-studio game-feel, team #4).
    final env = (t < 0.08 ? (t / 0.08) : ((1.0 - t) / 0.92)).clamp(0.0, 1.0);
    final fade = env;

    final w = size.width;
    final h = size.height;
    final ss = size.shortestSide;

    // CENTRE DEADZONE: nothing is painted within a circle of radius 50% of
    // shortestSide centred at the screen centre — lesson text always readable.
    // All drawing is corner-anchored and stays well clear of this zone.

    // Corner anchors: [corner offset, base angle of the inward fan in radians].
    // Each corner fans ~80° into the screen quadrant facing the centre.
    //   Top-left  (0,0)  → fan right+down   → baseAngle = 0°   (→ 80° sweep)
    //   Top-right (w,0)  → fan down+left    → baseAngle = 90°
    //   Bottom-right(w,h)→ fan left+up      → baseAngle = 180°
    //   Bottom-left(0,h) → fan up+right     → baseAngle = 270°
    const fanRays = 12;
    final corners = <(Offset, double)>[
      (Offset.zero, 0.0), // top-left
      (Offset(w, 0), math.pi / 2), // top-right
      (Offset(w, h), math.pi), // bottom-right
      (Offset(0, h), 3 * math.pi / 2), // bottom-left
    ];

    // Bloom radius per corner: grows outward from the corner with t.
    final bloomR = ss * (0.10 + 0.18 * t); // peaks at 0.28 * ss

    // Ray length from corner, inward: fans toward centre but stops at ~22% ss.
    final rayLen = ss * (0.06 + 0.16 * t); // peaks at 0.22 * ss

    for (final (corner, baseAngle) in corners) {
      // 1. Radial gold bloom centred ON the corner.
      canvas.drawCircle(
        corner,
        bloomR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              dqGold.withAlpha(_a(0.55 * fade)),
              dqGold.withAlpha(_a(0.30 * fade)),
              dqGold.withAlpha(0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: corner, radius: bloomR)),
      );

      // 2. Fan of 12 short rays from the corner pointing inward toward centre.
      // Spread evenly across 80° of the inward quadrant + slight t rotation.
      final rayPaint = Paint()
        ..color = dqGold.withAlpha(_a(0.35 * fade))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < fanRays; i++) {
        final frac = i / (fanRays - 1);
        final ang = baseAngle + frac * (math.pi / 2.25) + t * 0.15;
        final dir = Offset(math.cos(ang), math.sin(ang));
        canvas.drawLine(corner, corner + dir * rayLen, rayPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SolveBurstPainter old) => old.t != t;
}

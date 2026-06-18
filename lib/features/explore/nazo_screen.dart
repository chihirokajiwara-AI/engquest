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

  const NazoResult({
    required this.solved,
    required this.minosEarned,
    this.firstTryCorrect = false,
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

class NazoScreen extends StatefulWidget {
  final Hotspot hotspot;

  /// The 英検 level string for the town (drives hint text + ミノス max).
  final String eikenLevel;

  /// Hint coin service (injected for testability; defaults to shared instance).
  final HintCoinService? hintCoinService;

  const NazoScreen({
    super.key,
    required this.hotspot,
    required this.eikenLevel,
    this.hintCoinService,
  });

  @override
  State<NazoScreen> createState() => _NazoScreenState();
}

class _NazoScreenState extends State<NazoScreen> {
  late final MinosController _minos;
  late final HintCoinService _coins;
  final _cue = AudioCueService();
  final _sound = SoundService();

  int? _picked;
  bool _revealed = false;
  // Choreographed reward (studio #1): on a correct answer the learning text shows
  // FIRST (_revealed), then after a ~550ms read window the gold burst + continue
  // fire (_burstReady) — so the climax PUNCTUATES the answer instead of burying it
  // during the form-meaning encoding window. Auto-advance (~1.4s) carries non-
  // readers past the unreadable CTA. Reduced-motion collapses to the old instant.
  bool _burstReady = false;
  Timer? _burstTimer;
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

  // Teach-first (CEO 2026-06-09 致命的欠陥): when this ナゾ carries a [TeachCard],
  // the child is TAUGHT the words first and only sees the quiz after tapping
  // 「わかった！」. Starts true iff a card is present; flips false on advance.
  bool _teaching = false;

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
    _teaching = _teachCard != null;
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
    _finishTimer?.cancel();
    _wrongMeaningTimer?.cancel();
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
      // No-scold: replay the audio without advancing. Shake the tapped tile so
      // the child SEES their tap registered (it used to be swallowed silently).
      _optionKeys[i].currentState?.triggerShake();
      _cue.play(_step.autoPlayAudio);
      return;
    }
    if (!correct) {
      _minos.onWrong();
      _sound.playWrong();
      _optionKeys[i].currentState?.triggerShake();
      _autoRevealFirstWrongHint();
    }
    setState(() {
      _picked = i;
      _revealed = correct;
      if (_revealed) _sound.playCorrect();
    });
    if (!correct) return;
    // Read FIRST, celebrate SECOND. After a short window the burst + continue
    // appear; the moment also auto-advances so a non-reader is carried to the
    // restoration. Reduced-motion shows everything at once (old behaviour).
    if (prefersReducedMotion(context)) {
      setState(() => _burstReady = true);
      _scheduleAutoFinish();
    } else {
      _burstTimer = Timer(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() => _burstReady = true);
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

  /// Surface the tapped wrong word's meaning for ~2.4s (studio #3 — the error
  /// moment is the highest-salience encoding moment; teach, don't just shake).
  void _showWrongMeaning(int i) {
    final meaning = _meaningFor(_step.options[i].label);
    if (meaning == null) return;
    final word = _step.options[i].label;
    _wrongMeaningTimer?.cancel();
    setState(() => _wrongMeaning = '$word = $meaning');
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
    _finishTimer = Timer(const Duration(milliseconds: 1400), () {
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
    _burstTimer?.cancel();
    _finishTimer?.cancel();
    final earned = _minos.earn();
    Navigator.of(context).pop(NazoResult(
      solved: true,
      minosEarned: earned,
      firstTryCorrect: _firstTryCorrect,
    ));
  }

  void _dismiss() {
    Navigator.of(context).pop(const NazoResult(solved: false, minosEarned: 0));
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
    if (_teaching) return _teachScaffold();
    return DqScene(
      warm: kNazoWarmTheme,
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  _minosRow(),
                  const SizedBox(height: 12),
                  // Body CENTRES in the remaining space (scrolls when tall) so a
                  // short ナゾ fills the screen instead of clinging to the top over
                  // a dead navy void (#112 / EIKEN5-LAYTON-NAZO-PLAN.md #4).
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
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
                              if (widget.hotspot.framingJa != null) ...[
                                _framingBox(),
                                const SizedBox(height: 10),
                              ],
                              _quizCard(),
                              const SizedBox(height: 14),
                              _promptLabel(),
                              const SizedBox(height: 8),
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
                                      Expanded(
                                        child: Text(
                                          'ことばが ひびいた！ ―― 色（いろ）が もどる。',
                                          style: dqText(
                                              size: 14,
                                              w: FontWeight.w800,
                                              color: dqGold),
                                        ),
                                      ),
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
                                Semantics(
                                  liveRegion: true,
                                  label: 'せいかい！ ${_step.onCorrect}',
                                  excludeSemantics: true,
                                  child: DqDialogBox(
                                    speaker: _step.npcName,
                                    child: Text(_step.onCorrect,
                                        style: dqText(size: 15)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Gated on _burstReady (after the read window) so a child
                                // cannot skip past reading WHY it was right. Auto-advance also
                                // fires, so this is an optional early-skip, not the only exit.
                                if (_burstReady)
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
          // Solve climax (game-studio director's #1): the correct answer is the
          // game's most frequent core verb, but it used to land as a static
          // reveal ("nothing moves" — the 6yo playtester's "broken button"). A
          // one-shot full-screen gold burst makes the win VISCERAL. The teaching
          // reveal + 「ナゾ、解けた！」 button stay (a child must read why it was right),
          // so the burst celebrates without skipping the lesson. Reduced-motion → none.
          if (_burstReady && !prefersReducedMotion(context))
            const Positioned.fill(
              child: IgnorePointer(child: _SolveBurst()),
            ),
        ],
      ),
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

  // ── Teach-first view (shown BEFORE the quiz when a TeachCard is present) ─────

  Widget _teachScaffold() {
    final card = _teachCard!;
    const warm = kNazoWarmTheme;
    return DqScene(
      warm: kNazoWarmTheme,
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
                                for (final it in card.items) _teachItemTile(it),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          DqButton(
                            label: 'わかった！ こたえてみる ▶',
                            onTap: () => setState(() => _teaching = false),
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

  Widget _teachItemTile(TeachItem it) {
    const warm = kNazoWarmTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: warm ? pcParchment0 : dqBox.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: warm ? pcFrameBrown : dqGoldDeep.withAlpha(120),
            width: warm ? 1.5 : 1),
      ),
      child: Column(
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
            style: warm
                ? dqInkText(size: 18, w: FontWeight.w700, color: pcInkSoft)
                : dqText(size: 18, w: FontWeight.w700, color: dqInk),
          ),
          if (it.whenJa != null) ...[
            const SizedBox(height: 4),
            Text(
              '・${it.whenJa!}',
              style: warm
                  ? dqInkText(size: 12, color: pcInkSoft, w: FontWeight.w400)
                  : dqText(size: 12, color: dqInk, w: FontWeight.w400),
            ),
          ],
        ],
      ),
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
      duration: const Duration(milliseconds: 680),
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

/// A real "burst", not a flat flash (#88 re-audit): a radial gold BLOOM + 12
/// radiating RAYS + 6 outward-flying SPARKLES, all blooming from centre and fading
/// over the one-shot. The rays + sparkles are what make a correct 英検 answer FEEL
/// like an impact, not a div fading. Pure CustomPaint; one-shot (parent gates it on
/// reduced-motion).
class _SolveBurstPainter extends CustomPainter {
  final double t; // 0 → 1, eased
  const _SolveBurstPainter(this.t);

  static const _gold = Color(0xFFFFD700);
  int _a(double o) => (o.clamp(0.0, 1.0) * 255).round();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.55;
    final fade = (1.0 - t).clamp(0.0, 1.0);

    // 1. Radial bloom — originates from a POINT and punches outward (#98 R2-#3:
    // the easeOut curve made it spring into existence already at 25% radius = a
    // ghost that fades in, not a hit that lands). Starting at ~0 + easeOut's fast
    // early rise reads as an impact; peak radius (1.20·maxR) is preserved. The
    // burst mounts AFTER the 550ms read window, so a sharper punch only helps it
    // re-connect to the solve (the reconcile #98 flagged).
    final bloomR = maxR * (0.02 + 1.18 * t);
    canvas.drawCircle(
      center,
      bloomR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _gold.withAlpha(_a(0.80 * fade)),
            _gold.withAlpha(_a(0.32 * fade)),
            _gold.withAlpha(0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: bloomR)),
    );

    // 2. Radiating rays — thin gold spokes that shoot out and recede. Also
    // shoot from near-centre (#98) so they read as thrown FROM the impact point,
    // not as pre-existing spokes; peak length (1.40·maxR) preserved.
    final rayLen = maxR * (0.05 + 1.35 * t);
    final rayInner = maxR * 0.06;
    final rayPaint = Paint()
      ..color = _gold.withAlpha(_a(0.85 * fade))
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final ang = (i / rays) * 2 * math.pi + t * 0.25;
      final dir = Offset(math.cos(ang), math.sin(ang));
      canvas.drawLine(center + dir * rayInner, center + dir * rayLen, rayPaint);
    }

    // 3. Sparkles — small dots flung outward, shrinking as they go.
    final dist = maxR * (0.18 + 1.1 * t);
    final sparkPaint = Paint()..color = _gold.withAlpha(_a(fade));
    const sparks = 6;
    for (var i = 0; i < sparks; i++) {
      final ang = (i / sparks) * 2 * math.pi + 0.4;
      final dir = Offset(math.cos(ang), math.sin(ang));
      canvas.drawCircle(center + dir * dist, 3.2 * (1.0 - t * 0.6), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_SolveBurstPainter old) => old.t != t;
}

// lib/features/quest/battle/silent_battle_screen.dart
//
// サイレントバトル UI — reskin of quest_screen._encounter() as a turn-based battle.
//
// Layout: しずけさ HP bar + こころ hearts + combo flash + villager portrait reveal
// (grey→colour via ColorFilter/matrix) + VERBATIM dq_ui widgets for step bodies.
//
// NO new packages. Flutter-native animations only (AnimatedSwitcher,
// AnimatedContainer, TweenAnimationBuilder — all standard Flutter SDK).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio/audio_cue_service.dart';
import '../../../core/sound/sound_service.dart';
import '../../../core/audio/audio_mute.dart';
import '../../../core/firebase/auth_service.dart';
import '../../../core/fsrs/firestore_card_repository.dart';
import '../../../core/fsrs/fsrs_card_repository.dart';
import '../../../core/gamification/xp_service.dart';
import '../../../features/home/streak_service.dart';
import '../quest_data.dart';
import '../quest_screen.dart';
import '../ui/dq_ui.dart';
import '../ui/muted_voice_banner.dart';
import 'battle_rewards.dart';
import 'silent_battle_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SilentBattleScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Plays one "villager" battle (a [SilentBattleController] slice of a town).
///
/// Constructor args:
///   [controller]  — pre-built FSM (caller owns its lifecycle).
///   [repository]  — injectable for tests; defaults to FirestoreFsrsCardRepository.
///   [uid]         — player uid; if null, AuthService is called for it.
///   [onVictory]   — called after rewards applied; navigate forward.
///   [onDefeat]    — called on defeat; navigate back / retry.
class SilentBattleScreen extends StatefulWidget {
  final SilentBattleController controller;
  final FsrsCardRepository? repository;
  final String? uid;
  final VoidCallback? onVictory;
  final VoidCallback? onDefeat;

  const SilentBattleScreen({
    super.key,
    required this.controller,
    this.repository,
    this.uid,
    this.onVictory,
    this.onDefeat,
  });

  @override
  State<SilentBattleScreen> createState() => _SilentBattleScreenState();
}

class _SilentBattleScreenState extends State<SilentBattleScreen> {
  final _cue = AudioCueService();
  // Game-feel SFX (chimes), separate from the spoken _cue voice clips. The
  // flagship サイレントバトル was the ONLY answer path with no chime — every other
  // surface (nazo, exam) gives audio feedback on a pick. Process-wide singleton.
  final _sound = SoundService();
  // Last phase we reacted to, so a same-phase re-notify can't double-chime.
  BattlePhase? _lastPhase;

  bool _rewardsApplied = false;

  // Blend-letter sweep timer (same pattern as quest_screen.dart).
  int _activeLetter = -1;
  Timer? _sweepTimer;

  // Combo flash: briefly show the combo count when it increments.
  bool _showComboFlash = false;
  int _lastCombo = 0;

  @override
  void initState() {
    super.initState();
    // NOTE: do NOT touch Firebase here. AuthService/XpService/FirestoreRepo all
    // grab Firebase*.instance in their field initialisers, which throws if
    // Firebase isn't ready (the web demo, tests). The battle must RENDER and
    // PLAY without Firebase — reward persistence is best-effort, applied lazily
    // and fully guarded at victory (see _applyRewards).
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    _cue.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final ctrl = widget.controller;
    // Answer SFX on the phase TRANSITION (sound-feel parity with nazo/exam — the
    // flagship rescue loop was silent on every tap, reading as "did it work?" to a
    // 6yo). Transition-guarded so a same-phase re-notify can't double-fire. The
    // wrong tone honours the no-scold contract: teach/blend/word/phrase steps have
    // penalizeWrong==false → a wrong tap just replays audio, no red, no tone.
    if (ctrl.phase != _lastPhase) {
      if (ctrl.phase == BattlePhase.resolved) {
        if (ctrl.lastWasCorrect) {
          _sound.playCorrect();
        } else if (ctrl.currentStep.penalizeWrong) {
          _sound.playWrong();
        }
      } else if (ctrl.phase == BattlePhase.victory) {
        _sound.playSessionComplete();
      } else if (ctrl.phase == BattlePhase.defeat) {
        // Losing the LAST heart on a penalized wrong tap goes prompt→defeat
        // DIRECTLY, skipping resolved — so without this arm the losing tap was
        // silent. Give it the same wrong tone as any other penalized miss.
        if (ctrl.currentStep.penalizeWrong) _sound.playWrong();
      }
      _lastPhase = ctrl.phase;
    }
    // Combo flash when combo increments.
    if (ctrl.combo > _lastCombo) {
      _lastCombo = ctrl.combo;
      setState(() => _showComboFlash = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showComboFlash = false);
      });
    }
    // Auto-play audio on phase=prompt (new step entered from resolved).
    if (ctrl.phase == BattlePhase.prompt && ctrl.currentIndex > 0) {
      _maybeAutoPlay();
    }
    // Apply rewards exactly once on victory.
    if (ctrl.phase == BattlePhase.victory && !_rewardsApplied) {
      _rewardsApplied = true;
      _applyRewards();
    }
    setState(() {});
  }

  void _maybeAutoPlay() {
    final step = widget.controller.currentStep;
    _cue.play(step.autoPlayAudio);
    _sweepBlend();
  }

  void _sweepBlend() {
    _sweepTimer?.cancel();
    final step = widget.controller.currentStep;
    if (step is! BlendWord) {
      if (_activeLetter != -1) setState(() => _activeLetter = -1);
      return;
    }
    final n = step.letters.length;
    setState(() => _activeLetter = 0);
    var i = 0;
    _sweepTimer = Timer.periodic(const Duration(milliseconds: 460), (t) {
      i++;
      if (i >= n) {
        t.cancel();
        _sweepTimer = Timer(const Duration(milliseconds: 520), () {
          if (mounted) setState(() => _activeLetter = -1);
        });
      } else if (mounted) {
        setState(() => _activeLetter = i);
      }
    });
  }

  /// Best-effort reward persistence, applied once at victory. EVERYTHING here is
  /// guarded: if Firebase isn't initialised (web demo / tests) the game has
  /// already been played and we simply skip persistence rather than crash.
  Future<void> _applyRewards() async {
    try {
      // Stable uid: persists the real uid and reuses it when Firebase init
      // flakes, so reward writes never fork the durable deck (#14).
      final uid = widget.uid ?? await AuthService().resolveUid();
      final repo = widget.repository ??
          (() {
            try {
              return FirestoreFsrsCardRepository() as FsrsCardRepository;
            } catch (_) {
              return InMemoryFsrsCardRepository();
            }
          }());
      final rewards = BattleRewards(
        repository: repo,
        xpService: XpService(),
        streakService: StreakService(),
      );
      await rewards.applyRewards(
        uid: uid,
        stepResults: widget.controller.stepResults,
      );
    } catch (_) {
      // Persistence is best-effort; never let it break a won battle.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return DqScene(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          children: [
            _buildHeader(ctrl),
            const SizedBox(height: 6),
            _buildSilenceMeter(ctrl),
            const SizedBox(height: 6),
            _buildHearts(ctrl),
            const SizedBox(height: 4),
            // The prompt plays a phoneme/word the child must HEAR to pick the
            // right answer — if Voice is muted, warn + offer a one-tap unmute.
            if (ctrl.phase == BattlePhase.prompt &&
                AudioMute.voiceMuted &&
                ctrl.currentStep.autoPlayAudio != null) ...[
              MutedVoiceBanner(
                onUnmute: () => setState(() {}),
                message: kPhonicsMutedMessage,
              ),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                // Top-align the incoming/outgoing children so short content
                // never floats centred in the Expanded, leaving a dead void
                // in the middle of the screen (CEO-flagged 390×844 defect).
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: KeyedSubtree(
                  key: ValueKey(
                      'phase_${ctrl.phase.name}_${ctrl.currentIndex}_${ctrl.lastPicked}'),
                  child: switch (ctrl.phase) {
                    BattlePhase.intro => _buildIntro(ctrl),
                    BattlePhase.prompt => _buildPrompt(ctrl),
                    BattlePhase.resolved => _buildResolved(ctrl),
                    BattlePhase.victory => _buildVictory(ctrl),
                    BattlePhase.defeat => _buildDefeat(ctrl),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(SilentBattleController ctrl) {
    return Row(
      children: [
        IconButton(
          tooltip: 'もどる / Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: dqInk),
        ),
        Expanded(
          child: Center(
            child: dqBilingual(
              'サイレントじけん',
              'The Silent Case',
              jpSize: 16,
              jpColor: dqGold,
              stacked: true,
              align: TextAlign.center,
            ),
          ),
        ),
        if (_showComboFlash && ctrl.combo >= 2) _ComboFlash(combo: ctrl.combo),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── しずけさ meter ─────────────────────────────────────────────────────────

  Widget _buildSilenceMeter(SilentBattleController ctrl) {
    final total = ctrl.steps.length;
    final remaining = ctrl.silenceMeter;
    final progress = total == 0 ? 0.0 : (total - remaining) / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('しずけさ', style: dqText(size: 11, color: dqGoldDeep)),
            const Spacer(),
            Text('$remaining / $total',
                style: dqText(size: 11, color: dqGoldDeep)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: dqNight0,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: dqBorder, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(const Color(0xFF7B6FA0), dqGold, progress)!,
              ),
              minHeight: 10,
            ),
          ),
        ),
      ],
    );
  }

  // ── こころ hearts ──────────────────────────────────────────────────────────

  Widget _buildHearts(SilentBattleController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('こころ  ', style: dqText(size: 12, color: dqInk)),
        for (var i = 0; i < ctrl.maxHeartsValue; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: i < ctrl.hearts ? 1.0 : 0.25,
              child: Text(
                '♥',
                style: TextStyle(
                  fontSize: 22,
                  color: i < ctrl.hearts ? const Color(0xFFFF6B8A) : dqGoldDeep,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Intro phase ───────────────────────────────────────────────────────────
  //
  // Vertical rhythm: hero portrait (upper-third anchor) → tension narration
  // (middle) → CTA button (bottom). Uses LayoutBuilder+ConstrainedBox so the
  // content stretches to fill the available height via spaceBetween and scrolls
  // safely when OS text-scale pushes total content beyond the viewport.

  Widget _buildIntro(SilentBattleController ctrl) {
    final firstStep = ctrl.steps.first;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Upper anchor: enlarged grey portrait as the encounter HERO.
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _GreyPortrait(
                  npcName: firstStep.npcName,
                  npcEmoji: firstStep.npcEmoji,
                  size: 128,
                ),
              ),
              // ── Middle: tension narration.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: DqDialogBox(
                  speaker: 'サイレント',
                  child: Text(
                    'サイレントが ${firstStep.npcName} を つつんでいる。\nことばを となえて！',
                    style: dqText(size: 15),
                  ),
                ),
              ),
              // ── Bottom: action CTA.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DqButton(
                  label: '▶ となえる！',
                  onTap: () {
                    widget.controller.startBattle();
                    _maybeAutoPlay();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Prompt phase ──────────────────────────────────────────────────────────
  //
  // Rhythm: enlarged portrait hero (upper) → step body (middle) →
  // answer block (prompt label + options, bottom). LayoutBuilder+ConstrainedBox
  // guarantees fill with spaceBetween; scrolls at large OS text scale.

  Widget _buildPrompt(SilentBattleController ctrl) {
    final step = ctrl.currentStep;
    final colourProgress =
        ctrl.steps.isNotEmpty ? ctrl.clearedSteps / ctrl.steps.length : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Upper anchor: colour-revealing portrait (the tension hero).
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PortraitReveal(
                  npcName: step.npcName,
                  npcEmoji: step.npcEmoji,
                  colourProgress: colourProgress,
                  size: 128,
                ),
              ),
              // ── Middle: question / step body.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildStepBody(step),
              ),
              // ── Bottom: answer block (prompt label + choices).
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.practicePromptJa ?? '正（ただ）しい返事（へんじ）をえらぼう',
                    style: dqText(size: 12, color: dqGold),
                  ),
                  const SizedBox(height: 8),
                  ..._buildOptions(step, ctrl),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Resolved phase ────────────────────────────────────────────────────────
  //
  // Rhythm: portrait hero (upper) → step body + answered options (middle) →
  // feedback dialog + advance CTA (bottom). Same LayoutBuilder fill pattern.

  Widget _buildResolved(SilentBattleController ctrl) {
    final step = ctrl.currentStep;
    final correct = ctrl.lastWasCorrect;
    final colourProgress =
        ctrl.steps.isNotEmpty ? ctrl.clearedSteps / ctrl.steps.length : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Upper anchor: portrait hero.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PortraitReveal(
                  npcName: step.npcName,
                  npcEmoji: step.npcEmoji,
                  colourProgress: colourProgress,
                  size: 128,
                ),
              ),
              // ── Middle: step body + answered options.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepBody(step),
                    const SizedBox(height: 10),
                    Text(
                      step.practicePromptJa ?? '正（ただ）しい返事（へんじ）をえらぼう',
                      style: dqText(size: 12, color: dqGold),
                    ),
                    const SizedBox(height: 8),
                    ..._buildOptions(step, ctrl),
                  ],
                ),
              ),
              // ── Bottom: feedback + advance CTA.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (correct) ...[
                      DqDialogBox(
                        speaker: step.npcName,
                        child: Text(step.onCorrect, style: dqText(size: 15)),
                      ),
                      const SizedBox(height: 14),
                      DqButton(
                        label: _isLastStep(ctrl) ? 'むらびとをすくった！' : 'つぎの てがかりへ',
                        onTap: () => widget.controller.advance(),
                      ),
                    ] else ...[
                      DqDialogBox(
                        child: Text(
                          'もういちど となえて！',
                          style: dqText(size: 15, color: dqGold),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DqButton(
                        label: '▶ もういちど',
                        onTap: () => widget.controller.advance(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isLastStep(SilentBattleController ctrl) =>
      ctrl.currentIndex == ctrl.steps.length - 1;

  // ── Victory phase ─────────────────────────────────────────────────────────
  //
  // Rhythm: full-colour restored portrait (upper hero) → NPC speech (middle) →
  // rewards + CTA (bottom). Fills available height; scrolls on large text scale.

  Widget _buildVictory(SilentBattleController ctrl) {
    final xp = BattleRewards.totalXp(ctrl.stepResults);
    final step = ctrl.steps.last;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Upper anchor: full-colour portrait (colour restored = victory).
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: DqPortrait(
                  imageAsset: QuestScreen.npcImage(step.npcName),
                  emoji: step.npcEmoji,
                  size: 128,
                ),
              ),
              // ── Middle: NPC victory speech.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: DqDialogBox(
                  speaker: step.npcName,
                  child: Text(step.onCorrect, style: dqText(size: 15)),
                ),
              ),
              // ── Bottom: rewards summary + advance CTA.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShardsRow(shards: ctrl.shards),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: dqNight0.withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: dqGold.withAlpha(160), width: 1.5),
                      ),
                      child: Text(
                        '✨ +$xp XP 獲得！',
                        style:
                            dqText(size: 16, w: FontWeight.w800, color: dqGold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DqButton(
                      label: 'つぎの てがかりへ',
                      onTap: widget.onVictory ??
                          () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Defeat phase ──────────────────────────────────────────────────────────
  //
  // Rhythm: greyed portrait (still silenced — upper) → failure narration
  // (middle) → shards + retry/exit CTAs (bottom). Same fill+scroll pattern.

  Widget _buildDefeat(SilentBattleController ctrl) {
    final step = ctrl.currentStep;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Upper anchor: still-grey portrait (villager still silenced).
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _GreyPortrait(
                  npcName: step.npcName,
                  npcEmoji: step.npcEmoji,
                  size: 128,
                ),
              ),
              // ── Middle: failure narration.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: DqDialogBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ことばが まだ たりない…',
                        style:
                            dqText(size: 18, w: FontWeight.w800, color: dqInk),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'あつめた かけらは のこっている。\nもういちど ことばを となえに いこう。',
                        style: dqText(size: 14),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Bottom: shard count + retry / exit CTAs.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShardsRow(shards: ctrl.shards),
                    const SizedBox(height: 20),
                    DqButton(
                      label: '▶ もういちど となえる',
                      onTap: () => widget.controller.reset(),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: widget.onDefeat ??
                          () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '街（まち）の ちずへ',
                          style: dqText(size: 14, color: dqGoldDeep),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step body — VERBATIM kind-dispatch from quest_screen.dart
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepBody(QuestStep step) {
    return switch (step) {
      TeachSound s => PhonicsLetterCard(
          glyph: s.glyph,
          npcName: s.npcName,
          npcEmoji: s.npcEmoji,
          npcImage: QuestScreen.npcImage(s.npcName),
          teachJa: s.teachJa,
          onReplay: () => _cue.play(s.autoPlayAudio),
        ),
      BlendWord s => BlendWordCard(
          letters: s.letters,
          word: s.word,
          npcName: s.npcName,
          npcEmoji: s.npcEmoji,
          npcImage: QuestScreen.npcImage(s.npcName),
          teachJa: s.teachJa,
          activeLetter: _activeLetter,
          onReplay: () {
            _cue.play(s.autoPlayAudio);
            _sweepBlend();
          },
        ),
      TeachWord s => PhonicsLetterCard(
          glyph: s.word,
          npcName: s.npcName,
          npcEmoji: s.npcEmoji,
          npcImage: QuestScreen.npcImage(s.npcName),
          teachJa: s.teachJa,
          onReplay: () => _cue.play(s.autoPlayAudio),
        ),
      Phrase s => PhonicsLetterCard(
          glyph: s.text,
          npcName: s.npcName,
          npcEmoji: s.npcEmoji,
          npcImage: QuestScreen.npcImage(s.npcName),
          teachJa: s.teachJa,
          onReplay: () => _cue.play(s.autoPlayAudio),
        ),
      QuestEncounter q => _buildQuizPrompt(q),
    };
  }

  Widget _buildQuizPrompt(QuestEncounter q) {
    return Column(
      children: [
        DqPortrait(
          imageAsset: QuestScreen.npcImage(q.npcName),
          emoji: q.npcEmoji,
          size: 76,
        ),
        const SizedBox(height: 16),
        DqDialogBox(
          speaker: q.npcName,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.npcLine, style: dqText(size: 19, w: FontWeight.w700)),
              if (q.npcLineJa != null) ...[
                const SizedBox(height: 8),
                Text(q.npcLineJa!,
                    style: dqText(size: 12, color: dqInk, w: FontWeight.w400)),
              ],
            ],
          ),
        ),
        if (q.autoPlayAudio != null) ...[
          const SizedBox(height: 12),
          DqReplayButton(
            onTap: () => _cue.play(q.autoPlayAudio),
            label: '🔊 もういちど きく',
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Options — verbatim from quest_screen._options() with battle state mapping
  // ─────────────────────────────────────────────────────────────────────────

  List<Widget> _buildOptions(QuestStep step, SilentBattleController ctrl) {
    final opts = step.options;
    final phase = ctrl.phase;
    final picked = ctrl.lastPicked;
    final correct = ctrl.lastWasCorrect;

    return List.generate(opts.length, (i) {
      final o = opts[i];
      final isCorrect = i == step.correctIndex;

      DqChoiceState st = DqChoiceState.normal;
      if (phase == BattlePhase.resolved && correct && isCorrect) {
        st = DqChoiceState.correct;
      } else if (step.penalizeWrong &&
          phase == BattlePhase.resolved &&
          !correct &&
          picked == i &&
          !isCorrect) {
        st = DqChoiceState.wrong;
      }

      final audioKey = o.audioAsset ?? quizAudioAsset(o.label);
      return AudioOptionButton(
        label: o.label,
        state: st,
        onAudio: audioKey == null ? null : () => _cue.play(audioKey),
        onChoose: (phase == BattlePhase.prompt)
            ? () {
                final replayKey = widget.controller.castTap(i);
                if (replayKey != null) {
                  _cue.play(replayKey);
                }
              }
            : null,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Portrait with a greyscale colour filter.
class _GreyPortrait extends StatelessWidget {
  final String npcName;
  final String npcEmoji;
  final double size;

  const _GreyPortrait({
    required this.npcName,
    required this.npcEmoji,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.213,
        0.715,
        0.072,
        0,
        0,
        0.213,
        0.715,
        0.072,
        0,
        0,
        0.213,
        0.715,
        0.072,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: DqPortrait(
        imageAsset: QuestScreen.npcImage(npcName),
        emoji: npcEmoji,
        size: size,
      ),
    );
  }
}

/// Portrait that fades from greyscale to full colour as [colourProgress] rises.
/// Uses a linearly interpolated ColorFilter matrix — no extra packages needed.
class _PortraitReveal extends StatelessWidget {
  final String npcName;
  final String npcEmoji;
  final double colourProgress; // 0.0 = full grey, 1.0 = full colour
  final double size;

  const _PortraitReveal({
    required this.npcName,
    required this.npcEmoji,
    required this.colourProgress,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    final t = colourProgress.clamp(0.0, 1.0);
    // Interpolate: greyscale matrix → identity matrix.
    // greyscale row = [.213, .715, .072, 0, 0]
    // identity row  = [1,    0,    0,    0, 0] / [0, 1, 0, 0, 0] / [0, 0, 1, 0, 0]
    final r0 = 0.213 + t * (1 - 0.213);
    final r1 = 0.715 * (1 - t);
    final r2 = 0.072 * (1 - t);
    final g0 = 0.213 * (1 - t);
    final g1 = 0.715 + t * (1 - 0.715);
    final g2 = 0.072 * (1 - t);
    final b0 = 0.213 * (1 - t);
    final b1 = 0.715 * (1 - t);
    final b2 = 0.072 + t * (1 - 0.072);

    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        r0,
        r1,
        r2,
        0,
        0,
        g0,
        g1,
        g2,
        0,
        0,
        b0,
        b1,
        b2,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: DqPortrait(
        imageAsset: QuestScreen.npcImage(npcName),
        emoji: npcEmoji,
        size: size,
      ),
    );
  }
}

/// Combo flash badge (てがかり clue-combo multiplier display).
class _ComboFlash extends StatelessWidget {
  final int combo;
  const _ComboFlash({required this.combo});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.2, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: dqBorder, width: 1.5),
          boxShadow: [
            BoxShadow(color: dqGoldDeep.withAlpha(110), blurRadius: 8),
          ],
        ),
        child: Text(
          'てがかり × $combo',
          style: dqText(
            size: 12,
            w: FontWeight.w800,
            color: const Color(0xFF2A1C00),
          ),
        ),
      ),
    );
  }
}

/// 声のかけら shard count row.
class _ShardsRow extends StatelessWidget {
  final int shards;
  const _ShardsRow({required this.shards});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('声のかけら  ', style: dqText(size: 13, color: dqInk)),
        if (shards > 0)
          for (var i = 0; i < shards; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text('◆', style: dqText(size: 16, color: dqGold)),
            )
        else
          Text('—', style: dqText(size: 14, color: dqGoldDeep)),
      ],
    );
  }
}

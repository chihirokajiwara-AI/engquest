// lib/features/explore/nazo_screen.dart
// Wave 1 — ナゾ screen: presents a QuestStep as a Layton-style ナゾ puzzle.
//
// REUSES quest_screen's _quizPrompt/_options rendering via the shared widgets
// in dq_ui.dart (DqPortrait, DqDialogBox, AudioOptionButton, DqChoiceState).
// Does NOT duplicate quiz rendering logic.
//
// Added envelope:
//   • Optional [framingJa] line above the stem (in-world flavour, exam unchanged).
//   • ピカラット decay display (PicaratController) — wrong tap decays, no fail.
//   • 3-tier ひらめきコイン hint ladder (HintCoinService + NazoHint) — teaches,
//     never reveals the answer.
//   • On correct: reports [NazoResult] with earned ピカラット + solved flag back
//     to the caller (SceneView cross-fades grey→color).
//
// NO dart:io. Firebase is never touched here.

import 'package:flutter/material.dart';

import '../../core/audio/audio_assets.dart';
import '../../core/audio/audio_cue_service.dart';
import '../../core/audio/audio_mute.dart';
import '../../core/gamification/hint_coin_service.dart';
import '../../core/gamification/picarat_controller.dart';
import '../../core/sound/sound_service.dart';
import '../quest/quest_data.dart';
import '../quest/quest_screen.dart' show QuestScreen;
import '../quest/ui/dq_ui.dart';
import '../quest/ui/muted_voice_banner.dart';
import 'hotspot.dart';

// ── Result returned to the caller on dismiss ─────────────────────────────────

class NazoResult {
  final bool solved;
  final int picaratEarned;

  /// Whether the learner's FIRST answer was correct. Feeds 合格率 honestly: a
  /// ナゾ can be retried until solved, so [solved] alone would record every
  /// puzzle as 100% and inflate the pass meter — first-try correctness is the
  /// real comprehension signal. Defaults to false (e.g. an abandoned puzzle).
  final bool firstTryCorrect;

  const NazoResult({
    required this.solved,
    required this.picaratEarned,
    this.firstTryCorrect = false,
  });
}

// ── NazoScreen ────────────────────────────────────────────────────────────────

class NazoScreen extends StatefulWidget {
  final Hotspot hotspot;

  /// The 英検 level string for the town (drives hint text + ピカラット max).
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
  late final PicaratController _picarat;
  late final HintCoinService _coins;
  final _cue = AudioCueService();
  final _sound = SoundService();

  int? _picked;
  bool _revealed = false;
  // First-answer tracking for an honest 合格率 signal (#89): record whether the
  // child's very first choice was correct, regardless of later retries.
  bool _firstAttempted = false;
  bool _firstTryCorrect = false;
  int _coinBalance = 0;
  int _hintsShown = 0; // 0 = none; 1/2/3 = tiers revealed so far
  bool _coinLoading = false;
  // True when this ナゾ references an audio clip that isn't bundled (e.g. the
  // founder-pending 5級 phonemes). We then hide the dead 🔊 button + show an
  // honest "準備中" note instead of leaving the child with silence (#43).
  bool _audioMissing = false;

  QuestStep get _step => widget.hotspot.step!;

  @override
  void initState() {
    super.initState();
    _picarat = PicaratController(
      maxValue: picaratMaxForGrade(widget.eikenLevel),
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
    if (!correct && !_step.penalizeWrong) {
      // No-scold: replay the audio without advancing.
      _cue.play(_step.autoPlayAudio);
      return;
    }
    if (!correct) {
      _picarat.onWrong();
      _sound.playWrong();
    }
    setState(() {
      _picked = i;
      _revealed = correct;
      if (_revealed) _sound.playCorrect();
    });
  }

  void _finish() {
    final earned = _picarat.earn();
    Navigator.of(context).pop(NazoResult(
      solved: true,
      picaratEarned: earned,
      firstTryCorrect: _firstTryCorrect,
    ));
  }

  void _dismiss() {
    Navigator.of(context)
        .pop(const NazoResult(solved: false, picaratEarned: 0));
  }

  // ── Hint ladder ───────────────────────────────────────────────────────────

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
    return DqScene(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 12),
              _picaratRow(),
              const SizedBox(height: 12),
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
              if (_revealed) ...[
                const SizedBox(height: 12),
                DqDialogBox(
                  speaker: _step.npcName,
                  child: Text(_step.onCorrect, style: dqText(size: 15)),
                ),
                const SizedBox(height: 16),
                DqButton(label: '▶ ナゾ、解（と）けた！', onTap: _finish),
              ] else ...[
                const SizedBox(height: 16),
                _hintLadder(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
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

  Widget _header() => Row(
        children: [
          IconButton(
            onPressed: _dismiss,
            icon: const Icon(Icons.close, color: dqInk),
          ),
          Expanded(
            child: Text(
              '「？」ナゾが あらわれた！',
              textAlign: TextAlign.center,
              style: dqText(size: 16, w: FontWeight.w800, color: dqGold),
            ),
          ),
          // Coin balance display
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✦',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
                const SizedBox(width: 3),
                Text('$_coinBalance', style: dqText(size: 14, color: dqGold)),
              ],
            ),
          ),
        ],
      );

  Widget _picaratRow() {
    final current = _picarat.currentValue;
    final max = picaratMaxForGrade(widget.eikenLevel);
    final isFull = _picarat.wrongCount == 0;
    return DqPanel(
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
                  'ピカラット',
                  style: dqText(
                      size: 11, color: dqGold, w: FontWeight.w800, spacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  '$current / $max',
                  style: dqText(
                    size: 18,
                    w: FontWeight.w800,
                    color: isFull ? dqGold : const Color(0xFFE89090),
                  ),
                ),
              ],
            ),
          ),
          if (_picarat.wrongCount > 0)
            Text(
              '↓ まちがい × ${_picarat.wrongCount}',
              style: dqText(size: 11, color: const Color(0xFFE89090)),
            ),
        ],
      ),
    );
  }

  /// In-world framing line above the stem — exam content is UNCHANGED below it.
  Widget _framingBox() => DqPanel(
        title: 'じょうきょう / Scene',
        child: Text(
          widget.hotspot.framingJa!,
          style: dqText(size: 13, w: FontWeight.w500, color: dqInk)
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
            imageAsset: QuestScreen.npcImage(step.npcName),
            emoji: step.npcEmoji,
            size: 76,
          ),
          const SizedBox(height: 16),
          DqDialogBox(
            speaker: step.npcName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.npcLine, style: dqText(size: 19, w: FontWeight.w700)),
                if (step.npcLineJa != null) ...[
                  const SizedBox(height: 8),
                  Text(step.npcLineJa!,
                      style:
                          dqText(size: 12, color: dqInk, w: FontWeight.w400)),
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
          imageAsset: QuestScreen.npcImage(step.npcName),
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
          style: dqText(size: 12, color: dqGold),
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
        label: o.label,
        state: st,
        onAudio: onAudio,
        onChoose: _revealed ? null : () => _choose(i),
      );
    });
  }

  // ── Hint ladder ───────────────────────────────────────────────────────────

  Widget _hintLadder() {
    final hints = defaultHintsForLevel(widget.eikenLevel);
    return DqPanel(
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
    return GestureDetector(
      onTap: (unlocked || _coinLoading || _revealed)
          ? null
          : () => _tryUnlockHint(tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFF1A3522).withAlpha(210)
              : dqBox.withAlpha(200),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: unlocked ? const Color(0xFF8BE08B) : dqGoldDeep,
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
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFB8923C),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: unlocked
                  ? Text(hint.textJa,
                      style: dqText(size: 13, w: FontWeight.w500, color: dqInk)
                          .copyWith(height: 1.6))
                  : Text(
                      'T$tier ヒント — コイン $cost 枚（まい）',
                      style: dqText(size: 13, color: dqGold),
                    ),
            ),
            if (!unlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✦',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 13)),
                  const SizedBox(width: 2),
                  Text('$cost', style: dqText(size: 13, color: dqGold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

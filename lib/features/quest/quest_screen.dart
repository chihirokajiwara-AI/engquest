// lib/features/quest/quest_screen.dart
// A-KEN Quest — play one town in the 本格 scene framework:
// intro (narration box) → villager dialogue + English quiz (NPC portrait,
// dialogue box, command-window choices) → cleared (声の石 reward).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../character/progress_tinted_character.dart';

import '../../core/audio/audio_cue_service.dart';
import '../../core/audio/audio_mute.dart';
import '../../core/sound/sound_service.dart';
import 'quest_data.dart';
import 'ui/dq_ui.dart';
import 'ui/muted_voice_banner.dart';
import '../exam_practice/eiken_exam_config.dart';

class QuestScreen extends StatefulWidget {
  final QuestTown town;

  /// Design-audit only: jump straight to this encounter index (skips intro).
  final int? previewEncounterIndex;
  const QuestScreen(
      {super.key, required this.town, this.previewEncounterIndex});

  @override
  State<QuestScreen> createState() => _QuestScreenState();

  /// Maps an NPC name to a generated portrait asset path, or null if none
  /// is defined. Public so [SilentBattleScreen] and related widgets can reuse
  /// the same mapping without duplicating it.
  static String? npcImage(String name) => _QuestScreenState._npcImage(name);
}

enum _Phase { intro, encounter, cleared }

class _QuestScreenState extends State<QuestScreen> {
  // 声の石 per town, by order.
  static const _stoneNames = [
    'あいさつの石',
    'くらしの石',
    'まなびの石',
    'しゃかいの石',
    'しれんの石',
    'がくもんの石',
    '王（おう）の石',
  ];
  static const _stoneColors = [
    Color(0xFF6FC9FF),
    Color(0xFF7BE08B),
    Color(0xFFFFC857),
    Color(0xFF4FD6E0),
    Color(0xFFC58BEA),
    Color(0xFFFF8A8A),
    Color(0xFFFFD86A),
  ];

  final _sound = SoundService();
  final _cue = AudioCueService();
  _Phase _phase = _Phase.intro;
  int _index = 0;
  int? _picked;
  bool _revealed = false;

  // Blend-letter sweep: the c→a→t tiles light up in turn while the segmented
  // blend clip plays (-1 = none / whole word). Driven from the audio gesture so
  // the highlight roughly tracks "c…a…t……cat".
  int _activeLetter = -1;
  Timer? _sweepTimer;

  @override
  void initState() {
    super.initState();
    final p = widget.previewEncounterIndex;
    if (p != null && _hasEncounters) {
      _phase = _Phase.encounter;
      _index = p.clamp(0, widget.town.encounters.length - 1);
      // NOTE: do NOT auto-play here — initState is not a user gesture, so web
      // would throw NotAllowedError. The always-visible 🔊 button is the path.
    }
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    _cue.dispose();
    super.dispose();
  }

  QuestStep get _enc => widget.town.encounters[_index];

  /// Play the current step's auto-play clip. Only safe from a user-gesture
  /// chain (_start/_next/_choose). Best-effort; swallows errors.
  void _autoPlayCurrent() {
    _cue.play(_enc.autoPlayAudio);
    _sweepBlend();
  }

  /// Light the blend tiles c→a→t in turn, then hold the whole word and clear.
  /// Approximate sync to the segmented clip (no per-segment timestamps); the
  /// goal is the visual "tie the sounds together" cue, not frame-accuracy.
  /// Safe for non-blend steps (resets the highlight and returns).
  void _sweepBlend() {
    _sweepTimer?.cancel();
    final step = _enc;
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

  bool get _hasEncounters => widget.town.encounters.isNotEmpty;
  int get _townIdx => kQuestTowns.indexWhere((t) => t.id == widget.town.id);
  String get _stoneName => _townIdx >= 0 && _townIdx < _stoneNames.length
      ? _stoneNames[_townIdx]
      : 'こえの石';
  Color get _stoneColor => _townIdx >= 0 && _townIdx < _stoneColors.length
      ? _stoneColors[_townIdx]
      : dqGold;

  // Optional per-town scene art (falls back to the night gradient).
  String get _sceneAsset =>
      'assets/art/scenes/town_${widget.town.eikenLevel}.png';

  void _start() {
    setState(() => _phase = _hasEncounters ? _Phase.encounter : _Phase.cleared);
    // _start is a tap handler → safe to auto-play the first step's clip.
    if (_phase == _Phase.encounter) _autoPlayCurrent();
  }

  void _choose(int i) {
    if (_revealed) return;
    final correct = i == _enc.correctIndex;
    if (!correct && !_enc.penalizeWrong) {
      // No-scold (teach/blend/word/phrase): a wrong tap replays the audio and
      // keeps the card active — never red, never advancing. The wrong-chime +
      // haptic confirm the tap REGISTERED (it used to be silent here, so a wrong
      // tap felt broken on a phone). Mirrors nazo_screen; respects the SFX mute.
      _sound.playWrong();
      HapticFeedback.selectionClick();
      _cue.play(_enc.autoPlayAudio);
      return;
    }
    setState(() {
      _picked = i;
      _revealed = correct;
      if (_revealed) {
        _sound.playCorrect();
        HapticFeedback
            .lightImpact(); // pair the chime with a tick (mirror nazo)
      }
    });
  }

  void _next() {
    setState(() {
      if (_index < widget.town.encounters.length - 1) {
        _index++;
        _picked = null;
        _revealed = false;
      } else {
        _phase = _Phase.cleared;
        _sound.playLevelUp();
      }
    });
    // _next is a tap handler → safe to auto-play the new step's clip.
    if (_phase == _Phase.encounter) _autoPlayCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      backgroundAsset: _sceneAsset,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: switch (_phase) {
          _Phase.intro => _intro(),
          _Phase.encounter => _encounter(),
          _Phase.cleared => _cleared(),
        },
      ),
    );
  }

  Widget _header(String title) => Row(
        children: [
          IconButton(
            tooltip: 'もどる / Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: dqInk),
          ),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: dqText(size: 18, w: FontWeight.w800, color: dqGold)),
          ),
          const SizedBox(width: 48),
        ],
      );

  Widget _intro() {
    return Column(
      children: [
        _header('${widget.town.name}（${gradeLabelJa(widget.town.eikenLevel)}）'),
        const Spacer(),
        DqDialogBox(
          speaker: 'ものがたり',
          child: Text(widget.town.intro, style: dqText(size: 15)),
        ),
        const SizedBox(height: 24),
        DqButton(
            label: _hasEncounters ? '捜査（そうさ）を はじめる' : '準備中',
            onTap: _hasEncounters ? _start : null),
        const Spacer(),
      ],
    );
  }

  Widget _encounter() {
    final total = widget.town.encounters.length;
    final step = _enc;
    // Header pinned to the top; the puzzle body CENTRES in the remaining space
    // (scrolls when tall) so a short quiz fills the screen instead of clinging to
    // the top over a dead navy void (#112 / EIKEN5-LAYTON-NAZO-PLAN.md #4).
    return Column(
      children: [
        _header('${_index + 1} / $total'),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // This step plays a phoneme/word the child must HEAR — if Voice is
                    // muted, warn + offer a one-tap unmute.
                    if (AudioMute.voiceMuted && step.autoPlayAudio != null) ...[
                      MutedVoiceBanner(
                        onUnmute: () => setState(() {}),
                        message: kPhonicsMutedMessage,
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Kind-dispatch: phonics/blend/word/phrase get a teach card; Quiz keeps
                    // the original NPC-dialogue layout.
                    switch (step) {
                      TeachSound s => PhonicsLetterCard(
                          glyph: s.glyph,
                          npcName: s.npcName,
                          npcEmoji: s.npcEmoji,
                          npcImage: _npcImage(s.npcName),
                          teachJa: s.teachJa,
                          onReplay: () => _cue.play(s.autoPlayAudio),
                        ),
                      BlendWord s => BlendWordCard(
                          letters: s.letters,
                          word: s.word,
                          npcName: s.npcName,
                          npcEmoji: s.npcEmoji,
                          npcImage: _npcImage(s.npcName),
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
                          npcImage: _npcImage(s.npcName),
                          teachJa: s.teachJa,
                          onReplay: () => _cue.play(s.autoPlayAudio),
                        ),
                      Phrase s => PhonicsLetterCard(
                          glyph: s.text,
                          npcName: s.npcName,
                          npcEmoji: s.npcEmoji,
                          npcImage: _npcImage(s.npcName),
                          teachJa: s.teachJa,
                          onReplay: () => _cue.play(s.autoPlayAudio),
                        ),
                      QuestEncounter q => _quizPrompt(q),
                    },
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          step.practicePromptJa ?? '正（ただ）しい返事（へんじ）をえらぼう',
                          style: dqText(size: 12, color: dqGold)),
                    ),
                    const SizedBox(height: 8),
                    ..._options(step),
                    if (_revealed) ...[
                      const SizedBox(height: 8),
                      DqDialogBox(
                        speaker: step.npcName,
                        child: Text(step.onCorrect, style: dqText(size: 15)),
                      ),
                      const SizedBox(height: 16),
                      DqButton(
                          label: _index < total - 1
                              ? 'つぎの てがかりへ'
                              : '街（まち）を 解決（かいけつ）！',
                          onTap: _next),
                    ],
                    const SizedBox(height: 20),
                    _party(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The Quiz step's NPC portrait + dialogue (unchanged from the original).
  static String? _npcImage(String name) {
    const m = {
      'タロ': 'assets/art/masters/slime.webp',
      'サイレント': 'assets/art/npc/silentus.webp',
      '賢者': 'assets/art/npc/sage.webp',
      '灰守': 'assets/art/npc/sage.webp',
      'がくしゃ': 'assets/art/npc/sage.webp',
      'せんせい': 'assets/art/npc/sage.webp',
      'むらおさ': 'assets/art/npc/sage.webp',
      'もんばん': 'assets/art/npc/gatekeeper.webp',
      'へいし': 'assets/art/npc/gatekeeper.webp',
      'きし': 'assets/art/npc/gatekeeper.webp',
      'ミィ': 'assets/art/npc/girl_cat.webp',
      'おんなのこ': 'assets/art/npc/girl_cat.webp',
      'ねこ': 'assets/art/npc/girl_cat.webp',
      'いぬ': 'assets/art/npc/boy_dog.webp',
      'おとこのこ': 'assets/art/npc/boy_dog.webp',
      'こども': 'assets/art/npc/boy_dog.webp',
      'おばあさん': 'assets/art/npc/old_woman.webp',
      'おかあさん': 'assets/art/npc/old_woman.webp',
      'パンや': 'assets/art/npc/baker.webp',
      'やおや': 'assets/art/npc/baker.webp',
      'みせ': 'assets/art/npc/baker.webp',
      'しょうにん': 'assets/art/npc/baker.webp',
      'りょうし': 'assets/art/npc/fisherman.webp',
      'かいぞく': 'assets/art/npc/fisherman.webp',
      'おじいさん': 'assets/art/npc/fisherman.webp',
      'おんがくか': 'assets/art/npc/musician.webp',
      'しじん': 'assets/art/npc/musician.webp',
      'たびびと': 'assets/art/npc/villager.webp',
      'むらびと': 'assets/art/npc/villager.webp',
      'はなや': 'assets/art/npc/villager.webp',
    };
    for (final e in m.entries) {
      if (name.contains(e.key)) return e.value;
    }
    return null;
  }

  Widget _quizPrompt(QuestEncounter q) => Column(
        children: [
          DqPortrait(
              imageAsset: _npcImage(q.npcName), emoji: q.npcEmoji, size: 76),
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
                      style:
                          dqText(size: 12, color: dqInk, w: FontWeight.w400)),
                ],
              ],
            ),
          ),
          // Hear the English line. Only for 応答型 (complete-question) encounters
          // that carry line audio — cloze (穴埋め) lines are NOT auto-voiced here
          // (the model answer would spoil the blank); they model the full answer
          // on reveal instead. Shown only when a line clip is wired.
          if (q.autoPlayAudio != null) ...[
            const SizedBox(height: 12),
            DqReplayButton(
              onTap: () => _cue.play(q.autoPlayAudio),
              label: '🔊 もういちど きく',
            ),
          ],
        ],
      );

  /// Render the option tiles. EVERY step (phonics teach AND grammar quiz) uses
  /// the 🔊 [AudioOptionButton]: its leading 🔊 auditions the option's clip
  /// without committing, the body taps to choose. Phonics options carry an
  /// explicit `audioAsset`; quiz options derive their clip from the label
  /// (`audio/quiz/<slug>.mp3`). Quiz steps still flash red on a wrong commit
  /// (penalizeWrong); teach steps never do.
  List<Widget> _options(QuestStep step) {
    final opts = step.options;
    return List.generate(opts.length, (i) {
      final o = opts[i];
      final correct = i == step.correctIndex;
      DqChoiceState st = DqChoiceState.normal;
      if (_revealed && correct) {
        st = DqChoiceState.correct;
      } else if (step.penalizeWrong && _picked == i && !correct) {
        st = DqChoiceState.wrong;
      }
      final audioKey = o.audioAsset ?? quizAudioAsset(o.label);
      return AudioOptionButton(
        label: o.label,
        state: st,
        onAudio: audioKey == null ? null : () => _cue.play(audioKey),
        onChoose: _revealed ? null : () => _choose(i),
      );
    });
  }

  Widget _cleared() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        _voiceStone(),
        const SizedBox(height: 20),
        Text('〈$_stoneName〉を手（て）に入（い）れた！',
            textAlign: TextAlign.center,
            style: dqText(size: 18, w: FontWeight.w800, color: _stoneColor)),
        const SizedBox(height: 16),
        DqDialogBox(
          child: Text(
            widget.town.cleared ?? '街（まち）に「ことば」がもどった。つぎの街へ、旅（たび）はつづく。',
            style: dqText(size: 14),
          ),
        ),
        const SizedBox(height: 24),
        DqButton(
            label: '街（まち）の ちずへ', onTap: () => Navigator.of(context).pop(true)),
        const Spacer(),
      ],
    );
  }

  Widget _voiceStone() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 750),
        curve: Curves.elasticOut,
        builder: (context, t, _) => Transform.scale(
          scale: t.clamp(0.0, 1.0),
          child: Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white, _stoneColor, _stoneColor.withAlpha(170)],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                    color: _stoneColor.withAlpha(150),
                    blurRadius: 34,
                    spreadRadius: 4)
              ],
            ),
            child:
                const Center(child: Text('💎', style: TextStyle(fontSize: 46))),
          ),
        ),
      );

  Widget _party() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(children: [
            // The player portrait must be the SAME detective main shown on home /
            // pass-meter (HeroChoice m5/m6), not a clashing armored-warrior asset —
            // 'きみ' is one character, one art style (CEO 1294 art-direction lock).
            DqPortrait(imageAsset: HeroChoice.asset, emoji: '🧭', size: 44),
            const SizedBox(height: 2),
            Text('きみ',
                style: dqText(size: 10, color: dqInk, w: FontWeight.w400)),
          ]),
          const SizedBox(width: 22),
          Column(children: [
            const DqPortrait(
                imageAsset: 'assets/art/masters/slime.webp',
                emoji: '🟢',
                size: 44),
            const SizedBox(height: 2),
            Text('タロ',
                style: dqText(size: 10, color: dqInk, w: FontWeight.w400)),
          ]),
        ],
      );
}

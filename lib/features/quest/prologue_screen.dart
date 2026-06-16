// lib/features/quest/prologue_screen.dart
// A-KEN Quest — the opening PROLOGUE (『ことばを失った世界』).
//
// Full-bleed cinematic opening — 5 kishōtenketsu (起承転結) beats with ONE
// protagonist, ランプ the lampkeeper (diverse-team redesign, CEO 1372/1375; the
// 英検5級 phonics story, CEO 1385): 起 his lamp won't catch ("す…") → 承 his memory
// blooms the grey square to colour → 転 the サイレント drains it back, but きみ can
// still hear → the BLEND beat: the child taps 🔊, joins s·a·t, and the lampkeeper
// is restored grey→colour → 結 his lamp lights, "…ありがとう", a quiet road ahead.
// The blend is a guaranteed win (no-scold). The win is restoration, not conquest.
//
// Plays once-ever (the caller persists that); skippable from panel 1. The blend
// beat sounds each phoneme on its OWN tap (phoneme_s/a/t.mp3, all recorded) and
// the joined word (blend_sat.mp3) on the 🔁「つなげて きく」 replay — so the child
// HEARS the segments, then the blend (independent judge panel wmlj5x22c #1).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_cue_service.dart';
import 'ui/dq_ui.dart';

class _Panel {
  final String jp;
  final String en;
  final String? audio; // best-effort cue key (graceful no-op if unrecorded)
  final bool interactive; // panel 5: the s·a·t blend demo
  final bool isLast;
  const _Panel(this.jp, this.en,
      {this.audio, this.interactive = false, this.isLast = false});
}

// The opening as 6 kishōtenketsu (起承転結) beats — one protagonist: ランプ the
// lampkeeper (diverse-team redesign, CEO 1372/1375; 英検5級 phonics story, CEO 1385).
// Deepened per CEO 1870/1872/1873 (iterated design wf wme3rp4q8, 3 critique→redesign
// rounds): the first blend is "sat" — the child COMPLETES the keeper's own lost /s/
// sound 「す…」 (was the disconnected "cat"); 承 grieves ONE named nightly ritual
// (mono-no-aware); 転 (loss) breathes on its own beat; 結 plants WORLD-BIBLE §2's
// inward spiral VISUALLY (the relit flame leans toward the centre — no English needed).
const _panels = <_Panel>[
  // 起 — the lamplighter's lamp won't catch; his one surviving sound is /s/.
  _Panel(
    'ランプばんの ランプが、\nつかない。\n「す…」',
    "The lamplighter's lamp won't catch. \"s…\"",
    audio: 'audio/phonics/phoneme_s.mp3',
  ),
  // 承 — ONE named nightly ritual (his lamp told the square "it's evening"),
  //      then colour. mono-no-aware on a specific lost habit, not just "colour".
  _Panel(
    'むかし、まいばん。\nランプばんが この ランプを ともすと、\nひろばは「もう よるだ」と わかった。\nそして、いろで あふれた。',
    'Every night, when the lamplighter lit this lamp, the square knew '
        '"it\'s evening now." And it overflowed with colour.',
  ),
  // 転 — the loss, on its own beat. Faceless Silence; colour and voice SLEEP
  //      (ねむった, not die); his lamp goes out too.
  _Panel(
    'でも、サイレントが きて、\nことばを たべてしまった。\nいろも、こえも、しずかに ねむった。\nランプの ひも、きえた。',
    'But the Silence came and ate the words. Colour and voice fell quietly '
        'asleep. The lamp went out too.',
  ),
  // 転→結 — the hope-turn (you can still hear + speak) joined to the playable
  //         errorless blend. "sat" completes the keeper's lost /s/ — motivated,
  //         not arbitrary; it also rehearses 5級 case-1's first blend.
  _Panel(
    'でも、きみには まだ きこえる。\nそして、まだ こえに だせる。\nタップして、おとを つなげてみよう。',
    'But you can still hear. And you can still speak. Tap, and join the sounds.',
    audio: 'audio/phonics/blend_sat.mp3',
    interactive: true,
  ),
  // 結 — payoff + mystery-plant: the relit flame leans toward the CENTRE,
  //      seeding WORLD-BIBLE §2's inward spiral visually (a non-reader reads it).
  _Panel(
    'ランプに、ひが ともった。\n「…ありがとう。」\nでも その ほのおは、\nまんなかへ かたむいてる。\nしずけさは、そとから きたんじゃない。\nまんなかから、あるいて きたんだ。',
    'The lamp is lit. "…thank you." But its flame leans toward the centre. '
        'The quiet didn\'t come from outside — it walked out from the middle.',
  ),
  // 結 — the clean single hook.
  _Panel(
    'きえた ことばを、ひとつずつ、\nとりもどしに いこう。',
    "Let's bring back the words, one by one.",
    isLast: true,
  ),
];

class PrologueScreen extends StatefulWidget {
  /// Called when the player finishes (or skips) the prologue.
  final VoidCallback onDone;

  /// Design-audit only: start on this panel (skips the tap-through to it).
  final int startIndex;
  const PrologueScreen({super.key, required this.onDone, this.startIndex = 0});

  @override
  State<PrologueScreen> createState() => _PrologueScreenState();
}

class _PrologueScreenState extends State<PrologueScreen>
    with SingleTickerProviderStateMixin {
  final _cue = AudioCueService();
  late int _index = widget.startIndex.clamp(0, _panels.length - 1);

  // The blend beat: each 🔊 tap lights + SOUNDS the next phoneme s→a→t (tap-
  // driven). Single source of truth for the letters (shared with the
  // BlendWordCard in _foregroundElement).
  static const _blendLetters = <String>['s', 'a', 't'];
  int _activeLetter = -1; // -1 none lit; 0=s, 1=a, 2=t
  bool _blendDone = false; // true once all three are sounded → join + restore

  // Council S3 — non-reader gate: a 4-7yo who can't read 「つぎへ」 needs a VISUAL
  // cue for what to tap. If the panel sits untapped ~4s, pulse the advance/🔊
  // control to draw the eye. Reset on any interaction; suppressed under
  // reduce-motion.
  bool _idleHint = false;
  Timer? _idleTimer;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  _Panel get _p => _panels[_index];

  @override
  void initState() {
    super.initState();
    // Auto-voice the FIRST panel's instruction for a non-reader (best-effort:
    // web autoplay may defer it to the first tap — AudioCueService swallows that;
    // the idle pulse + the child's first tap then start the audio).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_p.interactive && _p.audio != null) _cue.play(_p.audio);
      _armIdle();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _pulse.dispose();
    _cue.dispose();
    super.dispose();
  }

  /// (Re)start the idle countdown: clear the hint now, and if the child hasn't
  /// touched anything in 4s, raise it so the advance control pulses.
  void _armIdle() {
    _idleTimer?.cancel();
    if (_idleHint) setState(() => _idleHint = false);
    _pulse.stop();
    _pulse.value = 0;
    _idleTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _idleHint = true);
      // Only animate while actually idle — keeps the controller (and the test
      // clock) quiet until the hint is needed.
      _pulse.repeat(reverse: true);
    });
  }

  void _next() {
    if (_p.isLast) {
      widget.onDone();
      return;
    }
    setState(() {
      _index++;
      _activeLetter = -1;
      _blendDone = false;
    });
    // This runs from a tap (user gesture) → safe to fire audio on web, except on
    // the interactive panel where the child taps 🔊 themselves.
    if (!_p.interactive && _p.audio != null) _cue.play(_p.audio);
    _armIdle();
  }

  /// TAP-DRIVEN blend (the diverse-team design's core: the CHILD performs the
  /// blend, not an auto-animation). Each 🔊 tap lights the next phoneme s→a→t;
  /// the third tap joins them into "sat" and restores ランプ. Errorless — there
  /// is no wrong tap, only "not yet complete" (the no-scold spine).
  void _playBlend() {
    if (_activeLetter < _blendLetters.length - 1) {
      // Segmenting: light + SOUND the next phoneme on its OWN (s→a→t). The
      // independent judge panel (wf wmlj5x22c, finding #1) found every tap was
      // replaying the WHOLE word, so the child never heard the segments — the
      // entire point of a blend. Now each tap sounds that one phoneme; the lamp
      // + colour still restore the moment all three are done (_blendDone).
      setState(() {
        _activeLetter++;
        if (_activeLetter >= _blendLetters.length - 1) _blendDone = true;
      });
      _cue.play('audio/phonics/phoneme_${_blendLetters[_activeLetter]}.mp3');
    } else {
      // All three sounded → tapping the 🔁「つなげて きく」 plays the JOINED word
      // (the blend payoff). Colour + the lamp already restored on _blendDone.
      _cue.play(_p.audio); // blend_sat.mp3 — the segments joined into one word
    }
    _armIdle();
  }

  @override
  Widget build(BuildContext context) {
    // Full-bleed cinematic opening (diverse-team redesign, CEO 1372/1375): the
    // painted 灰色のひろば fills the whole screen; the narrative is a subtitle over
    // a bottom scrim — no bordered card, no DqDialogBox. The framed-thumbnail
    // "asset-preview slideshow" is gone.
    return ColoredBox(
      color: const Color(0xFF05060F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 0 — full-bleed background (the canonical grey square, every beat)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child:
                KeyedSubtree(key: ValueKey('bg$_index'), child: _background()),
          ),
          // 0b — ランプ the lampkeeper, the one face the child rescues
          _lampkeeper(),
          // 1 — bottom scrim so captions stay legible over the art
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 2 — content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onDone,
                      child: Text('スキップ ▶▶',
                          style: dqText(size: 12, color: dqInk)),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        child: KeyedSubtree(
                            key: ValueKey(_index), child: _foregroundElement()),
                      ),
                    ),
                  ),
                  // Cinema subtitle over the scrim (replaces the dialog box).
                  // Full-width + centred so long JP lines wrap instead of
                  // clipping at the screen edge.
                  SizedBox(
                    width: double.infinity,
                    // Council S3: liveRegion so a screen reader ANNOUNCES each
                    // beat's line when the panel changes (not only when focused),
                    // keeping a non-visual child in step with the cutscene.
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_p.jp,
                          textAlign: TextAlign.center,
                          style: dqText(size: 16).copyWith(
                              height: 1.7,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 8)
                              ])),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: Text(_p.en,
                        textAlign: TextAlign.center,
                        style:
                            dqText(size: 11, color: dqInk, w: FontWeight.w400)
                                .copyWith(height: 1.4)),
                  ),
                  const SizedBox(height: 16),
                  _advanceControl(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _panels.length; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index
                                ? dqGold
                                : dqGoldDeep.withAlpha(110),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Council S2 (wf w4cnnw8ho, art-director canon catch): the prologue is the 5級
  // ENTRY, so it must open on the 5級 town plate — NOT town_pre1_grey_square (the
  // 準1級 FINALE, "full palette stripped" plate), which broke WORLD-BIBLE §2's
  // inward spiral (5級 misty edge → 準1 grey centre) and the colour-script (5級 =
  // near-monochrome ash + one lamp). town5_lane is a full-colour source; the
  // runtime _saturationMatrix greys it when silenced and restores colour as the
  // child earns it. Also keeps the cold-open intimate (5級 lane), not apocalyptic.
  static const _squareAsset = 'assets/art/scenes_layton/town5_lane.webp';

  /// Target colour saturation for the current beat (0 = grey/silenced, 1 = full
  /// colour): 起 grey → 承 his memory blooms → 転 the Silence drains it → blend
  /// grey until the child restores it → 結 restored.
  double get _beatSaturation {
    switch (_index) {
      case 1: // 承 — memory blooms
        return 1.0;
      case 3: // the blend — colour returns only when the child completes it
        return _blendDone ? 1.0 : 0.0;
      case 4: // 結 — restored (lamp lit, flame leans inward)
        return 1.0;
      case 5: // 結 — the CTA hook, stays in colour
        return 1.0;
      default: // 起 (0), 転 (2) — grey
        return 0.0;
    }
  }

  /// Whether ランプ shows in COLOUR. He colours WITH the world, so the lampkeeper
  /// is never grey-on-colour (the pasted-card tension): grey at 起, colour as the
  /// memory blooms at 承, grey again as the Silence drains it at 転, colour the
  /// moment the child completes the blend, and colour at 結. Tracking the beat's
  /// own saturation keeps the man and the world in lockstep (CEO 1436 design:
  /// "承 = 色がブワッと戻る").
  bool get _lampColoured => _beatSaturation >= 1.0;

  /// Full-bleed background: the canonical 灰色のひろば across every beat, under an
  /// animated saturation filter + a slow Ken Burns push-in. Reduced-motion jumps
  /// to the end state.
  Widget _background() {
    final to = _beatSaturation;
    Widget plate(double sat, double scale) => ClipRect(
          child: Transform.scale(
            scale: scale,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_saturationMatrix(sat)),
              child: Image.asset(_squareAsset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity),
            ),
          ),
        );
    if (prefersReducedMotion(context)) return plate(to, 1.06);
    return TweenAnimationBuilder<double>(
      // Re-keyed on beat AND blend state so the tween re-runs to the new target.
      key: ValueKey('bg$_index$_blendDone'),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2400),
      curve: Curves.easeInOut,
      builder: (_, t, __) => plate(to * t, 1.04 + 0.06 * t),
    );
  }

  /// ランプ — the lampkeeper, composited over the square: a grey (silenced) and a
  /// colour (restored) sprite cross-fading on restoration. He is the one face the
  /// child rescues. Reused npc_lampkeeper art (no new asset).
  Widget _lampkeeper() {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.34),
        child: FractionallySizedBox(
          widthFactor: 0.52,
          child: AspectRatio(
            aspectRatio: 0.8,
            // Feather the sprite into a soft oval so the lampkeeper reads as a
            // figure IN the square, not a hard-edged portrait card pasted on it
            // (the npc art has a baked vignette background) — super-strict
            // re-audit, CEO 1366/1372.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const RadialGradient(
                center: Alignment.center,
                radius: 0.6,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.62, 1.0],
              ).createShader(rect),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                child: Image.asset(
                  _lampColoured
                      ? 'assets/art/scenes_layton/npc_lampkeeper_color.webp'
                      : 'assets/art/scenes_layton/npc_lampkeeper_grey.webp',
                  key: ValueKey(_lampColoured),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The interactive panel gates "next" behind one 🔊 tap; others show "▶ つぎへ"
  /// (or "▶ はじめる" on the last panel).
  Widget _advanceControl() {
    final Widget control = (_p.interactive && !_blendDone)
        ? DqReplayButton(onTap: _playBlend, label: '🔊 おして、きいてみよう')
        : DqButton(label: _p.isLast ? '▶ はじめる / Begin' : '▶ つぎへ', onTap: _next);
    // Council S3: pulse the control when the child has gone idle, so a non-reader
    // sees WHERE to tap. Reduce-motion → no pulse (the control still stands out).
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!_idleHint || reduceMotion) return control;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) =>
          Transform.scale(scale: 1.0 + 0.06 * _pulse.value, child: child),
      child: control,
    );
  }

  // ── Foreground element over the full-bleed background. Only the blend beat has
  //    one (the s·a·t card the child taps); every other beat lets the grey square
  //    + the lampkeeper carry the moment.
  Widget _foregroundElement() {
    if (_p.interactive) {
      return BlendWordCard(
        letters: _blendLetters,
        word: 'sat',
        npcName: 'ランプ',
        npcEmoji: '🪔',
        npcImage: 'assets/art/scenes_layton/npc_lampkeeper_grey.webp',
        activeLetter: _activeLetter,
        onReplay: _playBlend,
      );
    }
    return const SizedBox.shrink();
  }

  /// 5x4 colour matrix that scales saturation: [s]=1 → identity (full colour),
  /// [s]=0 → fully desaturated (luminance grey). Rec.709 luma weights.
  List<double> _saturationMatrix(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return <double>[
      i * r + s, i * g, i * b, 0, 0, //
      i * r, i * g + s, i * b, 0, 0, //
      i * r, i * g, i * b + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

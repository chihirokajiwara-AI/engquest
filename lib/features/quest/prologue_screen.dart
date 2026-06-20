// lib/features/quest/prologue_screen.dart
// A-KEN Quest — the opening PROLOGUE (『ことばを失った世界』).
//
// Full-bleed cinematic opening — 6 kishōtenketsu (起承転結) beats with ONE
// protagonist, ランプ the lampkeeper (diverse-team redesign, CEO 1372/1375).
//
// 起 his lamp won't catch ("す…") → 承 his memory blooms the grey square to colour
// → 転 the サイレント drains it back → the DEDUCTION beat: the child taps the word
// that restores ランプ's sign (英検5級 大問1 word-deduction — knowing one English word
// restores the world) → 結 his lamp lights, "…ありがとう", a quiet road ahead.
//
// The deduction is a guaranteed win (no-scold). Correct tap = LIGHT → colour blooms
// radially from the lamp. Wrong tap = shake only, retry allowed.
//
// Plays once-ever (the caller persists that); skippable from panel 1.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_cue_service.dart';
import 'ui/dq_ui.dart';

class _Panel {
  final String jp;
  final String en;
  final String? audio; // best-effort cue key (graceful no-op if unrecorded)
  final bool interactive; // panel 3: the 英検 word-deduction beat
  final bool tappable; // 起: child taps 🔊 to sound the keeper's broken す… first
  final bool isLast;
  const _Panel(this.jp, this.en,
      {this.audio,
      this.interactive = false,
      this.tappable = false,
      this.isLast = false});
}

// The opening as 6 kishōtenketsu (起承転結) beats — one protagonist: ランプ the
// lampkeeper (diverse-team redesign, CEO 1372/1375). Deepened per CEO
// 1870/1872/1873 (iterated design wf wme3rp4q8, 3 critique→redesign rounds):
// the interactive beat replaces phonics with a real 英検5級 大問1 word-deduction —
// ランプ's sign reads "_ I G H T"; the child deduces LIGHT, and the lamp is restored.
const _panels = <_Panel>[
  // 起 — the lamplighter's lamp won't catch; his one surviving sound is /s/.
  _Panel(
    'ランプばんの ランプが、\nつかない。\n「す…」',
    "The lamplighter's lamp won't catch. \"s…\"",
    audio: 'audio/phonics/phoneme_s.mp3',
    tappable: true, // agency in the first ~10s: the child sounds the broken す…
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
  // 転→結 — the 英検5級 大問1 deduction beat: タロ's sign reads "_ I G H T"; the
  //         child deduces LIGHT and the lamp's colour is restored. Knowing one
  //         English word restores the world — dramatises the product's real value.
  _Panel(
    'ランプの ことばが きえてる。\nきみには、よめる?',
    "The lamp's word is gone. Can you read it?",
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

// ── Word-deduction constants ──────────────────────────────────────────────────
// The 英検5級 大問1 cloze: "_ I G H T" — the child picks which -IGHT word names
// the lamp. Correct = LIGHT (index 1, slot ②). NIGHT and RIGHT are plausible
// distractors (same rime family, all bundled in assets/audio/a1/).
const _kCorrectLabel = 'LIGHT';
const _kChoices = [
  (label: 'NIGHT', audio: 'audio/a1/eiken5_215_night.mp3'),
  (label: 'LIGHT', audio: 'audio/a1/eiken5_095_light.mp3'), // correct
  (label: 'RIGHT', audio: 'audio/a1/eiken5_182_right.mp3'),
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

  // ── Deduction beat state ──────────────────────────────────────────────────
  // Tracks which choice buttons are in which DqChoiceState for the -IGHT deduction.
  // Indexed 0/1/2 matching _kChoices.
  final _choiceStates = [
    DqChoiceState.normal,
    DqChoiceState.normal,
    DqChoiceState.normal,
  ];

  /// True once the child taps LIGHT (correct). Drives the colour bloom for this
  /// beat — replaces the old _blendDone gate in _beatSaturation / _background /
  /// _revealPlate so colour blooms radially from the lamp exactly as the blend did.
  bool _restored = false;

  // ── Other panel state ─────────────────────────────────────────────────────
  bool _heard = false; // 起: child has tapped to hear す…
  double _revealFrom = 0.0; // leaving beat's saturation → bloom/drain origin

  // Council S3 — non-reader gate: a 6-7yo who can't read 「つぎへ」 needs a VISUAL
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
      // Tappable 起 does NOT auto-voice — the child's tap IS the agency.
      if (!_p.interactive && !_p.tappable && _p.audio != null) {
        _cue.play(_p.audio);
      }
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
    final leaving = _beatSaturation; // origin for the next beat's bloom/drain
    setState(() {
      _revealFrom = leaving;
      _index++;
      // Reset deduction state on panel change.
      _choiceStates[0] = DqChoiceState.normal;
      _choiceStates[1] = DqChoiceState.normal;
      _choiceStates[2] = DqChoiceState.normal;
      _restored = false;
      _heard = false;
    });
    // This runs from a tap (user gesture) → safe to fire audio on web, except on
    // the interactive deduction / tappable 起 panels.
    if (!_p.interactive && !_p.tappable && _p.audio != null) {
      _cue.play(_p.audio);
    }
    _armIdle();
  }

  /// 起 agency: the child TAPS to sound the keeper's broken 「す…」 in the first
  /// ~10s, rather than it auto-playing. The idle pulse draws a non-reader's eye
  /// to the 🔊; tapping reveals ▶ つぎへ.
  void _hearPanel() {
    _cue.play(_p.audio);
    setState(() => _heard = true);
    _armIdle();
  }

  /// Word-deduction tap handler. Each choice plays its own audio; only LIGHT
  /// (index 1 in _kChoices) is correct. Errorless: wrong tap shakes the button
  /// and keeps the panel open; correct tap blooms colour and auto-advances.
  void _onChoiceTap(int i) {
    final isCorrect = _kChoices[i].label == _kCorrectLabel;
    _cue.play(_kChoices[i].audio);
    setState(() {
      _choiceStates[i] =
          isCorrect ? DqChoiceState.correct : DqChoiceState.wrong;
      if (isCorrect) _restored = true;
    });
    _armIdle();
    if (isCorrect) {
      // Brief hold so the child sees the green pop + colour bloom, then advance.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _next();
      });
    }
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
          // 1 — bottom scrim so captions stay legible over the art. The ramp
          // starts earlier (0.42) and reaches near-opaque by 0.72 — the band
          // where the subtitle, EN line and controls actually sit — because the
          // old transparent→0.5→black87 gradient left the caption zone only
          // half-darkened, so the cream ひらがな washed out over the BRIGHT warm
          // panels (4/5) and the mid-grey 転 panel (2) (visual-auditor, CEO 2132
          // contrast finding). Keeps the upper art fully clear (full-bleed
          // cinematic, no dialog card — CEO 1372/1375).
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xCC000000), // ~0.80 black across the caption band
                    Color(0xF2000000), // ~0.95 black at the very bottom
                  ],
                  stops: [0.0, 0.42, 0.72, 1.0],
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
  /// colour): 起 grey → 承 his memory blooms → 転 the Silence drains it → deduction
  /// grey until the child restores it → 結 restored.
  double get _beatSaturation {
    switch (_index) {
      case 1: // 承 — memory blooms
        return 1.0;
      case 3: // the deduction — colour returns only when the child taps LIGHT
        return _restored ? 1.0 : 0.0;
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
  /// moment the child taps LIGHT, and colour at 結. Tracking the beat's
  /// own saturation keeps the man and the world in lockstep (CEO 1436 design:
  /// "承 = 色がブワッと戻る").
  bool get _lampColoured => _beatSaturation >= 1.0;

  /// Full-bleed background: the canonical 灰色のひろば across every beat, under an
  /// animated saturation filter + a slow Ken Burns push-in. Reduced-motion jumps
  /// to the end state.
  Widget _background() {
    final to = _beatSaturation;
    if (prefersReducedMotion(context)) return _revealPlate(to, 1.06);
    return TweenAnimationBuilder<double>(
      // Re-keyed on beat AND restored state so the tween re-runs. Animates reveal
      // from the LEAVING beat's saturation (_revealFrom) to this beat's target:
      // colour BLOOMS outward from the lamp when it returns (起→承, LIGHT tapped)
      // and DRAINS back toward the lamp when the Silence eats it (承→転) — the
      // loss is SHOWN through the mechanic, not just narrated.
      // Seamless under the outer 450ms switcher: each beat starts at the
      // previous beat's end saturation, so the cross-fade has nothing to jump.
      key: ValueKey('bg$_index$_restored'),
      tween: Tween<double>(begin: _revealFrom, end: to),
      duration: const Duration(milliseconds: 2400),
      curve: Curves.easeInOut,
      builder: (_, reveal, __) => _revealPlate(reveal, 1.04 + 0.06 * reveal),
    );
  }

  /// A scaled, saturation-graded plate of the square.
  Widget _plate(double sat, double scale) => ClipRect(
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

  /// Colour returns by BLOOMING radially out from ランプ's lamp: [reveal] 0 = all
  /// grey, 1 = full colour; in between, a feathered colour disc grows from the lamp
  /// at the composition's focal point. At rest it's a single cheap plate.
  Widget _revealPlate(double reveal, double scale) {
    if (reveal <= 0.01) return _plate(0.0, scale);
    if (reveal >= 0.99) return _plate(1.0, scale);
    return Stack(fit: StackFit.expand, children: [
      _plate(0.0, scale),
      ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => RadialGradient(
          center: const Alignment(0, 0.34), // the lamp (matches _lampkeeper)
          radius: (reveal * 1.9).clamp(0.02, 2.0),
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(rect),
        child: _plate(1.0, scale),
      ),
    ]);
  }

  /// ランプ — the lampkeeper, composited over the square: a grey (silenced) and a
  /// colour (restored) sprite cross-fading on restoration.
  Widget _lampkeeper() {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.34),
        child: FractionallySizedBox(
          widthFactor: 0.52,
          child: AspectRatio(
            aspectRatio: 0.8,
            // Feather the sprite into a soft oval so the lampkeeper reads as a
            // figure IN the square, not a hard-edged portrait card pasted on it.
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

  /// The interactive deduction panel gates "next" behind a correct LIGHT tap;
  /// other panels show "▶ つぎへ" (or "▶ はじめる" on the last panel).
  Widget _advanceControl() {
    final Widget control = (_p.interactive && !_restored)
        ? const SizedBox.shrink() // choice buttons replace the advance control
        : (_p.tappable && !_heard)
            ? DqReplayButton(onTap: _hearPanel, label: '🔊 きいてみよう')
            : DqButton(
                label: _p.isLast ? '▶ はじめる / Begin' : '▶ つぎへ', onTap: _next);
    // Council S3: pulse the control when the child has gone idle.
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

  // ── Foreground element ────────────────────────────────────────────────────
  // Only the deduction beat has one — every other beat lets the grey square
  // + the lampkeeper carry the moment.
  Widget _foregroundElement() {
    if (_p.interactive) {
      return SingleChildScrollView(child: _deductionCard());
    }
    return const SizedBox.shrink();
  }

  /// The 英検5級 大問1 deduction card: a DetectiveCaseFrame over the grey lane plate
  /// showing the redacted sign "_ I G H T" and three AudioOptionButton choices.
  Widget _deductionCard() {
    return DetectiveCaseFrame(
      caseLabel: 'ランプの ことば',
      highlighted: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Redacted evidence sign ──────────────────────────────────────
          // "_ I G H T" — the first letter is a gold-bordered blank box;
          // "I G H T" is visible in gold. Honest: all three options end in -IGHT.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gold-bordered blank box for the missing first letter.
                _blankBox(),
                const SizedBox(width: 6),
                // The rest of the word in gold.
                Text(
                  'I G H T',
                  style: dqText(
                    size: 26,
                    color: dqGold,
                    w: FontWeight.w800,
                    spacing: 3,
                  ),
                ),
              ],
            ),
          ),
          // JP hint beneath the sign.
          Text(
            '「ランプの ことば」',
            style: dqText(size: 13, color: dqGold, w: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          // タロ's cheer copy after correct tap, else stay silent.
          if (_restored)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'そうだ! ことばが、ひかりを とりもどした!',
                textAlign: TextAlign.center,
                style: dqText(size: 14, color: dqGold),
              ),
            ),
          // ── Three AudioOptionButton choices ──────────────────────────────
          for (var i = 0; i < _kChoices.length; i++)
            AudioOptionButton(
              key: ValueKey('choice_$i'),
              label: _kChoices[i].label,
              state: _choiceStates[i],
              index: i + 1, // 1-based badge: ①②③
              onAudio: () => _cue.play(_kChoices[i].audio),
              onChoose: _choiceStates[i] == DqChoiceState.correct ||
                      _choiceStates[i] == DqChoiceState.wrong
                  ? null // already resolved — ignore re-tap
                  : () => _onChoiceTap(i),
            ),
        ],
      ),
    );
  }

  /// Gold-bordered blank box representing the missing first letter (the _ in
  /// _ I G H T). Sized to match the I G H T glyph height.
  Widget _blankBox() {
    return Container(
      width: 32,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dqGold.withAlpha(28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dqGold, width: 2),
      ),
      child: Text(
        '_',
        style: dqText(size: 22, color: dqGold, w: FontWeight.w800),
      ),
    );
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

// lib/features/quest/prologue_screen.dart
// A-KEN Quest — the opening PROLOGUE (『ことばを失った世界』).
//
// Full-bleed cinematic opening — 5 kishōtenketsu (起承転結) beats with ONE
// protagonist, ランプ the lampkeeper (diverse-team redesign, CEO 1372/1375; the
// 英検5級 phonics story, CEO 1385): 起 his lamp won't catch ("す…") → 承 his memory
// blooms the grey square to colour → 転 the サイレント drains it back, but きみ can
// still hear → the BLEND beat: the child taps 🔊, joins c·a·t, and the lampkeeper
// is restored grey→colour → 結 his lamp lights, "…ありがとう", a quiet road ahead.
// The blend is a guaranteed win (no-scold). The win is restoration, not conquest.
//
// Plays once-ever (the caller persists that); skippable from panel 1. Built to
// stand WITHOUT the not-yet-recorded phoneme audio: the one real audio moment is
// the blend on panel 5 (blend_cat.mp3 exists); phoneme keys are wired so they
// light up the instant the founder records them.

import 'package:flutter/material.dart';

import '../../core/audio/audio_cue_service.dart';
import 'ui/dq_ui.dart';

class _Panel {
  final String jp;
  final String en;
  final String? audio; // best-effort cue key (graceful no-op if unrecorded)
  final bool interactive; // panel 5: the c·a·t blend demo
  final bool isLast;
  const _Panel(this.jp, this.en,
      {this.audio, this.interactive = false, this.isLast = false});
}

// The opening as 5 kishōtenketsu (起承転結) beats — one protagonist: ランプ the
// lampkeeper. The child rescues ONE man's voice, not "the world" (diverse-team
// redesign, CEO 1372/1375; scoped to the 英検5級 phonics story, CEO 1385).
const _panels = <_Panel>[
  // 起 — one mute man, reaching for a lamp that won't catch
  _Panel(
    'ランプばんの ランプが、\nつかない。\n「す…」',
    "The lamplighter's lamp won't catch. \"s…\"",
    audio: 'audio/phonics/phoneme_s.mp3',
  ),
  // 承 — his memory: the square once overflowed with colour
  _Panel(
    'むかし、この ひろばは\nいろで あふれてた。',
    'Once, this square overflowed with colour.',
  ),
  // 転 — the Silence eats it back, but きみ can still hear
  _Panel(
    'でも、サイレントが\nことばを たべてしまう。\nきみの こえは、まだ きこえる。',
    'But the Silence eats the words. Your voice can still be heard.',
  ),
  // the turn, made playable — tap to join the sounds and give him a voice
  _Panel(
    'タップして、\nおとを つなげてみよう。',
    'Tap, and join the sounds.',
    audio: 'audio/phonics/blend_cat.mp3',
    interactive: true,
  ),
  // 結 — his lamp catches, his thanks, a quiet road ahead
  _Panel(
    'ランプに、ひが ともった。\n「…ありがとう。」\nさあ、ことばを とりもどしに いこう。',
    'The lamp is lit. "…thank you." Let\'s go and bring the words back.',
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

class _PrologueScreenState extends State<PrologueScreen> {
  final _cue = AudioCueService();
  late int _index = widget.startIndex.clamp(0, _panels.length - 1);

  // The blend beat: each 🔊 tap lights the next phoneme c→a→t (tap-driven).
  int _activeLetter = -1; // -1 none lit; 0=c, 1=a, 2=t
  bool _blendDone = false; // true once all three are sounded → join + restore

  _Panel get _p => _panels[_index];

  @override
  void dispose() {
    _cue.dispose();
    super.dispose();
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
  }

  /// TAP-DRIVEN blend (the diverse-team design's core: the CHILD performs the
  /// blend, not an auto-animation). Each 🔊 tap lights the next phoneme c→a→t;
  /// the third tap joins them into "cat" and restores ランプ. Errorless — there
  /// is no wrong tap, only "not yet complete" (the no-scold spine).
  void _playBlend() {
    _cue.play(_p.audio);
    setState(() {
      _activeLetter++;
      // c·a·t all sounded → join into the word + restore ランプ.
      if (_activeLetter >= 2) _blendDone = true;
    });
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
                    child: Text(_p.jp,
                        textAlign: TextAlign.center,
                        style: dqText(size: 16).copyWith(
                            height: 1.7,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 8)
                            ])),
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
      case 4: // 結 — restored
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
    if (_p.interactive && !_blendDone) {
      return DqReplayButton(onTap: _playBlend, label: '🔊 おして、きいてみよう');
    }
    return DqButton(
        label: _p.isLast ? '▶ はじめる / Begin' : '▶ つぎへ', onTap: _next);
  }

  // ── Foreground element over the full-bleed background. Only the blend beat has
  //    one (the c·a·t card the child taps); every other beat lets the grey square
  //    + the lampkeeper carry the moment.
  Widget _foregroundElement() {
    if (_p.interactive) {
      return BlendWordCard(
        letters: const ['c', 'a', 't'],
        word: 'cat',
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

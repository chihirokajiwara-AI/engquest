// lib/features/quest/prologue_screen.dart
// A-KEN Quest — the opening PROLOGUE (『ことばを失った世界』).
//
// Six tap-through panels that establish the world WITHOUT the old "you are
// secretly a prince" trope (see docs/design/OPENING-NARRATIVE-BIBLE.md): a quiet
// called サイレント drained the world's words and colour; きみ is special only
// because きみ can still HEAR the sounds and VOICE them — the exact skill the
// child is learning. Panel 5 is INTERACTIVE: the child taps 🔊 and blends c·a·t
// into "cat" and wins — a guaranteed win, so the no-scold contract is FELT.
//
// Plays once-ever (the caller persists that); skippable from panel 1. Built to
// stand WITHOUT the not-yet-recorded phoneme audio: the one real audio moment is
// the blend on panel 5 (blend_cat.mp3 exists); phoneme keys are wired so they
// light up the instant the founder records them.

import 'dart:async';

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

const _panels = <_Panel>[
  _Panel(
    '（くらやみ。ちいさな おとだけが きこえる）\ns … a … t …',
    'In the dark, only small sounds remain. s... a... t...',
    audio: 'audio/phonics/phoneme_s.mp3',
  ),
  _Panel(
    'むかし、この くに〈ソネア〉では、\nこえに だした ことばが、そのまま「いろ」に なった。',
    'Long ago, in Sonea, a spoken word turned into colour.',
  ),
  _Panel(
    'でも、あるひから ──\n「しずけさ」が、ひろがりはじめた。\nことばが きえると、いろも、こえも、しずかに なる。',
    'But one day, the Silence began to spread. When a word is forgotten, its colour and its voice grow quiet too.',
  ),
  _Panel(
    '……けれど、きみは ちがった。\nきみには、まだ おとが きこえる。\nそして、まだ こえに だせる。',
    "...but you are different. You can still hear the sounds. And you can still say them.",
  ),
  _Panel(
    '🔊を おして、おとを きいて、まねしてみよう。\nおとを つなげば、ことばが よみがえる。',
    'Tap 🔊, hear a sound, and try it. Join the sounds, and a word comes back to life.',
    audio: 'audio/phonics/blend_cat.mp3',
    interactive: true,
  ),
  _Panel(
    'これは、たたかいの たびじゃない。\nきえた ことばを、ひとつずつ かえしていく たび。\nきみの こえで、せかいに ことばを かえそう。',
    'This is not a journey of battle. It is a journey to give the lost words back, one by one. With your voice, give the world its words back.',
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

  // Panel 5 (interactive blend) — drives the c→a→t tile sweep, mirrored from
  // QuestScreen so the demo matches the real game exactly.
  int _activeLetter = -1;
  Timer? _sweep;
  bool _blendDone = false; // gates the "▶ つぎへ" until the child has tried once

  _Panel get _p => _panels[_index];

  @override
  void dispose() {
    _sweep?.cancel();
    _cue.dispose();
    super.dispose();
  }

  void _next() {
    _sweep?.cancel();
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

  void _playBlend() {
    _cue.play(_p.audio);
    _sweepLetters();
    setState(() => _blendDone = true);
  }

  void _sweepLetters() {
    _sweep?.cancel();
    setState(() => _activeLetter = 0);
    var i = 0;
    _sweep = Timer.periodic(const Duration(milliseconds: 460), (t) {
      i++;
      if (i >= 3) {
        t.cancel();
        _sweep = Timer(const Duration(milliseconds: 520), () {
          if (mounted) setState(() => _activeLetter = -1);
        });
      } else if (mounted) {
        setState(() => _activeLetter = i);
      }
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
          // 0 — full-bleed background (the grey square for scene beats; dark else)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child:
                KeyedSubtree(key: ValueKey('bg$_index'), child: _background()),
          ),
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

  /// Full-bleed background. Scene beats (1,2) = the canonical 灰色のひろば under the
  /// saturation filter + a slow Ken Burns push-in; other beats = a dark gradient
  /// (their foreground element carries the moment). Reduced-motion jumps to end.
  Widget _background() {
    final isScene = _index == 1 || _index == 2;
    if (!isScene) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E24), Color(0xFF05060F)],
          ),
        ),
      );
    }
    const asset = 'assets/art/scenes_layton/town_pre1_grey_square.webp';
    final drain =
        _index == 2; // panel 2 = colour drains; panel 1 = colour blooms
    final from = drain ? 1.0 : 0.0;
    final to = drain ? 0.0 : 1.0;
    Widget plate(double sat, double scale) => ClipRect(
          child: Transform.scale(
            scale: scale,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_saturationMatrix(sat)),
              child: Image.asset(asset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity),
            ),
          ),
        );
    if (prefersReducedMotion(context)) return plate(to, 1.06);
    return TweenAnimationBuilder<double>(
      key: ValueKey('bgtween$_index'),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2600),
      curve: Curves.easeInOut,
      builder: (_, t, __) => plate(from + (to - from) * t, 1.04 + 0.06 * t),
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

  // ── Foreground element over the full-bleed background. Scene beats (1,2) put
  //    the painted square in the background, so they have no foreground element.
  Widget _foregroundElement() {
    if (_p.interactive) {
      return BlendWordCard(
        letters: const ['c', 'a', 't'],
        word: 'cat',
        npcName: 'きみ',
        npcEmoji: '🧭',
        npcImage: 'assets/art/masters/hero.png',
        activeLetter: _activeLetter,
        onReplay: _playBlend,
      );
    }
    switch (_index) {
      case 0:
        return _glyphRow(['s', 'a', 't'], const Color(0xFFEDE3C8));
      case 1:
      case 2:
        return const SizedBox
            .shrink(); // the square is the full-bleed background
      case 3:
        return _heroSpark();
      default: // last
        return _mapHint();
    }
  }

  Widget _glyphRow(List<String> letters, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final l in letters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(l,
                  style: TextStyle(
                      color: color,
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2)),
            ),
        ],
      );

  /// A real painted ソネア scene whose COLOUR animates in or out — the bible's
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

  /// きみ as the last surviving spark of voice.
  Widget _heroSpark() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: dqGold.withAlpha(120),
                    blurRadius: 34,
                    spreadRadius: 4)
              ],
            ),
            child: DqPortrait(
                imageAsset: 'assets/art/masters/hero.png',
                emoji: '🧭',
                size: 96),
          ),
          const SizedBox(height: 12),
          Text('きみ', style: dqText(size: 13, color: dqGold)),
        ],
      );

  /// A hint of the road ahead — the first 声の石 lighting.
  Widget _mapHint() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✦', style: TextStyle(color: dqGold, fontSize: 60)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 7; i++)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0 ? dqGold : dqBox,
                    border: Border.all(
                        color: i == 0 ? dqGold : dqGoldDeep.withAlpha(120),
                        width: 2),
                    boxShadow: i == 0
                        ? [
                            BoxShadow(
                                color: dqGold.withAlpha(150), blurRadius: 14)
                          ]
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('ことばを 失（うしな）った 村（むら）へ', style: dqText(size: 12, color: dqInk)),
        ],
      );
}

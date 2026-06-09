// lib/features/explore/scene_view.dart
// Wave 1 — SceneView: Layton-style explorable painted scene.
//
// A Stack of parallax background layers (Transform shifts on drag) with
// Positioned tappable hotspot targets overlaid. On tap:
//   - NPC: plays clue audio (best-effort) + shows a 「？」bubble. Tapping the
//     bubble navigates to NazoScreen. On correct, the NPC portrait
//     AnimatedCrossFades from grey→color (the restoration payoff).
//   - Coin: plays a coin SFX, adds the coin to HintCoinService, vanishes.
//
// NO dart:io. NO Firebase. Image.asset always has errorBuilder → dq gradient.
// Firebase uid must NOT be used here (see test constraint).

import 'package:flutter/material.dart';

import '../../core/audio/audio_cue_service.dart';
import '../../core/gamification/hint_coin_service.dart';
import '../../core/sound/sound_service.dart';
import '../quest/ui/dq_ui.dart';
import '../home/streak_service.dart';
import '../exam_practice/pass/cse_model.dart';
import '../exam_practice/pass/skill_accuracy_store.dart';
import 'hotspot.dart';
import 'nazo_screen.dart';

export 'hotspot.dart'
    show
        kTown5Scene,
        kTown4Scene,
        kTown3Scene,
        kTownPre2Scene,
        kTownPre2PlusScene,
        kTown2Scene,
        kTownPre1Scene,
        kScenesByGrade,
        sceneForGrade,
        SceneDef;

/// Saturation [ColorFilter] matrix. `s == 1` → identity (full colour); `s == 0`
/// → greyscale (Rec.709 luma weights). This is the lean-Layton "ことばで世界に色が
/// 戻る" verb (ART-DIRECTION.md §1.2): a scene renders DESATURATED while its ナゾ are
/// unsolved, then the whole plate floods grey→colour on chapter clear — at runtime,
/// reusing the colour plate (no separate _grey asset).
List<double> saturationMatrix(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final ir = (1 - s) * lr, ig = (1 - s) * lg, ib = (1 - s) * lb;
  return <double>[
    ir + s, ig, ib, 0, 0, //
    ir, ig + s, ib, 0, 0, //
    ir, ig, ib + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// True when every NPC ナゾ in [scene] is solved (or the scene has none) — i.e. the
/// scene's colour is "restored". Drives the whole-plate grey→colour flood.
bool allNpcsSolved(SceneDef scene, Map<int, bool> solved) {
  for (var i = 0; i < scene.hotspots.length; i++) {
    if (scene.hotspots[i].kind == HotspotKind.npc && solved[i] != true) {
      return false;
    }
  }
  return true;
}

class SceneView extends StatefulWidget {
  final SceneDef scene;

  /// The 英検 level string for this scene (drives ピカラット + hint text).
  final String eikenLevel;

  const SceneView({
    super.key,
    required this.scene,
    this.eikenLevel = '5',
  });

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  // ── State ─────────────────────────────────────────────────────────────────

  // NPC solve state: hotspot index → solved bool
  final Map<int, bool> _solved = {};

  // Coin found state: hotspot index → found bool
  final Map<int, bool> _coinFound = {};

  // Which NPC index currently shows a 「？」speech-bubble (null = none)
  int? _bubbleIndex;

  // Coin balance (shown in HUD after collecting)
  int _coinBalance = 0;

  // Parallax offset driven by pan gesture
  double _parallaxOffset = 0.0;
  static const _parallaxMaxShift = 0.04; // fraction of container width

  /// Saturation of an unsolved scene — muted "the world lost its words" grade,
  /// NOT dead grey (s=0 reads as a broken image). Floods to 1.0 on chapter clear.
  static const _kMutedSaturation = 0.35;

  // Services
  final _cue = AudioCueService();
  final _sound = SoundService();
  late final HintCoinService _coins;

  @override
  void initState() {
    super.initState();
    _coins = HintCoinService();
    _loadCoinBalance();
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

  // ── Parallax ──────────────────────────────────────────────────────────────

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      // Drag right → layers drift left (negative shift for near, less for far).
      _parallaxOffset = (_parallaxOffset + d.delta.dx * 0.0008)
          .clamp(-_parallaxMaxShift, _parallaxMaxShift);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    // Spring back to centre
    setState(() => _parallaxOffset = 0.0);
  }

  // ── Hotspot interactions ──────────────────────────────────────────────────

  void _onHotspotTap(int idx) {
    final h = widget.scene.hotspots[idx];
    if (h.kind == HotspotKind.coin) {
      _collectCoin(idx, h);
    } else if (h.kind == HotspotKind.npc) {
      _tapNpc(idx, h);
    }
  }

  void _tapNpc(int idx, Hotspot h) {
    if (_solved[idx] == true) return; // already solved — no re-trigger
    // Play clue audio best-effort
    if (h.clueLineJa != null) {
      // Audio asset not available yet (generated separately); best-effort no-op.
      _cue.play(null);
    }
    setState(() {
      _bubbleIndex = (_bubbleIndex == idx) ? null : idx;
    });
  }

  void _onBubbleTap(int idx) {
    final h = widget.scene.hotspots[idx];
    if (h.step == null) return;
    setState(() => _bubbleIndex = null);
    _openNazo(idx, h);
  }

  Future<void> _openNazo(int idx, Hotspot h) async {
    final result = await Navigator.of(context).push<NazoResult>(
      MaterialPageRoute(
        builder: (_) => NazoScreen(
          hotspot: h,
          eikenLevel: widget.eikenLevel,
          hintCoinService: _coins,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null && result.solved) {
      setState(() => _solved[idx] = true);
      _sound.playCorrect();
      // Front-door 英検 puzzle solved → feed the home engagement spine (streak +
      // daily-goal), same as exam practice. Before this, scene play earned ZERO
      // streak/goal credit.
      recordExamHabit(1);
      // …and feed 合格率 with an HONEST signal: record first-try correctness
      // (a ナゾ retries to solve, so 1/1 every time would inflate the meter).
      // Scene ナゾ test vocab/reading 英検 knowledge → EikenSkill.reading.
      _recordSkill(result.firstTryCorrect);
    }
  }

  /// Records one front-door ナゾ into 合格率 (SkillAccuracyStore). Fire-and-forget;
  /// storage failures are swallowed and never interrupt the learner.
  void _recordSkill(bool firstTryCorrect) {
    () async {
      try {
        final store = await SkillAccuracyStore.getInstance();
        await store.record(
          grade: widget.eikenLevel,
          skill: EikenSkill.reading,
          correct: firstTryCorrect ? 1 : 0,
          total: 1,
        );
      } catch (_) {
        // Non-fatal: the pass meter simply won't reflect this one puzzle.
      }
    }();
  }

  Future<void> _collectCoin(int idx, Hotspot h) async {
    if (_coinFound[idx] == true) return;
    setState(() => _coinFound[idx] = true);
    _sound.playXpGain();
    final newBalance = await _coins.addCoin(h.coinValue);
    if (mounted) setState(() => _coinBalance = newBalance);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// Whole-scene colour is "restored" once every ナゾ is solved → the background
  /// plate floods grey→colour (the lean-Layton core verb).
  bool get _sceneRestored => allNpcsSolved(widget.scene, _solved);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dqNight0,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _sceneStack()),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: dqInk),
            ),
            Expanded(
              child: Text(
                widget.scene.titleJa,
                textAlign: TextAlign.center,
                style: dqText(size: 16, w: FontWeight.w800, color: dqGold),
              ),
            ),
            // Coin HUD
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
        ),
      );

  Widget _sceneStack() {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Background / parallax layers ──────────────────────────────
              // The whole plate renders desaturated until the chapter's ナゾ are
              // solved, then floods grey→colour over 2s (ART-DIRECTION §1.2 —
              // "ことばで世界に色が戻る"). Runtime saturation of the colour plate;
              // no separate _grey asset. Built inside the builder so parallax
              // pan still updates each frame.
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  // Floor at a MUTED saturation, not dead grey (s=0): a fully
                  // desaturated painting reads as a broken/missing image (the
                  // very defect class the CEO flagged). A muted "under-the-spell"
                  // grade is unmistakably intentional and the colour-flood payoff
                  // still lands. Restored → full colour.
                  tween: Tween<double>(
                    begin: _kMutedSaturation,
                    end: _sceneRestored ? 1.0 : _kMutedSaturation,
                  ),
                  duration: const Duration(milliseconds: 2000),
                  curve: Curves.easeInOut,
                  builder: (context, sat, _) => ColorFiltered(
                    colorFilter: ColorFilter.matrix(saturationMatrix(sat)),
                    child: Stack(children: _buildParallaxLayers(w, h)),
                  ),
                ),
              ),

              // ── Dark vignette overlay for legibility ──────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(80),
                        Colors.transparent,
                        Colors.black.withAlpha(130),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Hotspot overlay ───────────────────────────────────────────
              for (var i = 0; i < widget.scene.hotspots.length; i++)
                _hotspotWidget(i, w, h),

              // ── Active NPC speech bubble (scene-level so it is TAPPABLE) ────
              if (_bubbleIndex != null) _bubbleOverlay(_bubbleIndex!, w, h),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildParallaxLayers(double w, double h) {
    final layers = widget.scene.parallaxLayers;
    if (layers.isEmpty) {
      // Single background layer, no parallax.
      return [_backgroundImage(widget.scene.backgroundAsset, 0, w)];
    }
    // Multiple layers: far layer shifts least, near layer shifts most.
    return [
      for (var i = 0; i < layers.length; i++)
        _backgroundImage(layers[i], i / (layers.length - 1), w),
    ];
  }

  /// Render one parallax layer. [depthFraction] 0.0 = far (least movement),
  /// 1.0 = near (most movement). Shift is applied via Transform.translate.
  Widget _backgroundImage(String asset, double depthFraction, double w) {
    final shift = _parallaxOffset * w * depthFraction * 3;
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(shift, 0),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientFallback(),
        ),
      ),
    );
  }

  Widget _gradientFallback() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [dqNight0, dqNight1, dqNight0],
          ),
        ),
      );

  // ── Hotspot widget ────────────────────────────────────────────────────────

  Widget _hotspotWidget(int idx, double w, double h) {
    final hotspot = widget.scene.hotspots[idx];
    final isSolved = _solved[idx] == true;
    final isCoinFound = _coinFound[idx] == true;

    if (hotspot.kind == HotspotKind.coin && isCoinFound) {
      return const SizedBox.shrink(); // Vanished after collection
    }

    // Position: Alignment → pixel offset.
    final cx = (hotspot.pos.x + 1) / 2 * w;
    final cy = (hotspot.pos.y + 1) / 2 * h;
    final size = hotspot.size * w.clamp(100.0, 480.0);

    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _onHotspotTap(idx),
        // Just the hotspot target. The speech bubble is rendered separately at
        // SCENE level (see _bubbleOverlay) so it stays hit-testable — nesting it
        // here overflowed this small GestureDetector's bounds and silently ate
        // the tap (the 「ナゾをみる」-does-nothing bug, CEO 2026-06-09).
        child: hotspot.kind == HotspotKind.coin
            ? _coinTarget(size)
            : _npcTarget(idx, hotspot, isSolved, size),
      ),
    );
  }

  /// The 「？」speech bubble for the active NPC, rendered at SCENE level (a direct
  /// child of the scene Stack) so its 「ナゾをみる」 button is inside the hit-test
  /// bounds. Positioned just above the NPC and clamped to stay on-screen.
  Widget _bubbleOverlay(int idx, double w, double h) {
    final hotspot = widget.scene.hotspots[idx];
    final cx = (hotspot.pos.x + 1) / 2 * w;
    final cy = (hotspot.pos.y + 1) / 2 * h;
    final size = hotspot.size * w.clamp(100.0, 480.0);
    const bubbleW = 220.0;
    return Positioned(
      left: (cx - bubbleW / 2).clamp(4.0, (w - bubbleW - 4).clamp(4.0, w)),
      bottom: (h - (cy - size / 2) + 6).clamp(4.0, h - 48),
      child: GestureDetector(
        onTap: () => _onBubbleTap(idx),
        child: _speechBubble(hotspot.clueLineJa),
      ),
    );
  }

  Widget _coinTarget(double size) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, t, __) => Transform.scale(
        scale: t,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A1C00).withAlpha(180),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withAlpha(160),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text('✦',
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 20)),
          ),
        ),
      ),
    );
  }

  Widget _npcTarget(int idx, Hotspot hotspot, bool solved, double size) {
    final grey = hotspot.npcGreyAsset;
    final color = hotspot.npcColorAsset;

    // If no art exists yet: fallback to emoji/icon portrait
    if (grey == null && color == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dqBox.withAlpha(200),
          border: Border.all(
            color: solved ? const Color(0xFF8BE08B) : dqGold,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (solved ? const Color(0xFF8BE08B) : dqGold).withAlpha(100),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Text(
            hotspot.step?.npcEmoji ?? '👤',
            style: TextStyle(fontSize: size * 0.45),
          ),
        ),
      );
    }

    // Grey→color cross-fade on solve
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 600),
      crossFadeState:
          solved ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: _npcPortraitImage(grey ?? '', size),
      secondChild: _npcPortraitImage(color ?? '', size),
    );
  }

  Widget _npcPortraitImage(String asset, double size) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dqBox.withAlpha(200),
            border: Border.all(color: dqGold, width: 2),
          ),
          child:
              const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
        ),
      ),
    );
  }

  Widget _speechBubble(String? clueLineJa) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(245),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGold, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (clueLineJa != null) ...[
            Text(clueLineJa,
                style: dqText(size: 12, w: FontWeight.w500, color: dqInk)
                    .copyWith(height: 1.5)),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '「？」ナゾをみる',
                  style: dqText(
                      size: 12,
                      w: FontWeight.w800,
                      color: const Color(0xFF2A1C00)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

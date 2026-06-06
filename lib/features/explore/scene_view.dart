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
import 'hotspot.dart';
import 'nazo_screen.dart';

export 'hotspot.dart'
    show kTown5Scene, kTown4Scene, kScenesByGrade, sceneForGrade, SceneDef;

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
      _parallaxOffset =
          (_parallaxOffset + d.delta.dx * 0.0008).clamp(-_parallaxMaxShift, _parallaxMaxShift);
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
    }
  }

  Future<void> _collectCoin(int idx, Hotspot h) async {
    if (_coinFound[idx] == true) return;
    setState(() => _coinFound[idx] = true);
    _sound.playXpGain();
    final newBalance = await _coins.addCoin(h.coinValue);
    if (mounted) setState(() => _coinBalance = newBalance);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                  const Text('✦', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
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
              ..._buildParallaxLayers(w, h),

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
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // The hotspot target itself
            hotspot.kind == HotspotKind.coin
                ? _coinTarget(size)
                : _npcTarget(idx, hotspot, isSolved, size),

            // 「？」Speech bubble above the NPC (only when tapped)
            if (hotspot.kind == HotspotKind.npc && _bubbleIndex == idx)
              Positioned(
                bottom: size + 4,
                child: GestureDetector(
                  onTap: () => _onBubbleTap(idx),
                  child: _speechBubble(hotspot.clueLineJa),
                ),
              ),
          ],
        ),
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
            child: Text('✦', style: TextStyle(color: Color(0xFFFFD700), fontSize: 20)),
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
      crossFadeState: solved ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
          child: const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
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
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (clueLineJa != null) ...[
            Text(clueLineJa, style: dqText(size: 12, w: FontWeight.w500, color: dqInk).copyWith(height: 1.5)),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '「？」ナゾをみる',
                  style: dqText(size: 12, w: FontWeight.w800, color: const Color(0xFF2A1C00)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

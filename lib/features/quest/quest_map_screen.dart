// lib/features/quest/quest_map_screen.dart
// A-KEN Quest — the journey map. The hero travels level by level; a student
// begins in the town matching their 英検 level and unlocks the next by clearing
// a town. Rebuilt to the 本格 (Dragon-Quest-grade) look: a deep-night field, a
// 声の石 / Stones of Voice progress row, and town nodes strung along a glowing
// trail as command-window tiles. Behavior, persistence keys, the level picker,
// and the QuestScreen push are all preserved exactly.

import 'package:flutter/material.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'ui/dq_ui.dart';
import 'quest_data.dart';
import 'battle/quest_town_battle_flow.dart';

class QuestMapScreen extends StatefulWidget {
  /// 英検 level the student starts at ('5','4','3','pre2','2','pre1').
  final String startLevel;
  const QuestMapScreen({super.key, this.startLevel = '5'});

  @override
  State<QuestMapScreen> createState() => _QuestMapScreenState();
}

class _QuestMapScreenState extends State<QuestMapScreen> {
  static const _prefKey = 'quest_unlocked_index';
  static const _levelKey = 'quest_start_level';

  int _startIdx = 0;
  int _unlocked = 0;
  bool _loaded = false;
  bool _needsPick = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PreferencesService.getInstance();
    final level = prefs.getString(_levelKey);
    if (level == null) {
      setState(() {
        _needsPick = true;
        _loaded = true;
      });
      return;
    }
    final stored = prefs.getInt(_prefKey);
    _startIdx = startingTownIndex(level);
    setState(() {
      _unlocked = stored < _startIdx ? _startIdx : stored;
      _needsPick = false;
      _loaded = true;
    });
  }

  Future<void> _chooseLevel(String level) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setString(_levelKey, level);
    _startIdx = startingTownIndex(level);
    setState(() {
      _unlocked = _startIdx;
      _needsPick = false;
    });
    _saveUnlocked(_startIdx);
  }

  Future<void> _saveUnlocked(int idx) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setInt(_prefKey, idx);
  }

  Future<void> _openTown(int i) async {
    final town = kQuestTowns[i];
    // Wave 1: route 英検5級 town to the SceneView (Layton-style explorable
    // scene). All other towns keep the existing QuestTownBattleFlow.
    if (town.eikenLevel == '5') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SceneView(scene: kTown5Scene, eikenLevel: '5'),
        ),
      );
      // SceneView does not return a cleared bool; leave _unlocked unchanged
      // until Wave 3 wires ナゾーバ completion tracking.
      return;
    }
    final cleared = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) =>
              QuestTownBattleFlow(town: town)),
    );
    if (cleared == true && i + 1 > _unlocked) {
      setState(() => _unlocked = i + 1);
      _saveUnlocked(i + 1);
    }
  }

  /// Number of 声の石 recovered so far: every town strictly below the furthest
  /// unlocked town counts as cleared. Capped at the town count.
  int get _stonesWon => _unlocked.clamp(0, kQuestTowns.length);

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        children: [
          _header(),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator(color: dqGold))
                : _needsPick
                    ? _buildLevelPicker()
                    : _buildJourney(),
          ),
        ],
      ),
    );
  }

  // ── Title bar (replaces the old bright AppBar) ──
  Widget _header() {
    final canBack = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        children: [
          if (canBack)
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios_new, color: dqGold, size: 20),
              ),
            )
          else
            const SizedBox(width: 36),
          Expanded(
            child: Center(
              child: dqBilingual('ぼうけんの地図', 'World Map', jpSize: 19),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // Painted town plates (reused from the explorable SceneDefs) shown as the
  // node art on the overworld trail — so the map shows real PLACES, not a list.
  static const Map<String, String> _townArt = {
    '5': 'assets/art/scenes_layton/town5_lane.png',
    '4': 'assets/art/scenes_layton/town4_harbor.png',
    '3': 'assets/art/scenes_layton/town3_academy.png',
    'pre2': 'assets/art/scenes_layton/town_pre2_port.png',
    'pre2plus': 'assets/art/scenes_layton/town_pre2plus_bridge.png',
    '2': 'assets/art/scenes_layton/town_2_castle.png',
    'pre1': 'assets/art/scenes_layton/town_pre1_grey_square.png',
  };

  // ── The journey: prologue, 声の石 progress, then the painted overworld ──
  Widget _buildJourney() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _prologuePanel(),
        const SizedBox(height: 14),
        _stonesPanel(),
        const SizedBox(height: 18),
        _trailMap(),
      ],
    );
  }

  // ── The painted overworld: towns as medallions on a winding trail ──
  // A serpentine path (Duolingo-style guided progression + JRPG overworld):
  // each town is a circular plate of its own painted scene, alternating
  // left/right, joined by a glowing golden road. Reached towns are in colour;
  // still-locked towns are GREY — the same grey→colour language as the game's
  // サイレント mechanic, so the map itself tells the restoration story.
  Widget _trailMap() {
    const rowH = 142.0;
    const r = 44.0;
    final n = kQuestTowns.length;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        // Push the medallions toward their edge so the name column on the open
        // side has room even on a 320 px phone (≈0.74·w − 64 ≈ 150 px there).
        final leftX = w * 0.26;
        final rightX = w * 0.74;
        final centers = <Offset>[
          for (var i = 0; i < n; i++)
            Offset(i.isEven ? leftX : rightX, i * rowH + rowH / 2),
        ];
        final reached = _unlocked.clamp(0, n - 1);
        return SizedBox(
          width: w,
          height: n * rowH,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPainter(centers: centers, reachedIndex: reached),
                ),
              ),
              for (var i = 0; i < n; i++)
                ..._nodeWidgets(i, centers[i], r, w),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _nodeWidgets(int i, Offset center, double r, double w) {
    final town = kQuestTowns[i];
    final isSkipped = i < _startIdx;
    final isUnlocked = i >= _startIdx && i <= _unlocked;
    final isCleared = i < _unlocked && !isSkipped;
    final isLocked = i > _unlocked;
    final isStart = i == _startIdx;
    final onLeft = i.isEven;
    final onTap = isUnlocked ? () => _openTown(i) : null;

    return [
      // The painted town plate.
      Positioned(
        left: center.dx - r,
        top: center.dy - r,
        width: 2 * r,
        height: 2 * r,
        child: _medallion(
          town,
          d: 2 * r,
          isStart: isStart,
          isCleared: isCleared,
          isLocked: isLocked,
          isSkipped: isSkipped,
          onTap: onTap,
        ),
      ),
      // The name / grade / state, on the open side beside the plate.
      Positioned(
        top: center.dy - 42,
        height: 84,
        left: onLeft ? center.dx + r + 12 : 8,
        right: onLeft ? 8 : (w - (center.dx - r - 12)),
        child: _nodeInfo(
          town,
          onLeft: onLeft,
          isStart: isStart,
          isCleared: isCleared,
          isLocked: isLocked,
          isSkipped: isSkipped,
          onTap: onTap,
        ),
      ),
    ];
  }

  Widget _medallion(
    QuestTown town, {
    required double d,
    required bool isStart,
    required bool isCleared,
    required bool isLocked,
    required bool isSkipped,
    required VoidCallback? onTap,
  }) {
    final dim = isLocked || isSkipped;
    Widget img = Image.asset(
      _townArt[town.eikenLevel] ?? _townArt['5']!,
      width: d,
      height: d,
      fit: BoxFit.cover,
      // Decode at ~2× the on-screen size, not the full ~1.7 MB plate — keeps the
      // map light (7 scene PNGs would otherwise decode at full resolution).
      cacheWidth: 188,
      errorBuilder: (_, __, ___) => Container(
        color: dqNight1,
        alignment: Alignment.center,
        child: const Icon(Icons.castle, color: dqGold, size: 28),
      ),
    );
    if (dim) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kGreyscale),
        child: img,
      );
    }
    final ring = (isCleared || isStart)
        ? dqGold
        : (dim ? dqGoldDeep.withAlpha(190) : dqBorder);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: isStart ? 3.2 : 2.4),
          // Even locked towns get a faint halo so they read as places, not holes.
          boxShadow: dim
              ? [BoxShadow(color: dqGoldDeep.withAlpha(90), blurRadius: 6)]
              : [BoxShadow(color: dqGold.withAlpha(isStart ? 150 : 80), blurRadius: isStart ? 14 : 8)],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              img,
              // A light scrim (not the old near-opaque one) just to lift the
              // lock icon's contrast — the greyscale art stays visible beneath.
              if (isLocked) Container(color: dqNight0.withAlpha(70)),
              if (isLocked)
                const Center(child: Icon(Icons.lock, color: Colors.white, size: 26)),
              if (isCleared)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [dqGold, dqGoldDeep]),
                    ),
                    child: const Icon(Icons.check, color: Color(0xFF2A1C00), size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nodeInfo(
    QuestTown town, {
    required bool onLeft,
    required bool isStart,
    required bool isCleared,
    required bool isLocked,
    required bool isSkipped,
    required VoidCallback? onTap,
  }) {
    final dim = isLocked || isSkipped;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            onLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            _eikenLabel(town.eikenLevel),
            textAlign: onLeft ? TextAlign.left : TextAlign.right,
            style: dqText(size: 11, w: FontWeight.w800, color: dim ? dqGoldDeep.withAlpha(160) : dqGold),
          ),
          const SizedBox(height: 2),
          Text(
            town.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: onLeft ? TextAlign.left : TextAlign.right,
            style: dqText(size: 13.5, w: FontWeight.w700, color: dim ? dqInk.withAlpha(170) : Colors.white),
          ),
          const SizedBox(height: 4),
          // Keep the secondary line terse — the lock icon already carries
          // "locked"; a full sentence under every town is noise for a young
          // reader. (Adversarial child-UX note, 2026-06-07.)
          if (isStart)
            _badge('スタート / Start')
          else if (isCleared)
            _badge('クリア / Clear')
          else if (isLocked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 11, color: dqGoldDeep.withAlpha(190)),
                const SizedBox(width: 3),
                Text('まだ', style: dqText(size: 10.5, w: FontWeight.w700, color: dqGoldDeep.withAlpha(190))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _prologuePanel() => DqPanel(
        title: 'あなたの物語 / Your Story',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DqPortrait(imageAsset: 'assets/art/masters/hero.png', emoji: '🧭', size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                kQuestPrologue,
                style: dqText(size: 13.5, w: FontWeight.w500, color: dqInk).copyWith(height: 1.7),
              ),
            ),
          ],
        ),
      );

  // ── 声の石 progress: one gem per town, lit gold as it is recovered ──
  Widget _stonesPanel() {
    return DqPanel(
      title: 'こえのいし / Stones of Voice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < kQuestTowns.length; i++) _stone(i < _stonesWon),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: dqBilingual(
              '$_stonesWon / ${kQuestTowns.length} こ',
              'collected',
              jpSize: 13,
              jpColor: dqGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stone(bool lit) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: lit
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [dqGold, dqGoldDeep],
              )
            : null,
        color: lit ? null : dqNight0,
        border: Border.all(color: lit ? dqBorder : dqGoldDeep.withAlpha(110), width: 1.6),
        boxShadow: lit ? [BoxShadow(color: dqGold.withAlpha(150), blurRadius: 8)] : null,
      ),
      child: Icon(
        Icons.brightness_1,
        size: 10,
        color: lit ? const Color(0xFFFFF6DA) : dqGoldDeep.withAlpha(80),
      ),
    );
  }

  /// First-time level select: a student already at, say, 準2級 starts in the
  /// 準2級 town instead of replaying the easy ones.
  Widget _buildLevelPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        const SizedBox(height: 4),
        Center(child: dqBilingual('どの級からはじめますか？', 'Choose your level', jpSize: 20, align: TextAlign.center)),
        const SizedBox(height: 12),
        DqDialogBox(
          child: Text(
            'いま持っている英検の級をえらぶと、その街から旅がはじまります。\n'
            'Pick the Eiken grade you hold — your journey begins from that town.',
            style: dqText(size: 13, w: FontWeight.w500, color: dqInk).copyWith(height: 1.7),
          ),
        ),
        const SizedBox(height: 18),
        for (final t in kQuestTowns)
          DqTile(
            jp: '${_eikenLabel(t.eikenLevel)}・${t.name}',
            en: t.cefr,
            icon: Icons.shield_moon_outlined,
            onTap: () => _chooseLevel(t.eikenLevel),
          ),
      ],
    );
  }


  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: dqBorder, width: 1),
        ),
        child: Text(
          text,
          style: dqText(size: 10, w: FontWeight.w800, color: const Color(0xFF2A1C00), spacing: 0.5),
        ),
      );

  // ── Eiken label helpers (5級 / 準2級 / 準2級+ etc.) ──
  static String _eikenLabel(String level) {
    switch (level) {
      case 'pre2':
        return '英検準2級';
      case 'pre2plus':
        return '英検準2級+';
      case 'pre1':
        return '英検準1級';
      default:
        return '英検$level級';
    }
  }
}

/// Luminance-weighted desaturation + a brightness lift so locked towns read as
/// ghostly-grey PLACES (the サイレント state) on the night field rather than
/// black discs — they bloom into full colour only once reached. The +52 offset
/// is essential: the source scenes are already dark night art, so plain
/// greyscale alone left them invisible against the background.
const List<double> _kGreyscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 52,
  0.2126, 0.7152, 0.0722, 0, 52,
  0.2126, 0.7152, 0.0722, 0, 52,
  0, 0, 0, 1, 0,
];

/// Paints the winding golden road between town medallions. Segments leading to
/// a reached town glow gold; the road ahead stays a dim, unlit trail.
class _TrailPainter extends CustomPainter {
  final List<Offset> centers;
  final int reachedIndex;

  const _TrailPainter({required this.centers, required this.reachedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      final midY = (a.dy + b.dy) / 2;
      // An S-curve from a to b (control points pull the road sideways so the
      // serpentine reads as a road, not a zigzag).
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      final lit = (i + 1) <= reachedIndex;
      if (lit) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 15
            ..color = dqGold.withAlpha(55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = lit ? dqGold : dqGoldDeep.withAlpha(90),
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.reachedIndex != reachedIndex || old.centers != centers;
}

import 'package:flutter/material.dart';
import 'package:engquest/features/explore/chapter.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

/// The 案内図 — a chapter's locations as a hub-and-spoke map (#92 world-depth, the
/// structural answer to "one scene per story"). Reveal-1-ahead: a locked location
/// shows greyscale + padlock, the current one is full-colour + a 「ここ」 pin, and
/// cleared ones get a gold seal. Tapping a reachable node enters that location's
/// [SceneView]. Modelled on QuestMapScreen's medallion idiom for visual
/// consistency. Child-friendly per 2026 kids-UX research: state conveyed by
/// saturation + icon (never text alone), large tap targets, ≤4 nodes per board.
///
/// Single-location chapters never reach this screen — the caller routes straight
/// to the scene (zero added friction). It appears only once a chapter has 2+
/// locations, so today it is preview-only (?preview=chaptermap) until real 2nd
/// locations land.
class ChapterMapScreen extends StatelessWidget {
  final Chapter chapter;

  /// Mandatory ナゾ answered first-try-correct in each location (same length and
  /// order as [Chapter.locations]) — drives the reveal-1-ahead gate.
  final List<int> firstTryCorrectPerLocation;

  const ChapterMapScreen({
    super.key,
    required this.chapter,
    required this.firstTryCorrectPerLocation,
  });

  // Rec.709 luma greyscale for locked nodes (matches the scene saturation verb).
  static const List<double> _kGreyscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final states = deriveNodeStates(chapter, firstTryCorrectPerLocation);
    return DqScene(
      contentMaxWidth: 720,
      child: Column(
        children: [
          _header(context),
          Expanded(child: _board(context, states)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'もどる',
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: dqBorder),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('あんないず', style: dqText(size: 12, color: dqGold)),
                Text(
                  chapter.titleJa,
                  style: dqText(size: 18, color: dqBorder),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _board(BuildContext context, List<MapNodeState> states) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final d = (w * 0.26).clamp(76.0, 132.0);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TrailPainter(chapter.map.nodes, states),
              ),
            ),
            for (int i = 0; i < chapter.map.nodes.length; i++)
              _node(context, i, states[i], w, h, d),
          ],
        );
      },
    );
  }

  Widget _node(
    BuildContext context,
    int i,
    MapNodeState state,
    double w,
    double h,
    double d,
  ) {
    final node = chapter.map.nodes[i];
    final loc = chapter.locations[node.locationIndex];
    final locked = state == MapNodeState.locked;
    final cleared = state == MapNodeState.cleared;
    final current = state == MapNodeState.current;

    Widget img = Image.asset(
      loc.scene.backgroundAsset,
      width: d,
      height: d,
      fit: BoxFit.cover,
      cacheWidth: 264, // decode small — the map is not the full plate
      errorBuilder: (_, __, ___) => Container(
        color: dqNight1,
        alignment: Alignment.center,
        child: const Icon(Icons.castle, color: dqGold, size: 28),
      ),
    );
    if (locked) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kGreyscale),
        child: img,
      );
    }

    final ring = cleared || current ? dqGold : dqGoldDeep.withAlpha(190);
    final medallion = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: current ? 3.4 : 2.4),
        boxShadow: [
          BoxShadow(
            color:
                (current ? dqGold : dqGoldDeep).withAlpha(current ? 150 : 80),
            blurRadius: current ? 16 : 7,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            img,
            if (locked) Container(color: dqNight0.withAlpha(70)),
            if (locked)
              const Center(
                  child: Icon(Icons.lock, color: Colors.white, size: 28)),
            if (cleared)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [dqGold, dqGoldDeep]),
                  ),
                  child: const Icon(Icons.check,
                      color: Color(0xFF2A1C00), size: 16),
                ),
              ),
          ],
        ),
      ),
    );

    // "you are here" pin above the current node — an icon, not text (non-readers).
    final marker = current
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place, color: dqGold, size: 30),
              SizedBox(width: d, height: d, child: medallion),
            ],
          )
        : SizedBox(width: d, height: d, child: medallion);

    final pinH = current ? 30.0 : 0.0;
    final left = node.x * w - d / 2;
    final top = node.y * h - d / 2 - pinH;

    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        button: !locked,
        label: _a11yLabel(i, state),
        child: GestureDetector(
          onTap: locked
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SceneView(
                        scene: loc.scene,
                        eikenLevel: chapter.grade,
                      ),
                    ),
                  ),
          child: marker,
        ),
      ),
    );
  }

  String _a11yLabel(int i, MapNodeState state) {
    final n = i + 1;
    switch (state) {
      case MapNodeState.locked:
        return '$n ばんめの ばしょ。まだ いけません';
      case MapNodeState.current:
        return '$n ばんめの ばしょ。いま ここ。タップして はいる';
      case MapNodeState.cleared:
        return '$n ばんめの ばしょ。クリアずみ。もういちど はいれます';
    }
  }
}

/// Draws the road connecting consecutive map nodes — solid gold up to the current
/// node, faint dashed beyond (the not-yet-walked path).
class _TrailPainter extends CustomPainter {
  final List<MapNode> nodes;
  final List<MapNodeState> states;
  const _TrailPainter(this.nodes, this.states);

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.length < 2) return;
    for (int i = 0; i < nodes.length - 1; i++) {
      final a = Offset(nodes[i].x * size.width, nodes[i].y * size.height);
      final b =
          Offset(nodes[i + 1].x * size.width, nodes[i + 1].y * size.height);
      final walked = states[i] == MapNodeState.cleared;
      final paint = Paint()
        ..color = walked ? dqGold.withAlpha(200) : dqGoldDeep.withAlpha(110)
        ..strokeWidth = walked ? 4 : 3
        ..strokeCap = StrokeCap.round;
      if (walked) {
        canvas.drawLine(a, b, paint);
      } else {
        _dashed(canvas, a, b, paint);
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 9.0;
    const gap = 7.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double t = 0;
    while (t < total) {
      final start = a + dir * t;
      final end = a + dir * (t + dash).clamp(0, total);
      canvas.drawLine(start, end, paint);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.nodes != nodes || old.states != states;
}

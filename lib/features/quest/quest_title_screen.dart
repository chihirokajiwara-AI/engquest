// lib/features/quest/quest_title_screen.dart
// A-KEN Quest — the title screen, built to a 本格 Dragon-Quest standard:
// black field → ornate parchment+gold carved frame → textured map background
// → beveled crest logo → cursor menu. Verified against the DQ3 reference.

import 'package:flutter/material.dart';
import 'package:engquest/core/ui/app_fonts.dart';

class QuestTitleScreen extends StatelessWidget {
  /// Called when the player chooses はじめる.
  final VoidCallback onStart;
  const QuestTitleScreen({super.key, required this.onStart});

  static const _gold = Color(0xFFF0D080);
  static const _goldDeep = Color(0xFFB8923C);
  static const _goldDark = Color(0xFF6E5320);
  static const _parchment = Color(0xFF6B4F2A);
  static const _ink = Color(0xFFEDE3C8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _ornateFrame(child: _innerContent()),
          ),
        ),
      ),
    );
  }

  // ── Ornate carved frame: gold rim → dark bevel → gold inner line → corners ──
  Widget _ornateFrame({required Widget child}) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gold, _goldDeep, _goldDark, _goldDeep, _gold],
              stops: [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: _goldDeep.withAlpha(120), blurRadius: 26, spreadRadius: 2),
              const BoxShadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.all(7),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF120B04),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _goldDark, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(borderRadius: BorderRadius.circular(3), child: child),
          ),
        ),
        // four corner ornaments
        for (final a in const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight
        ])
          Positioned.fill(child: Align(alignment: a, child: _corner())),
      ],
    );
  }

  Widget _corner() => Container(
        margin: const EdgeInsets.all(3),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFF0C0), _goldDeep]),
          shape: BoxShape.circle,
          border: Border.all(color: _goldDark, width: 1.5),
          boxShadow: [BoxShadow(color: _gold.withAlpha(160), blurRadius: 8)],
        ),
      );

  // ── Inside the frame: textured map bg + logo + menu ──
  Widget _innerContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // textured background (generated map; parchment fallback). The warm
        // parchment field shows WHILE the painted map decodes, and the map fades
        // in over it — so a cold boot opens on parchment→map, never a black frame
        // inside the gold border (#56: CEO saw the painted map pop in late).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Color(0xFF8A6A38), _parchment, Color(0xFF3C2C16)],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Image.asset(
          'assets/art/title_bg.png',
          fit: BoxFit.cover,
          frameBuilder: (_, child, frame, wasSync) => AnimatedOpacity(
            opacity: (frame == null && !wasSync) ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeIn,
            child: child,
          ),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        // darken for logo/menu legibility
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withAlpha(150), Colors.black.withAlpha(70), Colors.black.withAlpha(190)],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _crest(),
              const SizedBox(height: 10),
              _logo(),
              const SizedBox(height: 12),
              _subtitleBanner(),
              const Spacer(flex: 4),
              _menu(),
              const Spacer(flex: 2),
              Text('© A-KEN QUEST  英検学習RPG',
                  style: notoSerifJp(color: _ink.withAlpha(140), fontSize: 9, letterSpacing: 1)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  // Generated heraldic crest (wings + gem). Falls back to a simple mark.
  Widget _crest() => Image.asset(
        'assets/art/crest.png',
        height: 96,
        errorBuilder: (_, __, ___) => SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.flip(flipX: true, child: const Icon(Icons.eco, color: _gold, size: 26)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.diamond, color: Color(0xFFBFE3FF), size: 22),
              ),
              const Icon(Icons.eco, color: _gold, size: 26),
            ],
          ),
        ),
      );

  // beveled blue+white title (DQ-style: gradient fill, light top, dark outline)
  Widget _logo() {
    final style = notoSerifJp(
      fontSize: 42,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // dark outline / extrude
        Text('コトバ探偵',
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..color = const Color(0xFF12233F),
              shadows: const [Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 4))],
            )),
        // blue→steel gradient fill with a white top highlight
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFF8FD0FF), Color(0xFF2E72C8), Color(0xFF1A4E97)],
            stops: [0.0, 0.32, 0.7, 1.0],
          ).createShader(r),
          child: Text('コトバ探偵', style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _subtitleBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A4E97), Color(0xFF2E72C8), Color(0xFF1A4E97)]),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _gold, width: 1),
        ),
        child: Text('英検（えいけん）の ぼうけん',
            style: notoSerifJp(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
      );

  Widget _menu() => Column(
        children: [
          _menuItem('はじめる / Start', selected: true, onTap: onStart),
          const SizedBox(height: 6),
          _menuItem('つづきから / Continue', selected: false, onTap: onStart),
        ],
      );

  // DQ-style command window: dark navy box, cream border, ▶ cursor when selected.
  Widget _menuItem(String label, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 36),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF101A33).withAlpha(selected ? 235 : 180),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF5ECD0), width: 2),
          boxShadow: selected
              ? [BoxShadow(color: _gold.withAlpha(120), blurRadius: 14)]
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: selected
                  ? const Icon(Icons.play_arrow, color: _gold, size: 18)
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label,
                    maxLines: 1,
                    style: notoSerifJp(
                      color: selected ? Colors.white : _ink.withAlpha(190),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

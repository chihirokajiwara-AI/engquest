// lib/features/quest/ui/dq_ui.dart
// A-KEN Quest — the shared 本格 (Dragon-Quest-grade) scene-framework components.
// Every quest scene composes these so the whole game reads as one coherent,
// professional RPG: atmospheric backgrounds, navy+cream dialogue boxes, ▶cursor
// command windows. Replaces the bright pastel card UI.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ──
const dqNight0 = Color(0xFF0A0E24);
const dqNight1 = Color(0xFF1A2244);
const dqBox = Color(0xFF101A33); // dialogue / command window fill
const dqBorder = Color(0xFFF5ECD0); // cream border
const dqGold = Color(0xFFF0D080);
const dqGoldDeep = Color(0xFFB8923C);
const dqInk = Color(0xFFEDE3C8);

TextStyle dqText({double size = 16, FontWeight w = FontWeight.w600, Color color = Colors.white, double spacing = 0.5}) =>
    GoogleFonts.notoSerifJp(
      color: color,
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      height: 1.5,
      shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2))],
    );

/// Full-screen atmospheric scene: a background image (or a deep-night gradient
/// fallback) under a darkening overlay for legibility.
class DqScene extends StatelessWidget {
  final String? backgroundAsset;
  final Widget child;
  const DqScene({super.key, this.backgroundAsset, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dqNight0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundAsset != null)
            Image.asset(backgroundAsset!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _gradient())
          else
            _gradient(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(120), Colors.black.withAlpha(60), Colors.black.withAlpha(170)],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }

  Widget _gradient() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [dqNight0, dqNight1, dqNight0],
          ),
        ),
      );
}

/// The DQ dialogue box: navy fill, cream double-border. Holds NPC speech /
/// narration, with an optional speaker nameplate notched into the top-left.
class DqDialogBox extends StatelessWidget {
  final Widget child;
  final String? speaker;
  const DqDialogBox({super.key, required this.child, this.speaker});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: dqBox.withAlpha(238),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: dqBorder, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: child,
        ),
        if (speaker != null)
          Positioned(
            top: -14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: dqBorder, width: 1.5),
              ),
              child: Text(speaker!,
                  style: GoogleFonts.notoSerifJp(
                      color: const Color(0xFF2A1C00), fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

/// A command-window choice (the answer tiles / menu items). State drives the
/// frame colour: normal / selected (gold) / correct (green) / wrong (red).
enum DqChoiceState { normal, correct, wrong }

class DqChoice extends StatelessWidget {
  final String label;
  final DqChoiceState state;
  final bool showCursor;
  final VoidCallback? onTap;
  const DqChoice({
    super.key,
    required this.label,
    this.state = DqChoiceState.normal,
    this.showCursor = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = dqBorder;
    Color fill = dqBox.withAlpha(210);
    if (state == DqChoiceState.correct) {
      border = const Color(0xFF8BE08B);
      fill = const Color(0xFF15351B).withAlpha(235);
    } else if (state == DqChoiceState.wrong) {
      border = const Color(0xFFE89090);
      fill = const Color(0xFF3A1414).withAlpha(235);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 2),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: showCursor ? const Icon(Icons.play_arrow, color: dqGold, size: 18) : null,
              ),
              Expanded(child: Text(label, style: dqText(size: 16))),
              if (state == DqChoiceState.correct)
                const Icon(Icons.check, color: Color(0xFF8BE08B), size: 20)
              else if (state == DqChoiceState.wrong)
                const Icon(Icons.close, color: Color(0xFFE89090), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold action button (はじめる / つぎへ).
class DqButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const DqButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? const LinearGradient(colors: [Color(0xFF5A5448), Color(0xFF3E3A32)])
              : const LinearGradient(colors: [dqGold, dqGoldDeep]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dqBorder, width: 1.5),
          boxShadow: onTap == null ? null : [BoxShadow(color: dqGoldDeep.withAlpha(120), blurRadius: 14)],
        ),
        child: Text(label,
            style: GoogleFonts.notoSerifJp(
                color: const Color(0xFF2A1C00), fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
      ),
    );
  }
}

/// Circular framed character portrait (NPC / party member).
class DqPortrait extends StatelessWidget {
  final String? imageAsset;
  final String? emoji;
  final double size;
  const DqPortrait({super.key, this.imageAsset, this.emoji, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dqBox,
        border: Border.all(color: dqGold, width: 2),
        boxShadow: [BoxShadow(color: dqGold.withAlpha(70), blurRadius: 8)],
      ),
      child: imageAsset != null
          ? Image.asset(imageAsset!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text(emoji ?? '👤', style: TextStyle(fontSize: size * 0.5))))
          : Center(child: Text(emoji ?? '👤', style: TextStyle(fontSize: size * 0.5))),
    );
  }
}

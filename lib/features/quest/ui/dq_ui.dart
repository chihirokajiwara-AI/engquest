// lib/features/quest/ui/dq_ui.dart
// A-KEN Quest — the shared コトバ探偵 scene-framework components.
// Every quest scene composes these so the whole game reads as one coherent,
// premium detective casebook: atmospheric backgrounds, navy+cream dialogue boxes,
// case-file entry tiles. Replaces the bright pastel card UI.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:engquest/core/ui/app_fonts.dart';
import 'package:engquest/core/ui/responsive.dart';

// ── Palette ──
const dqNight0 = Color(0xFF0A0E24);
const dqNight1 = Color(0xFF1A2244);
const dqBox = Color(0xFF101A33); // dialogue / command window fill
const dqBorder = Color(0xFFF5ECD0); // cream border
const dqGold = Color(0xFFF0D080);
const dqGoldDeep = Color(0xFFB8923C);
const dqInk = Color(0xFFEDE3C8);

// ── Detective-specific accent tokens ──
// evidenceRed: investigation urgency / solved-seal signal (think red evidence
// tape, stamped 「解決」). Distinct from gold so it can convey a separate state.
const evidenceRed = Color(0xFFCC2222);
// inkBlue: annotation ink / secondary information (think blue ballpoint margin
// notes in a detective's casebook). Used for secondary labels and gloss text.
const inkBlue = Color(0xFF4A7FAA);

// ── コトバ探偵 "casebook / 捜査ledger" tokens — our DISTINCT dark navy+gold skin.
// CEO 1933/1934: the earlier warm PARCHMENT version copied Layton's signature
// trade dress ("世界観も寄せすぎ"). We keep the premium FRAMED CRAFT (double-rule
// frame, framed-exhibit, name-tab — generic book-binding vocabulary) but re-skin
// the surface to OUR dark navy/gold (CEO 947 — intrinsically more distinct than
// parchment, and it matches the home/scene). The pc* names persist as "premium
// casebook"; the values are now the dark ink-ledger. cream-on-navy ≈ 9:1 (AAA).
// See memory distinct-identity-not-ip-copy; LAYTON-QUALITY-REDESIGN-SPEC.md.
const pcParchment0 = Color(0xFF0B1130); // page / tile base (deep navy)
const pcParchment1 = Color(0xFF15203E); // panel fill (navy)
const pcSepiaPanel = Color(0xFF1C2848); // raised card / framed-preview mat
const pcInk = Color(0xFFEDE3C8); // primary text (cream on navy)
const pcInkSoft = Color(0xFFBDB291); // labels / secondary (dim cream)
const pcFrameBrown = Color(0xFF6E5320); // fine outer border rule (dark gold)
const pcFrameGold = Color(0xFFF0D080); // inner gilt rule (bright gold)

TextStyle dqText(
        {double size = 16,
        FontWeight w = FontWeight.w600,
        Color color = Colors.white,
        double spacing = 0.5}) =>
    notoSerifJp(
      color: color,
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      height: 1.5,
      shadows: const [
        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2))
      ],
    );

/// Text on the warm parchment "casebook" surface (CEO 1904): [pcInk] by default
/// and NO drop shadow — ink on paper has no glow (the navy [dqText] uses a black
/// shadow for legibility over dark art; on cream that same shadow reads as grime).
TextStyle dqInkText(
        {double size = 16,
        FontWeight w = FontWeight.w600,
        Color color = pcInk,
        double spacing = 0.5}) =>
    notoSerifJp(
      color: color,
      fontSize: size,
      fontWeight: w,
      letterSpacing: spacing,
      height: 1.6,
    );

// ── Brand mark: コトバ探偵 magnifier-over-コ ──────────────────────────────────
//
// The detective identity in a single glyph: a gold magnifying lens framing
// the first character of our name (コ), with a short tapered handle. Drawn
// entirely with CustomPainter — zero new assets, crisp at any resolution.
//
// Proportions (based on `size` diameter D):
//   lens outer radius:   D * 0.42  (the circle)
//   ring stroke width:   D * 0.075 (readable but not chunky)
//   handle length:       D * 0.34  (exits lens at ~225° — lower-left)
//   handle width (base): D * 0.065 → tapers to D * 0.03 at tip
//   コ glyph:            D * 0.44  font size, centred in lens
//
// Use [BrandMark(size: 80)] at the title screen, [BrandMark(size: 48)] at
// the loading splash. Color is [dqGold] throughout with a subtle cream fill
// inside the lens to give slight depth.

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final d = size.width; // treat as square

    final outerR = d * 0.42;
    final ringW = d * 0.075;

    // ── 1. Subtle interior fill — a very dark navy so the コ glyph reads
    //       on a gold ring without harsh contrast.
    final fillPaint = Paint()
      ..color = const Color(0xFF0D1428)
      ..style = PaintingStyle.fill;
    // Lens centre: offset slightly UP-RIGHT so the handle exits lower-left.
    final lensCenter = Offset(cx - d * 0.04, cy - d * 0.04);
    canvas.drawCircle(lensCenter, outerR - ringW * 0.5, fillPaint);

    // ── 2. Outer glow ring (soft, large radius, low alpha) — makes the lens
    //       feel lit from above, like polished brass.
    final glowPaint = Paint()
      ..color = dqGold.withAlpha(55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringW * 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(lensCenter, outerR, glowPaint);

    // ── 3. Gold ring (the magnifier lens rim).
    final ringPaint = Paint()
      ..color = dqGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(lensCenter, outerR - ringW * 0.5, ringPaint);

    // ── 4. Handle: tapers from the lens at ~225° downward-left.
    //       Entry point = lens rim at 225°, exit = d*0.34 further along.
    // sin(225°) ≈ cos(225°) ≈ -√2/2 ≈ -0.7071 (lower-left diagonal).
    const sinA = -0.7071;
    const cosA = -0.7071;

    final rimX = lensCenter.dx + (outerR - ringW * 0.5) * cosA;
    final rimY = lensCenter.dy + (outerR - ringW * 0.5) * sinA;
    final tipX = lensCenter.dx + (outerR + d * 0.34) * cosA;
    final tipY = lensCenter.dy + (outerR + d * 0.34) * sinA;

    final baseHalf = d * 0.032;
    final tipHalf = d * 0.014;

    // Perpendicular direction (90° rotated from handle axis).
    const perpDx = -sinA; // perpendicular to handle direction
    const perpDy = cosA;

    final path = Path()
      ..moveTo(rimX + perpDx * baseHalf, rimY + perpDy * baseHalf)
      ..lineTo(tipX + perpDx * tipHalf, tipY + perpDy * tipHalf)
      ..lineTo(tipX - perpDx * tipHalf, tipY - perpDy * tipHalf)
      ..lineTo(rimX - perpDx * baseHalf, rimY - perpDy * baseHalf)
      ..close();

    final handleFill = Paint()
      ..color = dqGold
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, handleFill);

    // Handle edge stroke for crispness.
    final handleStroke = Paint()
      ..color = dqGoldDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = d * 0.012
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, handleStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The コトバ探偵 brand mark: a gold magnifying lens framing the katakana コ.
/// Drawn entirely with CustomPainter — no image assets required.
///
/// Sizes: 80–96 px at the title screen, 48 px at the loading splash.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    // The lens centre is nudged up-right inside the bounding box so the
    // lower-left handle has space without clipping.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Magnifier ring + handle.
          CustomPaint(
            size: Size(size, size),
            painter: const _BrandMarkPainter(),
          ),
          // コ glyph centred in the lens (offset matches lensCenter nudge).
          Transform.translate(
            offset: Offset(-size * 0.04, -size * 0.04),
            child: Text(
              'コ',
              style: notoSerifJp(
                color: dqGold,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                      color: Color(0xFF0A0E24),
                      blurRadius: 4,
                      offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a cloze/fill-in stem with the blank shown as a continuous gold
/// UNDERLINE gap (the print-英検 / mikan convention) instead of the literal
/// "(    )" the cloze builders insert — children misread parentheses as
/// punctuation, not a fill-in gap, and answer the format wrong rather than the
/// knowledge (#73). Splits on the whitespace-padded parens; degrades to plain
/// text when no blank marker is present. Shared by 大問1 vocab + 大問2 会話 + the
/// full mock. Matches 1+ inner spaces: the vocab builder inserts "(        )" but
/// the hand-authored reading/mock pool uses a single-space "( )" — both are blanks.
Widget clozeRich(String cloze, TextStyle style) {
  final m = RegExp(r'\(\s+\)').firstMatch(cloze);
  if (m == null) return Text(cloze, style: style);
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: cloze.substring(0, m.start)),
        TextSpan(
          text: '     ',
          style: style.copyWith(
            color: dqGold,
            decoration: TextDecoration.underline,
            decorationColor: dqGold,
            decorationThickness: 2.5,
          ),
        ),
        TextSpan(text: cloze.substring(m.end)),
      ],
    ),
  );
}

/// Full-screen atmospheric scene: a background image (or a deep-night gradient
/// fallback) under a darkening overlay for legibility.
class DqScene extends StatelessWidget {
  final String? backgroundAsset;
  final Widget child;

  /// When set, the content [child] is capped to this width and centred on wide
  /// screens (tablet / phone-landscape) so it doesn't stretch edge-to-edge — the
  /// dark scene fills the side margins. Null = full-width (the default; required
  /// for full-bleed screens like the world map whose layout uses the whole width).
  /// (#144 responsive — opt in on content screens.)
  final double? contentMaxWidth;

  /// Layton "casebook" surface (CEO 1904): when true, the scene is a warm
  /// parchment page (no dark backdrop/overlay) for the puzzle content screens.
  /// Default false keeps the dark 本格 world for exploration/scene screens.
  final bool warm;

  const DqScene({
    super.key,
    this.backgroundAsset,
    required this.child,
    this.contentMaxWidth,
    this.warm = false,
  });

  @override
  Widget build(BuildContext context) {
    if (warm) {
      return Scaffold(
        backgroundColor: pcParchment0,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Base layer: painted scene plate (blurred + scrimed) when provided,
            // otherwise the flat navy gradient. Puzzle cards sit on top, so the
            // world "surfaces behind" the ナゾ instead of being UI on a void.
            if (backgroundAsset != null) ...[
              // 1. Blurred scene plate — ImageFilter.blur recesses it so it reads
              //    as a deep atmospheric field, not a competing illustration.
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: 10, sigmaY: 10, tileMode: TileMode.clamp),
                child: Image.asset(
                  backgroundAsset!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0A0E24), Color(0xFF161F3C)],
                      ),
                    ),
                  ),
                ),
              ),
              // 2. Vertical-gradient scrim — evens the dimmed field top-to-bottom
              //    so the painted plate reads as a CONSISTENT recessed environment
              //    rather than a bright strip pinned to the top with a near-black
              //    bottom. Slightly heavier in the mid-zone (where the plate's
              //    brightest pigments live), lighter at the top edge and the
              //    already-dark lower sky — net result: flat perceived luminance.
              //    Alpha stops: 0x55 ≈ 0.33 · 0x88 ≈ 0.53 · 0x55 ≈ 0.33.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x55000000), // light at top
                      Color(0x88000000), // heavier mid-zone (bright pigments)
                      Color(0x66000000), // slightly lighter at the dark bottom
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ] else
              // Flat-gradient fallback when no plate is supplied.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A0E24), Color(0xFF161F3C)],
                  ),
                ),
              ),
            // Subtle vignette at the edges so the page reads as a deep field.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [Color(0x00000000), Color(0x30000000)],
                  stops: [0.65, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: contentMaxWidth != null
                  ? ResponsiveCenter(maxWidth: contentMaxWidth!, child: child)
                  : child,
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: dqNight0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundAsset != null)
            Image.asset(backgroundAsset!,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => _gradient())
          else
            _gradient(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(120),
                  Colors.black.withAlpha(60),
                  Colors.black.withAlpha(170)
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: contentMaxWidth != null
                ? ResponsiveCenter(maxWidth: contentMaxWidth!, child: child)
                : child,
          ),
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

  /// Layton "casebook" warm parchment skin (CEO 1904). Default false = navy.
  final bool warm;
  const DqDialogBox(
      {super.key, required this.child, this.speaker, this.warm = false});

  @override
  Widget build(BuildContext context) {
    if (warm) return DqParchPanel(speaker: speaker, child: child);
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
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))
            ],
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
                  style: notoSerifJp(
                      color: const Color(0xFF2A1C00),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
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
    // Screen-reader label: the choice text + its answered state, so a child
    // using VoiceOver/TalkBack hears "<choice>, せいかい/ふせいかい, ボタン".
    // The cursor-selected (▶) choice — e.g. a chosen mock answer before the
    // reveal — announces 「、せんたくちゅう」 IN THE LABEL so a screen-reader user
    // hears WHICH choice is selected (aria-selected alone was not reliably
    // surfaced by the Flutter-web button node — verified 2026-06-12).
    final semanticsLabel = state == DqChoiceState.correct
        ? '$label、せいかい'
        : state == DqChoiceState.wrong
            ? '$label、ふせいかい'
            : showCursor
                ? '$label、せんたくちゅう'
                : label;
    final Widget node = Semantics(
      button: true,
      label: semanticsLabel,
      // Expose the cursor-selected state (e.g. a chosen mock answer marked by ▶)
      // so a screen-reader user hears WHICH choice is selected — without this the
      // selection was visual-only (a11y gap surfaced by the 2026-06-12 playtest).
      selected: showCursor,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
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
                  child: showCursor
                      ? const Icon(Icons.play_arrow, color: dqGold, size: 18)
                      : null,
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
      ),
    );
    // Correct-answer kinetic POP (#64) — same win-feel as AudioOptionButton, for
    // DqChoice surfaces (exam practice: listening, mock exam). Reduced-motion → none.
    if (state == DqChoiceState.correct && !prefersReducedMotion(context)) {
      return TweenAnimationBuilder<double>(
        key: const ValueKey('dqchoice_correct_pop'),
        // A correct answer must read as a WIN = outward growth. The old
        // begin:0.85→1.0 SHRANK the tile first (recoil = the grammar of a wrong
        // hit; game-studio game-feel expert). Pop from 1.12 and elastic-settle
        // to resting 1.0 so the dominant motion is bigger, not smaller.
        // (begin:1.0→1.12 would have settled enlarged — kept end at 1.0.)
        tween: Tween(begin: 1.12, end: 1.0),
        duration: const Duration(milliseconds: 480),
        curve: Curves.elasticOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: node,
      );
    }
    return node;
  }
}

/// Gold action button (はじめる / つぎへ).
class DqButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  /// Secondary/ghost variant: a dim-navy fill with a gold outline + gold label
  /// instead of the filled-gold primary. Use for a "view/check" action sitting
  /// beside a primary "do" action so the pair has a clear focal hierarchy
  /// (visual-auditor CEO 2132 — the exam hub had two equal gold buttons).
  final bool secondary;
  const DqButton(
      {super.key, required this.label, this.onTap, this.secondary = false});

  @override
  State<DqButton> createState() => _DqButtonState();
}

class _DqButtonState extends State<DqButton>
    with SingleTickerProviderStateMixin {
  // Press-down spring (game-studio re-audit, CEO 1748): DqButton is the primary CTA
  // across the whole app but was a flat GestureDetector with NO tactile feedback —
  // a child pressed it and felt nothing. It now compresses on tap-down and springs
  // back (the same proven pattern as the Battle grade tiles). Reduced-motion → none.
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (widget.onTap == null || prefersReducedMotion(context)) return;
    _press.forward();
  }

  void _up([dynamic _]) {
    if (_press.value > 0) _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final label = widget.label;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _up,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            // 0 → 1 compresses 1.0 → 0.95; the elastic reverse overshoots back.
            final scale = 1.0 - 0.05 * Curves.easeOut.transform(_press.value);
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              // Disabled used a muddy OLIVE gradient that, with the dark ink
              // label below, measured ~1.2:1 — effectively illegible AND
              // off-palette (looked like a render bug; visual-auditor CEO 2132
              // on the writing 提出 button). Use a dim NAVY that fits the
              // dark-navy/gold scheme and reads as "not yet" without vanishing.
              gradient: onTap == null
                  ? const LinearGradient(
                      colors: [Color(0xFF353B57), Color(0xFF272C44)])
                  : widget.secondary
                      ? const LinearGradient(
                          colors: [Color(0xFF1A2138), Color(0xFF141A2E)])
                      : const LinearGradient(colors: [dqGold, dqGoldDeep]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      (widget.secondary && onTap != null) ? dqGold : dqBorder,
                  width: 1.5),
              boxShadow: (onTap == null || widget.secondary)
                  ? null
                  : [
                      BoxShadow(
                          color: dqGoldDeep.withAlpha(120), blurRadius: 14)
                    ],
            ),
            child: Text(label,
                style: notoSerifJp(
                    // Dark ink on gold (primary); GOLD on the dim-navy ghost
                    // (secondary); a dimmed CREAM on the dark disabled ground so
                    // the requirement text stays readable (≥4.5:1).
                    color: onTap == null
                        ? const Color(0xFFC9C0A8)
                        : widget.secondary
                            ? dqGold
                            : const Color(0xFF2A1C00),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ),
        ),
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
          ? Image.asset(imageAsset!,
              fit: BoxFit.cover,
              // Decode to the on-screen size, not the asset's native resolution:
              // a 1024px master sprite shown in a ~56px circle otherwise rasterizes
              // to ~4MB RAM and a main-thread decode hit (#perf flaw-hunt). cacheWidth
              // caps the decode at the displayed pixels. (Same pattern as scene_view.)
              cacheWidth:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, __, ___) => Center(
                  child: Text(emoji ?? '👤',
                      style: TextStyle(fontSize: size * 0.5))))
          : Center(
              child:
                  Text(emoji ?? '👤', style: TextStyle(fontSize: size * 0.5))),
    );
  }
}

/// Bilingual label helper. Renders `JP / EN` (CEO directive: English appears on
/// every short label since the app teaches English). Pass [stacked] to lay the
/// English under the Japanese (for tiles / large headings) instead of inline.
/// [jpSize] sizes the Japanese line; the English line is rendered ~0.7× in gold.
/// True for hiragana, katakana, CJK ideographs, and fullwidth forms (（）「」 etc.).
bool _isCjk(int r) =>
    (r >= 0x3040 && r <= 0x30FF) ||
    (r >= 0x4E00 && r <= 0x9FFF) ||
    (r >= 0x3000 && r <= 0x303F) ||
    (r >= 0xFF00 && r <= 0xFFEF);

/// Insert zero-width-space (U+200B) break opportunities after CJK characters so
/// Flutter-web/CanvasKit WRAPS long Japanese lines instead of overflowing and
/// clipping at the screen edge — CanvasKit does not apply CJK line-break rules
/// (verified on the live :8088 build, 2026-06-12; flutter#74742). Basic kinsoku:
/// never allow a break BEFORE closing punctuation. Latin runs keep normal spaces.
String jpBreak(String s) {
  const noBreakBefore = '。、，．）」』】〕｝！？・…ー';
  final runes = s.runes.toList();
  final b = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    b.writeCharCode(runes[i]);
    if (i + 1 < runes.length &&
        _isCjk(runes[i]) &&
        !noBreakBefore.contains(String.fromCharCode(runes[i + 1]))) {
      b.writeCharCode(0x200B);
    }
  }
  return b.toString();
}

Widget dqBilingual(
  String jp,
  String en, {
  double jpSize = 16,
  Color jpColor = Colors.white,
  Color enColor = dqGold,
  bool stacked = false,
  TextAlign align = TextAlign.start,
}) {
  final enSize = (jpSize * 0.7).clamp(10.0, 28.0).toDouble();
  if (stacked) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(jp,
            textAlign: align,
            style: dqText(size: jpSize, w: FontWeight.w700, color: jpColor)),
        const SizedBox(height: 2),
        Text(en,
            textAlign: align,
            style: dqText(
                size: enSize, w: FontWeight.w600, color: enColor, spacing: 1)),
      ],
    );
  }
  return RichText(
    textAlign: align,
    text: TextSpan(children: [
      TextSpan(
          text: jpBreak(jp),
          style: dqText(size: jpSize, w: FontWeight.w700, color: jpColor)),
      TextSpan(
          text: '  /  ',
          style: dqText(size: enSize, w: FontWeight.w600, color: dqGoldDeep)),
      TextSpan(
          text: en,
          style: dqText(
              size: enSize, w: FontWeight.w600, color: enColor, spacing: 1)),
    ]),
  );
}

/// A bordered navy panel for grouping content (stats, info, sections), with an
/// optional gold section [title]. Quieter than [DqDialogBox] — no nameplate —
/// for HUD blocks like 「もくひょう / Today's Goal」 or a stats grid.
class DqPanel extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;

  /// Layton "casebook" warm parchment skin (CEO 1904). Default false = navy.
  final bool warm;
  const DqPanel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.warm = false,
  });

  @override
  Widget build(BuildContext context) {
    if (warm) {
      return DqParchPanel(
        padding: padding is EdgeInsets
            ? padding as EdgeInsets
            : const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              // FIX 2: use pcInk (full cream ~9:1) instead of pcInkSoft (~3.5:1)
              // for the section label so multi-line ひらがな clears WCAG 4.5:1.
              Text(title!.toUpperCase(),
                  style: dqInkText(
                      size: 12, w: FontWeight.w800, color: pcInk, spacing: 2)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: pcFrameGold, height: 1, thickness: 1),
              ),
            ],
            child,
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: dqBox.withAlpha(225),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqBorder, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(title!.toUpperCase(),
                style: dqText(
                    size: 12, w: FontWeight.w800, color: dqGold, spacing: 2)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: dqGoldDeep, height: 1, thickness: 1),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

/// A command-style menu tile with a bilingual label (JP / EN) and an icon, for
/// home-screen quick-start actions (単語バトル / Word Battle, etc.). Renders as a
/// gold-bordered navy row with a leading icon medallion and a ▶ cursor; the
/// optional [color] tints only the icon medallion (the frame stays dq palette,
/// never candy-bright).
class DqTile extends StatelessWidget {
  final String jp;
  final String en;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  const DqTile({
    super.key,
    required this.jp,
    required this.en,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? dqGold;
    return Semantics(
      button: true,
      label: '$jp $en',
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [dqBox.withAlpha(235), dqNight1.withAlpha(235)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dqBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dqNight0,
                    border: Border.all(color: accent, width: 2),
                    boxShadow: [
                      BoxShadow(color: accent.withAlpha(70), blurRadius: 8)
                    ],
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: dqBilingual(jp, en, jpSize: 16, stacked: true)),
                const Icon(Icons.play_arrow, color: dqGold, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 英検5級『言葉を失った村』phonics-stage widgets ────────────────────────────
// Audio-central, autoplay-SAFE (every clip is also reachable via a large
// always-visible 🔊 button — see [DqReplayButton]). No pictures (hardened C4):
// meaning is carried by audio + the villager-revival beat.

/// A large, always-visible 🔊 replay button. The autoplay contract: on web,
/// audio must come from a user gesture, so this button is the guaranteed way to
/// hear (and imitate) every clip. [onTap] should call AudioCueService.play(...).
class DqReplayButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  const DqReplayButton({super.key, this.onTap, this.label = 'もう いちど きく'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: dqBorder, width: 2),
            boxShadow: [
              BoxShadow(color: dqGoldDeep.withAlpha(120), blurRadius: 14)
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volume_up_rounded,
                  color: Color(0xFF2A1C00), size: 24),
              const SizedBox(width: 10),
              Text(label,
                  style: notoSerifJp(
                      color: const Color(0xFF2A1C00),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase A card: a giant grapheme glyph + the Ember-Keeper villager portrait +
/// a large always-visible 🔊 replay button + the JA teach text. The pure phoneme
/// is auto-played on enter (best-effort) and replayed on the 🔊 tap.
class PhonicsLetterCard extends StatelessWidget {
  final String glyph;
  final String npcName;
  final String npcEmoji;
  final String? npcImage;
  final String? teachJa;
  final VoidCallback? onReplay;
  const PhonicsLetterCard({
    super.key,
    required this.glyph,
    required this.npcName,
    required this.npcEmoji,
    this.npcImage,
    this.teachJa,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DqPortrait(imageAsset: npcImage, emoji: npcEmoji, size: 64),
        const SizedBox(height: 14),
        // Giant glyph in a gold-framed plate.
        Container(
          width: 150,
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dqBox.withAlpha(235),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: dqGold, width: 3),
            boxShadow: [BoxShadow(color: dqGold.withAlpha(90), blurRadius: 20)],
          ),
          child: Text(glyph,
              style: notoSerifJp(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 16),
        DqReplayButton(onTap: onReplay, label: '🔁 おとを きく・まねする'),
        if (teachJa != null) ...[
          const SizedBox(height: 16),
          DqDialogBox(
              speaker: npcName, child: Text(teachJa!, style: dqText(size: 15))),
        ],
      ],
    );
  }
}

/// Phase A′/B card: separated letter tiles (c·a·t) that highlight in sequence
/// (driven by [activeLetter]) + a large 🔊 + the JA teach text. NO picture
/// (hardened C4). The whole-word options are rendered by the screen below.
class BlendWordCard extends StatelessWidget {
  final List<String> letters;
  final String word;
  final String npcName;
  final String npcEmoji;
  final String? npcImage;
  final String? teachJa;

  /// Index of the letter currently highlighted (-1 = none / whole word). Drives
  /// the c→a→t sweep the screen animates while the segmented audio plays.
  final int activeLetter;
  final VoidCallback? onReplay;
  const BlendWordCard({
    super.key,
    required this.letters,
    required this.word,
    required this.npcName,
    required this.npcEmoji,
    this.npcImage,
    this.teachJa,
    this.activeLetter = -1,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    // Council S3: once every phoneme is sounded the word is restored — announce
    // it so a screen-reader child hears "cat — できた" (liveRegion = on change).
    final done = activeLetter >= letters.length - 1;
    return Column(
      children: [
        DqPortrait(imageAsset: npcImage, emoji: npcEmoji, size: 60),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          label: done
              ? '$word、できた / $word complete'
              : 'おとを つなげよう / blend the sounds',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < letters.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child:
                        Text('·', style: dqText(size: 40, color: dqGoldDeep)),
                  ),
                _letterTile(letters[i], i == activeLetter),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        DqReplayButton(onTap: onReplay, label: '🔁 おとを つなげて きく'),
        if (teachJa != null) ...[
          const SizedBox(height: 16),
          DqDialogBox(
              speaker: npcName, child: Text(teachJa!, style: dqText(size: 15))),
        ],
      ],
    );
  }

  Widget _letterTile(String letter, bool active) {
    return Semantics(
      label: active ? '$letter、おとが でた' : letter,
      child: _letterTileBody(letter, active),
    );
  }

  Widget _letterTileBody(String letter, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 62,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF15351B).withAlpha(235)
            : dqBox.withAlpha(225),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active ? const Color(0xFF8BE08B) : dqBorder,
            width: active ? 3 : 2),
        boxShadow: active
            ? [
                BoxShadow(
                    color: const Color(0xFF8BE08B).withAlpha(140),
                    blurRadius: 16)
              ]
            : null,
      ),
      child: Text(letter,
          style: notoSerifJp(
              color: active ? const Color(0xFFCFF5CF) : Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800)),
    );
  }
}

/// An option button that PLAYS its own audio on tap (via [onAudio]) BEFORE the
/// answer is evaluated (via [onChoose]) — a [DqChoice] variant with a leading 🔊.
/// Lets a non-reader pick by sound. [state] colours correct (green); wrong is
/// only ever shown for penalized (Quiz) steps, handled by the caller.
class AudioOptionButton extends StatefulWidget {
  final String label;
  final DqChoiceState state;

  /// Plays the option's audio (call AudioCueService.play(option.audioAsset)).
  final VoidCallback? onAudio;

  /// Evaluates the choice (call the screen's _choose).
  final VoidCallback? onChoose;

  /// Layton "casebook" warm parchment tile (CEO 1904). Default false = navy.
  final bool warm;

  /// 1-based choice number. When set, a circled digit badge leads the tile so a
  /// 6歳 non-reader can tell THESE numbered cards are the answer choices — distinct
  /// from the ✦-coin hint rows below them (#115 affordance). Null = no badge
  /// (every non-ナゾ caller is unchanged). Arabic digit, not ①②③④, to avoid a
  /// subset-font tofu.
  final int? index;
  const AudioOptionButton({
    super.key,
    required this.label,
    this.state = DqChoiceState.normal,
    this.onAudio,
    this.onChoose,
    this.warm = false,
    this.index,
  });

  @override
  State<AudioOptionButton> createState() => AudioOptionButtonState();
}

/// Public so a caller (e.g. NazoScreen) can fire [triggerShake] imperatively via
/// a `GlobalKey<AudioOptionButtonState>` the instant a WRONG option is tapped —
/// the loop's only previously-dead interaction. (#59 game-feel; 2026 SOTA: a
/// kinetic wrong-answer response within one frame is table-stakes — Duolingo /
/// GameDev Academy 2025.) Critically this also gives feedback in the no-penalize
/// branch, which used to swallow the tap silently (a child could not tell it
/// registered).
class AudioOptionButtonState extends State<AudioOptionButton>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;
  // Press-down compression (studio #5): the game's MOST-tapped widget had zero
  // finger-down feedback → a 4-8yo got no confirmation their tap registered until
  // the answer resolved, training double-taps. Fire on press-DOWN (not release),
  // same proven pattern as DqButton. Reduced-motion skips it.
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // A damped left-right shudder that settles back to 0 (no residual offset).
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (prefersReducedMotion(context)) return;
    _press.forward();
  }

  void _pressUp() {
    if (_press.value > 0) _press.reverse();
  }

  /// Play the wrong-answer shudder once. No-op when "reduce motion" is on, so
  /// vestibular/seizure-sensitive children never get the shake.
  void triggerShake() {
    if (prefersReducedMotion(context)) return;
    _shakeCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final shakable = AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeCtrl.isAnimating ? _shakeAnim.value : 0, 0),
        child: child,
      ),
      child: _buildBody(context),
    );
    // Correct-answer kinetic POP (#64): wins were a static colour swap while wrong
    // answers shake (#59) — an inverted reward signal. On becoming correct, a brief
    // elastic scale-pop makes the win felt. The pop POPS BIG (1.12) then settles to
    // resting 1.0 — outward growth = a win; the old begin:0.85→1.0 shrank first,
    // which reads as a recoil/hit (game-studio game-feel expert). End stays 1.0 so
    // the tile never settles enlarged. Reduced-motion → no pop.
    final Widget content;
    if (widget.state == DqChoiceState.correct &&
        !prefersReducedMotion(context)) {
      content = TweenAnimationBuilder<double>(
        key: const ValueKey('dqaob_correct_pop'),
        tween: Tween(begin: 1.12, end: 1.0),
        duration: const Duration(milliseconds: 480),
        curve: Curves.elasticOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: shakable,
      );
    } else {
      content = shakable;
    }
    // Press-down compression on top (studio #5): the tile dips to 0.93 the instant
    // the finger lands, springs back on release. Under reduced-motion _press never
    // advances, so this is a no-op scale of 1.0.
    return AnimatedBuilder(
      animation: _press,
      builder: (_, child) => Transform.scale(
        scale: 1.0 - 0.07 * Curves.easeOut.transform(_press.value),
        child: child,
      ),
      child: content,
    );
  }

  Widget _buildBody(BuildContext context) {
    final label = widget.label;
    final state = widget.state;
    final onAudio = widget.onAudio;
    final onChoose = widget.onChoose;
    final warm =
        widget.warm; // "warm" = the framed casebook skin (now dark navy)
    Color border = warm ? pcFrameGold : dqBorder;
    Color fill = warm ? pcParchment1 : dqBox.withAlpha(210);
    final audioIcon = warm ? pcFrameGold : dqGold;
    if (state == DqChoiceState.correct) {
      border = const Color(0xFF7BD08B);
      fill = warm
          ? const Color(0xFF14361F)
          : const Color(0xFF15351B).withAlpha(235);
    } else if (state == DqChoiceState.wrong) {
      border = const Color(0xFFD9886A);
      fill = warm
          ? const Color(0xFF3A1A14)
          : const Color(0xFF3A1414).withAlpha(235);
    }
    // Body tap = choose (and play, so the child hears their pick). The leading
    // 🔊 is its OWN tap target that only auditions the clip — so a learner can
    // hear each option before committing (no accidental wrong-answer on a listen).
    final numPrefix = widget.index != null ? '${widget.index}ばん、' : '';
    // a11y: the inner 🔊 GestureDetector (its own preview-only tap for sighted
    // users) is hidden by excludeSemantics, so a screen-reader / switch child had
    // NO way to hear an option without committing — every activation was a blind
    // committed guess. Expose the preview as a SEPARATE custom action ("おとを きく")
    // so listen and choose are distinct in the a11y tree. Only promise listening
    // when an audio clip actually exists.
    final audioCb = onAudio; // local so the null-check promotes it for the map
    final semanticsLabel = state == DqChoiceState.correct
        ? '$numPrefix$label、せいかい'
        : state == DqChoiceState.wrong
            ? '$numPrefix$label、ふせいかい'
            : audioCb != null
                ? '$numPrefix$label。おとを きくこともできます'
                : '$numPrefix$label';
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: (onAudio == null && onChoose == null)
          ? null
          : () {
              onAudio?.call();
              onChoose?.call();
            },
      customSemanticsActions: audioCb == null
          ? null
          : {const CustomSemanticsAction(label: 'おとを きく'): audioCb},
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: GestureDetector(
          onTap: (onAudio == null && onChoose == null)
              ? null
              : () {
                  onAudio?.call();
                  onChoose?.call();
                },
          // Press-down compression (studio #5): only when the tile is answerable.
          onTapDown: (onAudio == null && onChoose == null)
              ? null
              : (_) => _pressDown(),
          onTapUp:
              (onAudio == null && onChoose == null) ? null : (_) => _pressUp(),
          onTapCancel: (onAudio == null && onChoose == null) ? null : _pressUp,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              children: [
                // Choice-number badge (#115): the unmistakable "pick one of these"
                // signal that separates answer tiles from the ✦-coin hint rows for
                // a non-reader. Only when an index was supplied (ナゾ).
                if (widget.index != null) ...[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (warm ? pcFrameGold : dqGold).withAlpha(38),
                      border: Border.all(
                          color: warm ? pcFrameGold : dqGold, width: 1.5),
                    ),
                    child: Text('${widget.index}',
                        style: warm
                            ? dqInkText(
                                size: 14, w: FontWeight.w800, color: pcInk)
                            : dqText(
                                size: 14, w: FontWeight.w800, color: dqGold)),
                  ),
                  const SizedBox(width: 10),
                ],
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAudio,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.volume_up_rounded,
                        color: audioIcon, size: 22),
                  ),
                ),
                Expanded(
                    child: Text(label,
                        style: warm
                            ? dqInkText(
                                size: 20, w: FontWeight.w700, color: pcInk)
                            : dqText(size: 20, w: FontWeight.w700))),
                if (state == DqChoiceState.correct)
                  const Icon(Icons.check, color: Color(0xFF7BD08B), size: 22)
                else if (state == DqChoiceState.wrong)
                  const Icon(Icons.close, color: Color(0xFFD9886A), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// True when the OS "reduce motion" accessibility setting is on. Gate animation
/// durations with this (→ Duration.zero) so vestibular/seizure-sensitive children
/// get the END state instantly instead of a transition. (#76 a11y, 2026-06-12)
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ── Layton "casebook" panels (CEO 1904 redesign — Phase 1 additive widgets;
//    not wired until the flagged ナゾ re-skin). See LAYTON-QUALITY-REDESIGN-SPEC.md.

/// A Layton casebook panel: warm parchment fill with a DOUBLE border (outer brown
/// rule + inset gilt rule) and a soft warm shadow — the core craft primitive the
/// dark navy boxes lack. Mirrors [DqDialogBox]'s optional gilt name-tab.
class DqParchPanel extends StatelessWidget {
  final Widget child;
  final String? speaker;
  final EdgeInsets padding;
  const DqParchPanel({
    super.key,
    required this.child,
    this.speaker,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: pcParchment1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pcFrameBrown, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: pcFrameGold, width: 1.2),
            ),
            child: child,
          ),
        ),
        if (speaker != null)
          Positioned(
            top: -13,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: pcFrameBrown, width: 1.2),
              ),
              child: Text(speaker!,
                  style: notoSerifJp(
                      color: const Color(0xFF2A1C00),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

// ── DetectiveCaseFrame — the cohesion-defining premium card (#113 / #159) ──────
//
// Problem: content screens (ナゾ teach card, achievements, caselog) render flat
// plain-navy rounded boxes while explore/title screens are genuinely crafted —
// the app reads as two different products. This reusable widget closes that gap:
// a premium dark-navy/gold framed card that makes any wrapped content read as a
// piece of the コトバ探偵 world.
//
// Design: outer dark-gold rule → 3 px gap → inner bright-gold gradient rule →
// subtle navy gradient fill (deeper at top/bottom edges for depth). Optional
// top "case bar" (e.g. EXHIBIT 01) and optional title slot; both use pcInk cream
// so contrast is AAA. [highlighted] brightens the gold rules and adds a soft
// gold glow — use it for the "focus" item (first teach item, active cue, etc.)
// to guide the eye without colour-palette pollution.
//
// No animations. No new colours — only dq_ui palette tokens. const-friendly.
//
// Usage:
//   DetectiveCaseFrame(
//     child: ...,
//     caseLabel: 'EXHIBIT 01',   // optional — narrow cap-text top bar
//     title: 'こんにちは',        // optional — gold heading inside frame
//     highlighted: true,          // optional — brighter frame + glow
//   )
/// A reusable premium dark-navy/gold framed card. Double-rule border: outer dark
/// gold [pcFrameBrown] rule + inset bright gold [pcFrameGold] gradient rule, with
/// a subtle navy gradient fill. Wraps arbitrary [child] content.
///
/// [caseLabel] — optional narrow ALL-CAPS strip at the very top of the card body
///               (e.g. 'EXHIBIT 01', 'てがかり'). Rendered in [pcInkSoft] at 11sp.
///               Adds a fine gold divider beneath it.
///
/// [title] — optional gold heading inside the frame, above [child].
///
/// [highlighted] — brighter outer/inner rules and a soft gold box-shadow. Use for
///                 the item that deserves visual priority (the first teach word,
///                 the current recall cue, etc.). Reduced-motion-safe: pure colour,
///                 no animation.
///
/// [padding] — inner padding; defaults to comfortable card padding.
class DetectiveCaseFrame extends StatelessWidget {
  final Widget child;
  final String? caseLabel;
  final String? title;
  final bool highlighted;
  final EdgeInsetsGeometry padding;

  const DetectiveCaseFrame({
    super.key,
    required this.child,
    this.caseLabel,
    this.title,
    this.highlighted = false,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });

  @override
  Widget build(BuildContext context) {
    // ── Colour tokens ────────────────────────────────────────────────────────
    // Normal:      outer rule = dark-gold (pcFrameBrown), inner = pcFrameGold
    // Highlighted: both rules brighter (pcFrameGold / dqGold) + soft gold glow
    final outerBorderColor = highlighted ? pcFrameGold : pcFrameBrown;
    final innerBorderColor = highlighted ? dqGold : pcFrameGold;

    // Fill: deep-navy → mid-navy → deep-navy (top-to-bottom) — the "depth" of
    // a physical object that catches the scene light in the middle.
    const fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0D1428), // deep edge (top)
        Color(0xFF192040), // mid fill (navy)
        Color(0xFF0D1428), // deep edge (bottom)
      ],
      stops: [0.0, 0.5, 1.0],
    );

    final outerBoxShadow = highlighted
        ? [
            BoxShadow(
                color: dqGold.withAlpha(55), blurRadius: 14, spreadRadius: 1)
          ]
        : const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))
          ];

    return Container(
      width: double.infinity,
      // Outer rule: the thick dark-gold frame that establishes the card boundary.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: outerBorderColor, width: highlighted ? 2.0 : 1.8),
        boxShadow: outerBoxShadow,
        // Fill sits at the outer container level so the inner margin gap shows
        // the gradient (the gap between outer rule and inner rule is the fill).
        gradient: fillGradient,
      ),
      child: Container(
        // Inner margin creates the visible gap between rules.
        margin: const EdgeInsets.all(3),
        // Inner rule: bright gold, thinner — the "gilt inlay" line.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: innerBorderColor, width: 1.0),
        ),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Optional top case-label strip ────────────────────────────────
            if (caseLabel != null) ...[
              Text(
                caseLabel!,
                style: dqInkText(
                  size: 10,
                  w: FontWeight.w800,
                  color: pcInkSoft,
                  spacing: 2.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 8),
                child: Container(
                  height: 1,
                  color: innerBorderColor.withAlpha(highlighted ? 200 : 120),
                ),
              ),
            ],
            // ── Optional gold title ──────────────────────────────────────────
            if (title != null) ...[
              Text(
                title!,
                style: dqInkText(
                  size: 13,
                  w: FontWeight.w800,
                  color: highlighted ? dqGold : pcFrameGold,
                  spacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
            ],
            // ── Content ──────────────────────────────────────────────────────
            child,
          ],
        ),
      ),
    );
  }
}

/// A Layton gold-framed "exhibit" preview — the framed puzzle thumbnail our ナゾ
/// screen is missing (the single most Layton-defining element). A sepia mat holds
/// [child] (art) inset, wrapped in the double brown+gold frame, with an optional
/// engraved [caption] strip (e.g. the puzzle genre).
class DqFramedPreview extends StatelessWidget {
  final Widget child;
  final String? caption;
  final double aspectRatio;
  const DqFramedPreview({
    super.key,
    required this.child,
    this.caption,
    this.aspectRatio = 16 / 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: pcSepiaPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pcFrameBrown, width: 2.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: pcFrameGold, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: AspectRatio(aspectRatio: aspectRatio, child: child),
              ),
            ),
            if (caption != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: pcParchment0,
                  border:
                      Border(top: BorderSide(color: pcFrameGold, width: 0.8)),
                ),
                child: Text(caption!,
                    textAlign: TextAlign.center,
                    style: dqInkText(
                        size: 12,
                        w: FontWeight.w800,
                        color: pcInkSoft,
                        spacing: 1.5)),
              ),
          ],
        ),
      ),
    );
  }
}

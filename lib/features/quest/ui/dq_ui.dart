// lib/features/quest/ui/dq_ui.dart
// A-KEN Quest — the shared 本格 (Dragon-Quest-grade) scene-framework components.
// Every quest scene composes these so the whole game reads as one coherent,
// professional RPG: atmospheric backgrounds, navy+cream dialogue boxes, ▶cursor
// command windows. Replaces the bright pastel card UI.

import 'package:flutter/material.dart';
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

  const DqScene({
    super.key,
    this.backgroundAsset,
    required this.child,
    this.contentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
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
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 360),
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
  const DqButton({super.key, required this.label, this.onTap});

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
              gradient: onTap == null
                  ? const LinearGradient(
                      colors: [Color(0xFF5A5448), Color(0xFF3E3A32)])
                  : const LinearGradient(colors: [dqGold, dqGoldDeep]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dqBorder, width: 1.5),
              boxShadow: onTap == null
                  ? null
                  : [
                      BoxShadow(
                          color: dqGoldDeep.withAlpha(120), blurRadius: 14)
                    ],
            ),
            child: Text(label,
                style: notoSerifJp(
                    color: const Color(0xFF2A1C00),
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
  const DqPanel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
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
    return Column(
      children: [
        DqPortrait(imageAsset: npcImage, emoji: npcEmoji, size: 60),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < letters.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('·', style: dqText(size: 40, color: dqGoldDeep)),
                ),
              _letterTile(letters[i], i == activeLetter),
            ],
          ],
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
  const AudioOptionButton({
    super.key,
    required this.label,
    this.state = DqChoiceState.normal,
    this.onAudio,
    this.onChoose,
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
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
    _shakeCtrl.dispose();
    super.dispose();
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
    // elastic scale-pop (grows past 100% then settles) makes the win felt. The
    // branch only exists in the correct state, so the freshly-inserted
    // TweenAnimationBuilder animates from begin once. Reduced-motion → no pop.
    if (widget.state == DqChoiceState.correct &&
        !prefersReducedMotion(context)) {
      return TweenAnimationBuilder<double>(
        key: const ValueKey('dqaob_correct_pop'),
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 360),
        curve: Curves.elasticOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: shakable,
      );
    }
    return shakable;
  }

  Widget _buildBody(BuildContext context) {
    final label = widget.label;
    final state = widget.state;
    final onAudio = widget.onAudio;
    final onChoose = widget.onChoose;
    Color border = dqBorder;
    Color fill = dqBox.withAlpha(210);
    if (state == DqChoiceState.correct) {
      border = const Color(0xFF8BE08B);
      fill = const Color(0xFF15351B).withAlpha(235);
    } else if (state == DqChoiceState.wrong) {
      border = const Color(0xFFE89090);
      fill = const Color(0xFF3A1414).withAlpha(235);
    }
    // Body tap = choose (and play, so the child hears their pick). The leading
    // 🔊 is its OWN tap target that only auditions the clip — so a learner can
    // hear each option before committing (no accidental wrong-answer on a listen).
    final semanticsLabel = state == DqChoiceState.correct
        ? '$label、せいかい'
        : state == DqChoiceState.wrong
            ? '$label、ふせいかい'
            : '$label。きくこともできます';
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: (onAudio == null && onChoose == null)
          ? null
          : () {
              onAudio?.call();
              onChoose?.call();
            },
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAudio,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child:
                        Icon(Icons.volume_up_rounded, color: dqGold, size: 22),
                  ),
                ),
                Expanded(
                    child: Text(label,
                        style: dqText(size: 20, w: FontWeight.w700))),
                if (state == DqChoiceState.correct)
                  const Icon(Icons.check, color: Color(0xFF8BE08B), size: 22)
                else if (state == DqChoiceState.wrong)
                  const Icon(Icons.close, color: Color(0xFFE89090), size: 22),
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

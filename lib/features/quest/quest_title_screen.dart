// lib/features/quest/quest_title_screen.dart
// A-KEN Quest — the title screen, コトバ探偵 detective identity.
// Dark-navy desk surface (noir/premium — NOT a parchment fantasy map).
// No ▶ cursor, no heraldic crest, no RPG command windows.
// Entry actions are case-file tiles in detective language.

import 'package:flutter/material.dart';
import 'package:engquest/core/ui/app_fonts.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

class QuestTitleScreen extends StatelessWidget {
  /// Called when the player chooses to begin a case (either entry action).
  final VoidCallback onStart;
  const QuestTitleScreen({super.key, required this.onStart});

  // Local palette aliases — reuse the shared dq_ui tokens.
  static const _gold = dqGold;
  static const _goldDeep = dqGoldDeep;
  static const _ink = dqInk;
  static const _night0 = dqNight0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _night0,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _thinGoldFrame(child: _innerContent()),
          ),
        ),
      ),
    );
  }

  // ── Clean thin gold hairline border — premium, not ornate or carved ──
  Widget _thinGoldFrame({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // Outer dark-gold rule.
        border: Border.all(color: const Color(0xFF6E5320), width: 1.8),
        boxShadow: [
          BoxShadow(
              color: _goldDeep.withAlpha(80), blurRadius: 28, spreadRadius: 1),
          const BoxShadow(
              color: Colors.black, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          // Inner bright-gold rule.
          border: Border.all(color: _gold.withAlpha(180), width: 1.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
    );
  }

  // ── Dark desk interior: deep-navy gradient + logo column + case-file tiles ──
  Widget _innerContent() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        // Detective noir: deep navy at the edges, slightly lighter mid —
        // the feel of a dark desk lamp pooling light in the centre.
        gradient: RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.1,
          colors: [
            Color(0xFF1C2448), // lamp-pool centre (lighter navy)
            dqNight1, // mid
            dqNight0, // deep edges
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const Spacer(flex: 3),
            // ── Brand mark: magnifier-over-コ ──
            const BrandMark(size: 88),
            const SizedBox(height: 14),
            _logo(),
            const SizedBox(height: 12),
            _subtitleBanner(),
            const Spacer(flex: 2),
            // Central case-file focal object (fills the mid void; presents the
            // unsolved case the detective opens — direction #1's case-envelope).
            _todaysCasePlate(),
            const Spacer(flex: 2),
            _caseEntries(),
            const Spacer(flex: 2),
            // Legal footer — product name stays, "RPG" dropped.
            Text(
              '英検対応 推理学習アプリ  ©︎ A-KEN QUEST',
              style: notoSerifJp(
                  color: _ink.withAlpha(130), fontSize: 9, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── コトバ探偵 wordmark — dark-navy outline + gold-to-white gradient fill ──
  Widget _logo() {
    final style = notoSerifJp(
      fontSize: 42,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // Dark outline / extrude.
        Text(
          'コトバ探偵',
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = const Color(0xFF0A1020),
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 4))
            ],
          ),
        ),
        // Gold→cream gradient fill with a top highlight.
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8DC), // cream top highlight
              dqGold, // bright gold upper-mid
              Color(0xFFD4A840), // mid gold
              dqGoldDeep, // deep gold base
            ],
            stops: [0.0, 0.28, 0.65, 1.0],
          ).createShader(r),
          child: Text('コトバ探偵', style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }

  // ── Subtitle banner — detective framing, no RPG adventure language ──
  Widget _subtitleBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        decoration: BoxDecoration(
          // Deep navy band with subtle gold borders — reads as a case-file label.
          color: const Color(0xFF0D1428),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _gold.withAlpha(160), width: 1),
        ),
        child: Text(
          'ことばを とりもどす 推理（すいり）',
          style: notoSerifJp(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
      );

  // ── Case-file entry tiles ─────────────────────────────────────────────────
  // A centred, non-interactive case-file plate: the unsolved case the detective
  // is about to open. Fills the title's mid-section with the product's premise
  // (replaces the dead navy void) and seats the evidence-red "unsolved" token.
  Widget _todaysCasePlate() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withAlpha(70), width: 1),
          color: Colors.black.withAlpha(55),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: evidenceRed, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  '未解決事件（みかいけつじけん）',
                  style: notoSerifJp(
                      color: _gold.withAlpha(205),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ことばを 失（うしな）った 街（まち）',
              style: notoSerifJp(
                  color: _ink.withAlpha(210),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1),
            ),
          ],
        ),
      );

  Widget _caseEntries() => Column(
        children: [
          _caseEntryTile(
            jp: '捜査（そうさ）を はじめる',
            en: 'Open the Case',
            // Small corner case-tag on the primary tile.
            caseTag: '事件 No.1',
            primary: true,
            semanticsLabel: '捜査（そうさ）を はじめる / Open the Case',
            onTap: onStart,
          ),
          const SizedBox(height: 8),
          _caseEntryTile(
            jp: '捜査を 再開（さいかい）',
            en: 'Resume',
            caseTag: null,
            primary: false,
            semanticsLabel: '捜査を 再開（さいかい） / Resume',
            onTap: onStart,
          ),
        ],
      );

  // Premium case-file entry tile.
  // No ▶ cursor. Corner [caseTag] on primary. Two hairline rules (inner/outer).
  Widget _caseEntryTile({
    required String jp,
    required String en,
    required String? caseTag,
    required bool primary,
    required String semanticsLabel,
    required VoidCallback onTap,
  }) {
    // a11y: the title screen is the universal first interaction — screen-reader
    // users must be able to start the game without sighted assistance.
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          // Outer double-rule container (matches DetectiveCaseFrame style).
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6E5320), width: 1.6),
            boxShadow: primary
                ? [
                    BoxShadow(color: _gold.withAlpha(90), blurRadius: 18),
                    const BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ]
                : [
                    const BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ],
          ),
          child: Container(
            // Inner bright-gold hairline rule (the "gilt inlay" line).
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: primary ? _gold.withAlpha(200) : _gold.withAlpha(100),
                  width: 1.0),
              // Fill: deep navy, slightly brighter for primary.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: primary
                    ? [
                        const Color(0xFF182042),
                        const Color(0xFF101830),
                      ]
                    : [
                        const Color(0xFF10192E),
                        const Color(0xFF0A0E24),
                      ],
              ),
            ),
            child: Stack(
              children: [
                // Case-tag corner label on the primary tile.
                if (caseTag != null)
                  Positioned(
                    top: 6,
                    right: 10,
                    child: Text(
                      caseTag,
                      style: notoSerifJp(
                        color: _gold.withAlpha(180),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                // Main label content.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      18, primary ? 16 : 13, 18, primary ? 16 : 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FittedBox so the JP line (with furigana parens) never
                      // wraps to a second line on a 390px tile — a wrap collided
                      // with the 事件 No. tag (CEO craft bar).
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          jp,
                          maxLines: 1,
                          style: notoSerifJp(
                            color: primary ? Colors.white : _ink.withAlpha(200),
                            fontSize: primary ? 17 : 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        en,
                        style: notoSerifJp(
                          color: primary
                              ? _gold.withAlpha(220)
                              : _gold.withAlpha(140),
                          fontSize: primary ? 11 : 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// lib/features/quest/quest_title_screen.dart
// A-KEN Quest — the title screen. The first impression: a 本格 (authentic) JRPG
// opening, not a form. Dark atmospheric sky, the hero, a serif gold title.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuestTitleScreen extends StatelessWidget {
  /// Called when the player taps はじめる.
  final VoidCallback onStart;
  const QuestTitleScreen({super.key, required this.onStart});

  // RPG palette — deep night sky + gold.
  static const _night0 = Color(0xFF0A0E24);
  static const _night1 = Color(0xFF231A4D);
  static const _night2 = Color(0xFF0A0E24);
  static const _gold = Color(0xFFF0D080);
  static const _goldDeep = Color(0xFFC9A24B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_night0, _night1, _night2],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // soft golden moon-glow behind the hero
              Align(
                alignment: const Alignment(0, -0.15),
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _gold.withAlpha(60),
                      _gold.withAlpha(0),
                    ]),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    // Title — serif gold, the story name above the brand.
                    Text(
                      'ことばの勇者',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSerifJp(
                        color: _gold,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        shadows: [
                          const Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 3)),
                          Shadow(color: _goldDeep.withAlpha(140), blurRadius: 24),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A-KEN  QUEST',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFE9E4F0),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(width: 56, height: 2, color: _goldDeep.withAlpha(180)),
                    const SizedBox(height: 6),
                    Text(
                      '英検（えいけん）の冒険（ぼうけん）',
                      style: GoogleFonts.notoSerifJp(
                        color: const Color(0xFFB9B2D6),
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(flex: 2),
                    // The hero, grounded with a soft shadow.
                    Expanded(
                      flex: 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/art/masters/prince.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.shield, color: _gold, size: 120),
                          ),
                          // Blend the master art's baked background into the night sky.
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [_night1, Colors.transparent, Colors.transparent, _night2],
                                stops: [0.0, 0.22, 0.72, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 1),
                    _startButton(),
                    const SizedBox(height: 10),
                    Text(
                      'タップして ぼうけんに でる',
                      style: GoogleFonts.notoSerifJp(
                          color: const Color(0xFF8E87AD), fontSize: 12),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _startButton() {
    return GestureDetector(
      onTap: onStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_gold, _goldDeep]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _gold, width: 1.5),
          boxShadow: [
            BoxShadow(color: _goldDeep.withAlpha(130), blurRadius: 22, spreadRadius: 1),
          ],
        ),
        child: Text(
          'はじめる',
          style: GoogleFonts.notoSerifJp(
            color: const Color(0xFF2A1C00),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

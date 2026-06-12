// lib/features/exam_practice/practice_result_stars.dart
//
// A compact 3-star reward row + tiered praise shown on every 英検 practice
// results screen (#51 reward moment, CEO 1320). The exam-practice modes — the
// core "passing" loop — ended on a flat score line: a perfect run looked
// identical to a bare 60% pass, so finishing well felt the same as scraping
// through. Stars that fill by accuracy give the satisfying "I did well!" beat
// that pulls a child into another session.
//
// PURELY COSMETIC: derived from the visible score only; never touches 合格率,
// scoring, or FSRS. Reused across all five results screens so the reward moment
// is consistent.

import 'package:flutter/material.dart';

import '../quest/ui/dq_ui.dart';

class PracticeResultStars extends StatelessWidget {
  final int correct;
  final int total;
  const PracticeResultStars({
    super.key,
    required this.correct,
    required this.total,
  });

  int get pct => total <= 0 ? 0 : (correct / total * 100).round();

  /// 0–3 filled stars by accuracy. Thresholds are gentle (a child near the 英検
  /// pass line of ~60% earns 2 stars) — encouraging, never punishing.
  int get stars => pct >= 85
      ? 3
      : pct >= 60
          ? 2
          : pct >= 35
              ? 1
              : 0;

  String get praise {
    if (pct >= 100) return 'ぜんもん せいかい！';
    if (pct >= 85) return 'すばらしい！';
    if (pct >= 60) return 'よく できました！';
    if (pct >= 35) return 'いい ちょうし！';
    return 'つぎは もっと いけるよ！';
  }

  @override
  Widget build(BuildContext context) {
    final filled = stars;
    return Column(
      key: const ValueKey('practice_result_stars'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40,
                  color: i < filled ? dqGold : dqInk.withAlpha(90),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          praise,
          style: dqText(size: 16, w: FontWeight.w800, color: dqGold),
        ),
      ],
    );
  }
}

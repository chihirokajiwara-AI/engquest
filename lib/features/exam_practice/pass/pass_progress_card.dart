// lib/features/exam_practice/pass/pass_progress_card.dart
// The session-end「合格率」progress moment — shown right after a practice session
// (battle / 大問) at the child's peak engagement. This is the daily-return spine
// (CEO 951): the child SEES their pass-readiness move closer to 合格, in context,
// the instant they finish — not a game-y reward, but honest progress toward the
// sole value (passing 英検).
//
// Honesty (mirrors the home readiness card, #66): on a thin sample (< 20 items)
// it does NOT show a confident %, it says "keep going, N more". A confident gauge
// would read as fabricated to a paying parent.

import 'package:flutter/material.dart';

import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/pass_gauge.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

class PassProgressCard extends StatelessWidget {
  /// Pass-readiness BEFORE this session (null = no prior data → no delta shown).
  final CseEstimate? pre;

  /// Pass-readiness AFTER this session. The caller skips the card entirely when
  /// the post estimate is null (unsupported grade / no data) — never fabricate.
  final CseEstimate post;

  const PassProgressCard({super.key, this.pre, required this.post});

  /// Minimum items before a confident 合格率 is shown (matches the home card).
  static const int kMinItems = 20;

  // Performance colours, consistent with the PassMeter skill bars.
  static const Color _pass = Color(0xFF8BE08B);
  static const Color _near = Color(0xFFE8B050);
  static const Color _far = Color(0xFFE0853A);

  @override
  Widget build(BuildContext context) {
    final n = post.totalItemsAttempted;
    final thin = n < kMinItems;

    return DqPanel(
      title: '合格率（ごうかくりつ）',
      child: thin ? _buildThin(n) : _buildConfident(),
    );
  }

  /// Thin sample → honest "keep going", no confident number.
  Widget _buildThin(int n) {
    final remaining = (kMinItems - n).clamp(1, kMinItems);
    return Row(
      children: [
        const Icon(Icons.search_rounded, color: _near, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('しんだんちゅう……',
                  style: dqText(size: 15, w: FontWeight.w800, color: dqInk)),
              const SizedBox(height: 3),
              Text('あと $remaining問（もん）で 合格率（ごうかくりつ）が でるよ',
                  style: dqText(
                      size: 12,
                      w: FontWeight.w500,
                      color: dqInk.withAlpha(200))),
            ],
          ),
        ),
      ],
    );
  }

  /// The encouragement / disclosure line under the headline. When the % is based
  /// on only some skills (Battle feeds reading; writing+listening untested for
  /// 3級+), it DISCLOSES the unmeasured skills so the % is never mistaken for a
  /// full readiness read — the same honesty the PassMeter enforces.
  String _subtext() {
    final un = post.unmeasuredSkills;
    if (un.isEmpty) return 'れんしゅうした ぶんだけ 合格（ごうかく）に 近（ちか）づく。';
    // Writing is AI-graded (backend), so it is "AI採点で測る", not something the
    // child measures by practising offline — say so honestly (#100 panel).
    final hasWriting = un.contains(EikenSkill.writing);
    final others = [
      if (un.contains(EikenSkill.listening)) 'リスニング',
      if (un.contains(EikenSkill.reading)) 'リーディング',
    ].join('・');
    if (hasWriting && others.isEmpty) {
      return '※ ライティングは AI採点で 測（はか）るよ';
    }
    if (hasWriting) {
      return '※ ライティングは AI採点、$others は これから 測るよ';
    }
    return '※ $others は これから 測（はか）るよ';
  }

  Widget _buildConfident() {
    final pct = post.readinessPct;
    final color = post.isPredictedPass ? _pass : (pct >= 65 ? _near : _far);

    final double? delta = pre != null ? pct - pre!.readinessPct : null;
    final bool gained = delta != null && delta >= 0.5;

    final String headline;
    if (post.isPredictedPass) {
      headline = '合格圏（ごうかくけん）の目安（めやす）！ この調子（ちょうし）。';
    } else if (pct >= 65) {
      headline = '合格（ごうかく）の目安（めやす）まで あと少（すこ）し';
    } else {
      headline = 'コツコツ つづけて 目安（めやす）に ちかづこう';
    }
    // NOTE: 合格圏 only fires when isPredictedPass — which requires
    // unmeasuredSkills to be empty (cse_model) — so we never claim PASS while a
    // required skill is untested. The % itself can still be from one skill only
    // (Battle feeds reading), so the subtext DISCLOSES what is not yet measured.

    return Row(
      children: [
        PassGauge(pct: pct, color: color, size: 92, stroke: 9, fontSize: 26),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (gained)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _pass.withAlpha(40),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _pass.withAlpha(150), width: 1.2),
                  ),
                  child: Text('＋${delta.toStringAsFixed(0)}％ アップ！',
                      style:
                          dqText(size: 13, w: FontWeight.w800, color: _pass)),
                ),
              if (gained) const SizedBox(height: 7),
              Text(headline,
                  style: dqText(size: 14, w: FontWeight.w800, color: color)),
              // Honesty qualifier (council #165): 合格圏 is a 目安, never a guaranteed
              // pass — a gentle child-readable note so the celebration can't be read
              // as a promise. Only on the predicted-pass state.
              if (post.isPredictedPass) ...[
                const SizedBox(height: 2),
                Text('※ いまの めやす だよ（ごうかくの やくそく では ないよ）',
                    style: dqText(
                        size: 10,
                        w: FontWeight.w500,
                        color: dqInk.withAlpha(160))),
              ],
              const SizedBox(height: 3),
              Text(_subtext(),
                  style: dqText(
                      size: 11,
                      w: FontWeight.w500,
                      color: dqInk.withAlpha(190))),
            ],
          ),
        ),
      ],
    );
  }
}

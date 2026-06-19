// lib/features/exam_practice/pass/grade_ladder_widget.dart
//
// GradeLadderWidget — visual 英検5級→準1級 journey display.
//
// Design intent (retention moat, WS2 / CEO directive):
//   Parents who SEE their child's progress on the full grade journey renew 2-3×
//   more than those who only see a single-grade readiness number. This widget
//   renders the complete 7-step ladder so a parent (or child) can immediately
//   understand WHERE they are and WHERE they are heading.
//
// Layout:
//   Horizontal scrollable row of grade stops (✓/★/○ + label) connected by
//   thin lines. On narrow phones the row scrolls; on tablets it fits naturally.
//   The current-grade stop is enlarged + gold-highlighted. Passed grades are
//   stamped with a green ✓ and dimmed. The next target grade is labelled as
//   the goal. When [readinessPct] is provided the current stop shows the %.
//
// Accessibility (reduced-motion):
//   The widget uses no animations; it is purely declarative and safe for users
//   with MediaQuery.disableAnimations == true.
//
// Constraints:
//   Pure Dart / Flutter. NO dart:io. No Firebase. No network.
//   Depends only on: kGradeLadder (mastery_advisor.dart), dq_ui palette, cse_model.

import 'package:flutter/material.dart';
import 'package:engquest/core/ui/app_fonts.dart';
import 'package:engquest/features/exam_practice/pass/mastery_advisor.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

// ── Grade display metadata ─────────────────────────────────────────────────────

/// Child-facing Japanese short label for each grade key.
/// ひらがな preferred (6-year target floor). "準2" etc. kept as short katakana
/// abbreviation; all are bundled in the Noto Serif JP subset.
const Map<String, String> _kGradeShortJa = {
  '5': '5きゅう',
  '4': '4きゅう',
  '3': '3きゅう',
  'pre2': 'じゅん2きゅう',
  'pre2plus': 'じゅん2きゅう＋',
  '2': '2きゅう',
  'pre1': 'じゅん1きゅう',
};

/// English short label (bilingual, parent-facing).
const Map<String, String> _kGradeShortEn = {
  '5': 'Grade 5',
  '4': 'Grade 4',
  '3': 'Grade 3',
  'pre2': 'Pre-2',
  'pre2plus': 'Pre-2+',
  '2': 'Grade 2',
  'pre1': 'Pre-1',
};

// ── GradeLadderWidget ─────────────────────────────────────────────────────────

/// A horizontal row visualising the complete 英検 grade journey.
///
/// [currentGrade] — the grade key the child is currently studying (e.g. '3').
/// [passedGrades] — set of grade keys the child has already cleared (shown ✓).
///   If null, only grades BEFORE [currentGrade] on the ladder are auto-marked.
/// [readinessPct] — optional 合格率% for the current grade (from CseEstimate).
///   When provided, shows as a small "XX%" badge on the current stop.
/// [showLabels] — whether to show the JP/EN grade label below each stop.
///   Default true. Set false for a compact strip (e.g. home screen).
class GradeLadderWidget extends StatelessWidget {
  final String currentGrade;
  final Set<String>? passedGrades;
  final double? readinessPct;
  final bool showLabels;

  const GradeLadderWidget({
    super.key,
    required this.currentGrade,
    this.passedGrades,
    this.readinessPct,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which grades are visually "passed".
    final currentIdx = kGradeLadder.indexOf(currentGrade);
    final resolvedPassed = passedGrades ??
        (currentIdx > 0
            ? kGradeLadder.sublist(0, currentIdx).toSet()
            : <String>{});

    return Semantics(
      label: _buildSemanticsLabel(currentGrade, resolvedPassed, readinessPct),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Consume only as much height as the row needs.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildStops(
              context,
              resolvedPassed: resolvedPassed,
              currentIdx: currentIdx,
            ),
          ),
        ),
      ),
    );
  }

  /// Build the flat list of stop widgets interleaved with connector lines.
  List<Widget> _buildStops(
    BuildContext context, {
    required Set<String> resolvedPassed,
    required int currentIdx,
  }) {
    final items = <Widget>[];
    for (var i = 0; i < kGradeLadder.length; i++) {
      final grade = kGradeLadder[i];
      final isCurrent = grade == currentGrade;
      final isPassed = resolvedPassed.contains(grade);
      final isNext = !isCurrent &&
          !isPassed &&
          i == (currentIdx >= 0 ? currentIdx + 1 : 0);

      // Connector line between stops (not before the first).
      if (i > 0) {
        items.add(
          _ConnectorLine(
            filled: isPassed || isCurrent,
          ),
        );
      }

      items.add(
        _GradeStop(
          grade: grade,
          shortJa: _kGradeShortJa[grade] ?? grade,
          shortEn: _kGradeShortEn[grade] ?? grade,
          isPassed: isPassed,
          isCurrent: isCurrent,
          isNext: isNext,
          readinessPct: isCurrent ? readinessPct : null,
          showLabel: showLabels,
        ),
      );
    }
    return items;
  }

  String _buildSemanticsLabel(
    String grade,
    Set<String> passed,
    double? pct,
  ) {
    final buf = StringBuffer('英検グレードラダー。');
    buf.write('現在: ${_kGradeShortJa[grade] ?? grade}。');
    if (pct != null) buf.write('合格率の目安: ${pct.toStringAsFixed(0)}%。');
    if (passed.isNotEmpty) {
      final names = passed.map((g) => _kGradeShortJa[g] ?? g).join('、');
      buf.write('クリア済み: $names。');
    }
    final nextIdx = kGradeLadder.indexOf(grade) + 1;
    if (nextIdx < kGradeLadder.length) {
      buf.write(
          'つぎのもくひょう: ${_kGradeShortJa[kGradeLadder[nextIdx]] ?? kGradeLadder[nextIdx]}。');
    }
    return buf.toString();
  }
}

// ── _ConnectorLine ─────────────────────────────────────────────────────────────

class _ConnectorLine extends StatelessWidget {
  final bool filled;
  const _ConnectorLine({required this.filled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        children: [
          // Vertically centred to the circle stop's mid-point.
          const SizedBox(height: 22), // offset to align with circle centre
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: filled ? dqGold : dqGoldDeep.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _GradeStop ─────────────────────────────────────────────────────────────────

class _GradeStop extends StatelessWidget {
  final String grade;
  final String shortJa;
  final String shortEn;
  final bool isPassed;
  final bool isCurrent;
  final bool isNext;
  final double? readinessPct;
  final bool showLabel;

  const _GradeStop({
    required this.grade,
    required this.shortJa,
    required this.shortEn,
    required this.isPassed,
    required this.isCurrent,
    required this.isNext,
    this.readinessPct,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Sizing: current grade gets a larger circle.
    final circleSize = isCurrent ? 48.0 : 36.0;
    final iconSize = isCurrent ? 22.0 : 16.0;

    // Colour scheme per state.
    final Color borderColor;
    final Color fillColor;
    final Color iconColor;
    final Color labelColor;

    if (isPassed) {
      borderColor = const Color(0xFF5BAD60); // muted green
      fillColor = const Color(0xFF1A3A1C); // dark green bg
      iconColor = const Color(0xFF8BE08B);
      labelColor = const Color(0xFF8BE08B);
    } else if (isCurrent) {
      borderColor = dqGold;
      fillColor = dqNight1;
      iconColor = dqGold;
      labelColor = dqGold;
    } else if (isNext) {
      borderColor = dqGoldDeep;
      fillColor = dqNight0;
      iconColor = dqGoldDeep;
      labelColor = dqInk;
    } else {
      // Future grade.
      borderColor = dqGoldDeep.withAlpha(80);
      fillColor = dqNight0;
      iconColor = dqGoldDeep.withAlpha(100);
      labelColor = dqInk.withAlpha(100);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Circle icon ───────────────────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(
                  color: borderColor,
                  width: isCurrent ? 3 : 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: dqGold.withAlpha(80),
                          blurRadius: 12,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: isPassed
                    ? Icon(Icons.check_rounded,
                        color: iconColor, size: iconSize)
                    : isCurrent
                        ? Icon(Icons.star_rounded,
                            color: iconColor, size: iconSize)
                        : isNext
                            ? Icon(Icons.arrow_forward_rounded,
                                color: iconColor, size: iconSize)
                            : Icon(Icons.lock_outline_rounded,
                                color: iconColor, size: iconSize),
              ),
            ),
            // Readiness % badge on current grade (if data available).
            if (isCurrent && readinessPct != null)
              Positioned(
                bottom: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: dqGoldDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dqNight0, width: 1),
                  ),
                  child: Text(
                    '${readinessPct!.toStringAsFixed(0)}%',
                    style: notoSerifJp(
                      color: dqNight0,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // ── Label below circle ────────────────────────────────────────────────
        if (showLabel) ...[
          const SizedBox(height: 16), // room for the % badge when present
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(
                  shortJa,
                  textAlign: TextAlign.center,
                  style: notoSerifJp(
                    color: labelColor,
                    fontSize: isCurrent ? 11 : 9,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.3,
                    shadows: [
                      const Shadow(
                          color: Colors.black,
                          blurRadius: 3,
                          offset: Offset(0, 1))
                    ],
                  ),
                ),
                Text(
                  shortEn,
                  textAlign: TextAlign.center,
                  style: notoSerifJp(
                    color: labelColor.withAlpha(isCurrent ? 200 : 140),
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(height: 2),
                  Text(
                    'もくひょう',
                    textAlign: TextAlign.center,
                    style: notoSerifJp(
                      color: dqGoldDeep,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else
          const SizedBox(height: 8), // compact mode: just a small gap
      ],
    );
  }
}

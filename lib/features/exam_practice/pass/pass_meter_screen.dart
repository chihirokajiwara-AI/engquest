// lib/features/exam_practice/pass/pass_meter_screen.dart
// A-KEN Quest — 合格メーター (Pass-Probability Readout Screen)
//
// Shows a child/parent:
//   • 予測合格率 NN% — how close to passing 英検 X級
//   • 合格まで あと N ポイント / 合格圏です — the gap in concrete CSE points
//   • Per-skill bars (Reading / Writing / Listening) with bilingual labels
//   • Weakest-skill call-to-action: "リスニングを のばそう"
//
// DESIGN CONTRACT:
//   • Reuses dq_ui.dart palette and components (DqScene, DqDialogBox, DqPanel,
//     DqButton, dqText, dqBilingual).
//   • Gentle, calm, ひらがな-friendly. No harsh red X. No grades below "がんばれ!".
//   • NO Firebase / network dependency in build or initState (R4).
//   • Data injected via constructor. Default [CseEstimate] demo profile works
//     immediately at ?preview (no dependency on real Firestore data).
//
// WIRING (to be done by the CEO — see REPORT section in task brief):
//   Add a route in app.dart, e.g.:
//     '/pass_meter': (context) {
//       final estimate = ModalRoute.of(context)!.settings.arguments as CseEstimate?;
//       return PassMeterScreen(estimate: estimate);
//     }
//   Trigger it from exam_practice_screen.dart after a session completes:
//     Navigator.pushNamed(context, '/pass_meter', arguments: myEstimate);
//
// NO dart:io. No Firebase. No network. (R4)

import 'package:flutter/material.dart';

import '../../quest/ui/dq_ui.dart';
import 'cse_model.dart';
import 'pass_gauge.dart';

// ── Demo profile (used when estimate is null, e.g. ?preview) ─────────────────

/// A pre-built 英検2級 demo estimate for quick previewing without real data.
/// Readiness ~83%: Writing is the limiting skill (60% accuracy → weak spot).
final _kDemoEstimate = CseEstimator.estimate(
  grade: '2',
  accuracies: [
    const SkillAccuracy(
        skill: EikenSkill.reading, accuracy: 0.81, itemsAttempted: 31),
    const SkillAccuracy(
        skill: EikenSkill.writing, accuracy: 0.60, itemsAttempted: 2),
    const SkillAccuracy(
        skill: EikenSkill.listening, accuracy: 0.74, itemsAttempted: 30),
  ],
)!;

// ── Screen ────────────────────────────────────────────────────────────────────

class PassMeterScreen extends StatelessWidget {
  /// The CSE estimate to display. Defaults to [_kDemoEstimate] when null,
  /// so the screen is always renderable (R3/R4: no null crash, no Firebase).
  final CseEstimate? estimate;

  const PassMeterScreen({super.key, this.estimate});

  @override
  Widget build(BuildContext context) {
    final est = estimate ?? _kDemoEstimate;
    final gradeLabel = _gradeLabelJa(est.grade);

    return DqScene(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back button + title ──────────────────────────────────────────
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                    child: Icon(Icons.arrow_back, color: dqGold, size: 24),
                  ),
                ),
                Expanded(
                  child: dqBilingual(
                    '$gradeLabel 合格メーター',
                    'Pass Prediction',
                    jpSize: 18,
                    stacked: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Hero meter ──────────────────────────────────────────────────
            _PassHero(est: est),

            const SizedBox(height: 20),

            // ── Per-skill bars ───────────────────────────────────────────────
            DqPanel(
              title: 'ぎじゅつべつ / Skills',
              child: _SkillBars(est: est),
            ),

            const SizedBox(height: 16),

            // ── Weakest-skill CTA ────────────────────────────────────────────
            if (est.limitingSkill != null && !est.isPredictedPass)
              _WeakSkillCta(
                skill: est.limitingSkill!,
                gradeLabel: gradeLabel,
                unmeasured: est.unmeasuredSkills.contains(est.limitingSkill),
              ),

            if (est.isPredictedPass) ...[
              const SizedBox(height: 8),
              _PassCelebration(gradeLabel: gradeLabel),
            ],

            const SizedBox(height: 20),

            // ── Motivational note ─────────────────────────────────────────────
            DqDialogBox(
              speaker: 'アドバイス',
              child: Text(
                _motivationalNote(est),
                style: dqText(size: 14),
              ),
            ),

            const SizedBox(height: 20),

            // ── Action button (placeholder — wired by CEO) ───────────────────
            DqButton(
              label: _ctaLabel(est),
              // Close the diagnose→practice loop: pop with the WEAKEST skill so
              // the caller (exam hub) routes the child straight into practising
              // it. Passing → pop null (just go back). #68
              onTap: () => Navigator.maybePop(
                context,
                est.isPredictedPass ? null : est.limitingSkill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero meter widget ─────────────────────────────────────────────────────────

class _PassHero extends StatelessWidget {
  final CseEstimate est;
  const _PassHero({required this.est});

  @override
  Widget build(BuildContext context) {
    final pct = est.readinessPct;
    final gradeLabel = _gradeLabelJa(est.grade);

    return DqPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),

          // Grade label
          Text(
            gradeLabel,
            textAlign: TextAlign.center,
            style: dqText(size: 15, color: dqGold),
          ),

          const SizedBox(height: 6),

          // Pass-probability gauge: a 270° arc filling toward the ごうかく goal,
          // the % centred and a goal marker at 100% — a designed meter, not a flat
          // bar (commercial-quality audit #68).
          PassGauge(pct: pct, color: _meterColor(pct)),

          const SizedBox(height: 2),
          Text(
            'よそくごうかくりつ / Predicted readiness',
            textAlign: TextAlign.center,
            style: dqText(size: 12, color: dqGold),
          ),

          // Basis disclosure: show how many questions back the % so a high
          // number built on few answers reads as provisional, not fabricated.
          if (est.totalItemsAttempted > 0) ...[
            const SizedBox(height: 6),
            Text(
              'これまでの ${est.totalItemsAttempted}もんを もとに けいさん\n'
              'based on ${est.totalItemsAttempted} answers',
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: const Color(0xFF8A93B5)),
            ),
          ],
          // Thin-sample honesty: a prediction on very few answers is a rough
          // guide, not a promise — say so rather than imply false precision.
          if (est.totalItemsAttempted > 0 && est.totalItemsAttempted < 20) ...[
            const SizedBox(height: 4),
            Text(
              '※ まだ データが すくないので、おおよその めやすです。',
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: const Color(0xFFE8B050)),
            ),
          ],

          // Provisional caption when a skill has no data yet — the headline %
          // counts that skill as 0, so it will rise once the child practices it.
          if (est.unmeasuredSkills.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '※ まだ れんしゅうしていない ぎじゅつが あるよ。\n'
              'やってみると ごうかくりつは かわります（とちゅうけいさん）。',
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: const Color(0xFF8A93B5)),
            ),
          ],

          const SizedBox(height: 10),

          // Points needed / pass message
          if (est.isPredictedPass)
            Text(
              'ごうかくけん！ / In passing zone',
              textAlign: TextAlign.center,
              style: dqText(size: 16, color: const Color(0xFF8BE08B)),
            )
          else
            Text(
              'ごうかくまで あと ${est.pointsNeeded} ポイント',
              textAlign: TextAlign.center,
              style: dqText(size: 16, color: dqInk),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Per-skill bars ────────────────────────────────────────────────────────────

class _SkillBars extends StatelessWidget {
  final CseEstimate est;
  const _SkillBars({required this.est});

  @override
  Widget build(BuildContext context) {
    final maxScores = CseEstimator.skillMaxScores(est.grade) ?? {};
    final skills = CseEstimator.skillsForGrade(est.grade) ?? [];

    return Column(
      children: [
        for (final skill in skills) ...[
          _SkillBar(
            skill: skill,
            score: est.skillScores[skill] ?? 0,
            maxScore: maxScores[skill] ?? 1,
            isLimiting: est.limitingSkill == skill,
            unmeasured: est.unmeasuredSkills.contains(skill),
            itemsAttempted: est.itemsAttempted[skill] ?? 0,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SkillBar extends StatelessWidget {
  final EikenSkill skill;
  final int score;
  final int maxScore;
  final bool isLimiting;

  /// True when the learner has no data for this skill — its 0 means "not yet
  /// measured", not "tested and failed". Shown as 未測定 with a muted bar.
  final bool unmeasured;

  /// How many questions this skill's score is based on — surfaced so a thin
  /// sample (e.g. writing on 2 items) is visible rather than hidden behind a
  /// confident-looking score.
  final int itemsAttempted;

  const _SkillBar({
    required this.skill,
    required this.score,
    required this.maxScore,
    required this.isLimiting,
    this.unmeasured = false,
    this.itemsAttempted = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    const mutedColor = Color(0xFF3A4256); // unmeasured: neutral, not warning
    // Performance-coded so a parent reads strong vs weak at a glance (audit):
    // green ≥80%, gold 65–79%, amber <65%. Unmeasured stays neutral (not failed).
    final barColor = unmeasured
        ? mutedColor
        : ratio >= 0.8
            ? const Color(0xFF8BE08B) // green — strong
            : ratio >= 0.65
                ? const Color(0xFFE8B050) // gold — building
                : const Color(0xFFE0853A); // amber — needs work
    final pctText = '${(ratio * 100).toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsive: a stacked (vertical) label + a wrappable right-aligned
        // readout so the row never overflows on a narrow phone (the inline
        // "JP / EN" label + score + sample count was ~230px too wide at 360px).
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isLimiting && !unmeasured)
              const Padding(
                padding: EdgeInsets.only(right: 6, bottom: 2),
                child: Icon(Icons.warning_amber, color: dqGold, size: 16),
              ),
            Expanded(
              child: dqBilingual(
                CseEstimator.skillLabelJa(skill),
                CseEstimator.skillLabelEn(skill),
                jpSize: 14,
                stacked: true,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                unmeasured
                    ? 'まだ / not measured'
                    : '$score / $maxScore ($pctText)・$itemsAttemptedもん',
                textAlign: TextAlign.right,
                style: dqText(
                  size: 13,
                  color: unmeasured ? const Color(0xFF8A93B5) : dqGold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: unmeasured ? 0.0 : ratio,
            minHeight: 14,
            backgroundColor: const Color(0xFF1A2244),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

// ── Weakest-skill CTA ─────────────────────────────────────────────────────────

class _WeakSkillCta extends StatelessWidget {
  final EikenSkill skill;
  final String gradeLabel;

  /// True when the limiting skill has NO data yet. Then the framing is "you
  /// haven't tried this — give it a go" (so we can measure you), NOT "your weak
  /// skill" — the child has nothing weak to improve, they simply haven't started.
  final bool unmeasured;

  const _WeakSkillCta({
    required this.skill,
    required this.gradeLabel,
    this.unmeasured = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelJa = CseEstimator.skillLabelJa(skill);
    final labelEn = CseEstimator.skillLabelEn(skill);

    return DqDialogBox(
      speaker: unmeasured
          ? 'まだの ぎじゅつ / Not tried yet'
          : 'よわいぎじゅつ / Weak skill',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_upward, color: dqGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unmeasured ? '$labelJaを ためしてみよう！' : '$labelJaを のばそう！',
                  style: dqText(size: 17, color: dqGold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            unmeasured
                ? '$labelJa ($labelEn) は まだ いちども やっていないよ。'
                    'いちど やってみると、ごうかくりつが もっと せいかくに なります。'
                : '$labelJa ($labelEn) が $gradeLabel ごうかくの カギです。'
                    'まいにち すこしずつ れんしゅうしよう！',
            style: dqText(size: 14),
          ),
        ],
      ),
    );
  }
}

// ── Pass celebration ──────────────────────────────────────────────────────────

class _PassCelebration extends StatelessWidget {
  final String gradeLabel;
  const _PassCelebration({required this.gradeLabel});

  @override
  Widget build(BuildContext context) {
    return DqPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFF8BE08B), size: 42),
          const SizedBox(height: 8),
          Text(
            '$gradeLabel ごうかくけん！',
            textAlign: TextAlign.center,
            style: dqText(size: 20, color: const Color(0xFF8BE08B)),
          ),
          const SizedBox(height: 6),
          Text(
            'このままがんばれば ごうかくできそうです！\n'
            'しけんびまで つづけよう。',
            textAlign: TextAlign.center,
            style: dqText(size: 14),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _meterColor(double pct) {
  if (pct >= 100) return const Color(0xFF8BE08B); // green — passing
  if (pct >= 80) return const Color(0xFFF0D080);  // gold — close
  if (pct >= 60) return const Color(0xFF6ABFEF);  // sky blue — building
  return const Color(0xFFEDE3C8);                  // cream — early stage
}

String _gradeLabelJa(String grade) {
  switch (grade) {
    case '5':
      return '英けん5きゅう';
    case '4':
      return '英けん4きゅう';
    case '3':
      return '英けん3きゅう';
    case 'pre2':
      return '英けんじゅん2きゅう';
    case 'pre2plus':
      return '英けんじゅん2きゅうプラス';
    case '2':
      return '英けん2きゅう';
    case 'pre1':
      return '英けんじゅん1きゅう';
    default:
      return '英けん';
  }
}

String _motivationalNote(CseEstimate est) {
  if (est.isPredictedPass) {
    return 'すばらしい！ ごうかくけんに はいっています。'
        'しけんびまで まいにちの れんしゅうを つづけて、'
        'じしんをもって うけましょう。';
  }
  final limitJa = est.limitingSkill != null
      ? CseEstimator.skillLabelJa(est.limitingSkill!)
      : 'れんしゅう';
  // If the weakest skill is simply untried, urge trying it (not "improve").
  if (est.limitingSkill != null &&
      est.unmeasuredSkills.contains(est.limitingSkill)) {
    return '$limitJa を まだ ためしていないよ。いちど やってみると、'
        'ごうかくりつが もっと せいかくに わかります！';
  }
  final needed = est.pointsNeeded;
  return '$limitJa を のばすと ごうかくに ちかづきます。'
      'あと $needed ポイント。まいにち すこしずつ れんしゅうすれば'
      'かならず とどきます！';
}

String _ctaLabel(CseEstimate est) {
  if (est.isPredictedPass) return 'もどる';
  final skill = est.limitingSkill;
  if (skill != null) {
    // Name the weakest skill so the CTA is an explicit "practise THIS" action,
    // not vague advice (#68 — diagnose→practice loop).
    return '${CseEstimator.skillLabelJa(skill)}を れんしゅうする';
  }
  return 'れんしゅうする';
}

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

import '../../../core/config/flavor_config.dart';
import '../../../core/storage/preferences_service.dart';
import '../../character/progress_tinted_character.dart';
import '../../paywall/grade_gate_screen.dart';
import '../../quest/ui/dq_ui.dart';
import '../../home/streak_service.dart';
import '../practice_encouragement.dart';
import 'cse_model.dart';
import 'mastery_advisor.dart';
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

  /// When non-null, a 「答え合わせ（見直し）」 button is shown that pushes the widget
  /// this builds (the post-mock review). Decoupled: PassMeterScreen does not
  /// import the review screen — the mock caller supplies the builder. Null for
  /// non-mock uses (the live 合格メーター), which have nothing to review.
  final WidgetBuilder? onReviewBuilder;

  /// Mastery-based progression advice (#14). When non-null, a gentle card
  /// suggests advancing / keeping practising / reviewing easier material.
  final MasteryRecommendation? recommendation;

  /// The streak/daily-goal state earned by the session that pushed this screen
  /// (the フル模試). When non-null a [SessionEndHook] celebrates the daily-return
  /// progress at the completion peak — the flagship mock previously ended with a
  /// score only, missing the at-completion reinforcement every other exam section
  /// already shows (#151). Null for the live 合格メーター (no session to credit).
  final StreakState? earnedStreak;

  const PassMeterScreen({
    super.key,
    this.estimate,
    this.onReviewBuilder,
    this.recommendation,
    this.earnedStreak,
  });

  @override
  Widget build(BuildContext context) {
    final est = estimate ?? _kDemoEstimate;
    final gradeLabel = _gradeLabelJa(est.grade);

    return DqScene(
      contentMaxWidth:
          600, // #144: centre the column on tablet, full-width on phone
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back button + title ──────────────────────────────────────────
            Row(
              children: [
                Semantics(
                  button: true,
                  label: 'もどる / Back',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Center(
                          child:
                              Icon(Icons.arrow_back, color: dqGold, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: dqBilingual(
                    '$gradeLabel 合格（ごうかく）メーター',
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

            // ── Daily-return reward at the completion peak (#151) ───────────
            // The mock is the highest-investment session; surface the streak /
            // daily-goal it just earned right after the 合格率 result, the way
            // every other exam section shows it at session end. Present only when
            // a session pushed this screen (the live 合格メーター has no earnedStreak).
            if (earnedStreak != null) ...[
              const SizedBox(height: 16),
              SessionEndHook(streak: earnedStreak!),
            ],

            // ── Mastery-based progression advice (#14) ──────────────────────
            if (recommendation != null) ...[
              const SizedBox(height: 16),
              _MasteryAdviceCard(rec: recommendation!),
            ],

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

            // ── Review answers (post-mock only) ──────────────────────────────
            // The highest-learning moment after a timed mock: step through the
            // items and see what was missed. Shown only when a review builder is
            // supplied (i.e. coming from フル模試), above the practice CTA.
            if (onReviewBuilder != null) ...[
              DqButton(
                label: '答（こた）え合（あ）わせを する / Review',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: onReviewBuilder!),
                ),
              ),
              const SizedBox(height: 12),
            ],

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

class _PassHero extends StatefulWidget {
  final CseEstimate est;
  const _PassHero({required this.est});

  @override
  State<_PassHero> createState() => _PassHeroState();
}

class _PassHeroState extends State<_PassHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final targetPct = widget.est.readinessPct;
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _anim = Tween<double>(begin: 0, end: targetPct).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS "reduce motion" accessibility setting: skip the sweep and
    // show the final value instantly. prefersReducedMotion is defined in dq_ui.dart.
    final reduced = prefersReducedMotion(context);
    final pct = widget.est.readinessPct;
    final gradeLabel = _gradeLabelJa(widget.est.grade);

    // When motion is reduced, jump the controller to the end state so _anim.value
    // equals the final pct. We do this lazily on first build rather than in
    // initState so the BuildContext is available for MediaQuery.
    if (reduced && !_ctrl.isCompleted) {
      _ctrl.value = 1.0;
    }

    return DqPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),

          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final animPct = reduced ? pct : _anim.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hero colours in with the HONEST readiness (CEO 3758 ①): grey
                  // when far from 合格, full colour at the 目安 — the same % the
                  // gauge below shows, felt as the protagonist coming to life.
                  // Default M5; gender-select #110.
                  ProgressTintedCharacter(
                    asset: HeroChoice.asset, // the child's chosen main (#110)
                    readiness: animPct / 100.0,
                    width: 84,
                    height: 120,
                    semanticLabel: '探偵（たんてい）。れんしゅうするほど 色（いろ）がつきます。',
                  ),
                  const SizedBox(height: 4),

                  // Grade label
                  Text(
                    gradeLabel,
                    textAlign: TextAlign.center,
                    style: dqText(size: 15, color: dqGold),
                  ),

                  const SizedBox(height: 6),

                  // Pass-probability gauge: a 270° arc filling toward the ごうかく
                  // goal, the % centred and a goal marker at 100% — a designed
                  // meter, not a flat bar (commercial-quality audit #68).
                  PassGauge(pct: animPct, color: _meterColor(animPct)),
                ],
              );
            },
          ),

          const SizedBox(height: 2),
          Text(
            '合格（ごうかく）の目安（めやす） / Readiness guide',
            textAlign: TextAlign.center,
            style: dqText(size: 12, color: dqGold),
          ),

          // Basis disclosure: show how many questions back the % so a high
          // number built on few answers reads as provisional, not fabricated.
          if (widget.est.totalItemsAttempted > 0) ...[
            const SizedBox(height: 6),
            Text(
              'これまでの ${widget.est.totalItemsAttempted}もんを もとに けいさん\n'
              'based on ${widget.est.totalItemsAttempted} answers',
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: const Color(0xFF8A93B5)),
            ),
          ],
          // Thin-sample honesty: a prediction on very few answers is a rough
          // guide, not a promise — say so rather than imply false precision.
          if (widget.est.totalItemsAttempted > 0 &&
              widget.est.totalItemsAttempted < 20) ...[
            const SizedBox(height: 4),
            Text(
              '※ まだ データが すくないので、おおよその めやすです。',
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: const Color(0xFFE8B050)),
            ),
          ],

          // Provisional caption when a skill has no data yet — the headline %
          // counts that skill as 0, so it will rise once the child practices it.
          // Writing is special: offline it can only be 未測定 because quality is
          // AI-graded, so we say so honestly rather than "you haven't tried it"
          // (which would be false — practicing writing offline records nothing).
          if (widget.est.unmeasuredSkills.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _unmeasuredCaption(widget.est.unmeasuredSkills),
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: const Color(0xFF8A93B5)),
            ),
          ],

          const SizedBox(height: 10),

          // Honest "how close" line — a 目安 band, never a fabricated CSE-point
          // gap (#113). The raw→CSE conversion is non-public + per-administration.
          Text(
            CseEstimator.readinessMessageJa(widget.est),
            textAlign: TextAlign.center,
            style: dqText(
              size: 16,
              color: widget.est.reachedPassMeyasu
                  ? const Color(0xFF8BE08B)
                  : dqInk,
            ),
          ),
          const SizedBox(height: 8),
          // Standing honesty disclaimer: this is a 目安, not a precise prediction.
          Text(
            '合格（ごうかく）の目安（めやす）は 正答率（せいとうりつ）'
            '${(widget.est.passTargetRaw * 100).round()}%（${widget.est.grade == 'pre1' ? '７割' : '６割'}）。\n'
            '${CseEstimator.meyasuDisclaimerJa}',
            textAlign: TextAlign.center,
            // Was size 10 in a muted blue-grey — a dense furigana paragraph that
            // failed 6yo readability (CEO demo-audit). Lift to 12 + cream so the
            // honesty disclaimer is actually legible.
            style: dqText(size: 12, color: dqInk.withAlpha(180))
                .copyWith(height: 1.5),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Honest caption for the unmeasured-skills disclosure. Writing offline is
/// 未測定 because quality is AI-graded (backend), NOT because the learner hasn't
/// tried — so its copy says "AI採点で測る（接続後）" instead of "やってみよう".
String _unmeasuredCaption(Set<EikenSkill> unmeasured) {
  final hasWriting = unmeasured.contains(EikenSkill.writing);
  final others = unmeasured.where((s) => s != EikenSkill.writing).isNotEmpty;
  if (hasWriting && !others) {
    return '※ ライティングの 質は AI採点で 測ります（接続後）。\n'
        'それまでは ライティングを のぞいた とちゅうけいさんです。';
  }
  if (hasWriting && others) {
    return '※ ライティングは AI採点で 測ります（接続後）。\n'
        'ほかの ぎじゅつは やってみると ごうかくりつが かわります。';
  }
  return '※ まだ れんしゅうしていない ぎじゅつが あるよ。\n'
      'やってみると ごうかくりつは かわります（とちゅうけいさん）。';
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

/// A shape-distinct icon for each performance tier, so the strong/building/
/// needs-work state is NOT conveyed by bar colour alone (WCAG 2.2 SC 1.4.1 — 8%
/// of boys are red-green colour-blind and the bar hues collapse for them). The
/// icon shapes (✓ / ↗ / !) read regardless of colour. #127.
({IconData icon, String labelJa}) _skillTier(double ratio) {
  if (ratio >= 0.8) {
    return (icon: Icons.check_circle_outline, labelJa: 'よくできている');
  }
  if (ratio >= 0.65) return (icon: Icons.trending_up, labelJa: 'あと少（すこ）し');
  return (icon: Icons.priority_high, labelJa: 'のばそう');
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
            if (!unmeasured) ...[
              Icon(
                _skillTier(ratio).icon,
                color: barColor,
                size: 16,
                semanticLabel: _skillTier(ratio).labelJa,
              ),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                unmeasured
                    // Writing quality is AI-graded (backend), so offline it is
                    // "AI採点まち" — honestly distinct from a skill the learner
                    // simply hasn't tried yet (#100 panel fast-follow).
                    ? (skill == EikenSkill.writing
                        ? 'AI採点（さいてん）まち / AI-graded'
                        : 'まだ / not measured')
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
    // Writing offline is 未測定 because quality is AI-graded — not because it was
    // never tried. Saying "ためしてみよう" would be false (offline writing records
    // nothing). Instead point to the AI grade + the offline 見直しチェック (#100).
    final writingUnmeasured = unmeasured && skill == EikenSkill.writing;

    return DqDialogBox(
      speaker: writingUnmeasured
          ? 'AI採点（さいてん）まち / Graded by AI'
          : unmeasured
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
                  writingUnmeasured
                      ? 'ライティングは AI先生が さいてん！'
                      : unmeasured
                          ? '$labelJaを ためしてみよう！'
                          : '$labelJaを のばそう！',
                  style: dqText(size: 17, color: dqGold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            writingUnmeasured
                ? 'ライティングの 中身の 質は AI先生が 採点します（接続後）。'
                    '今は「見直しチェック」で 形（かたち）を たしかめられるよ。'
                : unmeasured
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
  if (pct >= 80) return const Color(0xFFF0D080); // gold — close
  if (pct >= 60) return const Color(0xFF6ABFEF); // sky blue — building
  return const Color(0xFFEDE3C8); // cream — early stage
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
  // Writing is AI-graded — offline it cannot be "tried into" the gauge, so urge
  // the AI grade + 見直しチェック, not "try it" (which would be false).
  if (est.limitingSkill == EikenSkill.writing &&
      est.unmeasuredSkills.contains(EikenSkill.writing)) {
    return 'ライティングの 質は AI先生が 採点します（接続後）。'
        'それまでは「見直しチェック」で 形（かたち）を ととのえておこう！';
  }
  // If the weakest skill is simply untried, urge trying it (not "improve").
  if (est.limitingSkill != null &&
      est.unmeasuredSkills.contains(est.limitingSkill)) {
    return '$limitJa を まだ ためしていないよ。いちど やってみると、'
        'ごうかくりつが もっと せいかくに わかります！';
  }
  return '$limitJa を のばすと 合格（ごうかく）の目安（めやす）に ちかづきます。'
      'まいにち すこしずつ れんしゅうすれば、かならず とどきます！';
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

/// Gentle mastery-based progression advice card (#14). Encouraging, never
/// scolding — even "review" is framed as a positive next step.
class _MasteryAdviceCard extends StatelessWidget {
  final MasteryRecommendation rec;
  const _MasteryAdviceCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    // Name the concrete target grade when there is one, so the advice is
    // actionable ("英けん4きゅうに いける かも！") rather than vague.
    final g = rec.suggestedGrade;
    final gl = g != null ? _gradeLabelJa(g) : null;
    final title = switch (rec.advice) {
      ProgressionAdvice.advance =>
        gl != null ? '🎉 $gl に いける かも！' : '🎉 つぎの きゅうへ いける かも！',
      ProgressionAdvice.reviewBasics => '🌱 きそを かためよう',
      ProgressionAdvice.keepPracticing => '💪 この ちょうしで つづけよう',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dqGold.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGold.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: dqText(size: 13, w: FontWeight.w800, color: dqGold)),
          const SizedBox(height: 4),
          Text(rec.reasonJa, style: dqText(size: 12.5).copyWith(height: 1.5)),
          // One-tap action so the "advance" advice is not a dead-end: tap to
          // move up a grade right here (confirmed, reversible from Settings).
          if (rec.advice == ProgressionAdvice.advance && g != null) ...[
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: '${gl ?? ''} に すすむ',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('advice_advance_button'),
                onTap: () => _confirmAdvance(context, g, gl ?? ''),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: dqGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${gl ?? 'つぎの きゅう'} に すすむ',
                      style: dqText(
                          size: 13,
                          w: FontWeight.w800,
                          color: const Color(0xFF2A1C00))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Confirm + change the persisted 英検 grade, then pop back to the home (which
  /// reloads on return, so the new grade drives practice + 合格率). Reversible
  /// anytime from Settings.
  Future<void> _confirmAdvance(
      BuildContext context, String grade, String label) async {
    // A paid grade (aken freemium) must go through the paywall — never a free
    // one-tap advance. Mirrors GradeSelectorScreen / the Settings grade picker.
    if (!FlavorConfig.instance.isGradeFree(grade)) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GradeGateScreen(
          eikenGrade: grade,
          onSubscribe: () async {
            try {
              final prefs = await PreferencesService.getInstance();
              await prefs.setString('onboarding_start_level', grade);
            } catch (_) {/* leave unchanged */}
            if (context.mounted) Navigator.of(context).pop(); // close the gate
          },
        ),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('$label に すすむ？',
            style: dqText(size: 15, w: FontWeight.w700, color: dqInk)),
        content:
            Text('いつでも せっていで もどせるよ。', style: dqText(size: 13, color: dqInk)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text('まだ', style: dqText(size: 13, color: dqGoldDeep))),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text('すすむ', style: dqText(size: 13, color: dqGold))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.setString('onboarding_start_level', grade);
    } catch (_) {
      return; // persistence failed → leave the grade unchanged
    }
    if (context.mounted) Navigator.of(context).pop(); // → home reloads
  }
}

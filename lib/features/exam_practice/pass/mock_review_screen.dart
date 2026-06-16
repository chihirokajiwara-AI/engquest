// lib/features/exam_practice/pass/mock_review_screen.dart
// A-KEN Quest — post-mock 答え合わせ (review) screen.
//
// WHY THIS EXISTS (pedagogy gap, flaw-hunt 2026-06-11): the timed フル模試
// (mock_exam_screen) scored the session and dead-ended at the 合格メーター — the
// child saw their 合格率 but could NOT review WHICH questions they missed. After a
// 60-question mock, reviewing the wrong items is the single highest-learning
// moment; without it the mock measures but does not teach. This screen closes
// that loop: every MCQ item is shown with the child's answer vs the correct one,
// defaulting to a まちがいだけ (wrong-only) focus so review targets the gaps.
//
// HONESTY: it reads back the SAME items + answers the child actually saw/picked —
// no fabricated explanation. Items show an authored 解説 only when one exists
// (英検5級 reading so far); items without one show no rationale (never fabricated),
// so we show the correct choice plainly (見直し), never a made-up "why".
//
// NO dart:io. Pure-Dart widget. (R4)

import 'package:flutter/material.dart';

import '../../quest/ui/dq_ui.dart';
import '../listening_data.dart';
import 'cse_model.dart';
import 'mock_exam.dart';

class MockReviewScreen extends StatefulWidget {
  /// The MCQ items the mock presented, in exam order.
  final List<MockMcqItem> items;

  /// The child's answers: item id → chosen choice index. Missing id = unanswered.
  final Map<String, int> answers;

  /// Japanese grade label for the header (e.g. 「英検2級」).
  final String gradeLabel;

  const MockReviewScreen({
    super.key,
    required this.items,
    required this.answers,
    required this.gradeLabel,
  });

  @override
  State<MockReviewScreen> createState() => _MockReviewScreenState();
}

class _MockReviewScreenState extends State<MockReviewScreen> {
  /// Default to wrong-only: review should target the gaps, not re-read corrects.
  bool _wrongOnly = true;

  bool _isCorrect(MockMcqItem it) => widget.answers[it.id] == it.correctIdx;
  bool _isAnswered(MockMcqItem it) => widget.answers.containsKey(it.id);

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final correct = widget.items.where(_isCorrect).length;
    // "missed" = wrong OR left unanswered — both are review targets.
    final missed = widget.items.where((it) => !_isCorrect(it)).toList();

    final shown = _wrongOnly ? missed : widget.items;

    return DqScene(
      contentMaxWidth: 600, // tablet-centre, phone full-width (#144)
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
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
                      '${widget.gradeLabel} 答（こた）え合（あ）わせ',
                      'Review',
                      jpSize: 18,
                      stacked: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Summary + wrong-only toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '正解（せいかい） $correct / $total',
                      style:
                          dqText(size: 15, w: FontWeight.w800, color: dqGold),
                    ),
                  ),
                  if (missed.isNotEmpty)
                    _Toggle(
                      wrongOnly: _wrongOnly,
                      missedCount: missed.length,
                      onChanged: (v) => setState(() => _wrongOnly = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          missed.isEmpty
                              ? '全問正解（ぜんもんせいかい）！ 見直（みなお）す\nまちがいは ありません。すばらしい！'
                              : 'ここに 表示（ひょうじ）する\nもんだいが ありません。',
                          textAlign: TextAlign.center,
                          style: dqText(size: 15).copyWith(height: 1.6),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final it = shown[i];
                        // Original exam position (1-based) for orientation.
                        final pos = widget.items.indexOf(it) + 1;
                        return _ReviewCard(
                          item: it,
                          position: pos,
                          chosen: widget.answers[it.id],
                          answered: _isAnswered(it),
                          correct: _isCorrect(it),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool wrongOnly;
  final int missedCount;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.wrongOnly,
    required this.missedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!wrongOnly),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: wrongOnly ? dqGold.withAlpha(40) : dqBox,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: wrongOnly ? dqGold : dqInk.withAlpha(60),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              wrongOnly ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: wrongOnly ? dqGold : dqInk.withAlpha(150),
            ),
            const SizedBox(width: 6),
            Text(
              'まちがいだけ ($missedCount)',
              style: dqText(
                size: 12,
                w: FontWeight.w700,
                color: wrongOnly ? dqGold : dqInk.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final MockMcqItem item;
  final int position;
  final int? chosen;
  final bool answered;
  final bool correct;

  const _ReviewCard({
    required this.item,
    required this.position,
    required this.chosen,
    required this.answered,
    required this.correct,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF6FBF73);
    const red = Color(0xFFE08A8A);
    final accent = correct ? green : red;
    // For a missed listening item, reveal the authored transcript so the child
    // can READ what they misheard — the listening-learning loop in review.
    final transcript = item.skill == EikenSkill.listening
        ? transcriptForAudioKey(item.id)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dqBox,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number + skill + verdict
          Row(
            children: [
              Text(
                'Q$position',
                style: dqText(size: 13, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(width: 8),
              // Expanded (not a fixed Text + Spacer): at textScaler 2.0 the skill
              // label + Q + verdict overflowed the row by ~39px (WCAG SC 1.4.4).
              // Expanded absorbs the squeeze (ellipsis) and still pushes the
              // verdict to the right edge.
              Expanded(
                child: Text(
                  CseEstimator.skillLabelJa(item.skill),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dqText(size: 11, w: FontWeight.w600, color: dqInk)
                      .copyWith(color: dqInk.withAlpha(160)),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 4),
              Text(
                correct ? '正解' : (answered ? '不正解' : 'みかいとう'),
                style: dqText(size: 12, w: FontWeight.w700, color: accent),
              ),
            ],
          ),
          if (item.questionText.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            // #73: same as the live mock — render the cloze blank as an underline
            // gap, not literal "( )". clozeRich degrades to plain text for non-cloze
            // (reading/listening) stems, so the review reads exactly like the exam.
            clozeRich(
              item.questionText.trim(),
              dqText(size: 14).copyWith(height: 1.5),
            ),
          ],
          if (transcript != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dqNight1,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔊 スクリプト / Script',
                    style: dqText(
                        size: 10,
                        w: FontWeight.w700,
                        color: dqInk.withAlpha(150)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transcript,
                    style: dqText(size: 13).copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Choices, with the child's pick and the correct one marked.
          ...List.generate(item.choices.length, (i) {
            final isCorrect = i == item.correctIdx;
            final isChosen = answered && i == chosen;
            Color? bg;
            if (isCorrect) {
              bg = green.withAlpha(38);
            } else if (isChosen) {
              bg = red.withAlpha(38);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isCorrect
                        ? green.withAlpha(140)
                        : (isChosen ? red.withAlpha(140) : Colors.transparent),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.choices[i],
                        style: dqText(size: 13).copyWith(height: 1.4),
                      ),
                    ),
                    if (isCorrect) ...[
                      const SizedBox(width: 6),
                      Text('正解',
                          style: dqText(
                              size: 11, w: FontWeight.w800, color: green)),
                    ] else if (isChosen) ...[
                      const SizedBox(width: 6),
                      Text('あなた',
                          style:
                              dqText(size: 11, w: FontWeight.w800, color: red)),
                    ],
                  ],
                ),
              ),
            );
          }),
          // Authored 解説 (teach-why) — only when the item carries a real one
          // (no fabricated rationale). Currently populated for 英検5級 reading.
          if (item.explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dqGold.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dqGold.withAlpha(90)),
              ),
              child: Text(
                '💡 ${item.explanation!}',
                style: dqText(size: 12.5).copyWith(height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

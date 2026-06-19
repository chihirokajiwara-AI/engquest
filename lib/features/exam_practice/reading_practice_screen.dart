// lib/features/exam_practice/reading_practice_screen.dart
// A-KEN Quest — Eiken Part 3/4: Reading Comprehension (長文読解)
//
// Displays a short passage (email, notice, article) then asks
// multiple-choice comprehension questions about it.
// Supports two modes:
//   1. Standard comprehension — read passage, answer questions about content
//   2. Passage fill-in (空所補充) — passage has blanks, choose what fits

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/home/streak_service.dart';
import '../../core/gamification/xp_service.dart';
import 'exam_session_rewards.dart';
import 'package:engquest/core/sound/practice_feedback.dart';
import 'package:engquest/features/exam_practice/practice_result_stars.dart';
import 'eiken_exam_config.dart';
import 'practice_encouragement.dart';
import 'choice_shuffle.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';
import 'exam_review_store.dart';

/// Returns [q] with its choices shuffled and [correctIdx] remapped. The authored
/// reading keys cluster at idx 1–2 (93%); shuffling at load removes that
/// positional tell (the answer feeds 合格率). See [shuffledChoiceSet].
_ComprehensionQuestion _shuffleReadingChoices(
    _ComprehensionQuestion q, Random rng) {
  final s = shuffledChoiceSet(q.choices, q.correctIdx, rng);
  return _ComprehensionQuestion(
    question: q.question,
    choices: s.choices,
    correctIdx: s.correctIdx,
    explanation: q.explanation,
  );
}

_ReadingPassage _shufflePassageChoices(_ReadingPassage p, Random rng) =>
    _ReadingPassage(
      title: p.title,
      type: p.type,
      content: p.content,
      questions: [for (final q in p.questions) _shuffleReadingChoices(q, rng)],
    );

class _ReadingPassage {
  final String title;
  final String type; // "email", "notice", "article", "letter", "ad"
  final String content;
  final List<_ComprehensionQuestion> questions;

  const _ReadingPassage({
    required this.title,
    required this.type,
    required this.content,
    required this.questions,
  });
}

class _ComprehensionQuestion {
  final String question;
  final List<String> choices;
  final int correctIdx;

  /// Post-answer teaching line (the 英検 reading skill is locating the evidence):
  /// quotes the passage sentence that proves the answer, in child-facing 日本語.
  /// Optional — grades not yet authored simply omit it (purely additive).
  final String? explanation;

  const _ComprehensionQuestion({
    required this.question,
    required this.choices,
    required this.correctIdx,
    this.explanation,
  });
}

/// Session-end "review these" list for 大問4 読解: one row per question the child
/// got wrong, with its 解説 (which quotes the passage evidence) so the mistake
/// closes into a concrete re-read prompt. Brings reading to parity with the
/// 会話/語彙/リスニング missed-review lists. Pure + testable: takes (question, why)
/// records, so a widget test can assert the rows + the 解説 without driving the
/// whole passage screen.
class ReadingReviewPanel extends StatelessWidget {
  final List<({String question, String? why})> missed;
  const ReadingReviewPanel({super.key, required this.missed});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('reading_review_panel'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dqBox,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGold.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'もう一度（いちど）よんでみよう / Review these',
            style: dqText(size: 13, w: FontWeight.w800, color: dqGold),
          ),
          const SizedBox(height: 10),
          for (final m in missed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '・${m.question}',
                    style: dqText(size: 12, w: FontWeight.w700, color: dqInk)
                        .copyWith(height: 1.4),
                  ),
                  if (m.why != null && m.why!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Text(
                        m.why!,
                        style: dqText(size: 11, color: dqInk.withAlpha(200))
                            .copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Post-answer teaching panel (#5): a 💡解説 box that points the learner at the
/// passage evidence. Mirrors the vocab screen's れい: explanation so the whole
/// exam-practice suite teaches "why", not just right/wrong.
class _ExplanationPanel extends StatelessWidget {
  final String text;
  const _ExplanationPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('reading_explanation'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(235),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGoldDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: dqGold, size: 18),
              const SizedBox(width: 6),
              Text('かいせつ / Why',
                  style: dqText(
                      size: 12, w: FontWeight.w800, color: dqGold, spacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: dqText(size: 14, w: FontWeight.w500, color: dqInk)
                  .copyWith(height: 1.6)),
        ],
      ),
    );
  }
}

class ReadingPracticeScreen extends StatefulWidget {
  const ReadingPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
  });

  final String eikenGrade;
  final ExamSection section;

  /// Minimum time a question must be on screen before an answer counts toward the
  /// by-comprehension reading 合格率 (#R5 anti-gaming). An answer faster than a
  /// human can read+comprehend is excluded (not blocked). Overridable in tests.
  @visibleForTesting
  static Duration minReadTime = const Duration(seconds: 2);

  @override
  State<ReadingPracticeScreen> createState() => _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends State<ReadingPracticeScreen> {
  late List<_ReadingPassage> _passages;
  // #118: FSRS error-corrective re-testing — a passage holding a question the
  // child got WRONG is surfaced FIRST next session (re-read → re-answer), not
  // just counted. Keyed by the question text (stable per item).
  final _reviewStore = ExamReviewStore(section: 'reading');
  int _passageIdx = 0;
  int _questionIdx = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  StreakState? _earnedStreak; // shown on results via SessionEndHook

  // Questions the child got WRONG this session — surfaced on the results screen
  // as a "review these" list (question + its 解説, which quotes the passage
  // evidence). Brings 大問4 読解 to parity with the 会話/語彙/リスニング missed-review
  // lists (reading is the highest-points section, so closing the mistake loop
  // here matters most). Text-only: no audio, so just (question, why) records.
  final List<({String question, String? why})> _missedReading = [];

  // Struggling-child support (CEO 1135 / no-scold spine): a cold streak triggers
  // a gentle 探偵 encouragement (shared PracticeEncouragementBanner). Resets to 0
  // on any correct answer.
  int _consecutiveWrong = 0;

  /// Consecutive CORRECT answers — the positive mirror; drives the momentum
  /// banner (shares the cold-streak slot, the two are mutually exclusive).
  int _consecutiveCorrect = 0;
  int _totalQuestions = 0;
  bool _sessionDone = false;

  // #R5 anti-gaming: only questions the child plausibly had time to READ feed the
  // by-comprehension reading 合格率. Tracked separately from the visible
  // _correctCount/_totalQuestions (which still count every answer for progress).
  DateTime? _questionShownAt;
  int _measuredCorrect = 0;
  int _measuredTotal = 0;

  // #16 hint scaffold: a once-per-question "2つに しぼる" (narrow to 2) lifeline for
  // a struggling reader — eliminates two WRONG choices (50/50). Using it EXCLUDES
  // the question from the by-comprehension 合格率 (same honesty principle as a
  // too-fast or un-read answer): a hinted answer is not a clean comprehension
  // result, so it never inflates readiness.
  bool _hintUsed = false;
  Set<int> _eliminated = {};

  // Drives the question pane so the 解説 (which appears below the choices on
  // answer) is scrolled into view — otherwise the teaching sits below the fold.
  final ScrollController _qScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _passages = _getPassages(widget.eikenGrade, widget.section.id)
        .map((p) => _shufflePassageChoices(p, rng))
        .toList();
    _totalQuestions = _passages.fold(0, (sum, p) => sum + p.questions.length);
    _questionShownAt =
        DateTime.now(); // start the read-time clock for question 1
    _applyDueOrder();
  }

  /// #118: bring passages holding a previously-MISSED question (FSRS-due) to the
  /// front this session, so the failed comprehension item actually comes back
  /// (re-read the passage → re-answer). Async (SharedPreferences); only reorders
  /// before the child has started. No due cards (first visit) → keep the order.
  Future<void> _applyDueOrder() async {
    try {
      final due = await _reviewStore.dueReviewKeys(widget.eikenGrade);
      if (due.isEmpty ||
          !mounted ||
          _passageIdx != 0 ||
          _questionIdx != 0 ||
          _answered) {
        return;
      }
      bool hasDue(_ReadingPassage p) => p.questions
          .any((q) => due.contains(ExamReviewStore.keyFor(q.question)));
      setState(() {
        _passages.sort((a, b) => (hasDue(a) ? 0 : 1) - (hasDue(b) ? 0 : 1));
        _questionShownAt = DateTime.now(); // restart the read clock for new Q1
      });
    } catch (_) {
      // Non-fatal — keep the generated order.
    }
  }

  @override
  void dispose() {
    _qScroll.dispose();
    super.dispose();
  }

  _ComprehensionQuestion get _currentQuestion =>
      _passages[_passageIdx].questions[_questionIdx];

  /// Eliminate two WRONG choices (keep the correct one + one distractor) — a
  /// once-per-question 50/50 lifeline. Marks the question hint-used so it is
  /// excluded from the by-comprehension 合格率.
  void _useHint() {
    if (_answered || _hintUsed) return;
    final q = _currentQuestion;
    final wrong = [
      for (var i = 0; i < q.choices.length; i++)
        if (i != q.correctIdx) i
    ]..shuffle();
    setState(() {
      _hintUsed = true;
      _eliminated = {...wrong.take(2)};
    });
  }

  void _selectAnswer(int idx) {
    if (_answered || _eliminated.contains(idx)) return;
    // Only count this question toward the by-comprehension reading 合格率 if the
    // child plausibly had time to READ it (#R5). An answer faster than a human can
    // read+comprehend is not a real reading result — excluded, NOT blocked (the
    // child still answers + sees the 解説). Same honesty principle as un-played
    // listening (#112/#R5): un-read ≠ a measured comprehension result.
    final shown = _questionShownAt;
    final measured = shown != null &&
        DateTime.now().difference(shown) >= ReadingPracticeScreen.minReadTime;
    final correct = idx == _currentQuestion.correctIdx;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      if (correct) {
        _correctCount++;
      } else {
        // Track the missed question for the session-end review list.
        _missedReading.add((
          question: _currentQuestion.question,
          why: _currentQuestion.explanation,
        ));
      }
      _consecutiveWrong = correct ? 0 : _consecutiveWrong + 1;
      _consecutiveCorrect = correct ? _consecutiveCorrect + 1 : 0;
      // A hinted answer is excluded from the by-comprehension 合格率 (honesty).
      if (measured && !_hintUsed) {
        _measuredTotal++;
        if (correct) _measuredCorrect++;
      }
    });
    // Game-feel (#51): a haptic tick + chime so answering feels responsive.
    PracticeFeedback.answered(correct: correct);
    // #118: reschedule this question via FSRS — wrong → comes back soon; a correct
    // answer that wasn't a clean comprehension result (hinted, or too fast to have
    // read it) is "hard"; a clean unaided correct is "good". Fire-and-forget.
    _reviewStore.recordAnswer(
      grade: widget.eikenGrade,
      word: _currentQuestion.question,
      correct: correct,
      hinted: _hintUsed || !measured,
    );
    // a11y (WCAG 4.1.3): speak the verdict for assistive-tech users.
    SemanticsService.sendAnnouncement(
      View.of(context),
      correct ? 'せいかい' : 'ふせいかい',
      Directionality.of(context),
    );
    // After the 解説 lays out, bring it into view (it renders below the choices).
    if (_currentQuestion.explanation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_qScroll.hasClients) {
          _qScroll.animateTo(
            _qScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Records the completed session result into [SkillAccuracyStore].
  /// readingComprehension + passage fill-in → EikenSkill.reading.
  Future<void> _recordSessionResult() async {
    if (_totalQuestions <= 0) return;
    // Feed the home engagement spine (streak + daily-goal) for any attempt.
    recordExamXp(_totalQuestions);
    recordExamAchievements();
    recordExamHabitAndGet(_totalQuestions).then((st) {
      if (mounted && st != null) setState(() => _earnedStreak = st);
    });
    // Only plausibly-read answers feed the by-comprehension 合格率 (#R5). If every
    // answer was too fast to be real reading, record nothing — reading stays
    // honestly 未測定 rather than logging un-read guesses.
    if (_measuredTotal <= 0) return;
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.reading,
        correct: _measuredCorrect,
        total: _measuredTotal,
      );
    } catch (_) {
      // Store errors are non-fatal — never interrupt the learner.
    }
  }

  void _next() {
    // New question scrolls back to the top (question + choices first).
    if (_qScroll.hasClients) _qScroll.jumpTo(0);
    final passage = _passages[_passageIdx];
    if (_questionIdx < passage.questions.length - 1) {
      setState(() {
        _questionIdx++;
        _selectedAnswer = null;
        _answered = false;
        _hintUsed = false;
        _eliminated = {};
        _questionShownAt = DateTime.now(); // restart read-time clock (#R5)
      });
    } else if (_passageIdx < _passages.length - 1) {
      setState(() {
        _passageIdx++;
        _questionIdx = 0;
        _selectedAnswer = null;
        _answered = false;
        _hintUsed = false;
        _eliminated = {};
        _questionShownAt = DateTime.now(); // restart read-time clock (#R5)
      });
    } else {
      _recordSessionResult(); // fire-and-forget; UI does not wait
      setState(() => _sessionDone = true);
      PracticeFeedback.sessionComplete();
    }
  }

  bool get _isPassageFillIn {
    final id = widget.section.id;
    // All 長文の語句空所補充 (passage cloze) sections — drives the '長文語句空所補充'
    // title. 'p2p_r2' was missing here (a pre-existing title-label bug: 準2プラス
    // fill-in showed '長文読解'); 'pre2_r3' is the new 準2 大問3 (Task#32).
    return id == 'pre2_r3' || id == 'p2p_r2' || id == '2_r2' || id == 'p1_r2';
  }

  @override
  Widget build(BuildContext context) {
    // Honest empty-state: grades with no dedicated passages (e.g. 準2級プラス)
    // — never index into an empty _passages list.
    final title =
        _isPassageFillIn ? '長文語句空所補充（ちょうぶんごくくうしょほじゅう）' : '長文読解（ちょうぶんどっかい）';
    if (_passages.isEmpty) {
      return DqScene(
        child: Column(
          children: [
            _header(title),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'この級（きゅう）の長文（ちょうぶん）問題（もんだい）は\n準備中（じゅんびちゅう）です。',
                    textAlign: TextAlign.center,
                    style: dqText(size: 16, w: FontWeight.w600, color: dqInk),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return DqScene(
      contentMaxWidth:
          600, // #144: centre the column on tablet, full-width on phone
      child: Column(
        children: [
          _header(title),
          Expanded(
            child: _sessionDone ? _buildResults() : _buildReading(),
          ),
        ],
      ),
    );
  }

  /// Dark command-bar header: a gold ✕ close + centred gold title, matching the
  /// vocab / conversation practice screens (one coherent 本格 exam surface).
  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'とじる / Close',
            icon: const Icon(Icons.close, color: dqInk),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: dqText(size: 16, w: FontWeight.w800, color: dqGold),
            ),
          ),
          const SizedBox(
              width: 36), // balance the close button so title centres
        ],
      ),
    );
  }

  Widget _buildReading() {
    final passage = _passages[_passageIdx];
    final question = _currentQuestion;

    // Calculate overall progress
    int answeredSoFar = 0;
    for (int i = 0; i < _passageIdx; i++) {
      answeredSoFar += _passages[i].questions.length;
    }
    answeredSoFar += _questionIdx;

    // Phone-layout fix: the old flex(3)/flex(2) split gave the choices region
    // only ~40% of available height (~338px on a 844px phone after header), which
    // caused choice 4 to clip off-screen with no scroll affordance. The fix:
    // - Progress row stays pinned at the top (no change).
    // - Passage + question + choices live in ONE unified SingleChildScrollView
    //   so the child scrolls through a single continuous column — no clipping.
    // - "次へ" button is pinned OUTSIDE the scroll so it is always reachable
    //   without having to scroll to the very bottom first.
    return Column(
      children: [
        // ── Pinned progress bar ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: dqBox,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dqGoldDeep, width: 1),
                ),
                child: Text(
                  passage.type.toUpperCase(),
                  style: dqText(
                      size: 11,
                      w: FontWeight.w800,
                      color: dqGold,
                      spacing: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalQuestions > 0
                        ? (answeredSoFar + (_answered ? 1 : 0)) /
                            _totalQuestions
                        : 0,
                    backgroundColor: dqNight1,
                    valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${answeredSoFar + 1}/$_totalQuestions',
                style: dqText(size: 13, w: FontWeight.w600, color: dqInk),
              ),
              // Only show the running ✓ correct-count once the child has engaged
              // (answered the current question or a prior one). A prominent "✓0"
              // on the fresh first question — before any answer — reads as a
              // discouraging zero-score to a 6yo and carries no information
              // (real-render re-audit, CEO 1363; #163).
              if (answeredSoFar > 0 || _answered) ...[
                const SizedBox(width: 8),
                Text(
                  '✓$_correctCount',
                  style: dqText(
                      size: 13,
                      w: FontWeight.w800,
                      color: const Color(0xFF8BE08B)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Unified scroll body: passage → question → choices → extras ────────
        // Single scroll eliminates the fixed-height split that clipped choice 4.
        Expanded(
          child: SingleChildScrollView(
            controller: _qScroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Passage card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dqBox.withAlpha(235),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dqBorder, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (passage.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            passage.title,
                            style: dqText(
                                size: 16, w: FontWeight.w800, color: dqGold),
                          ),
                        ),
                      Text(
                        passage.content,
                        style:
                            dqText(size: 15, w: FontWeight.w500, color: dqInk)
                                .copyWith(height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Question frame
                // The question was a bare white Text carrying LESS visual
                // weight than the bordered answer cards below — visual-audit
                // #159 iter2 (#178): after reading the passage a 6yo couldn't
                // tell what was being ASKED. Give the question its own framed
                // focal bar (DetectiveCaseFrame, highlighted) so it reads as
                // the prompt, visually separated from passage and answers.
                DetectiveCaseFrame(
                  highlighted: true,
                  title: 'しつもん / Question',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    question.question,
                    style: dqText(size: 16, w: FontWeight.w700, color: dqInk),
                  ),
                ),
                const SizedBox(height: 12),
                // Answer choices — all 4 always rendered, never clipped
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: question.choices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final isSelected = _selectedAnswer == i;
                    final isCorrect = i == question.correctIdx;

                    Color bgColor = dqBox;
                    Color borderColor = dqGoldDeep.withAlpha(120);
                    Color textColor = dqInk;

                    // #16 hint: a choice eliminated by the 50/50 lifeline
                    // is dimmed + un-tappable (only before answering).
                    final eliminated = !_answered && _eliminated.contains(i);

                    if (_answered) {
                      if (isCorrect) {
                        bgColor = const Color(0xFF14301B);
                        borderColor = const Color(0xFF8BE08B);
                        textColor = const Color(0xFF8BE08B);
                      } else if (isSelected) {
                        bgColor = const Color(0xFF3A1A1A);
                        borderColor = const Color(0xFFE0853A);
                        textColor = const Color(0xFFE89A82);
                      }
                    } else if (eliminated) {
                      bgColor = dqBox.withAlpha(90);
                      borderColor = dqGoldDeep.withAlpha(50);
                      textColor = dqInk.withAlpha(90);
                    } else if (isSelected) {
                      borderColor = dqGold;
                      bgColor = dqNight1;
                    }

                    final semLabel = _answered && isCorrect
                        ? '${i + 1}. ${question.choices[i]}、せいかい'
                        : _answered && isSelected
                            ? '${i + 1}. ${question.choices[i]}、ふせいかい'
                            : eliminated
                                ? '${i + 1}. ${question.choices[i]}、じょがい'
                                : '${i + 1}. ${question.choices[i]}';
                    return Semantics(
                      button: true,
                      label: semLabel,
                      onTap: (_answered || eliminated)
                          ? null
                          : () => _selectAnswer(i),
                      excludeSemantics: true,
                      child: Material(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: ValueKey('reading_choice_$i'),
                          onTap: eliminated ? null : () => _selectAnswer(i),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            child: Row(
                              children: [
                                // Unified circular number disc — match the
                                // vocab/listening/conversation option widget
                                // (CEO 2186 craft audit: reading used an
                                // inline "1." while the same task used a disc
                                // elsewhere). One option component, all types.
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: borderColor.withAlpha(30),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    question.choices[i],
                                    style: dqText(
                                        size: 15,
                                        w: FontWeight.w600,
                                        color: textColor),
                                  ),
                                ),
                                if (_answered && isCorrect)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF8BE08B), size: 20),
                                if (_answered && isSelected && !isCorrect)
                                  const Icon(Icons.cancel_rounded,
                                      color: Color(0xFFE0853A), size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // #16 hint scaffold: a once-per-question 50/50 lifeline.
                // Hidden after answering; replaced by an honesty notice
                // once used (the question is then out of the 合格率).
                if (!_answered && !_hintUsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Semantics(
                      button: true,
                      label: '2つに しぼる。ヒントを つかうと、この問題は '
                          '合格率に 入りません',
                      excludeSemantics: true,
                      child: InkWell(
                        key: const ValueKey('reading_hint_button'),
                        onTap: _useHint,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: dqGoldDeep.withAlpha(120), width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lightbulb_outline,
                                  color: dqGold, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '2つに しぼる（合格率には 入りません）',
                                  style: dqText(size: 12, color: dqGoldDeep),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_hintUsed && !_answered)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '💡 2つに しぼったよ。この問題は 合格率に 入りません。',
                      style: dqText(size: 12, color: dqGoldDeep),
                    ),
                  ),
                // Struggling-child support: a cold streak shows a gentle,
                // non-scolding 探偵 encouragement above the 解説. (CEO 1135)
                if (_answered &&
                    _selectedAnswer != question.correctIdx &&
                    _consecutiveWrong >= kStruggleThreshold)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: PracticeEncouragementBanner(
                        message: kReadingEncourageMsg),
                  )
                // Positive mirror: celebrate a correct streak (same slot).
                else if (_answered &&
                    _selectedAnswer == question.correctIdx &&
                    _consecutiveCorrect >= kMomentumThreshold)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: PracticeMomentumBanner(streak: _consecutiveCorrect),
                  ),
                if (_answered && question.explanation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ExplanationPanel(text: question.explanation!),
                  ),
              ],
            ),
          ),
        ),
        // ── Pinned "次へ" button — always reachable without scrolling ─────────
        if (_answered)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DqButton(label: '次へ', onTap: _next),
          ),
      ],
    );
  }

  Widget _buildResults() {
    final pct = _totalQuestions == 0
        ? 0
        : (_correctCount / _totalQuestions * 100).round();
    final passed = pct >= 60;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.workspace_premium_rounded : Icons.refresh_rounded,
              size: 72,
              color: passed ? dqGold : dqInk.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              passed ? '合格（ごうかく）ライン到達（とうたつ）！' : 'もう少（すこ）し！',
              style: dqText(size: 24, w: FontWeight.w900, color: dqGold),
            ),
            const SizedBox(height: 12),
            Text(
              '$_correctCount / $_totalQuestions 正解 ($pct%)',
              style: dqText(size: 18, w: FontWeight.w600, color: dqInk),
            ),
            const SizedBox(height: 16),
            PracticeResultStars(correct: _correctCount, total: _totalQuestions),
            // Honesty (#157): the 合格率 counts only UNAIDED answers — disclose the
            // hinted ones so the session score and the home meter don't silently
            // contradict (mirrors word_ordering's existing note).
            if (_totalQuestions - _measuredTotal > 0) ...[
              const SizedBox(height: 10),
              Text(
                'ヒントを つかった ${_totalQuestions - _measuredTotal}問（もん）は、\n'
                '合格率（ごうかくりつ）に 入（い）れていません。',
                textAlign: TextAlign.center,
                style: dqText(color: dqInk.withAlpha(160), size: 12),
              ),
            ],
            if (_missedReading.isNotEmpty) ...[
              const SizedBox(height: 20),
              ReadingReviewPanel(missed: _missedReading),
            ],
            if (_earnedStreak != null) ...[
              const SizedBox(height: 20),
              SessionEndHook(streak: _earnedStreak!),
            ],
            const SizedBox(height: 32),
            DqButton(
              label: '戻る',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Passage banks ─────────────────────────────────────────────────────────

  static List<_ReadingPassage> _getPassages(String grade, String sectionId) {
    // Passage fill-in sections (準2級 / 準2級プラス / Grade 2 / Pre-1)
    if (sectionId == 'pre2_r3') return _pre2FillIn;
    if (sectionId == 'p2p_r2') return _pre2PlusFillIn;
    if (sectionId == '2_r2') return _grade2FillIn;
    if (sectionId == 'p1_r2') return _pre1FillIn;

    // Standard reading comprehension
    switch (grade) {
      case '5':
        return _grade5Passages;
      case '4':
        return _grade4Passages;
      case '3':
        return _grade3Passages;
      case 'pre2':
        return _pre2Passages;
      case 'pre2plus':
        return _pre2PlusPassages;
      case '2':
        return _grade2Passages;
      case 'pre1':
        return _pre1Passages;
      default:
        // No dedicated passages for this grade → empty, so the screen shows a
        // 準備中 state rather than silently serving another grade's passages.
        return const [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GRADE 5 (A1) — Simple notices, short emails (4 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _grade5Passages = [
    _ReadingPassage(
      title: 'School Notice',
      type: 'notice',
      content: 'Dear Students,\n\n'
          'We will have a school festival on Saturday, November 15. '
          'The festival starts at 10:00 a.m. and finishes at 3:00 p.m. '
          'Each class will have a food shop or a game shop. '
          'Class 5-A will sell rice balls. Class 5-B will have a fishing game. '
          'Please come and enjoy the festival with your family!\n\n'
          'From: Mr. Tanaka',
      questions: [
        _ComprehensionQuestion(
          question: 'When is the school festival?',
          choices: [
            'On Friday, November 14',
            'On Saturday, November 15',
            'On Sunday, November 16',
            'On Monday, November 17',
          ],
          correctIdx: 1,
          explanation: '本文に "a school festival on Saturday, November 15" '
              'とあるね。だから「11月15日（土）」が正解だよ。',
        ),
        _ComprehensionQuestion(
          question: 'What will Class 5-A do?',
          choices: [
            'Have a fishing game',
            'Sell rice balls',
            'Sell drinks',
            'Have a card game',
          ],
          correctIdx: 1,
          explanation: '"Class 5-A will sell rice balls." とあるよ。'
              '5-Aは「おにぎりを売る（sell rice balls）」が正解。',
        ),
      ],
    ),
    _ReadingPassage(
      title: '',
      type: 'email',
      content: 'Hi Tom,\n\n'
          'Thank you for your email. I am happy to hear about your new dog. '
          'What is his name? I also have a pet. I have a cat. Her name is Mimi. '
          'She is three years old. She likes to sleep on my bed. '
          'Do you want to see a picture of her?\n\n'
          'Your friend,\nYuki',
      questions: [
        _ComprehensionQuestion(
          question: 'What pet does Yuki have?',
          choices: [
            'A dog',
            'A bird',
            'A cat',
            'A rabbit',
          ],
          correctIdx: 2,
          explanation: '"I have a cat. Her name is Mimi." とあるね。'
              'ユキのペットは「ねこ（a cat）」だよ。',
        ),
        _ComprehensionQuestion(
          question: 'Where does Mimi like to sleep?',
          choices: [
            'On the sofa',
            'On the floor',
            "On Yuki's bed",
            'In the kitchen',
          ],
          correctIdx: 2,
          explanation: '"She likes to sleep on my bed." の my はユキのこと。'
              'だから「ユキのベッドの上（on Yuki\'s bed）」が正解。',
        ),
      ],
    ),
    // Depth expansion 2026-06-14: more practice variety (reading).
    _ReadingPassage(
      title: 'My Favorite Animal',
      type: 'email',
      content: 'Hello. My name is Emma. I like animals very much. My favorite '
          'animal is the rabbit. I have a white rabbit at home. Its name is '
          'Snow. Snow likes to eat carrots and lettuce. Every morning, I give '
          'Snow some water and clean its box. I love playing with Snow after '
          'school.',
      questions: [
        _ComprehensionQuestion(
          question: 'What animal does Emma like best?',
          choices: [
            'A cat.',
            'A dog.',
            'A rabbit.',
            'A bird.',
          ],
          correctIdx: 2,
          explanation: '"My favorite animal is the rabbit." とあるね。'
              'エマの すきな どうぶつは「ウサギ（rabbit）」だよ。',
        ),
        _ComprehensionQuestion(
          question: 'What does Snow like to eat?',
          choices: [
            'Rice and fish.',
            'Carrots and lettuce.',
            'Bread and milk.',
            'Meat.',
          ],
          correctIdx: 1,
          explanation: '"Snow likes to eat carrots and lettuce." とあるよ。'
              'ニンジンと レタスを たべるんだ。',
        ),
      ],
    ),
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GRADE 4 (A1-A2) — Articles, newsletters, short stories (5 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _grade4Passages = [
    _ReadingPassage(
      title: 'Summer Camp',
      type: 'article',
      content:
          'Last summer, I went to a camp in the mountains with my classmates. '
          'We stayed there for three days. On the first day, we hiked to a lake '
          'and went swimming. The water was very cold, but it was fun. '
          'On the second day, we cooked curry and rice for dinner. '
          'I cut the vegetables and my friend Tom cooked the rice. '
          'It was the best curry I ever had. On the last day, we cleaned our rooms '
          'and said goodbye to each other. I want to go back next year.',
      questions: [
        _ComprehensionQuestion(
          question: 'How long did they stay at the camp?',
          choices: [
            'Two days',
            'Three days',
            'Four days',
            'One week',
          ],
          correctIdx: 1,
          explanation: '"We stayed there for three days." とあるよ。'
              '答えは「3日間（three days）」。',
        ),
        _ComprehensionQuestion(
          question: 'What did they do on the first day?',
          choices: [
            'Cooked curry',
            'Cleaned their rooms',
            'Went swimming in a lake',
            'Said goodbye',
          ],
          correctIdx: 2,
          explanation:
              '"On the first day, we hiked to a lake and went swimming." '
              'とあるね。最初の日は「湖で泳いだ（went swimming in a lake）」。',
        ),
        _ComprehensionQuestion(
          question: 'Who cooked the rice?',
          choices: [
            'The writer',
            'Tom',
            'The teacher',
            'Everyone together',
          ],
          correctIdx: 1,
          explanation: '"my friend Tom cooked the rice." とあるよ。'
              'ごはんを炊いたのは「トム（Tom）」。',
        ),
      ],
    ),
    _ReadingPassage(
      title: 'City Library Newsletter',
      type: 'notice',
      content: 'Midtown Public Library\nSpring Events 2026\n\n'
          '• Reading Club (every Saturday, 2:00-3:30 p.m.)\n'
          '  Join us to read and discuss books! This month: "The Secret Garden"\n\n'
          '• Children\'s Art Workshop (March 20, 10:00 a.m.)\n'
          '  Make your own picture book! Materials provided. Ages 6-12.\n'
          '  *Please sign up at the front desk by March 15.\n\n'
          '• Movie Night (March 28, 6:00 p.m.)\n'
          '  Free movie showing for all ages. Popcorn and drinks available.\n\n'
          'The library is closed on Mondays and national holidays.',
      questions: [
        _ComprehensionQuestion(
          question: 'How often is the Reading Club?',
          choices: [
            'Every day',
            'Every Saturday',
            'Once a month',
            'Twice a week',
          ],
          correctIdx: 1,
          explanation: '"Reading Club (every Saturday, 2:00-3:30 p.m.)" '
              'とあるね。読書クラブは「毎週土曜日（every Saturday）」。',
        ),
        _ComprehensionQuestion(
          question: 'What must you do to join the Art Workshop?',
          choices: [
            'Buy materials',
            'Be over 12 years old',
            'Sign up by March 15',
            'Come with a parent',
          ],
          correctIdx: 2,
          explanation: '"Please sign up at the front desk by March 15." '
              'とあるよ。だから「3月15日までに申し込む（sign up by March 15）」が正解。'
              '（材料は用意されているよ：Materials provided.）',
        ),
      ],
    ),
    // Depth expansion 2026-06-14: more practice variety (reading).
    _ReadingPassage(
      title: 'NOTICE: New City Library',
      type: 'notice',
      content: 'The new city library will open next Monday. It is near the '
          'train station. The library has more than 50,000 books in English and '
          'Japanese. You can also use the computers there for free. The library '
          'is open from 9 a.m. to 8 p.m. every day except Wednesday. To borrow '
          'books, please bring your student card or ID card.',
      questions: [
        _ComprehensionQuestion(
          question: 'Where is the new library?',
          choices: [
            'Near the school.',
            'Near the train station.',
            'Near the park.',
            'In the city hall.',
          ],
          correctIdx: 1,
          explanation: '"It is near the train station." とあるね。'
              '駅（えき）の ちかくだよ。',
        ),
        _ComprehensionQuestion(
          question: 'When is the library closed?',
          choices: [
            'On Monday.',
            'On Sunday.',
            'On Wednesday.',
            'It is never closed.',
          ],
          correctIdx: 2,
          explanation: '"open ... every day except Wednesday" とあるよ。'
              '水曜日（すいようび）は おやすみ。',
        ),
        _ComprehensionQuestion(
          question: 'What do you need to borrow books?',
          choices: [
            'Money.',
            'A student card or ID card.',
            'A library bag.',
            'A computer.',
          ],
          correctIdx: 1,
          explanation: '"please bring your student card or ID card" とあるね。',
        ),
      ],
    ),
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GRADE 3 (A2) — Notices, letters, explanatory texts (10 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _grade3Passages = [
    _ReadingPassage(
      title: 'Community Center Notice',
      type: 'notice',
      content: 'Greenville Community Center\nSummer Programs 2026\n\n'
          'We are happy to announce our summer programs for young people!\n\n'
          '1. Swimming Lessons (July 1-31)\n'
          '   - Beginners: Mon & Wed, 9:00-10:00 a.m.\n'
          '   - Intermediate: Tue & Thu, 9:00-10:00 a.m.\n'
          '   - Fee: \$50 per person (includes pool use)\n\n'
          '2. English Drama Camp (August 5-9)\n'
          '   - Ages 10-15\n'
          '   - 10:00 a.m. - 3:00 p.m. daily\n'
          '   - Fee: \$80 (lunch included)\n'
          '   - Final performance on August 9 at 6:00 p.m.\n\n'
          'Registration opens June 1. Please call (555) 234-5678 or visit '
          'our website: www.greenvillecc.org\n'
          '*Early bird discount: 10% off if you register before June 15.',
      questions: [
        _ComprehensionQuestion(
          question: 'When do swimming lessons for beginners take place?',
          choices: [
            'Monday and Wednesday mornings',
            'Tuesday and Thursday mornings',
            'Every day in July',
            'Weekends only',
          ],
          correctIdx: 0,
          explanation:
              '本文に "Beginners: Mon & Wed, 9:00-10:00 a.m." とあるね。初級（しょきゅう）のスイミングは「月・水の朝（Monday and Wednesday mornings）」だよ。',
        ),
        _ComprehensionQuestion(
          question: 'What is included in the English Drama Camp fee?',
          choices: [
            'A swimming pool pass',
            'Lunch',
            'A costume',
            'Transportation',
          ],
          correctIdx: 1,
          explanation:
              'ドラマキャンプの料金（りょうきん）は "(lunch included)" とあるよ。「ひるごはん（lunch）」がふくまれているね。',
        ),
        _ComprehensionQuestion(
          question: 'How can you get 10% off?',
          choices: [
            'By joining both programs',
            'By being under 10 years old',
            'By registering before June 15',
            'By paying in cash',
          ],
          correctIdx: 2,
          explanation:
              '"Early bird discount: 10% off if you register before June 15." とあるね。6月15日より前に申し込むと「10％オフ」になるよ。',
        ),
      ],
    ),
    _ReadingPassage(
      title: '',
      type: 'email',
      content: 'Dear Mr. and Mrs. Tanaka,\n\n'
          'Thank you for letting your son Kenji stay with our family during his '
          'school trip to Australia. He was a wonderful guest! He helped my mother '
          'cook dinner on Tuesday and played soccer with my younger brother every '
          'afternoon.\n\n'
          'On Wednesday, we took Kenji to the beach. He said it was his first time '
          'seeing the ocean in Australia. He was surprised that the water was so warm '
          'in February. We also saw some dolphins near the shore.\n\n'
          'Kenji gave us a beautiful Japanese fan as a gift. We put it on our wall '
          'in the living room. Please tell Kenji he is welcome to visit again '
          'anytime!\n\n'
          'Best wishes,\nThe Smith Family',
      questions: [
        _ComprehensionQuestion(
          question: 'What did Kenji do on Tuesday?',
          choices: [
            'Went to the beach',
            'Played soccer all day',
            'Helped cook dinner',
            'Gave a gift to the family',
          ],
          correctIdx: 2,
          explanation:
              '"He helped my mother cook dinner on Tuesday" とあるよ。火曜日にケンジがしたのは「夕食（ゆうしょく）づくりの手伝い」。',
        ),
        _ComprehensionQuestion(
          question: 'Why was Kenji surprised at the beach?',
          choices: [
            'The beach was very crowded',
            'The ocean water was warm in February',
            'He saw sharks',
            'The sand was red',
          ],
          correctIdx: 1,
          explanation:
              '"He was surprised that the water was so warm in February." とあるね。2月なのに海の水があたたかくて、ケンジはおどろいたんだ。',
        ),
        _ComprehensionQuestion(
          question: 'Where did the Smith family put the Japanese fan?',
          choices: [
            'In Kenji\'s room',
            'In the kitchen',
            'On the living room wall',
            'In the garden',
          ],
          correctIdx: 2,
          explanation:
              '"We put it on our wall in the living room." とあるよ。日本のせんすは「リビングのかべ（on the living room wall）」にかざったよ。',
        ),
      ],
    ),
    _ReadingPassage(
      title: 'School Uniforms Around the World',
      type: 'article',
      content:
          'Many countries have school uniforms, but they look very different. '
          'In Japan, most junior high and high school students wear uniforms. '
          'Boys often wear black or dark blue suits, and girls wear sailor-style '
          'uniforms or blazers with skirts.\n\n'
          'In England, many schools have uniforms too. Students usually wear a '
          'white shirt, a tie, and dark trousers or a skirt. Some schools also '
          'have a special hat or blazer with the school logo.\n\n'
          'In Australia, because the weather is often hot, uniforms are usually '
          'simple. Students wear polo shirts and shorts or light dresses. Many '
          'schools require students to wear a hat outside to protect them from '
          'the sun.\n\n'
          'Some people think uniforms are good because all students look the same '
          'and families save money on clothes. Other people think students should '
          'choose their own clothes to show their personality.',
      questions: [
        _ComprehensionQuestion(
          question: 'What do boys in Japan often wear to school?',
          choices: [
            'Polo shirts and shorts',
            'Black or dark blue suits',
            'A white shirt and tie',
            'Jeans and a T-shirt',
          ],
          correctIdx: 1,
          explanation:
              '"Boys often wear black or dark blue suits" とあるね。日本の男子（だんし）がよく着るのは「黒（くろ）か こん色のスーツ」。',
        ),
        _ComprehensionQuestion(
          question: 'Why do Australian schools require hats?',
          choices: [
            'To look smart',
            'To show the school logo',
            'To protect students from the sun',
            'Because it rains a lot',
          ],
          correctIdx: 2,
          explanation:
              '"...wear a hat outside to protect them from the sun." とあるよ。オーストラリアでぼうしが必要（ひつよう）なのは「日ざしから身を守るため」。',
        ),
        _ComprehensionQuestion(
          question: 'What is one reason people support school uniforms?',
          choices: [
            'Students can show their personality',
            'They are more comfortable than other clothes',
            'Families save money on clothes',
            'Students can wear any color they like',
          ],
          correctIdx: 2,
          explanation:
              '"...families save money on clothes." とあるね。せいふくに さんせいする理由（りゆう）の一つは「服（ふく）のお金をせつやくできる」こと。',
        ),
        _ComprehensionQuestion(
          question: 'In which country do students often wear ties to school?',
          choices: [
            'Japan',
            'Australia',
            'England',
            'All three countries',
          ],
          correctIdx: 2,
          explanation:
              '"In England... Students usually wear a white shirt, a tie..." とあるよ。ネクタイ（tie）をするのは「イングランド（England）」。',
        ),
      ],
    ),
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PRE-2 (B1) — Longer articles, formal communications (7 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _pre2Passages = [
    _ReadingPassage(
      title: 'The Rise of Electric Vehicles',
      type: 'article',
      content:
          'Over the past decade, electric vehicles (EVs) have become increasingly '
          'popular worldwide. In 2015, only about 1% of new cars sold globally were '
          'electric. By 2025, that figure had risen to nearly 20%. Several factors '
          'have driven this change.\n\n'
          'First, governments in many countries have offered financial incentives, '
          'such as tax reductions, to encourage people to buy EVs. Second, the cost '
          'of batteries has dropped significantly — by about 80% since 2010 — making '
          'electric cars more affordable. Third, growing awareness of climate change '
          'has motivated consumers to seek greener transportation options.\n\n'
          'However, challenges remain. Many rural areas still lack charging stations, '
          'and some drivers worry about running out of power on long trips. Battery '
          'production also raises environmental concerns, as mining lithium and cobalt '
          'can damage ecosystems.\n\n'
          'Despite these issues, most experts predict that EVs will account for the '
          'majority of new car sales by 2035. Car manufacturers are investing billions '
          'in EV technology, and several countries have announced plans to ban the sale '
          'of new gasoline-powered cars within the next decade.',
      questions: [
        _ComprehensionQuestion(
          question:
              'What percentage of new cars sold globally were electric by 2025?',
          choices: [
            'About 1%',
            'About 10%',
            'Nearly 20%',
            'Over 50%',
          ],
          correctIdx: 2,
          explanation:
              '"By 2025, that figure had risen to nearly 20%." とあるね。2025年には新車（しんしゃ）の「約20%」が電気自動車（でんきじどうしゃ）だったよ。',
        ),
        _ComprehensionQuestion(
          question: 'How much have battery costs decreased since 2010?',
          choices: [
            'By about 20%',
            'By about 50%',
            'By about 80%',
            'By about 95%',
          ],
          correctIdx: 2,
          explanation:
              '"the cost of batteries has dropped ... by about 80% since 2010" とあるよ。電池（でんち）のコストは「約80%」下がった。',
        ),
        _ComprehensionQuestion(
          question: 'What is one challenge mentioned about EVs in rural areas?',
          choices: [
            'Cars are too expensive',
            'There are not enough charging stations',
            'People do not know about EVs',
            'The roads are too rough for EVs',
          ],
          correctIdx: 1,
          explanation:
              '"Many rural areas still lack charging stations" とあるね。地方（ちほう）の課題（かだい）は「じゅうでんスタンドが足りない」こと。',
        ),
        _ComprehensionQuestion(
          question:
              'What environmental concern is raised about battery production?',
          choices: [
            'It uses too much water',
            'Mining lithium and cobalt can damage ecosystems',
            'Old batteries pollute rivers',
            'Factory smoke causes air pollution',
          ],
          correctIdx: 1,
          explanation:
              '"mining lithium and cobalt can damage ecosystems" とあるよ。電池作りの問題は「リチウムやコバルトをほり出すと自然（しぜん）をこわすこと」。',
        ),
      ],
    ),
    _ReadingPassage(
      title: '',
      type: 'email',
      content: 'Dear Ms. Nakamura,\n\n'
          'I am writing to inform you about changes to our student exchange program '
          'for next academic year. Due to increased demand, we have decided to expand '
          'the program from two weeks to four weeks. The new dates will be from '
          'July 10 to August 7, 2027.\n\n'
          'In addition to the homestay experience, we are adding new activities. '
          'Students will now have the opportunity to attend classes at a local high '
          'school for two weeks, participate in community service projects, and take '
          'weekend excursions to nearby cultural sites.\n\n'
          'The program fee has been adjusted to reflect these additions. The new cost '
          'is \$3,200 per student, which includes airfare, accommodation, meals, and '
          'all activities. A deposit of \$500 is required by March 31 to secure a place.\n\n'
          'We have 25 spots available for Japanese students this year. Given the '
          'popularity of the program, I recommend that interested students apply '
          'as soon as possible. Application forms are available on our website.\n\n'
          'Please do not hesitate to contact me if you have any questions.\n\n'
          'Sincerely,\nDavid Chen\nInternational Programs Coordinator',
      questions: [
        _ComprehensionQuestion(
          question: 'How long will the exchange program be next year?',
          choices: [
            'Two weeks',
            'Three weeks',
            'Four weeks',
            'Six weeks',
          ],
          correctIdx: 2,
          explanation:
              '"expand the program from two weeks to four weeks" とあるね。来年（らいねん）のプログラムは「4週間（four weeks）」になるよ。',
        ),
        _ComprehensionQuestion(
          question: 'What is a new activity added to the program?',
          choices: [
            'Learning to cook local food',
            'Attending classes at a local high school',
            'Working part-time at a company',
            'Taking a language certification test',
          ],
          correctIdx: 1,
          explanation:
              '"attend classes at a local high school" とあるよ。新しい活動の一つは「地元（じもと）の高校で授業（じゅぎょう）を受ける」こと。',
        ),
        _ComprehensionQuestion(
          question: 'How much deposit must be paid by March 31?',
          choices: [
            '\$200',
            '\$500',
            '\$1,000',
            '\$3,200',
          ],
          correctIdx: 1,
          explanation:
              '"A deposit of \$500 is required by March 31" とあるね。3月31日までに払う前金（まえきん）は「500ドル」が正解。',
        ),
      ],
    ),
    // Depth expansion 2026-06-14: more practice variety on the high-weight reading
    // skill (the standalone practice screen seeded only 2 passages/grade).
    _ReadingPassage(
      title: 'The History of Chocolate',
      type: 'article',
      content:
          'Chocolate is one of the most popular sweets in the world, but its '
          'history is longer and more surprising than many people think. '
          'Chocolate comes from the seeds of the cacao tree, which grows in warm '
          'areas near the equator.\n\n'
          'More than three thousand years ago, the ancient peoples of Central '
          'America were the first to use cacao. However, they did not eat sweet '
          'chocolate bars like we do today. Instead, they made a bitter drink by '
          'mixing ground cacao seeds with water and spices. This drink was so '
          'valuable that cacao seeds were sometimes used as money.\n\n'
          'When explorers brought cacao back to Europe in the sixteenth century, '
          'people there added sugar to make the drink sweeter. For a long time, '
          'chocolate remained an expensive treat that only rich people could '
          'enjoy.\n\n'
          'Everything changed in the nineteenth century. New machines made it '
          'possible to produce solid chocolate bars quickly and cheaply. Soon, '
          'chocolate became a treat that almost everyone could afford. Today, '
          'millions of tons of chocolate are made every year, and it is enjoyed '
          'by people of all ages around the world.',
      questions: [
        _ComprehensionQuestion(
          question: 'Where does chocolate come from?',
          choices: [
            'The leaves of a special plant.',
            'The seeds of the cacao tree.',
            'A type of sugar cane.',
            'The roots of a tree.',
          ],
          correctIdx: 1,
          explanation:
              '本文（ほんぶん）に "Chocolate comes from the seeds of the cacao tree" とあるね。カカオの木（き）の種（たね）からできるよ。',
        ),
        _ComprehensionQuestion(
          question: 'How did the ancient peoples of Central America use cacao?',
          choices: [
            'They ate sweet chocolate bars.',
            'They used it only as medicine.',
            'They made a bitter drink from it.',
            'They grew it for its flowers.',
          ],
          correctIdx: 2,
          explanation:
              '"they made a bitter drink by mixing ground cacao seeds with water and spices" とあるよ。',
        ),
        _ComprehensionQuestion(
          question:
              'Why could only rich people enjoy chocolate for a long time?',
          choices: [
            'Because it was hard to find.',
            'Because it was illegal.',
            'Because it tasted bad.',
            'Because it was expensive.',
          ],
          correctIdx: 3,
          explanation:
              '"chocolate remained an expensive treat that only rich people could enjoy" とあるね。値段（ねだん）が高（たか）かったから。',
        ),
        _ComprehensionQuestion(
          question: 'What change happened in the nineteenth century?',
          choices: [
            'Machines made cheap solid chocolate bars possible.',
            'Cacao trees disappeared.',
            'Chocolate became illegal.',
            'People stopped adding sugar.',
          ],
          correctIdx: 0,
          explanation:
              '"New machines made it possible to produce solid chocolate bars quickly and cheaply" とあるよ。',
        ),
      ],
    ),
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GRADE 2 (B1-B2) — Academic passages, news articles (12 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _grade2Passages = [
    _ReadingPassage(
      title: 'The Science of Sleep',
      type: 'article',
      content:
          'Sleep is essential for both physical and mental health, yet millions of '
          'people around the world do not get enough of it. Research shows that adults '
          'need between seven and nine hours of sleep per night, but surveys indicate '
          'that nearly one-third of adults regularly sleep less than six hours.\n\n'
          'During sleep, the brain goes through several cycles, each lasting about 90 '
          'minutes. These cycles include light sleep, deep sleep, and REM (rapid eye '
          'movement) sleep. Deep sleep is crucial for physical recovery — the body '
          'repairs tissues and strengthens the immune system during this phase. REM '
          'sleep, on the other hand, is essential for memory consolidation and emotional '
          'processing.\n\n'
          'Chronic sleep deprivation has been linked to numerous health problems, '
          'including obesity, heart disease, diabetes, and depression. It also impairs '
          'cognitive function, reducing attention span, decision-making ability, and '
          'creativity. Studies have shown that driving after being awake for 24 hours '
          'is comparable to driving with a blood alcohol level above the legal limit.\n\n'
          'Experts recommend several strategies for improving sleep quality: maintaining '
          'a consistent sleep schedule, avoiding screens for at least one hour before bed, '
          'keeping the bedroom cool and dark, and limiting caffeine intake after noon.',
      questions: [
        _ComprehensionQuestion(
          question:
              'According to the passage, how long does each sleep cycle last?',
          choices: [
            'About 60 minutes',
            'About 90 minutes',
            'About 120 minutes',
            'About 180 minutes',
          ],
          correctIdx: 1,
          explanation:
              '"the brain goes through several cycles, each lasting about 90 minutes." とあるね。睡眠の各サイクルは「約90分」続く。',
        ),
        _ComprehensionQuestion(
          question: 'What happens during deep sleep?',
          choices: [
            'Dreams occur most frequently',
            'The body repairs tissues and strengthens immunity',
            'Memories are consolidated',
            'The brain processes emotions',
          ],
          correctIdx: 1,
          explanation:
              '"Deep sleep is crucial for physical recovery — the body repairs tissues and strengthens the immune system during this phase." とあるね。深い睡眠中に体は組織を修復し、免疫を強くする。',
        ),
        _ComprehensionQuestion(
          question:
              'What comparison is made about sleep deprivation and driving?',
          choices: [
            'It is like driving in heavy rain',
            'It is like driving without glasses',
            'It is like driving above the speed limit',
            'It is like driving with illegal blood alcohol levels',
          ],
          correctIdx: 3,
          explanation:
              '"driving after being awake for 24 hours is comparable to driving with a blood alcohol level above the legal limit." とあるよ。24時間起きたままの運転は、法律の基準を超えたアルコールでの運転と同じくらいあぶない、と比べている。',
        ),
        _ComprehensionQuestion(
          question: 'Which is NOT mentioned as a tip for better sleep?',
          choices: [
            'Keeping a regular sleep schedule',
            'Exercising vigorously before bed',
            'Avoiding screens before bed',
            'Limiting afternoon caffeine',
          ],
          correctIdx: 1,
          explanation:
              '本文が挙げる工夫は「一定の睡眠スケジュール／就寝前のスクリーン回避／寝室を涼しく暗く／午後のカフェイン制限」。"Exercising vigorously before bed"（寝る前の激しい運動）は書かれていない。NOT問題は、本文にある工夫を消して、残った選択肢を選ぶ。',
        ),
      ],
    ),
    _ReadingPassage(
      title: 'Urban Farming: Growing Food in Cities',
      type: 'article',
      content:
          'As urban populations continue to grow, an increasing number of city '
          'residents are turning to urban farming — growing food in small spaces '
          'within cities. This movement takes many forms, from rooftop gardens and '
          'community plots to vertical farms housed in former warehouses.\n\n'
          'One of the primary motivations for urban farming is food security. In '
          'many low-income urban neighborhoods, fresh produce is difficult to find. '
          'These areas, sometimes called "food deserts," may have convenience stores '
          'and fast-food restaurants but lack grocery stores with affordable fruits '
          'and vegetables. Urban farms can help fill this gap by providing locally '
          'grown food directly to the community.\n\n'
          'Environmental benefits are another driving force. Traditional agriculture '
          'requires transporting food hundreds or even thousands of kilometers from '
          'farm to table. Urban farming dramatically reduces this distance, cutting '
          'carbon emissions associated with transportation. Additionally, green spaces '
          'in cities help absorb rainwater, reduce the urban heat island effect, and '
          'provide habitat for pollinators like bees.\n\n'
          'Critics point out that urban farms cannot produce food at the same scale '
          'as traditional agriculture and that the cost per unit of food is often '
          'higher. Nevertheless, proponents argue that urban farming\'s greatest value '
          'lies not in replacing conventional farming but in supplementing it while '
          'building community connections and educating city dwellers about where '
          'their food comes from.',
      questions: [
        _ComprehensionQuestion(
          question: 'What is a "food desert" as described in the passage?',
          choices: [
            'A dry region where crops cannot grow',
            'A neighborhood lacking stores with affordable fresh produce',
            'A city with no restaurants',
            'An area affected by drought',
          ],
          correctIdx: 1,
          explanation:
              '"\\"food deserts,\\" may have convenience stores and fast-food restaurants but lack grocery stores with affordable fruits and vegetables." とあるね。food desert は、コンビニやファストフードはあっても、手頃なくだものや野さいを売る店がない地域のこと。',
        ),
        _ComprehensionQuestion(
          question: 'How does urban farming help the environment?',
          choices: [
            'It uses less water than traditional farming',
            'It reduces transportation-related carbon emissions',
            'It eliminates the need for pesticides',
            'It prevents all types of flooding',
          ],
          correctIdx: 1,
          explanation:
              '"Urban farming dramatically reduces this distance, cutting carbon emissions associated with transportation." とあるよ。都市農業は farm-to-table の輸送距離を縮め、輸送による炭素排出を減らす。',
        ),
        _ComprehensionQuestion(
          question: 'What criticism of urban farming is mentioned?',
          choices: [
            'It causes noise pollution in cities',
            'It uses dangerous chemicals',
            'It cannot produce food at the same scale as traditional farming',
            'It takes away housing space',
          ],
          correctIdx: 2,
          explanation:
              '"Critics point out that urban farms cannot produce food at the same scale as traditional agriculture" とあるね。批判は「都市農業は従来の農業と同じ規模では食料を作れない」という点。',
        ),
        _ComprehensionQuestion(
          question:
              'According to proponents, what is urban farming\'s greatest value?',
          choices: [
            'Producing cheaper food than supermarkets',
            'Completely replacing traditional agriculture',
            'Supplementing farming while building community and education',
            'Creating jobs for unemployed people',
          ],
          correctIdx: 2,
          explanation:
              '"urban farming\'s greatest value lies not in replacing conventional farming but in supplementing it while building community connections and educating city dwellers" とあるよ。推進派は、最大の価値は従来農業を置き換えることではなく「補完」し、地域のつながりや食育を育む点だと考えている。',
        ),
      ],
    ),
    _ReadingPassage(
      title: '',
      type: 'letter',
      content: 'Dear Editor,\n\n'
          'I am writing in response to last week\'s article about the city council\'s '
          'proposal to ban cars from the downtown area on weekends. While I understand '
          'the intention to reduce pollution and create a more pedestrian-friendly '
          'environment, I believe the plan has several serious flaws.\n\n'
          'First, many small business owners in the downtown area rely on weekend '
          'customers who drive to their shops. A car ban could reduce foot traffic '
          'for these businesses by 30-40%, according to a survey conducted by the '
          'Chamber of Commerce. Several shop owners I spoke with said they might be '
          'forced to close if the ban is implemented.\n\n'
          'Second, the current public transportation system is not adequate to handle '
          'the increased demand. Buses run only every 30 minutes on weekends, and the '
          'nearest train station is a 20-minute walk from the main shopping district.\n\n'
          'I suggest a compromise: instead of a complete ban, the council could create '
          'car-free zones on certain streets while maintaining access roads for those '
          'who need to drive. They could also invest in improving weekend bus service '
          'before implementing any restrictions.\n\n'
          'Sincerely,\nHiroshi Yamamoto',
      questions: [
        _ComprehensionQuestion(
          question: 'What is the city council proposing?',
          choices: [
            'Building a new train station downtown',
            'Banning cars from downtown on weekends',
            'Closing small businesses on weekends',
            'Increasing bus fares',
          ],
          correctIdx: 1,
          explanation:
              '"the city council\'s proposal to ban cars from the downtown area on weekends" とあるね。市議会の提案は「週末に中心街から車を締め出す」こと。',
        ),
        _ComprehensionQuestion(
          question:
              'According to the survey, how much could foot traffic decrease?',
          choices: [
            '10-20%',
            '20-30%',
            '30-40%',
            '40-50%',
          ],
          correctIdx: 2,
          explanation:
              '"A car ban could reduce foot traffic for these businesses by 30-40%, according to a survey conducted by the Chamber of Commerce." とあるよ。商工会議所の調査では、客足が「30〜40％」減りうる。',
        ),
        _ComprehensionQuestion(
          question:
              'What problem with public transport does the writer mention?',
          choices: [
            'Buses are too expensive',
            'Trains do not run on weekends',
            'Buses run only every 30 minutes on weekends',
            'The bus stops are too far from homes',
          ],
          correctIdx: 2,
          explanation:
              '"Buses run only every 30 minutes on weekends" とあるね。筆者は週末のバスが「30分に1本」しかない点を、公共交通の不十分さとして挙げている。',
        ),
        _ComprehensionQuestion(
          question: 'What does the writer suggest as a compromise?',
          choices: [
            'Cancel the plan entirely',
            'Ban cars only on Sundays',
            'Create car-free zones on certain streets only',
            'Build a large parking lot outside downtown',
          ],
          correctIdx: 2,
          explanation:
              '"instead of a complete ban, the council could create car-free zones on certain streets while maintaining access roads" とあるよ。筆者の折衷案は、全面禁止ではなく「一部の通りだけ歩行者専用にし、必要な人のためのアクセス道路は残す」こと。',
        ),
      ],
    ),
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // GRADE 2 — Passage Fill-in (長文語句空所補充) (6 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 準2級 (A2–B1) — 大問3 長文の語句空所補充 (passage cloze).  #60/Task#32: the
  // config previously SKIPPED 大問3 entirely (vocab→conv→内容一致). The 2024 reform
  // (eiken.or.jp 2024renewal, verified 2026-06-14) removed 大問3B (設問28-30, −3),
  // leaving 大問3 = ONE short passage with TWO blanks (29 = 15+5+2+7). NOT the
  // pre-reform [A]2+[B]3=5 (that ei-navi description is stale). content-qa 2026-06-14.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const _pre2FillIn = [
    // One short daily-episode passage, 2 blanks (post-2024-reform format).
    _ReadingPassage(
      title: "Mika's Photographs",
      type: 'story',
      content:
          'Last month, Mika started taking photographs of the flowers in her '
          'neighborhood. At first, her pictures were not very good, but she did '
          'not give up. She watched videos online to learn ( 1 ) to use her '
          'camera better. After many weeks of practice, her photos became '
          'beautiful. Her friends were so ( 2 ) with them that they asked her to '
          'teach them, too.',
      questions: [
        _ComprehensionQuestion(
          question: 'Which word best fits in blank ( 1 )?',
          choices: ['how', 'what', 'which', 'where'],
          correctIdx: 0,
          explanation: '「how to ＋ 動詞の原形」で「〜の仕方」。カメラの「使い方」を学んだ流れ。',
        ),
        _ComprehensionQuestion(
          question: 'Which word best fits in blank ( 2 )?',
          choices: ['bored', 'impressed', 'angry', 'careful'],
          correctIdx: 1,
          explanation: '写真が上達し、友達は「感心した」。be impressed with 〜 で「〜に感心する」。',
        ),
      ],
    ),
  ];

  // 準2級プラス (A2–B1) — 大問2 長文の語句空所補充 (passage cloze)
  // Closes the standalone 準備中 gap: pre2plus reading was mock-only before.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const _pre2PlusFillIn = [
    _ReadingPassage(
      title: 'The Comeback of the Bicycle',
      type: 'article',
      content:
          'In many cities around the world, the bicycle is becoming popular '
          'again. For years, cars were the most common way to travel, but rising '
          'fuel prices and growing concern about the environment have changed how '
          'people get around. ( 1 ), more and more people are choosing to ride '
          'bicycles for their daily commute.\n\n'
          'One reason for this change is health. Riding a bicycle is a form of '
          'exercise that fits easily into a busy day. Doctors say that cycling for '
          'just thirty minutes a day can improve heart health and reduce stress. '
          '( 2 ), it does not require expensive equipment or a gym membership.\n\n'
          'Cities have also started to support cyclists. Many have built special '
          'bicycle lanes that make riding ( 3 ) than before. Some cities offer '
          'bike-sharing programs, where people can rent a bicycle for a short trip '
          'and return it at another station. These programs are especially useful '
          'for tourists and for people who do not own a bicycle.\n\n'
          'Of course, cycling is not perfect for everyone. In very hot or rainy '
          'weather, riding can be uncomfortable, and some people live ( 4 ) to '
          'cycle to work. Still, for short distances, the bicycle is often faster '
          'than a car, because cyclists do not get stuck in traffic.\n\n'
          'As more people discover these advantages, experts believe the number '
          'of cyclists will continue to ( 5 ) in the coming years.',
      questions: [
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 1 )?',
          choices: [
            'As a result,',
            'However,',
            'For example,',
            'In contrast,',
          ],
          correctIdx: 0,
          explanation: '習慣が変わった「結果」として自転車を選ぶ人が増えた、という流れ。As a result（その結果）が自然。',
        ),
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 2 )?',
          choices: [
            'However,',
            'Instead,',
            'In addition,',
            'Finally,',
          ],
          correctIdx: 2,
          explanation: '前文(健康効果)に「さらに」費用がかからない利点を加えている。In addition（さらに）が適切。',
        ),
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 3 )?',
          choices: [
            'more dangerous',
            'slower',
            'more expensive',
            'safer and more comfortable',
          ],
          correctIdx: 3,
          explanation:
              '自転車レーンを作ると、以前より「安全で快適」に乗れるという文脈。safer and more comfortable が適切。',
        ),
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 4 )?',
          choices: [
            'close enough',
            'too far away',
            'very near',
            'right next door',
          ],
          correctIdx: 1,
          explanation: '職場まで「遠すぎて」自転車で通えない人もいる、という欠点。too far away が適切。',
        ),
        _ComprehensionQuestion(
          question: 'Which word best fits in blank ( 5 )?',
          choices: [
            'disappear',
            'fall',
            'grow',
            'stop',
          ],
          correctIdx: 2,
          explanation: '利点に気づく人が増え、自転車利用者は今後も「増え続ける」と専門家は考えている。grow が適切。',
        ),
      ],
    ),
  ];

  // 準2級プラス (A2–B1) — 大問3 長文の内容一致選択 (reading comprehension)
  static const _pre2PlusPassages = [
    _ReadingPassage(
      title: 'Community Gardens',
      type: 'article',
      content:
          'In recent years, community gardens have appeared in many towns and '
          'cities. A community garden is a shared piece of land where local '
          'people can grow their own vegetables, fruits, and flowers. Each person '
          'or family usually rents a small plot for a low yearly fee.\n\n'
          'These gardens offer many benefits. First, they give people who live in '
          'apartments a chance to grow fresh food, even if they have no garden of '
          'their own. Second, gardening is good exercise and can reduce stress. '
          'Many gardeners say that spending time outdoors makes them feel calmer '
          'and happier.\n\n'
          'Community gardens also bring people together. Neighbors who might never '
          'have spoken often become friends while working side by side. '
          'Experienced gardeners share advice with beginners, and some gardens '
          'hold events where members cook and eat the food they have grown.\n\n'
          'Of course, running a community garden takes effort. Members must agree '
          'on rules, share tools, and take turns caring for shared areas such as '
          'paths and water taps. Despite these challenges, the number of community '
          'gardens continues to grow, as more people discover the joy of growing '
          'food and making friends at the same time.',
      questions: [
        _ComprehensionQuestion(
          question: 'What is a community garden?',
          choices: [
            'A large public park with no plants.',
            'A shared piece of land where local people grow plants.',
            'A private farm owned by one family.',
            'A store that sells vegetables.',
          ],
          correctIdx: 1,
          explanation:
              '本文（ほんぶん）に "a shared piece of land where local people can grow their own vegetables" とあるね。地域（ちいき）の人がみんなで使（つか）う土地（とち）だよ。',
        ),
        _ComprehensionQuestion(
          question:
              'According to the passage, what is one benefit for people who live in apartments?',
          choices: [
            'They can sell their vegetables for money.',
            'They get free apartments.',
            'They can grow fresh food even without their own garden.',
            'They no longer need to buy any food.',
          ],
          correctIdx: 2,
          explanation:
              '"give people who live in apartments a chance to grow fresh food, even if they have no garden of their own" とあるね。',
        ),
        _ComprehensionQuestion(
          question: 'How do community gardens bring people together?',
          choices: [
            'By holding sports competitions.',
            'By giving away free land.',
            'Neighbors become friends while working side by side.',
            'By offering paid cooking classes.',
          ],
          correctIdx: 2,
          explanation:
              '"Neighbors who might never have spoken often become friends while working side by side." とあるよ。',
        ),
        _ComprehensionQuestion(
          question: 'What is one challenge of running a community garden?',
          choices: [
            'The vegetables are very expensive.',
            'There is never enough sunlight.',
            'Only experts are allowed to join.',
            'Members must agree on rules and share tools.',
          ],
          correctIdx: 3,
          explanation:
              '"Members must agree on rules, share tools, and take turns caring for shared areas" とあるね。',
        ),
      ],
    ),
    _ReadingPassage(
      title: 'NOTICE: Spring Beach Cleanup',
      type: 'notice',
      content:
          'The Greenport Town Council invites all residents to join our annual '
          'beach cleanup on Saturday, April 12th. Last year, more than 200 '
          'volunteers collected over 500 bags of trash from our beaches. This '
          'year, we hope to do even better.\n\n'
          'Volunteers should meet at the main beach entrance at 9:00 a.m. Gloves '
          'and trash bags will be provided, but please bring your own water bottle '
          'and wear a hat, as the weather may be sunny and warm. The cleanup will '
          'finish at noon, and a free lunch will be served to all volunteers at '
          'the beach cafe.\n\n'
          'Children under 12 are welcome but must be accompanied by an adult. If '
          'it rains heavily, the event will be moved to the following Saturday, '
          'April 19th. For more information, please call the town office or visit '
          'our website.',
      questions: [
        _ComprehensionQuestion(
          question: 'What should volunteers bring?',
          choices: [
            'Their own gloves and trash bags.',
            'Their own water bottle.',
            'Their own lunch.',
            'A small boat.',
          ],
          correctIdx: 1,
          explanation:
              '"Gloves and trash bags will be provided, but please bring your own water bottle" とあるね。手袋（てぶくろ）とゴミ袋（ぶくろ）は用意（ようい）される。',
        ),
        _ComprehensionQuestion(
          question: 'What happens if it rains heavily?',
          choices: [
            'The event is cancelled completely.',
            'The event starts earlier.',
            'Volunteers clean indoors.',
            'The event moves to the following Saturday.',
          ],
          correctIdx: 3,
          explanation:
              '"If it rains heavily, the event will be moved to the following Saturday, April 19th." とあるよ。',
        ),
        _ComprehensionQuestion(
          question: 'What is provided to volunteers at noon?',
          choices: [
            'A free T-shirt.',
            'A free lunch.',
            'A cash reward.',
            'A boat trip.',
          ],
          correctIdx: 1,
          explanation:
              '"a free lunch will be served to all volunteers at the beach cafe." とあるね。',
        ),
      ],
    ),
    // Depth expansion 2026-06-14: more practice variety (reading).
    _ReadingPassage(
      title: 'The Rise of Food Trucks',
      type: 'article',
      content:
          'Food trucks have become a common sight in many cities. A food truck '
          'is a large vehicle with a kitchen inside, where cooks prepare and sell '
          'meals to customers on the street. Although food trucks have existed '
          'for over a hundred years, they have become especially popular in the '
          'last decade.\n\n'
          'There are several reasons for their success. First, starting a food '
          'truck costs much less than opening a traditional restaurant, so it '
          'allows young cooks to start their own business more easily. Second, '
          'because the trucks can move, owners can drive to busy areas such as '
          'office districts at lunchtime or music festivals on weekends.\n\n'
          'Customers enjoy food trucks too. They often offer creative and '
          'international dishes that are hard to find elsewhere, and the food is '
          'usually served quickly. Many cities now hold food truck events where '
          'dozens of trucks gather in one place.\n\n'
          'Of course, food trucks face challenges as well. The weather can affect '
          'business, and owners must follow strict health and safety rules. Even '
          'so, food trucks continue to grow in popularity, changing the way many '
          'people eat in cities.',
      questions: [
        _ComprehensionQuestion(
          question: 'What is a food truck?',
          choices: [
            'A restaurant with many tables.',
            'A large vehicle with a kitchen that sells meals on the street.',
            'A store that sells vegetables.',
            'A delivery service for restaurants.',
          ],
          correctIdx: 1,
          explanation:
              '本文に "a large vehicle with a kitchen inside, where cooks prepare and sell meals to customers on the street" とあるね。',
        ),
        _ComprehensionQuestion(
          question: 'Why is starting a food truck attractive to young cooks?',
          choices: [
            'It requires no cooking skills.',
            'It is open only on weekends.',
            'It costs much less than opening a restaurant.',
            'The government pays for it.',
          ],
          correctIdx: 2,
          explanation:
              '"starting a food truck costs much less than opening a traditional restaurant" とあるよ。',
        ),
        _ComprehensionQuestion(
          question: 'What is one challenge food trucks face?',
          choices: [
            'They cannot move at all.',
            'They are always too cheap.',
            'Customers dislike new dishes.',
            'Bad weather can affect business.',
          ],
          correctIdx: 3,
          explanation: '"The weather can affect business" とあるね。',
        ),
      ],
    ),
  ];

  static const _grade2FillIn = [
    _ReadingPassage(
      title: 'The History of Vending Machines',
      type: 'article',
      content:
          'Japan is famous for having more vending machines per person than any other '
          'country — approximately one machine for every 23 people. These machines sell '
          'everything from drinks and snacks to umbrellas and fresh flowers.\n\n'
          'The first modern vending machine was invented in England in the 1880s. It '
          'sold postcards. ( 1 ) In the early 1900s, vending machines selling '
          'chewing gum appeared in New York subway stations. Japan got its first '
          'vending machine in 1888, which sold tobacco.\n\n'
          'Today, Japanese vending machines are among the most advanced in the world. '
          'Many use facial recognition technology to ( 2 ) based on the customer\'s '
          'apparent age and gender. For example, a machine might suggest hot coffee to '
          'a middle-aged man on a cold morning, or a sweet juice to a young woman on '
          'a summer afternoon.\n\n'
          'The popularity of vending machines in Japan can be explained by several '
          'factors. Japan has low crime rates, so machines are rarely vandalized or '
          'robbed. ( 3 ) The country also has a culture of convenience and efficiency '
          'that makes 24-hour automated sales attractive to consumers.',
      questions: [
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 1 )?',
          choices: [
            'However, these machines were not very popular at first.',
            'The idea quickly spread to other countries.',
            'Postcards were expensive in those days.',
            'England stopped making vending machines soon after.',
          ],
          correctIdx: 1,
          explanation:
              '直前は「イギリスで最初の自販機（ハガキ用）」、直後はニューヨークなど他の国の例。空所には「その考えはすぐ他の国へ広まった」が入り、例への橋渡しになる。',
        ),
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 2 )?',
          choices: [
            'reduce the price of drinks',
            'recommend products',
            'count the number of customers',
            'take photographs',
          ],
          correctIdx: 1,
          explanation:
              '直後の例が「年齢や性別に合わせて飲み物をすすめる」。だから空所は「商品をおすすめする(recommend products)」。顔認識で客に合った商品を提案する流れ。',
        ),
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 3 )?',
          choices: [
            'This means owners do not need to worry about theft.',
            'This is why Japan has fewer machines than other countries.',
            'Japanese people prefer shopping at convenience stores.',
            'The police regularly check the machines.',
          ],
          correctIdx: 0,
          explanation:
              '直前は「犯罪が少なく、盗まれにくい」。空所は This means でその結果＝「持ち主は盗難を心配しなくてよい」とまとめる。次の文の also（〜も）が別の理由を足す合図。',
        ),
      ],
    ),
    _ReadingPassage(
      title: 'How Colors Affect Our Mood',
      type: 'article',
      content:
          'Color psychology is the study of how colors influence human emotions and '
          'behavior. Businesses, hospitals, and schools have long used this knowledge '
          'to create environments that ( 4 ).\n\n'
          'Warm colors like red and orange are known to increase energy and excitement. '
          'Restaurants often use red in their interior design because research shows it '
          'can stimulate appetite. ( 5 ) This is why many fast-food chains use red '
          'and yellow in their branding.\n\n'
          'Cool colors such as blue and green have the opposite effect. They tend to '
          'calm people down and reduce stress. Hospitals and clinics frequently paint '
          'their walls in soft blue or green tones to help patients feel more relaxed. '
          'Similarly, many tech companies use blue in their logos because it conveys '
          'a sense of trust and reliability.\n\n'
          'However, cultural differences play an important role in color perception. '
          '( 6 ) In Western countries, white is associated with purity and weddings, '
          'while in many East Asian cultures, white is traditionally worn at funerals. '
          'This means that businesses operating internationally must carefully consider '
          'how their color choices will be interpreted in different markets.',
      questions: [
        _ComprehensionQuestion(
          question: 'Which phrase best fits in blank ( 4 )?',
          choices: [
            'save money on electricity',
            'produce the desired psychological effect',
            'make buildings look more modern',
            'attract tourists from other countries',
          ],
          correctIdx: 1,
          explanation:
              'この段落の主題は「色が心理にあたえる効果」。会社・病院・学校が色の知識で作る環境は「ねらった心理的な効果を生む(produce the desired psychological effect)」もの。',
        ),
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 5 )?',
          choices: [
            'Blue is sometimes used in diet products to reduce hunger.',
            'Yellow is believed to encourage quick decision-making.',
            'Green makes people think of healthy food.',
            'Purple is considered a royal color in many countries.',
          ],
          correctIdx: 1,
          explanation:
              '直前は「赤が食欲を刺激する」、直後の結論は「だから赤と黄色を使う」。結論が"黄色"にも触れるので、空所は黄色の働き＝「黄色は素早い決断をうながすと言われる」が入る。',
        ),
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 6 )?',
          choices: [
            'Some people are colorblind and cannot see certain colors.',
            'Colors do not change meaning over time.',
            'The same color can have very different meanings in different cultures.',
            'Most businesses use the same colors worldwide.',
          ],
          correctIdx: 2,
          explanation:
              '直後に「白は西洋では清らかさ・結婚式、東アジアではおそうしきの色」という例が続く。空所はその主題文＝「同じ色でも文化によって意味が大きく異なる」が入る。',
        ),
      ],
    ),
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PRE-1 (B2) — Complex academic passages (10 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _pre1Passages = [
    _ReadingPassage(
      title: 'The Paradox of Choice',
      type: 'article',
      content:
          'In his influential 2004 book, psychologist Barry Schwartz argued that '
          'having too many options can actually make people less happy rather than '
          'more so. This counterintuitive idea, which he called "the paradox of '
          'choice," has since been supported by numerous psychological studies.\n\n'
          'Schwartz distinguished between two types of decision-makers: "maximizers," '
          'who always seek the absolute best option, and "satisficers," who choose '
          'the first option that meets their criteria. His research found that '
          'maximizers, despite often making objectively better choices, tend to feel '
          'less satisfied with their decisions. They are plagued by counterfactual '
          'thinking — imagining how other options might have turned out better.\n\n'
          'A landmark study at a California grocery store demonstrated this effect. '
          'When 24 varieties of jam were displayed, only 3% of shoppers made a '
          'purchase. When just 6 varieties were offered, 30% bought jam. The extensive '
          'selection, while initially attractive, ultimately overwhelmed consumers and '
          'inhibited their ability to commit to a choice.\n\n'
          'Critics of Schwartz\'s theory note that subsequent attempts to replicate '
          'the jam study have yielded mixed results. They argue that the relationship '
          'between choice and satisfaction is more nuanced than Schwartz suggests — '
          'expertise, personal importance, and the nature of the decision all moderate '
          'the effect. Nevertheless, the core insight that more is not always better '
          'has influenced fields ranging from user interface design to public policy.',
      questions: [
        _ComprehensionQuestion(
          question: 'What is the "paradox of choice"?',
          choices: [
            'People with fewer options make worse decisions',
            'Having too many options can reduce satisfaction',
            'All choices lead to the same outcome',
            'People prefer not to make choices at all',
          ],
          correctIdx: 1,
          explanation:
              '"having too many options can actually make people less happy rather than more so." とあるね。「選択肢が多すぎると、かえって人は幸せでなくなる」のが paradox of choice。',
        ),
        _ComprehensionQuestion(
          question: 'According to Schwartz, what characterizes "maximizers"?',
          choices: [
            'They choose quickly without thinking',
            'They avoid making decisions whenever possible',
            'They always seek the absolute best option',
            'They let others make decisions for them',
          ],
          correctIdx: 2,
          explanation:
              '"\\"maximizers,\\" who always seek the absolute best option" とあるよ。maximizer は常に「いちばん良い選択肢」を求めるタイプ。',
        ),
        _ComprehensionQuestion(
          question:
              'What happened in the jam study when 24 varieties were displayed?',
          choices: [
            '30% of shoppers bought jam',
            'Most shoppers bought multiple jars',
            'Only 3% of shoppers made a purchase',
            'Shoppers complained about the selection',
          ],
          correctIdx: 2,
          explanation:
              '"When 24 varieties of jam were displayed, only 3% of shoppers made a purchase." とあるね。24種類のときは購入したのはたった3%だった（6種類なら30%）。',
        ),
        _ComprehensionQuestion(
          question: 'What do critics say about Schwartz\'s theory?',
          choices: [
            'It has been completely disproven',
            'The jam study could not be replicated at all',
            'The relationship is more nuanced than Schwartz suggests',
            'More choice always leads to better satisfaction',
          ],
          correctIdx: 2,
          explanation:
              '"the relationship between choice and satisfaction is more nuanced than Schwartz suggests" とあるよ。批判する人たちは「選択と満足の関係は、Schwartz が言うほど単純ではない」と指摘している。',
        ),
        _ComprehensionQuestion(
          question:
              'What does "counterfactual thinking" refer to in this context?',
          choices: [
            'Ignoring facts when making decisions',
            'Imagining how other options might have turned out',
            'Thinking about choices that do not exist',
            'Making decisions based on false information',
          ],
          correctIdx: 1,
          explanation:
              '"imagining how other options might have turned out better" とあるね。counterfactual thinking とは「別の選択肢ならもっと良かったのでは」と想像すること。',
        ),
      ],
    ),
    _ReadingPassage(
      title: 'Microplastics: An Invisible Threat',
      type: 'article',
      content:
          'Microplastics — fragments of plastic smaller than five millimeters — have '
          'become one of the most pervasive pollutants on Earth. Recent studies have '
          'detected them in locations as remote as Arctic ice cores and as intimate '
          'as human blood samples. The implications of this contamination are only '
          'beginning to be understood.\n\n'
          'These tiny particles enter the environment through multiple pathways. '
          'When synthetic clothing is washed, thousands of microscopic fibers are '
          'released into wastewater. Larger plastic items, such as bottles and bags, '
          'gradually break down through exposure to sunlight and mechanical stress. '
          'Even car tires shed microplastic particles as they wear against road '
          'surfaces — a source that accounts for an estimated 28% of all microplastic '
          'pollution in oceans.\n\n'
          'The biological effects of microplastics remain a subject of active research. '
          'Laboratory studies have shown that high concentrations can cause inflammation, '
          'disrupt hormone function, and damage cells in fish and mammals. However, '
          'translating these findings to real-world conditions is challenging because '
          'laboratory exposures typically far exceed environmental concentrations.\n\n'
          'Addressing the microplastics problem requires action at multiple levels. '
          'Some countries have banned microbeads in cosmetics, and researchers are '
          'developing biodegradable alternatives to conventional plastics. Wastewater '
          'treatment plants can filter out up to 99% of microplastics, though the '
          'remaining 1% still represents billions of particles annually given the '
          'enormous volumes of water processed.',
      questions: [
        _ComprehensionQuestion(
          question: 'What are microplastics defined as in the passage?',
          choices: [
            'Any type of plastic waste in the ocean',
            'Plastic fragments smaller than five millimeters',
            'Plastic that cannot be seen with the naked eye',
            'Synthetic clothing fibers',
          ],
          correctIdx: 1,
          explanation:
              '"Microplastics — fragments of plastic smaller than five millimeters" とあるね。マイクロプラスチックは「5ミリ未満のプラスチックのかけら」と定義されている。',
        ),
        _ComprehensionQuestion(
          question:
              'According to the passage, what percentage of ocean microplastics '
              'comes from car tires?',
          choices: [
            'About 10%',
            'About 18%',
            'About 28%',
            'About 45%',
          ],
          correctIdx: 2,
          explanation:
              '"car tires shed microplastic particles ... a source that accounts for an estimated 28% of all microplastic pollution in oceans." とあるよ。タイヤ由来が海のマイクロプラスチックの約28%を占める。',
        ),
        _ComprehensionQuestion(
          question:
              'Why is it difficult to apply laboratory findings about microplastics '
              'to real-world conditions?',
          choices: [
            'Scientists cannot create microplastics in laboratories',
            'Laboratory exposures typically exceed environmental concentrations',
            'Animals behave differently in laboratories',
            'Real-world microplastics are a different type',
          ],
          correctIdx: 1,
          explanation:
              '"laboratory exposures typically far exceed environmental concentrations." とあるね。実験室で与える量は実際の環境よりずっと多いので、結果をそのまま現実にあてはめにくい。',
        ),
        _ComprehensionQuestion(
          question: 'What limitation of wastewater treatment is mentioned?',
          choices: [
            'It cannot remove any microplastics',
            'It is too expensive for most countries',
            'The 1% that passes through still represents billions of particles',
            'It only works for larger plastic pieces',
          ],
          correctIdx: 2,
          explanation:
              '"the remaining 1% still represents billions of particles annually" とあるね。処理場が99%除去できても、残り1%が年間で数えきれないほど大量のかけらになる。',
        ),
        _ComprehensionQuestion(
          question:
              'Which source of microplastics is mentioned in relation to daily activities?',
          choices: [
            'Cooking with plastic utensils',
            'Washing synthetic clothing',
            'Drinking from plastic bottles',
            'Using plastic shopping bags',
          ],
          correctIdx: 1,
          explanation:
              '"When synthetic clothing is washed, thousands of microscopic fibers are released into wastewater." とあるよ。合成素材の服を洗うと、無数の細かい糸が排水へ流れ出す（日常の行動が発生源）。',
        ),
      ],
    ),
    // Depth expansion 2026-06-14: more practice variety (B2 reading).
    _ReadingPassage(
      title: 'Why Languages Disappear',
      type: 'article',
      content:
          'Of the roughly seven thousand languages spoken around the world '
          'today, experts estimate that nearly half may disappear by the end of '
          'this century. A language is generally considered endangered when '
          'children stop learning it as their first language, because once a '
          'generation grows up speaking only a dominant language, the older '
          'tongue is rarely passed on.\n\n'
          'Several forces drive this decline. Globalization encourages people to '
          'adopt widely spoken languages such as English or Mandarin for '
          'education and business, often at the expense of their local language. '
          'In addition, migration from rural villages to cities scatters small '
          'language communities, making it harder for speakers to use their '
          'language daily.\n\n'
          'The loss of a language is more than the loss of words. Each language '
          'carries unique knowledge about the natural world, history, and ways of '
          'thinking that may not exist anywhere else. When a language vanishes, '
          'this cultural heritage often disappears with it.\n\n'
          'Linguists and communities are working to reverse the trend. Some '
          'create written records and dictionaries, while others develop apps and '
          'school programs to teach younger generations. Although saving every '
          'endangered language is unlikely, these efforts can preserve at least '
          'part of the remarkable linguistic diversity of the world.',
      questions: [
        _ComprehensionQuestion(
          question: 'When is a language generally considered endangered?',
          choices: [
            'When it has fewer than a thousand words.',
            'When children stop learning it as their first language.',
            'When it is not written down.',
            'When it is spoken only in cities.',
          ],
          correctIdx: 1,
          explanation:
              '本文に "considered endangered when children stop learning it as their first language" とある。',
        ),
        _ComprehensionQuestion(
          question:
              'According to the passage, how does globalization contribute to language decline?',
          choices: [
            'It bans local languages by law.',
            'It reduces the world population.',
            'It makes international travel more expensive.',
            'People adopt widely spoken languages for education and business.',
          ],
          correctIdx: 3,
          explanation:
              '"Globalization encourages people to adopt widely spoken languages such as English or Mandarin for education and business" とある。',
        ),
        _ComprehensionQuestion(
          question:
              'Why does the passage say losing a language is more than losing words?',
          choices: [
            'Each language carries unique cultural knowledge.',
            'Words can easily be replaced by new ones.',
            'Languages are used only for business.',
            'New words appear every year.',
          ],
          correctIdx: 0,
          explanation:
              '"Each language carries unique knowledge about the natural world, history, and ways of thinking" とある。',
        ),
        _ComprehensionQuestion(
          question:
              'What are linguists and communities doing to reverse the trend?',
          choices: [
            'Banning all dominant languages.',
            'Moving people back to villages.',
            'Creating records and developing teaching programs.',
            'Stopping all migration to cities.',
          ],
          correctIdx: 2,
          explanation:
              '"Some create written records and dictionaries, while others develop apps and school programs to teach younger generations" とある。',
        ),
      ],
    ),
  ];

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PRE-1 — Passage Fill-in (長文語句空所補充) (6 questions)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static const _pre1FillIn = [
    _ReadingPassage(
      title: 'The Neuroscience of Habit Formation',
      type: 'article',
      content:
          'Habits are automatic behaviors triggered by contextual cues. When we '
          'perform an action repeatedly in the same context, the brain gradually '
          'shifts control from the prefrontal cortex — responsible for conscious '
          'decision-making — to the basal ganglia, a structure associated with '
          'automatic routines. ( 1 )\n\n'
          'Research by Phillippa Lally at University College London found that, on '
          'average, it takes 66 days for a new behavior to become automatic, though '
          'individual variation is enormous — ranging from 18 to 254 days. The '
          'complexity of the behavior matters significantly. ( 2 ) More complex '
          'habits, such as a 15-minute meditation practice, require considerably '
          'more repetition.\n\n'
          'One of the most effective strategies for building new habits is called '
          '"habit stacking" — attaching a desired new behavior to an existing routine. '
          'For instance, someone who wants to start flossing might do so immediately '
          'after brushing their teeth. ( 3 ) The existing habit acts as a reliable '
          'trigger, eliminating the need to remember or motivate oneself to perform '
          'the new action.',
      questions: [
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 1 )?',
          choices: [
            'This is why habits feel effortless once established.',
            'The prefrontal cortex is located at the front of the brain.',
            'Most people have difficulty breaking bad habits.',
            'Scientists first studied habits in the 1950s.',
          ],
          correctIdx: 0,
          explanation:
              '直前で「脳のコントロールが自動ルーチンを担う部分（基底核）に移る」と述べているね。空所は This is why（だから）で、その結果＝「習慣は一度身につくと楽に感じる」とまとめる文が流れに合う。',
        ),
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 2 )?',
          choices: [
            'Lally\'s study was published in a medical journal.',
            'Most participants in the study were university students.',
            'Simple actions like drinking a glass of water after breakfast can become habitual within a few weeks.',
            'Some researchers disagree with these findings.',
          ],
          correctIdx: 2,
          explanation:
              '前後が「行動の複雑さが大きく影響する」→（空所）→「より複雑な習慣はもっと多くの繰り返しが必要」という対比。空所には"簡単な側"の例（朝食後にコップの水を飲むような単純な行動は数週間で習慣になる）が入る。',
        ),
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 3 )?',
          choices: [
            'Flossing is important for dental health.',
            'By linking the new behavior to an established one, the brain can more easily encode the sequence.',
            'Many dentists recommend flossing at least once a day.',
            'However, this technique does not work for everyone.',
          ],
          correctIdx: 1,
          explanation:
              '直前のフロスの例（既存の習慣の直後に新しい行動をする）を一般化する文が入る。「新しい行動を既存の習慣に結びつけると、脳が一連の流れを覚えやすい」が、次の「既存の習慣が引き金になる」へ自然につながる。',
        ),
      ],
    ),
    _ReadingPassage(
      title: 'The Economics of Attention',
      type: 'article',
      content:
          'In 1971, economist Herbert Simon observed that "a wealth of information '
          'creates a poverty of attention." This insight has become increasingly '
          'relevant in the digital age, where the average person encounters an '
          'estimated 6,000 to 10,000 advertisements daily. ( 4 )\n\n'
          'The "attention economy" refers to the marketplace in which human attention '
          'is treated as a scarce resource that companies compete to capture. Social '
          'media platforms, news outlets, and streaming services all employ '
          'sophisticated algorithms designed to maximize user engagement — that is, '
          'to keep people scrolling, watching, or clicking for as long as possible. '
          '( 5 ) These techniques exploit fundamental aspects of human psychology, '
          'such as our attraction to novelty and our sensitivity to social validation.\n\n'
          'Some scholars argue that treating attention as a commodity has profound '
          'implications for democracy. When citizens\' attention is fragmented across '
          'countless competing sources of information, it becomes difficult to sustain '
          'the kind of focused, deliberative thinking that democratic governance '
          'requires. ( 6 ) Others counter that the abundance of information, while '
          'challenging, ultimately empowers citizens by giving them access to diverse '
          'perspectives that were previously unavailable.',
      questions: [
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 4 )?',
          choices: [
            'Simon won the Nobel Prize in Economics in 1978.',
            'Attention has become the currency that drives the modern digital economy.',
            'Most people enjoy watching advertisements.',
            'Traditional media companies are no longer profitable.',
          ],
          correctIdx: 1,
          explanation:
              '直前は「人は毎日6千〜1万もの広告に接する」という情報過多の話。空所はその結論＝この段落の主題「注目（アテンション）が現代デジタル経済を動かすお金になった」。次段落の attention economy の説明へつながる。',
        ),
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 5 )?',
          choices: [
            'Most users are aware of these strategies.',
            'The internet was invented in the 1960s.',
            'Features like infinite scrolling, autoplay, and push notifications are not accidental but carefully engineered.',
            'Social media has many positive effects on society.',
          ],
          correctIdx: 2,
          explanation:
              '直後の文が "These techniques exploit ... human psychology"。この These techniques（これらの手法）が指す中身を空所で挙げる必要がある。「無限スクロール・自動再生・通知は偶然ではなく入念に設計されたもの」が入り、指示語がきれいにつながる。',
        ),
        _ComprehensionQuestion(
          question: 'Which sentence best fits in blank ( 6 )?',
          choices: [
            'Democracy has existed for over two thousand years.',
            'This concern has led some to call for regulations on algorithmic content curation.',
            'Most politicians use social media effectively.',
            'The problem is likely to solve itself over time.',
          ],
          correctIdx: 1,
          explanation:
              '直前の「民主主義への心配」を This concern（この心配）で受ける文が入る。「アルゴリズムによる情報の選別を制限すべきだという声につながった」が、直後の Others counter（反論する人もいる）と対比になる。',
        ),
      ],
    ),
  ];
}

/// Test-only: whether the reading practice screen serves real passages for a
/// (grade, sectionId) — i.e. it would NOT show the 準備中 empty state. Used by the
/// exam-surface completeness gate so a config section can never ship as 準備中.
@visibleForTesting
bool readingHasPassagesForTest(String grade, String sectionId) =>
    _ReadingPracticeScreenState._getPassages(grade, sectionId).isNotEmpty;

/// Test-only: every comprehension question's explanation (null if absent) across
/// all passages of (grade, sectionId) — for the teach-why coverage gate, so a
/// reading question can never ship without teaching WHY the answer is correct.
@visibleForTesting
List<String?> readingExplanationsForTest(String grade, String sectionId) =>
    _ReadingPracticeScreenState._getPassages(grade, sectionId)
        .expand((p) => p.questions)
        .map((q) => q.explanation)
        .toList();

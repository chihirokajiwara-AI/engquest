// lib/features/exam_practice/vocab_grammar_practice_screen.dart
// A-KEN Quest — Eiken Part 1: Vocabulary/Grammar fill-in-the-blank
//
// Generates exam-style questions from the vocabulary database:
// "He ( ) to school every day."
// 1. goes  2. go  3. went  4. going
//
// Uses VocabRepository + buildAntiLeakDistractors for accurate 4-choice questions
// (the stored JSON distractors are discarded — see distractor_generator.dart, #76).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../core/audio/word_audio_player_service.dart';
import '../../core/sound/practice_feedback.dart';
import 'practice_result_stars.dart';
import '../../core/data/vocab_repository.dart';
import '../../core/models/vocab_item.dart';
import 'distractor_generator.dart';
import 'eiken_exam_config.dart';
import 'practice_encouragement.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';
import 'exam_review_store.dart';
import '../quest/ui/dq_ui.dart';
import '../home/streak_service.dart';
import '../../core/gamification/xp_service.dart';
import 'exam_session_rewards.dart';

/// The CEFR band a 大問1 *graded answer* must stay within, per grade (#84).
/// 英検 grades map to CEFR ceilings; the cloze TARGET (the word being tested)
/// must not exceed it, or the child is measured on above-grade vocab. Above-grade
/// words can still appear as distractors/exposure — they just can't be the answer.
/// Only 準1's bank actually carries above-ceiling words today (289 C1 of 4500);
/// every other grade is fully on-grade, so this is a no-op for them. The filter
/// falls back to the full pool if a grade ever lacks enough on-grade items.
const Map<String, CefrLevel> kGradeCefrCeiling = {
  '5': CefrLevel.a1,
  '4': CefrLevel.a2,
  '3': CefrLevel.b1,
  'pre2': CefrLevel.b1,
  'pre2plus': CefrLevel.b1,
  '2': CefrLevel.b2,
  'pre1': CefrLevel.b2,
};

/// First WHOLE-WORD (\b-bounded), case-insensitive match of [word] in [sentence],
/// or null. Boundary-anchored so an inflected form never matches a stem fragment
/// ("ant" must NOT match inside "ants") — used to avoid highlighting a fragment
/// in the post-answer example sentence. Top-level + public so it is unit-testable.
RegExpMatch? wholeWordMatch(String sentence, String word) =>
    RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false)
        .firstMatch(sentence);

/// True when [word] can be cleanly blanked in [sentence] for a cloze: it appears
/// as a whole word EXACTLY once and NOT as a substring of any other word (#78).
/// This rejects the leaky cases — inflected forms ("ant" → "(  )s" reveals the
/// plural), compounds ("snow" inside "snowman" while standalone "snow" stays
/// visible), and multi-word/underscore keys — so a child never sees the answer.
bool hasCleanCloze(String sentence, String word) {
  final w = word.trim();
  if (w.isEmpty || w.contains('_') || w.contains(' ')) return false;
  // Reject hyphenated compounds: \b fires at a hyphen, so "commerce" in
  // "E-commerce" would otherwise pass yet leak the "E-" prefix in the cloze.
  if (RegExp('-${RegExp.escape(w)}|${RegExp.escape(w)}-', caseSensitive: false)
      .hasMatch(sentence)) {
    return false;
  }
  final whole = RegExp('\\b${RegExp.escape(w)}\\b', caseSensitive: false)
      .allMatches(sentence)
      .length;
  final anySub = RegExp(RegExp.escape(w), caseSensitive: false)
      .allMatches(sentence)
      .length;
  return whole == 1 && anySub == 1;
}

class VocabGrammarPracticeScreen extends StatefulWidget {
  const VocabGrammarPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
  });

  final String eikenGrade;
  final ExamSection section;

  @override
  State<VocabGrammarPracticeScreen> createState() =>
      _VocabGrammarPracticeScreenState();
}

class _VocabGrammarPracticeScreenState
    extends State<VocabGrammarPracticeScreen> {
  final _vocabRepo = VocabRepository();
  final _reviewStore = ExamReviewStore();
  final _rng = Random();

  // Tap-to-hear the answer word in feedback (CEO 1132 non-reader lens): a true
  // beginner who can't yet READ the word or example sentence can still HEAR the
  // correct word — the same proven WordAudioPlayerService the battle flashcards
  // use. Graceful when audio is unavailable (no crash; button just no-ops) and
  // respects the Settings voice-mute.
  final _wordAudio = WordAudioPlayerService();

  List<_Question> _questions = [];
  int _currentIdx = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  // Words missed THIS session, surfaced on the results screen as a concrete
  // "review exactly what you got wrong" study list (with meanings) — an
  // actionable, outcomes-oriented close to the session, not just a score. The
  // same words are already scheduled in the FSRS review store (#119), so the
  // list and the home due-count agree.
  final List<VocabItem> _missedWords = [];
  // Words already given one in-session re-test (cap 1 per word) so a string of
  // misses cannot grow the session unboundedly — mirrors Battle's re-queue cap.
  final Set<String> _retriedWords = {};
  // The streak/daily-goal earned THIS session, shown on the results screen so the
  // child feels their progress at the moment that pulls them back (SessionEndHook).
  StreakState? _earnedStreak;
  bool _loading = true;
  bool _loadError = false; // question generation threw → show a retry state
  bool _sessionDone = false;

  // Teach-first scaffold (CEO 1132 cont. / flaw-hunt #111): a true beginner
  // cannot read the English stimulus or choices, so the practice was pure
  // guessing. An OPT-IN 「いみを みる」 hint reveals each choice's Japanese meaning
  // BEFORE answering — comprehensible input that lets a pre-reader reason
  // instead of guess. Because seeing all four meanings makes a vocab item
  // answerable by meaning-matching, a hinted question is ASSISTED and is
  // excluded from the measured 合格率 (only unaided answers feed readiness) —
  // so the scaffold helps the child WITHOUT inflating the honesty of the
  // pass-meter (the 英検-instructor's assessment-validity concern).
  bool _hintShown = false; // hint revealed for the CURRENT question
  int _assistedCount = 0; // questions answered with the hint up (session)
  int _unaidedTotal = 0; // questions answered WITHOUT the hint
  int _unaidedCorrect = 0; // correct among the unaided

  // Struggling-child support (CEO 1135 / no-scold spine): a child who misses
  // several in a row gets a gentle, 探偵-framed encouragement (never a scold) and
  // a nudge toward the opt-in 「いみを みる」 hint — so a cold streak builds
  // resilience instead of shame. Resets to 0 on any correct answer.
  int _consecutiveWrong = 0;

  /// Consecutive CORRECT answers — the positive mirror of [_consecutiveWrong].
  /// Drives a brief momentum banner at [kMomentumThreshold] so a child on a roll
  /// FEELS the flow (engagement spine), not just per-answer feedback. Resets on
  /// any wrong answer. Mutually exclusive with the cold-streak banner.
  int _consecutiveCorrect = 0;

  @override
  void initState() {
    super.initState();
    // Skeleton-first (#52 "dead/slow tap"): the question build — vocab JSON
    // decode (up to ~3.7 MB / ~1.4 s for 準1級) plus per-item anti-leak
    // distractor synthesis (~0.2–0.5 s) — is heavy and CPU-bound, and Flutter
    // web has no isolates (compute() runs on the main thread), so it CANNOT be
    // moved off-thread. We instead paint the loading scaffold BEFORE starting
    // it, so the tap shows this screen + spinner instantly instead of freezing
    // the previous screen. Matches the post-frame pattern already used by the
    // reading / listening / conversation practice screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadQuestions();
    });
  }

  @override
  void dispose() {
    _wordAudio.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    // No dedicated vocab DB for this grade (e.g. 準2級プラス) → show the empty/
    // 準備中 state instead of silently falling back to 英検5級 words.
    if (!VocabRepository.hasGrade(widget.eikenGrade)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      await _vocabRepo.initialize(eikenGrade: widget.eikenGrade);
      final allWords = _vocabRepo.getAll();

      // Eligible base = has a first example sentence that can be CLEANLY clozed
      // (#78): the word appears as a whole word exactly once and not inside
      // another word, so the blank never leaks a suffix/compound.
      final eligible = allWords
          .where((w) =>
              w.exampleSentences.isNotEmpty &&
              hasCleanCloze(w.exampleSentences.first, w.word))
          .toList()
        ..shuffle(_rng);

      // Keep an above-grade word from being the GRADED answer of a 大問1 cloze
      // (#84). 準1's bank carries 289 C1-tagged words; testing a child on C1
      // vocab as if it were 準1 mis-measures readiness on the marquee grade. We
      // restrict the TARGET pool to on-grade words (distractors are capped at the
      // same ceiling below via distractorBank, so the whole item is grade-pure).
      // Guarded so a grade that can't field enough on-grade items keeps the full
      // pool rather than running empty.
      final ceiling = kGradeCefrCeiling[widget.eikenGrade];
      if (ceiling != null) {
        final onGrade =
            eligible.where((w) => w.cefrLevel.index <= ceiling.index).toList();
        if (onGrade.length >= widget.section.questionCount) {
          eligible
            ..clear()
            ..addAll(onGrade);
        }
      }

      // Spaced repetition (#119): surface words the child previously got WRONG
      // and that FSRS now schedules as DUE *first*, so a session actually
      // re-teaches what was forgotten instead of being fresh random recognition.
      // New words fill the rest. Falls back to pure-random on a first-ever visit
      // (no due cards) or any store error.
      try {
        final due = await _reviewStore.dueReviewKeys(widget.eikenGrade);
        if (due.isNotEmpty) {
          eligible.sort((a, b) {
            final ad = due.contains(ExamReviewStore.keyFor(a.word)) ? 0 : 1;
            final bd = due.contains(ExamReviewStore.keyFor(b.word)) ? 0 : 1;
            return ad - bd; // due words first; stable within each tier
          });
        }
      } catch (_) {
        // Non-fatal — keep the shuffled order.
      }

      // Build questions, regenerating distractors per item (#76). The stored
      // `distractors` are alphabetical-adjacency artifacts (~92% make the answer
      // the trivial first-letter odd-one-out), so we DISCARD them and synthesise
      // same-grade / same-POS / SAME-first-letter single-word distractors via
      // buildAntiLeakDistractors — killing the orthographic leak by construction.
      // Items whose grade bank can't yield three clean distractors are skipped.
      // word → Japanese meaning, used to gloss every distractor in the reveal.
      final glossOf = <String, String>{
        for (final w in allWords) w.word.toLowerCase(): w.jpTranslation,
      };

      // #84: keep DISTRACTORS on-grade too. The TARGET is already ceiling-capped
      // above, but distractors were drawn from the full bank — so a 準1 item
      // (target ≤B2) could still slip a C1 jargon word in as an option. Cap the
      // distractor candidate pool at the same ceiling; fall back to the full bank
      // only if the on-grade pool is too thin to ever field three candidates.
      final distractorBank = ceiling == null
          ? allWords
          : (() {
              final onGrade = allWords
                  .where((w) => w.cefrLevel.index <= ceiling.index)
                  .toList();
              return onGrade.length >= 4 ? onGrade : allWords;
            })();

      final wanted = widget.section.questionCount;
      final questions = <_Question>[];
      for (final word in eligible) {
        if (questions.length >= wanted) break;
        final sentence = word.exampleSentences.first;
        final distractors =
            buildAntiLeakDistractors(word, sentence, distractorBank, _rng);
        if (distractors == null) continue; // not enough clean candidates
        final cloze = _makeCloze(sentence, word.word);
        final choices = [word.word, ...distractors];
        choices.shuffle(_rng);
        questions.add(_Question(
          cloze: cloze,
          choices: choices,
          correctIdx: choices.indexOf(word.word),
          word: word,
          originalSentence: sentence,
          choiceGloss: {
            for (final d in distractors)
              if ((glossOf[d.toLowerCase()] ?? '').isNotEmpty)
                d: glossOf[d.toLowerCase()]!,
          },
        ));
      }
      _questions = questions;

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      // Show a child-friendly retry state — NOT a raw Dart exception in a
      // SnackBar (a 6yo can't read 'FirebaseException…') and NOT the "準備中"
      // empty state (a wrong reason: the content exists, the load failed).
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
    }
  }

  /// Blank the target WHOLE word in the sentence (#78). Items are pre-filtered by
  /// [hasCleanCloze] so a whole-word match exists and is unique; the prepend
  /// fallback is a safety net that should not normally trigger.
  String _makeCloze(String sentence, String word) {
    final m = wholeWordMatch(sentence, word);
    if (m == null) return '(        ) — $sentence';
    return '${sentence.substring(0, m.start)}(        )${sentence.substring(m.end)}';
  }

  /// Split [sentence] at the first WHOLE-WORD occurrence of [word] and emphasise
  /// it (bold + amber) so the child sees the answer in context. Word boundaries
  /// (\b) are required so an inflected form never highlights a fragment — e.g.
  /// "ant" in "ants" must NOT show "[ant]s". When there is no whole-word match
  /// (inflected/underscore-key forms), the sentence is shown plainly, unhighlighted
  /// — honest context without a misleading partial highlight.
  List<TextSpan> _sentenceSpans(String sentence, String word) {
    final match = wholeWordMatch(sentence, word);
    if (match == null) {
      return [TextSpan(text: sentence)];
    }
    return [
      TextSpan(text: sentence.substring(0, match.start)),
      TextSpan(
        text: sentence.substring(match.start, match.end),
        style: const TextStyle(color: dqGold, fontWeight: FontWeight.w800),
      ),
      TextSpan(text: sentence.substring(match.end)),
    ];
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    final q = _questions[_currentIdx];
    final correct = idx == q.correctIdx;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      if (correct) {
        _correctCount++;
      } else if (!_missedWords.contains(q.word)) {
        _missedWords.add(q.word);
      }
      // Track a cold streak to trigger gentle encouragement (no-scold spine) and
      // a HOT streak for the positive counterpart — momentum (this 調子！). They
      // are mutually exclusive, so they share one banner slot below.
      _consecutiveWrong = correct ? 0 : _consecutiveWrong + 1;
      _consecutiveCorrect = correct ? _consecutiveCorrect + 1 : 0;
      // Honest measurement: only UNAIDED FIRST attempts count toward 合格率. A
      // hinted question is recorded as assisted; an error-corrective RE-TEST
      // (isRetry) is a learning re-exposure and is excluded entirely — the
      // first attempt already set the score, so a 2nd-chance success must not
      // inflate the readiness signal.
      if (!q.isRetry) {
        if (_hintShown) {
          _assistedCount++;
        } else {
          _unaidedTotal++;
          if (correct) _unaidedCorrect++;
        }
      }
    });
    // Game-feel (#51): a haptic tick + chime so answering feels responsive.
    PracticeFeedback.answered(correct: correct);
    // a11y (WCAG 4.1.3 Status Messages): a blind/low-vision child only gets a
    // colour+icon swap, so SPEAK the verdict + the answer word & meaning — the
    // teaching reveal below is otherwise silent to assistive tech.
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${correct ? 'せいかい' : 'ふせいかい'}。 ${q.word.word.replaceAll('_', ' ')}は${q.word.jpTranslation}。',
      Directionality.of(context),
    );
    // Spaced repetition (#119): schedule this word via FSRS so a missed word
    // is re-surfaced in a future session (acquisition, not one-shot recognition).
    // Fire-and-forget; a hinted-correct is scheduled as 'hard' (not mastered).
    // A RE-TEST is NOT re-scheduled — the first miss already scheduled it, and
    // one in-session retrieval doesn't make the word "mastered" for next session.
    if (!q.isRetry) {
      _reviewStore.recordAnswer(
        grade: widget.eikenGrade,
        word: q.word.word,
        correct: correct,
        hinted: _hintShown,
      );
    }

    // In-session error-corrective re-retrieval (2026 SLA: retrieval AFTER
    // feedback builds durable encoding; a passive answer-reveal alone does not).
    // Mirrors Battle's re-queue (battle_screen.dart): a first-attempt miss is
    // re-presented ~3 questions later so the child RETRIEVES the correct form
    // before the session ends. Capped at one re-test per word; the re-test is
    // learning-only (excluded from 合格率 above). Hinted misses are not re-tested
    // (the child already saw the meanings — that path is the scaffold, not an error).
    if (!correct &&
        !q.isRetry &&
        !_hintShown &&
        !_retriedWords.contains(q.word.word)) {
      _retriedWords.add(q.word.word);
      final insertAt = min(_currentIdx + 3, _questions.length);
      setState(() => _questions.insert(insertAt, q.asRetry()));
    }
  }

  /// Reveal the choice meanings for the current question (opt-in scaffold).
  void _showHint() {
    if (_answered || _hintShown) return;
    setState(() => _hintShown = true);
  }

  /// The Japanese meaning to show under choice [i] of question [q] when the
  /// hint is up: the answer's own meaning, or a distractor's gloss.
  String _glossForChoice(_Question q, int i) {
    if (i == q.correctIdx) return q.word.jpTranslation;
    return q.choiceGloss[q.choices[i]] ?? '';
  }

  /// Records the completed session result into [SkillAccuracyStore].
  /// vocabGrammar → EikenSkill.reading (Part 1 = Reading大問).
  Future<void> _recordSessionResult() async {
    if (_questions.isEmpty) return;
    // Capture the streak/daily-goal the child just earned so the results screen
    // can SHOW it at the session-end peak (SessionEndHook), not only on home.
    recordExamXp(_questions.length);
    recordExamAchievements();
    recordExamHabitAndGet(_questions.length).then((st) {
      if (mounted && st != null) setState(() => _earnedStreak = st);
    });
    // Honesty: feed 合格率 ONLY the unaided answers. If every question used the
    // hint, nothing is recorded (the skill stays honestly 未測定 rather than
    // logging a meaning-matched guess as reading skill).
    if (_unaidedTotal == 0) return;
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.reading,
        correct: _unaidedCorrect,
        total: _unaidedTotal,
      );
    } catch (_) {
      // Store errors are non-fatal — never interrupt the learner.
    }
  }

  /// Test hook (#37 record-path integrity): the correct choice text for each
  /// generated question, in order. Questions are randomised at runtime from the
  /// vocab DB, so the record-path test cannot know the answers from outside;
  /// this lets it answer deterministically and assert the recorded (skill,
  /// correct, total) faithfully matches the session.
  @visibleForTesting
  List<String> get debugCorrectChoices =>
      _questions.map((q) => q.choices[q.correctIdx]).toList();

  /// Test hooks for the retry-aware record-path test: a wrong answer re-inserts a
  /// re-test question, so the session length is not fixed — drive by these.
  @visibleForTesting
  int get debugCurrentIdx => _currentIdx;
  @visibleForTesting
  bool get debugSessionDone => _sessionDone;

  /// Test hook (#37): a choice text for [questionIdx] that is NOT the correct
  /// answer — lets the record-path test deliberately answer one question wrong.
  @visibleForTesting
  String debugWrongChoiceFor(int questionIdx) {
    final q = _questions[questionIdx];
    for (var i = 0; i < q.choices.length; i++) {
      if (i != q.correctIdx) return q.choices[i];
    }
    return q.choices.first;
  }

  void _nextQuestion() {
    if (_currentIdx >= _questions.length - 1) {
      _recordSessionResult(); // fire-and-forget; UI does not wait
      setState(() => _sessionDone = true);
      PracticeFeedback.sessionComplete();
    } else {
      setState(() {
        _currentIdx++;
        _selectedAnswer = null;
        _answered = false;
        _hintShown = false; // each question decides its own scaffold afresh
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      contentMaxWidth:
          600, // #144: centre the column on tablet, full-width on phone
      child: Column(
        children: [
          // Dark header (matches the home / quest / exam hub — #67 cohesion).
          Padding(
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
                    widget.section.nameJa,
                    style: dqText(size: 15, w: FontWeight.w800, color: dqGold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: dqGold))
                : _sessionDone
                    ? _buildResults()
                    : _loadError
                        ? _buildLoadError()
                        : _questions.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'この級（きゅう）の問題（もんだい）は\n準備中（じゅんびちゅう）です。',
                                    textAlign: TextAlign.center,
                                    style: dqText(size: 15, color: dqInk),
                                  ),
                                ),
                              )
                            : _buildQuestion(),
          ),
        ],
      ),
    );
  }

  /// Child-friendly state when question generation throws (vs the 準備中 empty
  /// state, which is a DIFFERENT reason — no content authored). Gives a ひらがな
  /// explanation + a RETRY (the failure is usually transient) + a labelled もどる.
  Widget _buildLoadError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'もんだいの よみこみに しっぱいしました。\nもういちど ためしてみてね。',
                textAlign: TextAlign.center,
                style: dqText(size: 15, color: dqInk),
              ),
              const SizedBox(height: 20),
              DqButton(
                label: 'もういちど',
                onTap: () {
                  setState(() {
                    _loadError = false;
                    _loading = true;
                  });
                  _loadQuestions();
                },
              ),
              const SizedBox(height: 10),
              DqButton(
                label: 'もどる / Back',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );

  Widget _buildQuestion() {
    final q = _questions[_currentIdx];

    // Scrollable content + a STICKY bottom 次へ button (rank-2 studio fix): the
    // button used to live inside the scroll view and scrolled out of sight on
    // long answered items — confusing young children ("is it broken?"). Now the
    // content scrolls and the button is pinned at the bottom, always visible.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress indicator
                Row(
                  children: [
                    Text(
                      '問${_currentIdx + 1} / ${_questions.length}',
                      style: dqText(size: 14, w: FontWeight.w700, color: dqInk),
                    ),
                    const Spacer(),
                    // no-scold: don't show "正答: 0" before the first correct (CEO #101/#106)
                    if (_correctCount > 0)
                      Text(
                        '正答: $_correctCount',
                        style: dqText(
                            size: 14,
                            w: FontWeight.w700,
                            color: const Color(0xFF8BE08B)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentIdx + 1) / _questions.length,
                    backgroundColor: dqNight1,
                    valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
                  ),
                ),
                const SizedBox(height: 24),
                // Cloze sentence — the PROMPT plate. Visual-audit #159 iter2 (#178):
                // this used the SAME dqBox fill + gold-hairline border as the four
                // answer cards below, so the question had no focal anchor — the eye
                // read it as "answer zero". DetectiveCaseFrame(highlighted) gives the
                // prompt a heavier double-gold frame + soft glow + 問題 seal so it
                // reads as the question; the answer cards stay on the subordinate
                // dqBox treatment. Single highest-leverage cohesion fix from iter2.
                DetectiveCaseFrame(
                  highlighted: true,
                  title: '問題',
                  padding: const EdgeInsets.all(20),
                  child: clozeRich(
                    q.cloze,
                    dqText(size: 18, w: FontWeight.w500, color: dqInk)
                        .copyWith(height: 1.6),
                  ),
                ),
                const SizedBox(height: 24),
                // Answer choices
                ...List.generate(q.choices.length, (i) {
                  final isSelected = _selectedAnswer == i;
                  final isCorrect = i == q.correctIdx;

                  // Dark dq palette (#67). Answer-state greens/reds tuned for the dark
                  // background; correct = pass-green, wrong = soft red.
                  Color bgColor = dqBox;
                  Color borderColor = dqGoldDeep.withAlpha(120);
                  Color textColor = dqInk;

                  if (_answered) {
                    if (isCorrect) {
                      bgColor = const Color(0xFF14301B);
                      borderColor = const Color(0xFF8BE08B);
                      textColor = const Color(0xFF8BE08B);
                    } else if (isSelected && !isCorrect) {
                      bgColor = const Color(0xFF3A1A1A);
                      borderColor = const Color(0xFFE0853A);
                      textColor = const Color(0xFFE89A82);
                    }
                  } else if (isSelected) {
                    borderColor = dqGold;
                    bgColor = dqNight1;
                  }

                  final semLabel = _answered && isCorrect
                      ? '${i + 1}. ${q.choices[i]}、せいかい'
                      : _answered && isSelected && !isCorrect
                          ? '${i + 1}. ${q.choices[i]}、ふせいかい'
                          : '${i + 1}. ${q.choices[i]}';
                  return Padding(
                    // #68: wider gap so a young child does not mis-tap a
                    // neighbouring option (a mis-tap = a FALSE wrong answer that
                    // would corrupt the FSRS signal + the child's confidence).
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Semantics(
                      button: true,
                      label: semLabel,
                      onTap: _answered ? null : () => _selectAnswer(i),
                      excludeSemantics: true,
                      child: Material(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: ValueKey('vg_choice_$i'),
                          onTap: () => _selectAnswer(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            // #68: taller tap target for developing motor skills
                            // (young kids need > the 44-48 adult floor).
                            constraints: const BoxConstraints(minHeight: 60),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              children: [
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        q.choices[i].replaceAll('_', ' '),
                                        style: TextStyle(
                                          color: textColor,
                                          // #68: larger choice text for child
                                          // readability (was 16).
                                          fontSize: 18,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      // Opt-in scaffold: the Japanese meaning under each
                                      // choice so a pre-reader can reason (this question
                                      // is then excluded from 合格率).
                                      if (_hintShown &&
                                          _glossForChoice(q, i).isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _glossForChoice(q, i),
                                          style: dqText(
                                              size: 12,
                                              w: FontWeight.w600,
                                              color: dqGold.withAlpha(220)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_answered && isCorrect)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF8BE08B), size: 22),
                                if (_answered && isSelected && !isCorrect)
                                  const Icon(Icons.cancel_rounded,
                                      color: Color(0xFFE0853A), size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // Opt-in teach-first scaffold: reveal the choice meanings BEFORE
                // answering so a child who can't yet read the English isn't reduced to
                // guessing. Using it marks the question 学習 (excluded from 合格率).
                if (!_answered && !_hintShown) ...[
                  const SizedBox(height: 4),
                  Semantics(
                    button: true,
                    label: 'いみを みる。ヒントを つかうと、この問題は 合格率に 入りません',
                    excludeSemantics: true,
                    child: InkWell(
                      key: const ValueKey('vg_hint'),
                      onTap: _showHint,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: dqGold.withAlpha(110)),
                        ),
                        // #69: the 合格率 penalty must be ON the tap target, not a
                        // dim note below it — a child used to tap before reading the
                        // consequence. Now the sub-line states it inside the button.
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.translate_rounded,
                                    color: dqGold, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'いみを みる（読（よ）めないとき）',
                                    textAlign: TextAlign.center,
                                    style: dqText(
                                        size: 13,
                                        w: FontWeight.w700,
                                        color: dqGold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '※つかうと この問題（もんだい）は 合格率（ごうかくりつ）に 入（はい）らないよ',
                              textAlign: TextAlign.center,
                              style: dqText(
                                  size: 10.5,
                                  w: FontWeight.w600,
                                  color: const Color(0xFFE0A050)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Explanation + Next button (shown after answering)
                if (_answered) ...[
                  // Struggling-child support: after a cold streak, encourage (never
                  // scold) and point to the hint. Only on a WRONG answer that extends
                  // the streak past the threshold. (CEO 1135 / no-scold spine)
                  if (_selectedAnswer != q.correctIdx &&
                      _consecutiveWrong >= kStruggleThreshold) ...[
                    const PracticeEncouragementBanner(
                        message: kVocabEncourageMsg),
                    const SizedBox(height: 10),
                  ]
                  // Positive mirror: on a correct streak, celebrate the momentum
                  // (same slot — hot/cold streaks are mutually exclusive).
                  else if (_selectedAnswer == q.correctIdx &&
                      _consecutiveCorrect >= kMomentumThreshold) ...[
                    PracticeMomentumBanner(streak: _consecutiveCorrect),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dqBox,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: dqGold.withAlpha(90)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_rounded,
                                color: dqGold, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                // Underscore keys (ice_cream, thank_you) are storage
                                // keys, not spelling — show them spaced for the child.
                                q.word.reading.isNotEmpty
                                    ? '${q.word.word.replaceAll('_', ' ')}（${q.word.reading}）— ${q.word.jpTranslation}'
                                    : '${q.word.word.replaceAll('_', ' ')} — ${q.word.jpTranslation}',
                                style: dqText(
                                    size: 14,
                                    w: FontWeight.w800,
                                    color: dqGold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Hear the correct word — non-reader support (CEO 1132).
                            _HearWordButton(
                              audio: _wordAudio,
                              vocabId: q.word.id,
                              word: q.word.word,
                            ),
                          ],
                        ),
                        // The word IN CONTEXT — for a cloze item this is the real
                        // lesson: see the answer resolved in a natural sentence, not
                        // just its meaning. Converts a wrong answer into learning.
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: RichText(
                            text: TextSpan(
                              style: dqText(
                                      size: 13,
                                      w: FontWeight.w500,
                                      color: dqInk.withAlpha(220))
                                  .copyWith(height: 1.5),
                              children: [
                                const TextSpan(
                                  text: 'れい:  ',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                ..._sentenceSpans(
                                    q.originalSentence, q.word.word),
                              ],
                            ),
                          ),
                        ),
                        // Teach the wrong choices too: each is a real same-grade word
                        // with a different meaning that doesn't fit the blank. Turns one
                        // cloze into a 4-word vocab lesson (#76 follow-through).
                        if (q.choiceGloss.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ほかの言葉 / Other choices',
                                  style: dqText(
                                      size: 11,
                                      w: FontWeight.w700,
                                      color: dqInk.withAlpha(150)),
                                ),
                                const SizedBox(height: 3),
                                ...q.choiceGloss.entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: RichText(
                                      text: TextSpan(
                                        style: dqText(
                                            size: 12,
                                            w: FontWeight.w500,
                                            color: dqInk.withAlpha(190)),
                                        children: [
                                          TextSpan(
                                            text: e.key.replaceAll('_', ' '),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800),
                                          ),
                                          TextSpan(text: ' — ${e.value}'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Sticky bottom — the 次へ button never scrolls out of view (rank-2).
        if (_answered)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: dqNight0,
              border: Border(top: BorderSide(color: dqGoldDeep.withAlpha(60))),
            ),
            child: SafeArea(
              top: false,
              child: DqButton(
                label: _currentIdx < _questions.length - 1 ? '次の問題へ' : '結果を見る',
                onTap: _nextQuestion,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResults() {
    // Verdict on the HONEST measured signal (UNAIDED first-attempts that fed
    // 合格率), not the all-items tally inflated by hinted answers (R2-F7 sweep).
    // A session answered entirely with the hint up is practice-only — no pass.
    final measuredBasis = _unaidedTotal > 0;
    final resultCorrect = measuredBasis ? _unaidedCorrect : _correctCount;
    final resultTotal = measuredBasis ? _unaidedTotal : _questions.length;
    final pct =
        resultTotal == 0 ? 0 : (resultCorrect / resultTotal * 100).round();
    final passed = measuredBasis && pct >= 60;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              passed
                  ? Icons.workspace_premium_rounded
                  : (measuredBasis
                      ? Icons.refresh_rounded
                      : Icons.menu_book_rounded),
              size: 72,
              color: passed ? dqGold : dqInk.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              passed
                  ? '合格（ごうかく）ライン到達（とうたつ）！'
                  : (measuredBasis ? 'もう少（すこ）し！' : 'れんしゅう おつかれさま！'),
              style: dqText(size: 24, w: FontWeight.w900, color: dqGold),
            ),
            const SizedBox(height: 12),
            Text(
              '$resultCorrect / $resultTotal 正解 ($pct%)',
              style: dqText(size: 18, w: FontWeight.w600, color: dqInk),
            ),
            const SizedBox(height: 16),
            PracticeResultStars(correct: resultCorrect, total: resultTotal),
            // Honesty: tell the child/parent that hinted questions were kept out
            // of the 合格率, so the pass-meter reflects unaided skill only.
            if (_assistedCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'ヒントを つかった $_assistedCount問（もん）は、\n合格率（ごうかくりつ）に 入（い）れていません。',
                textAlign: TextAlign.center,
                style: dqText(size: 12, color: dqInk.withAlpha(160)),
              ),
            ],
            // Actionable next-step: the exact words missed this session, with
            // meanings — a "review what you got wrong" study list. They're already
            // in the FSRS review list, so the home will resurface them too.
            if (_missedWords.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
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
                      'ふくしゅうする言葉（ことば） / Review these',
                      style:
                          dqText(size: 13, w: FontWeight.w800, color: dqGold),
                    ),
                    const SizedBox(height: 8),
                    ..._missedWords.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: dqText(
                                      size: 13,
                                      w: FontWeight.w500,
                                      color: dqInk.withAlpha(220)),
                                  children: [
                                    TextSpan(
                                      text: w.word.replaceAll('_', ' '),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(text: ' — ${w.jpTranslation}'),
                                  ],
                                ),
                              ),
                            ),
                            _HearWordButton(
                              audio: _wordAudio,
                              vocabId: w.id,
                              word: w.word,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'この言葉（ことば）は、ふくしゅうリストに 入（い）れたよ。',
                      style: dqText(size: 11, color: dqInk.withAlpha(160)),
                    ),
                  ],
                ),
              ),
            ],
            // Session-end retention hook: the streak/goal just earned, in タロ's
            // voice — felt at the peak, closing the loop with the home spine.
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
}

class _Question {
  final String cloze;
  final List<String> choices;
  final int correctIdx;
  final VocabItem word;
  final String originalSentence;

  /// distractor word → its Japanese meaning, so the post-answer panel can teach
  /// every choice (the answer + 3 real same-grade words). Turns one cloze into a
  /// 4-word vocab lesson and shows the wrong choices are real words that simply
  /// don't fit — not random noise (#76 follow-through). Excludes the answer,
  /// whose meaning is shown prominently at the top of the panel.
  final Map<String, String> choiceGloss;

  /// True when this is a RE-TEST copy re-inserted after the child missed the
  /// word earlier this session (error-corrective retrieval). A retry is a
  /// LEARNING re-exposure only — it is excluded from the 合格率 signal and is
  /// not re-scheduled in the cross-session store (the first miss already did).
  final bool isRetry;

  const _Question({
    required this.cloze,
    required this.choices,
    required this.correctIdx,
    required this.word,
    required this.originalSentence,
    this.choiceGloss = const {},
    this.isRetry = false,
  });

  _Question asRetry() => _Question(
        cloze: cloze,
        choices: choices,
        correctIdx: correctIdx,
        word: word,
        originalSentence: originalSentence,
        choiceGloss: choiceGloss,
        isRetry: true,
      );
}

/// A small 🔊 tap-to-hear button for the answer word, driven by
/// [WordAudioPlayerService] (the same engine as the Battle flashcards). Reflects
/// the loading state for THIS word and otherwise shows a speaker icon. It exists
/// for the non-reader (CEO 1132): a beginner who can't read the word/example can
/// still HEAR the correct answer. Playback no-ops gracefully when audio is
/// unavailable or voice is muted, so the button is always safe to tap.
class _HearWordButton extends StatelessWidget {
  final WordAudioPlayerService audio;
  final String vocabId;
  final String word;

  const _HearWordButton({
    required this.audio,
    required this.vocabId,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final loadingThis = audio.isLoading && audio.currentVocabId == vocabId;
        return Semantics(
          button: true,
          label: '$word を きく',
          child: InkWell(
            onTap: () => audio.playWord(vocabId: vocabId, word: word),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: loadingThis
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: dqGold),
                    )
                  : const Icon(Icons.volume_up_rounded,
                      color: dqGold, size: 22),
            ),
          ),
        );
      },
    );
  }
}

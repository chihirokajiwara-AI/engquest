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
import '../../core/data/vocab_repository.dart';
import '../../core/models/vocab_item.dart';
import 'distractor_generator.dart';
import 'eiken_exam_config.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';
import '../quest/ui/dq_ui.dart';
import '../home/streak_service.dart';

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
  final whole =
      RegExp('\\b${RegExp.escape(w)}\\b', caseSensitive: false)
          .allMatches(sentence)
          .length;
  final anySub =
      RegExp(RegExp.escape(w), caseSensitive: false).allMatches(sentence).length;
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
  final _rng = Random();

  List<_Question> _questions = [];
  int _currentIdx = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  bool _loading = true;
  bool _sessionDone = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
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

      // Build questions, regenerating distractors per item (#76). The stored
      // `distractors` are alphabetical-adjacency artifacts (~92% make the answer
      // the trivial first-letter odd-one-out), so we DISCARD them and synthesise
      // same-grade / same-POS / SAME-first-letter single-word distractors via
      // buildAntiLeakDistractors — killing the orthographic leak by construction.
      // Items whose grade bank can't yield three clean distractors are skipped.
      final wanted = widget.section.questionCount;
      final questions = <_Question>[];
      for (final word in eligible) {
        if (questions.length >= wanted) break;
        final sentence = word.exampleSentences.first;
        final distractors =
            buildAntiLeakDistractors(word, sentence, allWords, _rng);
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
        ));
      }
      _questions = questions;

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('問題の読み込みに失敗: $e')),
        );
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
        style: const TextStyle(
            color: dqGold, fontWeight: FontWeight.w800),
      ),
      TextSpan(text: sentence.substring(match.end)),
    ];
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      if (idx == _questions[_currentIdx].correctIdx) {
        _correctCount++;
      }
    });
  }

  /// Records the completed session result into [SkillAccuracyStore].
  /// vocabGrammar → EikenSkill.reading (Part 1 = Reading大問).
  Future<void> _recordSessionResult() async {
    if (_questions.isEmpty) return;
    recordExamHabit(_questions.length); // streak + daily-goal, not just 合格率
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.reading,
        correct: _correctCount,
        total: _questions.length,
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
    } else {
      setState(() {
        _currentIdx++;
        _selectedAnswer = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        children: [
          // Dark header (matches the home / quest / exam hub — #67 cohesion).
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              children: [
                IconButton(
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
                ? const Center(
                    child: CircularProgressIndicator(color: dqGold))
                : _sessionDone
                    ? _buildResults()
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

  Widget _buildQuestion() {
    final q = _questions[_currentIdx];

    // Scrollable so the question + 4 choices + the explanation never overflow on
    // small phones / landscape (the column was previously fixed-height).
    return SingleChildScrollView(
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
          // Cloze sentence
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dqBox,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dqGoldDeep.withAlpha(120), width: 1.5),
            ),
            child: Text(
              q.cloze,
              style: dqText(size: 18, w: FontWeight.w500, color: dqInk)
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
              padding: const EdgeInsets.only(bottom: 10),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
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
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            q.choices[i],
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
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
          const SizedBox(height: 24),
          // Explanation + Next button (shown after answering)
          if (_answered) ...[
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
                              size: 14, w: FontWeight.w800, color: dqGold),
                        ),
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
                          ..._sentenceSpans(q.originalSentence, q.word.word),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DqButton(
              label: _currentIdx < _questions.length - 1 ? '次の問題へ' : '結果を見る',
              onTap: _nextQuestion,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    final pct = _questions.isEmpty
        ? 0
        : (_correctCount / _questions.length * 100).round();
    final passed = pct >= 60;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed
                  ? Icons.workspace_premium_rounded
                  : Icons.refresh_rounded,
              size: 72,
              color: passed ? dqGold : dqInk.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              passed ? '合格ライン到達！' : 'もう少し！',
              style: dqText(size: 24, w: FontWeight.w900, color: dqGold),
            ),
            const SizedBox(height: 12),
            Text(
              '$_correctCount / ${_questions.length} 正解 ($pct%)',
              style: dqText(size: 18, w: FontWeight.w600, color: dqInk),
            ),
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

  const _Question({
    required this.cloze,
    required this.choices,
    required this.correctIdx,
    required this.word,
    required this.originalSentence,
  });
}

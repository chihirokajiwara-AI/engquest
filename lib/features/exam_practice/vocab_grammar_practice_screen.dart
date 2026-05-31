// lib/features/exam_practice/vocab_grammar_practice_screen.dart
// A-KEN Quest — Eiken Part 1: Vocabulary/Grammar fill-in-the-blank
//
// Generates exam-style questions from the vocabulary database:
// "He ( ) to school every day."
// 1. goes  2. go  3. went  4. going
//
// Uses VocabRepository + distractors field for accurate 4-choice questions.

import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/data/vocab_repository.dart';
import '../../core/models/vocab_item.dart';
import 'eiken_exam_config.dart';

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
    try {
      await _vocabRepo.initialize(eikenGrade: widget.eikenGrade);
      final allWords = _vocabRepo.getAll();

      // Filter to words that have distractors and example sentences
      final eligible = allWords
          .where((w) =>
              w.distractors.length >= 3 && w.exampleSentences.isNotEmpty)
          .toList()
        ..shuffle(_rng);

      final count = widget.section.questionCount.clamp(0, eligible.length);
      _questions = eligible.take(count).map((word) {
        // Create a cloze from the example sentence
        final sentence = word.exampleSentences.first;
        final cloze = _makeCloze(sentence, word.word);

        // Build choices: correct + 3 distractors, shuffled
        final choices = [word.word, ...word.distractors.take(3)];
        final correctIdx = 0; // before shuffle
        choices.shuffle(_rng);
        final newCorrectIdx = choices.indexOf(word.word);

        return _Question(
          cloze: cloze,
          choices: choices,
          correctIdx: newCorrectIdx,
          word: word,
          originalSentence: sentence,
        );
      }).toList();

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

  /// Replace the target word in the sentence with (    ).
  String _makeCloze(String sentence, String word) {
    // Case-insensitive replacement of the word
    final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
    if (pattern.hasMatch(sentence)) {
      return sentence.replaceFirst(pattern, '(        )');
    }
    // If word not found in sentence, prepend cloze
    return '(        ) — $sentence';
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

  void _nextQuestion() {
    if (_currentIdx >= _questions.length - 1) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.section.nameJa,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _sessionDone
                ? _buildResults()
                : _questions.isEmpty
                    ? const Center(child: Text('問題を生成できませんでした'))
                    : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIdx];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          Row(
            children: [
              Text(
                '問${_currentIdx + 1} / ${_questions.length}',
                style: const TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '正答: $_correctCount',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentIdx + 1) / _questions.length,
            backgroundColor: Colors.grey[200],
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
          ),
          const SizedBox(height: 24),
          // Cloze sentence
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              q.cloze,
              style: const TextStyle(
                color: Color(0xFF263238),
                fontSize: 18,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Answer choices
          ...List.generate(q.choices.length, (i) {
            final isSelected = _selectedAnswer == i;
            final isCorrect = i == q.correctIdx;

            Color bgColor = Colors.white;
            Color borderColor = Colors.grey.shade300;
            Color textColor = const Color(0xFF263238);

            if (_answered) {
              if (isCorrect) {
                bgColor = const Color(0xFFE8F5E9);
                borderColor = const Color(0xFF4CAF50);
                textColor = const Color(0xFF2E7D32);
              } else if (isSelected && !isCorrect) {
                bgColor = const Color(0xFFFFEBEE);
                borderColor = const Color(0xFFF44336);
                textColor = const Color(0xFFC62828);
              }
            } else if (isSelected) {
              borderColor = const Color(0xFF4FC3F7);
              bgColor = const Color(0xFFE1F5FE);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
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
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_answered && isCorrect)
                          const Icon(Icons.check_circle,
                              color: Color(0xFF4CAF50), size: 22),
                        if (_answered && isSelected && !isCorrect)
                          const Icon(Icons.cancel,
                              color: Color(0xFFF44336), size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Explanation + Next button (shown after answering)
          if (_answered) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Color(0xFFFF8F00), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${q.word.word} — ${q.word.jpTranslation}',
                      style: const TextStyle(
                        color: Color(0xFF263238),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentIdx < _questions.length - 1 ? '次の問題へ' : '結果を見る',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
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
              passed ? Icons.emoji_events : Icons.refresh,
              size: 72,
              color: passed ? const Color(0xFFFFD700) : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? '合格ライン到達！' : 'もう少し！',
              style: const TextStyle(
                color: Color(0xFF263238),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_correctCount / ${_questions.length} 正解 ($pct%)',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '戻る',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
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

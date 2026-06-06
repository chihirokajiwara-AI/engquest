// lib/features/exam_practice/word_ordering_practice_screen.dart
// A-KEN Quest — Eiken Part 3 (5級/4級): Word Ordering (語句の並びかえ)
//
// Given a Japanese sentence and scrambled English words,
// the user drags/taps words into correct order.
//
// Example:
//   日本語: 「私は毎日学校に歩いて行きます。」
//   Words: [school / I / to / every / walk / day]
//   Answer: I walk to school every day.

import 'dart:math';

import 'package:flutter/material.dart';
import 'eiken_exam_config.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';

/// A word ordering problem.
class _OrderingProblem {
  final String jpSentence;
  final List<String> correctOrder;
  final List<String> scrambled;

  _OrderingProblem({
    required this.jpSentence,
    required this.correctOrder,
  }) : scrambled = List.from(correctOrder)..shuffle(Random());
}

class WordOrderingPracticeScreen extends StatefulWidget {
  const WordOrderingPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
  });

  final String eikenGrade;
  final ExamSection section;

  @override
  State<WordOrderingPracticeScreen> createState() =>
      _WordOrderingPracticeScreenState();
}

class _WordOrderingPracticeScreenState
    extends State<WordOrderingPracticeScreen> {
  late List<_OrderingProblem> _problems;
  int _currentIdx = 0;
  List<String> _selectedWords = [];
  List<String> _remainingWords = [];
  bool _answered = false;
  bool _correct = false;
  int _correctCount = 0;
  bool _sessionDone = false;

  @override
  void initState() {
    super.initState();
    _problems = _generateProblems(widget.eikenGrade);
    _resetProblem();
  }

  void _resetProblem() {
    final p = _problems[_currentIdx];
    _selectedWords = [];
    _remainingWords = List.from(p.scrambled);
    _answered = false;
    _correct = false;
  }

  void _tapWord(String word) {
    if (_answered) return;
    setState(() {
      _remainingWords.remove(word);
      _selectedWords.add(word);
    });
  }

  void _removeWord(int idx) {
    if (_answered) return;
    setState(() {
      final word = _selectedWords.removeAt(idx);
      _remainingWords.add(word);
    });
  }

  void _checkAnswer() {
    final p = _problems[_currentIdx];
    final isCorrect = _selectedWords.join(' ').toLowerCase() ==
        p.correctOrder.join(' ').toLowerCase();
    setState(() {
      _answered = true;
      _correct = isCorrect;
      if (isCorrect) _correctCount++;
    });
  }

  /// Records the completed session result into [SkillAccuracyStore].
  /// wordOrdering → EikenSkill.reading (Part 3 = Reading大問, 5/4級).
  Future<void> _recordSessionResult() async {
    if (_problems.isEmpty) return;
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.reading,
        correct: _correctCount,
        total: _problems.length,
      );
    } catch (_) {
      // Store errors are non-fatal — never interrupt the learner.
    }
  }

  void _nextProblem() {
    if (_currentIdx >= _problems.length - 1) {
      _recordSessionResult(); // fire-and-forget; UI does not wait
      setState(() => _sessionDone = true);
    } else {
      setState(() {
        _currentIdx++;
        _resetProblem();
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
        title: const Text(
          '語句の並びかえ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _sessionDone ? _buildResults() : _buildProblem(),
      ),
    );
  }

  Widget _buildProblem() {
    final p = _problems[_currentIdx];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress
          Row(
            children: [
              Text(
                '問${_currentIdx + 1} / ${_problems.length}',
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
            value: (_currentIdx + 1) / _problems.length,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
          ),
          const SizedBox(height: 24),
          // Japanese sentence
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4FC3F7).withAlpha(60)),
            ),
            child: Column(
              children: [
                const Text(
                  '次の日本語を英語にしなさい：',
                  style: TextStyle(color: Color(0xFF607D8B), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  p.jpSentence,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Answer area (selected words)
          Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _answered
                  ? (_correct
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE))
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _answered
                    ? (_correct
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336))
                    : Colors.grey.shade300,
              ),
            ),
            child: _selectedWords.isEmpty
                ? Center(
                    child: Text(
                      '下の単語をタップして並べましょう',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_selectedWords.length, (i) {
                      return GestureDetector(
                        onTap: () => _removeWord(i),
                        child: _WordChip(
                          word: _selectedWords[i],
                          selected: true,
                          removable: !_answered,
                        ),
                      );
                    }),
                  ),
          ),
          // Show correct answer if wrong
          if (_answered && !_correct) ...[
            const SizedBox(height: 8),
            Text(
              '正解: ${p.correctOrder.join(" ")}',
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          // Word bank (remaining words)
          if (!_answered || _remainingWords.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _remainingWords.map((word) {
                return GestureDetector(
                  onTap: () => _tapWord(word),
                  child: _WordChip(word: word, selected: false),
                );
              }).toList(),
            ),
          const Spacer(),
          // Check / Next button
          if (!_answered && _remainingWords.isEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '答え合わせ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (_answered)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextProblem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentIdx < _problems.length - 1 ? '次の問題へ' : '結果を見る',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final pct = _problems.isEmpty
        ? 0
        : (_correctCount / _problems.length * 100).round();
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
              '$_correctCount / ${_problems.length} 正解 ($pct%)',
              style: TextStyle(color: Colors.grey[700], fontSize: 18),
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

  // ── Static problem bank ─────────────────────────────────────────────────

  static List<_OrderingProblem> _generateProblems(String grade) {
    // Grade-appropriate sentence ordering problems
    final problems = <_OrderingProblem>[];

    if (grade == '5') {
      problems.addAll([
        _OrderingProblem(
          jpSentence: '私は毎日学校へ歩いて行きます。',
          correctOrder: ['I', 'walk', 'to', 'school', 'every', 'day'],
        ),
        _OrderingProblem(
          jpSentence: '彼女は英語を勉強しています。',
          correctOrder: ['She', 'is', 'studying', 'English'],
        ),
        _OrderingProblem(
          jpSentence: 'あなたは何が好きですか？',
          correctOrder: ['What', 'do', 'you', 'like'],
        ),
        _OrderingProblem(
          jpSentence: '私の兄はサッカーが上手です。',
          correctOrder: ['My', 'brother', 'is', 'good', 'at', 'soccer'],
        ),
        _OrderingProblem(
          jpSentence: '今日は天気がいいです。',
          correctOrder: ['It', 'is', 'nice', 'today'],
        ),
      ]);
    } else if (grade == '4') {
      problems.addAll([
        _OrderingProblem(
          jpSentence: '私は昨日図書館で本を読みました。',
          correctOrder: [
            'I',
            'read',
            'a',
            'book',
            'in',
            'the',
            'library',
            'yesterday'
          ],
        ),
        _OrderingProblem(
          jpSentence: '彼は私より背が高いです。',
          correctOrder: ['He', 'is', 'taller', 'than', 'me'],
        ),
        _OrderingProblem(
          jpSentence: 'もし明日雨なら、家にいます。',
          correctOrder: [
            'If',
            'it',
            'rains',
            'tomorrow',
            'I',
            'will',
            'stay',
            'home'
          ],
        ),
        _OrderingProblem(
          jpSentence: 'この映画を見たことがありますか？',
          correctOrder: ['Have', 'you', 'ever', 'seen', 'this', 'movie'],
        ),
        _OrderingProblem(
          jpSentence: '彼女は3年間ピアノを弾いています。',
          correctOrder: [
            'She',
            'has',
            'played',
            'the',
            'piano',
            'for',
            'three',
            'years'
          ],
        ),
      ]);
    } else {
      // Grade 3+ problems
      problems.addAll([
        _OrderingProblem(
          jpSentence: '彼がその仕事を終えるのにどのくらいかかりましたか？',
          correctOrder: [
            'How',
            'long',
            'did',
            'it',
            'take',
            'him',
            'to',
            'finish',
            'the',
            'work'
          ],
        ),
        _OrderingProblem(
          jpSentence: '私はあなたにそのパーティーに来てほしいです。',
          correctOrder: [
            'I',
            'want',
            'you',
            'to',
            'come',
            'to',
            'the',
            'party'
          ],
        ),
        _OrderingProblem(
          jpSentence: 'この本は世界中で読まれています。',
          correctOrder: [
            'This',
            'book',
            'is',
            'read',
            'around',
            'the',
            'world'
          ],
        ),
        _OrderingProblem(
          jpSentence: '彼女が作ったケーキはとてもおいしかった。',
          correctOrder: [
            'The',
            'cake',
            'she',
            'made',
            'was',
            'very',
            'delicious'
          ],
        ),
        _OrderingProblem(
          jpSentence: '電車に乗り遅れないように早く起きました。',
          correctOrder: [
            'I',
            'got',
            'up',
            'early',
            'so',
            'that',
            'I',
            'would',
            'not',
            'miss',
            'the',
            'train'
          ],
        ),
      ]);
    }

    return problems;
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.selected,
    this.removable = false,
  });

  final String word;
  final bool selected;
  final bool removable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE1F5FE) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF4FC3F7) : Colors.grey.shade300,
        ),
        boxShadow: selected
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: TextStyle(
              color: const Color(0xFF263238),
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (removable) ...[
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: Colors.grey[500]),
          ],
        ],
      ),
    );
  }
}

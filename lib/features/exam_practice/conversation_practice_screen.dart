// lib/features/exam_practice/conversation_practice_screen.dart
// A-KEN Quest — Eiken Part 2: Conversation Completion (会話文の文空所補充)
//
// Two speakers have a conversation with one blank line.
// User picks the most natural response from 4 choices.

import 'package:flutter/material.dart';
import 'eiken_exam_config.dart';

class _ConversationProblem {
  final String speakerA;
  final String speakerB; // contains (      ) or is the blank itself
  final String context; // optional scene description
  final List<String> choices;
  final int correctIdx;

  const _ConversationProblem({
    required this.speakerA,
    required this.speakerB,
    this.context = '',
    required this.choices,
    required this.correctIdx,
  });
}

class ConversationPracticeScreen extends StatefulWidget {
  const ConversationPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
  });

  final String eikenGrade;
  final ExamSection section;

  @override
  State<ConversationPracticeScreen> createState() =>
      _ConversationPracticeScreenState();
}

class _ConversationPracticeScreenState
    extends State<ConversationPracticeScreen> {
  late List<_ConversationProblem> _problems;
  int _currentIdx = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  bool _sessionDone = false;

  @override
  void initState() {
    super.initState();
    _problems = _getProblems(widget.eikenGrade);
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      if (idx == _problems[_currentIdx].correctIdx) {
        _correctCount++;
      }
    });
  }

  void _nextProblem() {
    if (_currentIdx >= _problems.length - 1) {
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
        title: const Text(
          '会話文の空所補充',
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
          const SizedBox(height: 20),
          // Context (if any)
          if (p.context.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                p.context,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // Conversation bubbles
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Speaker A
                _ChatBubble(
                  speaker: 'A',
                  text: p.speakerA,
                  isLeft: true,
                ),
                const SizedBox(height: 12),
                // Speaker B (with blank)
                _ChatBubble(
                  speaker: 'B',
                  text: p.speakerB,
                  isLeft: false,
                  isBlank: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Answer choices
          Expanded(
            child: ListView.separated(
              itemCount: p.choices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final isSelected = _selectedAnswer == i;
                final isCorrect = i == p.correctIdx;

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
                }

                return Material(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _selectAnswer(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.choices[i],
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (_answered && isCorrect)
                            const Icon(Icons.check_circle,
                                color: Color(0xFF4CAF50), size: 20),
                          if (_answered && isSelected && !isCorrect)
                            const Icon(Icons.cancel,
                                color: Color(0xFFF44336), size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Next button
          if (_answered)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
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
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('戻る',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Problem banks ─────────────────────────────────────────────────────────

  static List<_ConversationProblem> _getProblems(String grade) {
    if (grade == '5') {
      return const [
        _ConversationProblem(
          context: 'At school',
          speakerA: 'Do you like music?',
          speakerB: '(        )',
          choices: [
            'Yes, I do. I like singing.',
            'No, I am not.',
            'It is Monday.',
            'I go to school.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At home',
          speakerA: 'What time do you get up?',
          speakerB: '(        )',
          choices: [
            'I am fine, thank you.',
            'I get up at seven.',
            'I like mornings.',
            'It is sunny today.',
          ],
          correctIdx: 1,
        ),
        _ConversationProblem(
          context: 'In the park',
          speakerA: 'How many dogs do you have?',
          speakerB: '(        )',
          choices: [
            'I have two dogs.',
            'I like dogs very much.',
            'They are cute.',
            'My dog is white.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At a restaurant',
          speakerA: 'What would you like to drink?',
          speakerB: '(        )',
          choices: [
            'I like hamburgers.',
            'Orange juice, please.',
            'Yes, I would.',
            'Thank you very much.',
          ],
          correctIdx: 1,
        ),
        _ConversationProblem(
          context: 'After school',
          speakerA: "Let's play tennis after school.",
          speakerB: '(        )',
          choices: [
            "Sorry, I can't. I have homework.",
            'Tennis is a sport.',
            'I played tennis last week.',
            'My racket is new.',
          ],
          correctIdx: 0,
        ),
      ];
    } else if (grade == '4') {
      return const [
        _ConversationProblem(
          context: 'At the station',
          speakerA: 'Excuse me. Could you tell me how to get to the museum?',
          speakerB: '(        )',
          choices: [
            'Take the second left and go straight.',
            'The museum is very interesting.',
            'I went there last weekend.',
            'It opens at nine.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'On the phone',
          speakerA: "I'm sorry, but she's not here right now.",
          speakerB: '(        )',
          choices: [
            'OK. Could you ask her to call me back?',
            'I see. She is busy.',
            'That sounds great.',
            "I don't think so.",
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At school',
          speakerA: 'You look tired today. Are you OK?',
          speakerB: '(        )',
          choices: [
            "I stayed up late studying for the test.",
            'I am always happy.',
            'You look nice today too.',
            'The weather is bad.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'Shopping',
          speakerA: 'This shirt is nice, but do you have a smaller size?',
          speakerB: '(        )',
          choices: [
            "Let me check. I'll be right back.",
            'This is the best shirt we have.',
            'The price is 3,000 yen.',
            'We close at eight.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At a friend\'s house',
          speakerA: "Would you like some more cake?",
          speakerB: '(        )',
          choices: [
            "No, thank you. I'm full.",
            'I made this cake yesterday.',
            'Cake is my favorite food.',
            'The cake is on the table.',
          ],
          correctIdx: 0,
        ),
      ];
    } else {
      // Grade 3+
      return const [
        _ConversationProblem(
          context: 'At work',
          speakerA: "I heard you're thinking about changing jobs.",
          speakerB: '(        )',
          choices: [
            "Yes, I've been looking for something more challenging.",
            'I started this job three years ago.',
            'My office is very comfortable.',
            'I work from Monday to Friday.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At a café',
          speakerA: "Do you mind if I sit here?",
          speakerB: '(        )',
          choices: [
            'No, not at all. Please go ahead.',
            'I mind very much.',
            'This café is popular.',
            'I usually sit over there.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At the doctor',
          speakerA: "How long have you had this headache?",
          speakerB: '(        )',
          choices: [
            "It started about three days ago.",
            'I take medicine every day.',
            'Headaches are common.',
            'I went to the hospital last year.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'Planning a trip',
          speakerA: "What do you think about visiting Kyoto this summer?",
          speakerB: '(        )',
          choices: [
            "That sounds wonderful! I've always wanted to go there.",
            'Kyoto is in Japan.',
            'Summer is very hot.',
            'I visited Tokyo last year.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At the library',
          speakerA: "I'm looking for books about environmental issues.",
          speakerB: '(        )',
          choices: [
            "You'll find them in the science section on the second floor.",
            'I like reading books.',
            'The library closes at five.',
            'Environmental issues are important.',
          ],
          correctIdx: 0,
        ),
      ];
    }
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.speaker,
    required this.text,
    required this.isLeft,
    this.isBlank = false,
  });

  final String speaker;
  final String text;
  final bool isLeft;
  final bool isBlank;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (isLeft) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF4FC3F7),
            child: Text(speaker,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isBlank
                  ? const Color(0xFFFFF8E1)
                  : (isLeft
                      ? const Color(0xFFF5F5F5)
                      : const Color(0xFFE3F2FD)),
              borderRadius: BorderRadius.circular(12),
              border: isBlank
                  ? Border.all(
                      color: const Color(0xFFFFB74D),
                      style: BorderStyle.solid,
                    )
                  : null,
            ),
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFF263238),
                fontSize: 15,
                fontStyle: isBlank ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ),
        if (!isLeft) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFF7043),
            child: Text(speaker,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

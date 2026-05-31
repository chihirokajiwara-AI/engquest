// lib/features/exam_practice/reading_practice_screen.dart
// A-KEN Quest — Eiken Part 3/4: Reading Comprehension (長文読解)
//
// Displays a short passage (email, notice, article) then asks
// multiple-choice comprehension questions about it.

import 'package:flutter/material.dart';
import 'eiken_exam_config.dart';

class _ReadingPassage {
  final String title;
  final String type; // "email", "notice", "article"
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

  const _ComprehensionQuestion({
    required this.question,
    required this.choices,
    required this.correctIdx,
  });
}

class ReadingPracticeScreen extends StatefulWidget {
  const ReadingPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
  });

  final String eikenGrade;
  final ExamSection section;

  @override
  State<ReadingPracticeScreen> createState() => _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends State<ReadingPracticeScreen> {
  late List<_ReadingPassage> _passages;
  int _passageIdx = 0;
  int _questionIdx = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  int _totalQuestions = 0;
  bool _sessionDone = false;

  @override
  void initState() {
    super.initState();
    _passages = _getPassages(widget.eikenGrade);
    _totalQuestions =
        _passages.fold(0, (sum, p) => sum + p.questions.length);
  }

  _ComprehensionQuestion get _currentQuestion =>
      _passages[_passageIdx].questions[_questionIdx];

  void _selectAnswer(int idx) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      if (idx == _currentQuestion.correctIdx) _correctCount++;
    });
  }

  void _next() {
    final passage = _passages[_passageIdx];
    if (_questionIdx < passage.questions.length - 1) {
      setState(() {
        _questionIdx++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else if (_passageIdx < _passages.length - 1) {
      setState(() {
        _passageIdx++;
        _questionIdx = 0;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      setState(() => _sessionDone = true);
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
          '長文読解',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _sessionDone ? _buildResults() : _buildReading(),
      ),
    );
  }

  Widget _buildReading() {
    final passage = _passages[_passageIdx];
    final question = _currentQuestion;

    return Column(
      children: [
        // Progress
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  passage.type.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF9C27B0),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '問${_questionIdx + 1}/${passage.questions.length}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Passage
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (passage.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        passage.title,
                        style: const TextStyle(
                          color: Color(0xFF263238),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    passage.content,
                    style: const TextStyle(
                      color: Color(0xFF37474F),
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Question + choices
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  question.question,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: question.choices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final isSelected = _selectedAnswer == i;
                      final isCorrect = i == question.correctIdx;

                      Color bgColor = Colors.white;
                      Color borderColor = Colors.grey.shade300;

                      if (_answered) {
                        if (isCorrect) {
                          bgColor = const Color(0xFFE8F5E9);
                          borderColor = const Color(0xFF4CAF50);
                        } else if (isSelected) {
                          bgColor = const Color(0xFFFFEBEE);
                          borderColor = const Color(0xFFF44336);
                        }
                      }

                      return Material(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _selectAnswer(i),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              '${i + 1}. ${question.choices[i]}',
                              style: const TextStyle(
                                color: Color(0xFF263238),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_answered)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FC3F7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('次へ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final pct = _totalQuestions == 0
        ? 0
        : (_correctCount / _totalQuestions * 100).round();
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
            '$_correctCount / $_totalQuestions 正解 ($pct%)',
            style: TextStyle(color: Colors.grey[700], fontSize: 18),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
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

  // ── Passage banks ─────────────────────────────────────────────────────────

  static List<_ReadingPassage> _getPassages(String grade) {
    if (grade == '5') {
      return const [
        _ReadingPassage(
          title: 'School Notice',
          type: 'notice',
          content:
              'Dear Students,\n\n'
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
            ),
          ],
        ),
        _ReadingPassage(
          title: '',
          type: 'email',
          content:
              'Hi Tom,\n\n'
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
            ),
          ],
        ),
      ];
    } else if (grade == '4') {
      return const [
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
            ),
          ],
        ),
        _ReadingPassage(
          title: 'City Library Newsletter',
          type: 'notice',
          content:
              'Midtown Public Library\nSpring Events 2026\n\n'
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
            ),
          ],
        ),
      ];
    } else {
      // Grade 3+
      return const [
        _ReadingPassage(
          title: 'Working from Home',
          type: 'article',
          content:
              'Since 2020, many companies have allowed their employees to work from home. '
              'A recent survey found that 65% of office workers prefer a mix of home and '
              'office work. They say working from home saves time because they do not need '
              'to commute. However, some workers feel lonely and find it hard to separate '
              'work time from personal time.\n\n'
              'Many companies are now creating "hybrid" work policies. Employees come to '
              'the office two or three days a week for meetings and teamwork, and work from '
              'home on other days. This approach seems to make both employers and employees happy.',
          questions: [
            _ComprehensionQuestion(
              question: 'What percentage of workers prefer hybrid work?',
              choices: ['35%', '50%', '65%', '80%'],
              correctIdx: 2,
            ),
            _ComprehensionQuestion(
              question:
                  'What is one problem of working from home mentioned in the article?',
              choices: [
                'It costs more money',
                'Workers feel lonely',
                'Companies lose customers',
                'Computers break easily',
              ],
              correctIdx: 1,
            ),
            _ComprehensionQuestion(
              question: 'In hybrid work, how often do employees go to the office?',
              choices: [
                'Every day',
                'Once a week',
                'Two or three days a week',
                'Once a month',
              ],
              correctIdx: 2,
            ),
          ],
        ),
        _ReadingPassage(
          title: '',
          type: 'email',
          content:
              'Dear Ms. Johnson,\n\n'
              'I am writing to ask about the volunteer program at Green Park Zoo. '
              'I am a second-year high school student and I am very interested in '
              'working with animals. I read on your website that volunteers help feed '
              'the animals and clean their areas.\n\n'
              'I am available every Saturday from April. Could you please send me '
              'more information about how to apply? I would also like to know if there '
              'is a minimum age requirement.\n\n'
              'Thank you for your time.\n'
              'Sincerely,\nKenta Yamada',
          questions: [
            _ComprehensionQuestion(
              question: 'Why is Kenta writing this email?',
              choices: [
                'To complain about the zoo',
                'To ask about a volunteer program',
                'To buy tickets for the zoo',
                'To report a lost animal',
              ],
              correctIdx: 1,
            ),
            _ComprehensionQuestion(
              question: 'When is Kenta available to volunteer?',
              choices: [
                'Every day after school',
                'Sundays in March',
                'Saturdays from April',
                'During summer vacation only',
              ],
              correctIdx: 2,
            ),
          ],
        ),
      ];
    }
  }
}

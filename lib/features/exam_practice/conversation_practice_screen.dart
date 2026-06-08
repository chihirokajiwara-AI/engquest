// lib/features/exam_practice/conversation_practice_screen.dart
// A-KEN Quest — Eiken Part 2: Conversation Completion (会話文の文空所補充)
//
// Two speakers have a conversation with one blank line.
// User picks the most natural response from 4 choices.

import 'dart:math';

import 'package:flutter/material.dart';
import 'eiken_exam_config.dart';
import 'choice_shuffle.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';
import '../quest/ui/dq_ui.dart';

/// Returns [p] with its choices shuffled and [correctIdx] remapped. The authored
/// data is 92% correctIdx:0, which let a child score ~92% by always tapping
/// choice 1 — inflating 合格率 with no real comprehension. See [shuffledChoiceSet].
_ConversationProblem _shuffleConversationChoices(
    _ConversationProblem p, Random rng) {
  final s = shuffledChoiceSet(p.choices, p.correctIdx, rng);
  return _ConversationProblem(
    speakerA: p.speakerA,
    speakerB: p.speakerB,
    context: p.context,
    choices: s.choices,
    correctIdx: s.correctIdx,
  );
}

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
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _problems = _getProblems(widget.eikenGrade)
        .map((p) => _shuffleConversationChoices(p, _rng))
        .toList();
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

  /// Records the completed session result into [SkillAccuracyStore].
  /// conversationComplete → EikenSkill.reading (Part 2 = Reading大問).
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
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: dqInk),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text('会話文（かいわぶん）の空所補充（くうしょほじゅう）',
                      style:
                          dqText(size: 15, w: FontWeight.w800, color: dqGold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _sessionDone ? _buildResults() : _buildProblem(),
          ),
        ],
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
              value: (_currentIdx + 1) / _problems.length,
              backgroundColor: dqNight1,
              valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
            ),
          ),
          const SizedBox(height: 20),
          // Context (if any)
          if (p.context.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                p.context,
                style: dqText(
                        size: 13,
                        w: FontWeight.w500,
                        color: dqInk.withAlpha(170))
                    .copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          // Conversation bubbles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dqBox,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dqGoldDeep.withAlpha(120), width: 1.5),
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

                return Material(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: ValueKey('conv_choice_$i'),
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
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF8BE08B), size: 20),
                          if (_answered && isSelected && !isCorrect)
                            const Icon(Icons.cancel_rounded,
                                color: Color(0xFFE0853A), size: 20),
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
              child: DqButton(
                label:
                    _currentIdx < _problems.length - 1 ? '次の問題へ' : '結果を見る',
                onTap: _nextProblem,
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
            '$_correctCount / ${_problems.length} 正解 ($pct%)',
            style: dqText(size: 18, w: FontWeight.w600, color: dqInk),
          ),
          const SizedBox(height: 32),
          DqButton(
            label: '戻る',
            onTap: () => Navigator.of(context).pop(),
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
    } else if (grade == '3') {
      // 英検3級 (CEFR A1–A2): everyday school/home/shop exchanges; grammar at
      // 3級 level (present perfect, can, since). One clearly-best response;
      // distractors are same-register but off-function. Content-QA'd 2026-06-08.
      return const [
        _ConversationProblem(
          context: 'At school',
          speakerA: 'Have you finished your homework yet?',
          speakerB: '(        )',
          choices: [
            "Not yet. I'll do it after dinner.",
            'I have a lot of homework today.',
            'Homework is really difficult.',
            'Yes, I like doing homework.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At a store',
          speakerA: 'Excuse me, where can I find notebooks?',
          speakerB: '(        )',
          choices: [
            "They're on the shelf next to the pens.",
            'I need a new notebook.',
            'Notebooks are very cheap here.',
            'This store is really big.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At home',
          speakerA: 'Why are you so tired today?',
          speakerB: '(        )',
          choices: [
            'Because I practiced soccer for three hours.',
            'I am usually very busy.',
            'Tired people need sleep.',
            'Today is a school day.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'On the phone',
          speakerA: 'Can you come to my birthday party on Saturday?',
          speakerB: '(        )',
          choices: [
            'Sure! What time should I come?',
            "It's my birthday too.",
            'I really like parties.',
            'Saturday comes after Friday.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'In the classroom',
          speakerA: "I can't open this door. Is it locked?",
          speakerB: '(        )',
          choices: [
            'Yes. The teacher has the key.',
            'Doors are made of wood.',
            'I opened it this morning.',
            'The classroom is very clean.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At lunchtime',
          speakerA: 'Do you want to eat lunch together?',
          speakerB: '(        )',
          choices: [
            'Sorry, I already ate. Maybe tomorrow.',
            'Lunch is my favorite meal.',
            'The cafeteria is over there.',
            'I usually eat rice for lunch.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'After class',
          speakerA: 'You speak English really well. How did you learn it?',
          speakerB: '(        )',
          choices: [
            "Thank you. I've studied it since I was six.",
            'English is a useful language.',
            'I want to learn French too.',
            'Many people speak English.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'Talking about the weekend',
          speakerA: 'How was your trip to the mountains?',
          speakerB: '(        )',
          choices: [
            'It was great! We saw a beautiful lake.',
            'Mountains are very tall.',
            'I want to go on a trip.',
            'The weekend was two days.',
          ],
          correctIdx: 0,
        ),
      ];
    } else {
      // 英検準2級 (CEFR A2–B1): the only other grade whose 一次 includes 大問2
      // 会話文の文空所補充. Slightly longer social/transactional exchanges; a
      // single best functional response. Content-QA'd 2026-06-08.
      return const [
        _ConversationProblem(
          context: 'At a restaurant',
          speakerA: 'Would you like to order now, or do you need more time?',
          speakerB: '(        )',
          choices: [
            'Could you give us a few more minutes, please?',
            'This restaurant is very popular.',
            'We came here last weekend.',
            'The waiter is really friendly.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At the office',
          speakerA: "I'm having trouble finishing this report by Friday.",
          speakerB: '(        )',
          choices: [
            'Would you like me to give you a hand?',
            'Reports are usually boring.',
            'Friday is the last weekday.',
            'I finished mine yesterday.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'Making plans',
          speakerA: "The concert is sold out. We couldn't get tickets.",
          speakerB: '(        )',
          choices: [
            "That's too bad. Let's do something else instead.",
            'Concerts are usually loud.',
            'I love listening to music.',
            'The tickets were expensive.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At a clothing shop',
          speakerA: 'I bought this jacket here last week, but the zipper is broken.',
          speakerB: '(        )',
          choices: [
            "I'm sorry about that. Would you like a refund or an exchange?",
            'That jacket looks warm.',
            'We sell many jackets here.',
            'Last week was very busy.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'Asking a favor',
          speakerA: 'Could you water my plants while I am away next week?',
          speakerB: '(        )',
          choices: [
            'Of course. Just leave me your key.',
            'Plants need a lot of water.',
            'I water my plants every morning.',
            'Your garden is beautiful.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At the library',
          speakerA: 'Excuse me, am I allowed to borrow these magazines?',
          speakerB: '(        )',
          choices: [
            "I'm afraid magazines can only be read here, not taken out.",
            'Magazines come out every month.',
            'The library has many books.',
            'I enjoy reading magazines.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'Catching up',
          speakerA: 'I heard you moved to a new apartment. How do you like it?',
          speakerB: '(        )',
          choices: [
            "It's much closer to the station, so I'm really happy.",
            'Moving takes a lot of work.',
            'Apartments can be expensive.',
            'I lived there for two years.',
          ],
          correctIdx: 0,
        ),
        _ConversationProblem(
          context: 'At school',
          speakerA: "I'm thinking of joining the volunteer club. What do you think?",
          speakerB: '(        )',
          choices: [
            "That's a great idea. They do a lot of good work.",
            'Clubs meet after school.',
            'There are many clubs here.',
            'I joined the tennis club.',
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
            backgroundColor: const Color(0xFF5DA9E9),
            child: Text(speaker,
                style: const TextStyle(
                    color: Color(0xFF0A0E24),
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isBlank ? dqNight0 : dqNight1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBlank ? dqGold : dqGoldDeep.withAlpha(90),
                width: isBlank ? 1.5 : 1,
              ),
            ),
            child: Text(
              text,
              style: dqText(
                size: 15,
                w: FontWeight.w500,
                color: isBlank ? dqGold : dqInk,
              ).copyWith(
                  fontStyle: isBlank ? FontStyle.italic : FontStyle.normal),
            ),
          ),
        ),
        if (!isLeft) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: dqGold,
            child: Text(speaker,
                style: const TextStyle(
                    color: Color(0xFF2A1C00),
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ],
    );
  }
}

/// Test-only: the choices + correct index per conversation item, so the content
/// invariant (4 distinct non-empty choices, valid correctIdx) can be asserted
/// in CI without exposing the private problem type.
@visibleForTesting
List<({List<String> choices, int correctIdx})> conversationItemsForTest(
        String grade) =>
    _ConversationPracticeScreenState._getProblems(grade)
        .map((p) => (choices: p.choices, correctIdx: p.correctIdx))
        .toList();

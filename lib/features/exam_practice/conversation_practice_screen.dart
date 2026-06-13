// lib/features/exam_practice/conversation_practice_screen.dart
// A-KEN Quest — Eiken Part 2: Conversation Completion (会話文の文空所補充)
//
// Two speakers have a conversation with one blank line.
// User picks the most natural response from 4 choices.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'eiken_exam_config.dart';
import 'practice_encouragement.dart';
import 'choice_shuffle.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';
import '../quest/ui/dq_ui.dart';
import '../../core/sound/practice_feedback.dart';
import 'practice_result_stars.dart';
import '../home/streak_service.dart';

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
    explanation: p.explanation,
  );
}

class _ConversationProblem {
  final String speakerA;
  final String speakerB; // contains (      ) or is the blank itself
  final String context; // optional scene description
  final List<String> choices;
  final int correctIdx;

  /// Post-answer teaching line (大問2 skill = matching the response TYPE to the
  /// question/cue): names what the prompt calls for and why the answer fits, in
  /// child-facing 日本語. Optional — grades not yet authored simply omit it.
  final String? explanation;

  const _ConversationProblem({
    required this.speakerA,
    required this.speakerB,
    this.context = '',
    required this.choices,
    required this.correctIdx,
    this.explanation,
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
  StreakState? _earnedStreak; // shown on results via SessionEndHook
  // Grammar/usage points missed THIS session — surfaced on the results screen as
  // a concrete "review these patterns" study list (the explanation of each missed
  // conversation item), so 大問2 closes with an actionable next-step, not just a
  // score (consistent with the 大問1 review list).
  final List<String> _missedPoints = [];

  // Struggling-child support (CEO 1135 / no-scold spine): a cold streak triggers
  // a gentle 探偵 encouragement (shared PracticeEncouragementBanner). Resets to 0
  // on any correct answer.
  int _consecutiveWrong = 0;
  bool _sessionDone = false;
  final Random _rng = Random();

  // Scrolls the 解説 (rendered below the choices on answer) into view.
  final ScrollController _qScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _problems = _getProblems(widget.eikenGrade)
        .map((p) => _shuffleConversationChoices(p, _rng))
        .toList();
  }

  @override
  void dispose() {
    _qScroll.dispose();
    super.dispose();
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      final correct = idx == _problems[_currentIdx].correctIdx;
      if (correct) {
        _correctCount++;
      } else {
        final exp = _problems[_currentIdx].explanation;
        if (exp != null && exp.isNotEmpty && !_missedPoints.contains(exp)) {
          _missedPoints.add(exp);
        }
      }
      _consecutiveWrong = correct ? 0 : _consecutiveWrong + 1;
    });
    // Game-feel (#51): a haptic tick + chime so answering feels responsive.
    final correct = idx == _problems[_currentIdx].correctIdx;
    PracticeFeedback.answered(correct: correct);
    // a11y (WCAG 4.1.3): speak the verdict so AT users get the feedback the
    // colour/icon swap only shows sighted users.
    SemanticsService.sendAnnouncement(
      View.of(context),
      correct ? 'せいかい' : 'ふせいかい',
      Directionality.of(context),
    );
    if (_problems[_currentIdx].explanation != null) {
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
  /// conversationComplete → EikenSkill.reading (Part 2 = Reading大問).
  Future<void> _recordSessionResult() async {
    if (_problems.isEmpty) return;
    recordExamHabitAndGet(_problems.length).then((st) {
      if (mounted && st != null) setState(() => _earnedStreak = st);
    });
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
    if (_qScroll.hasClients) _qScroll.jumpTo(0);
    if (_currentIdx >= _problems.length - 1) {
      _recordSessionResult(); // fire-and-forget; UI does not wait
      setState(() => _sessionDone = true);
      PracticeFeedback.sessionComplete();
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
      contentMaxWidth:
          600, // #144: centre the column on tablet, full-width on phone
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
            child: _problems.isEmpty
                ? _buildEmpty()
                : (_sessionDone ? _buildResults() : _buildProblem()),
          ),
        ],
      ),
    );
  }

  // Honest 準備中 for grades with no authored 大問2 会話 (準2級プラス/2級/準1級
  // use 長文空所) — never serve another grade's items mislabelled (#7).
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'この級（きゅう）の会話（かいわ）もんだいは\n準備中（じゅんびちゅう）です。',
          textAlign: TextAlign.center,
          style: dqText(size: 16, w: FontWeight.w600, color: dqInk),
        ),
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
          // Answer choices (+ 解説 after answering) — scrollable, button pinned.
          Expanded(
            child: SingleChildScrollView(
              controller: _qScroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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

                      final semLabel = _answered && isCorrect
                          ? '${i + 1}. ${p.choices[i]}、せいかい'
                          : _answered && isSelected && !isCorrect
                              ? '${i + 1}. ${p.choices[i]}、ふせいかい'
                              : '${i + 1}. ${p.choices[i]}';
                      return Semantics(
                        button: true,
                        label: semLabel,
                        onTap: _answered ? null : () => _selectAnswer(i),
                        excludeSemantics: true,
                        child: Material(
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
                        ),
                      );
                    },
                  ),
                  // Struggling-child support: a cold streak shows a gentle,
                  // non-scolding 探偵 encouragement above the 解説. (CEO 1135)
                  if (_answered &&
                      _selectedAnswer != p.correctIdx &&
                      _consecutiveWrong >= kStruggleThreshold)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: PracticeEncouragementBanner(
                          message: kConversationEncourageMsg),
                    ),
                  if (_answered && p.explanation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ConvExplanationPanel(text: p.explanation!),
                    ),
                ],
              ),
            ),
          ),
          // Next button (pinned below the scrollable choices + 解説)
          if (_answered)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DqButton(
                label: _currentIdx < _problems.length - 1 ? '次の問題へ' : '結果を見る',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
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
            '$_correctCount / ${_problems.length} 正解 ($pct%)',
            style: dqText(size: 18, w: FontWeight.w600, color: dqInk),
          ),
          const SizedBox(height: 16),
          PracticeResultStars(correct: _correctCount, total: _problems.length),
          // Actionable next-step: the conversation patterns missed this session,
          // each with its 解説 — a "review these points" study list.
          if (_missedPoints.isNotEmpty) ...[
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
                    'ふくしゅうする ポイント / Review these',
                    style: dqText(size: 13, w: FontWeight.w800, color: dqGold),
                  ),
                  const SizedBox(height: 8),
                  ..._missedPoints.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '・$e',
                        style: dqText(
                                size: 12,
                                w: FontWeight.w500,
                                color: dqInk.withAlpha(220))
                            .copyWith(height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
          explanation: '「Do you like 〜?」は do で始まる質問だから、Yes, I do. / '
              'No, I don\'t. で答えるよ。"Yes, I do. I like singing." が自然。'
              '"No, I am not." は be動詞の答えで、do の質問には合わないんだ。',
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
          explanation: '「What time 〜?」は時間（なんじ？）をたずねる質問。'
              'だから「7時に起きるよ（I get up at seven.）」が正解。'
              '"I am fine, thank you." は How are you? への返事だね。',
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
          explanation: '「How many 〜?」は数（いくつ？）をたずねる質問。'
              '数で答えている「2ひき いるよ（I have two dogs.）」が正解だよ。',
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
          explanation: '「What would you like to drink?」は「何を飲みますか？」と'
              '注文をきく言い方。飲み物で答える「オレンジジュースをください'
              '（Orange juice, please.）」が自然。hamburgers は食べ物だね。',
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
          explanation: '「Let\'s 〜（〜しよう）」のさそいには、いいよ / ごめんできない '
              'で返事をするよ。「ごめん、できないんだ。宿題があるの'
              '（Sorry, I can\'t. I have homework.）」がさそいへの自然な返事。',
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
          explanation:
              '「how to get to 〜?」は行き方（いきかた）をたずねる質問。道あんないをしている「Take the second left and go straight.」が正解だよ。',
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
          explanation:
              '電話（でんわ）で「いま いません」と言われたら、あとでかけてもらうよう おねがいするのが自然。「Could you ask her to call me back?」が正解。',
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
          explanation:
              '「つかれてる？だいじょうぶ？」と聞かれているね。りゆうを答える「I stayed up late studying for the test.」が自然な返事だよ。',
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
          explanation:
              '店（みせ）で「smaller size はある？」と聞かれたら、店員（てんいん）は「Let me check. I\'ll be right back.」と答えるのが自然。',
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
          explanation:
              '「もっとケーキはいかが？」のおすすめには、いる か いらない で答えるよ。「No, thank you. I\'m full.」がていねいな ことわり方。',
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
          explanation:
              '「Have you finished 〜 yet?(もう〜し終えた?)」は現在完了の質問。終わったかどうかを返すのが答えで、「Not yet(まだ)」が自然。ほかは宿題の話だが「終わったか」には答えていない。',
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
          explanation:
              '「Where can I find 〜?(どこにありますか?)」は場所をたずねる質問。場所（ペンの隣）を答える文が正解。ほかはノートの話でも「どこ」に答えていない。',
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
          explanation:
              '「Why 〜?(なぜ?)」には Because 〜（〜だから）で理由を答えるのが基本。「3時間サッカーを練習したから」と理由を述べる文が正解。',
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
          explanation:
              '「Can you come 〜?」はさそい。「Sure!(いいよ)」と受けて「何時に行けばいい?」と話を前に進める返事が自然。さそいには"受ける/断る"で応じる。',
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
          explanation:
              '「Is it locked?(かぎがかかってる?)」は Yes/No でたずねる質問。「Yes」と答え、「かぎは先生が持っている」と情報を足すと会話がかみ合う。',
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
          explanation:
              '「Do you want to 〜 together?」はさそい。断るときは「Sorry(ごめん)＋理由(もう食べた)＋代わりの案(また明日)」の流れが自然で、ていねい。',
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
          explanation:
              '「How did you learn it?(どうやって覚えた?)」への答え。ほめ言葉に「Thank you」と返し、「6歳のころから(since)ずっと勉強している」と"いつから続けているか"を答えるのが正解。',
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
          explanation:
              '「How was 〜?(どうだった?)」は感想をたずねる質問。「It was great!(よかった)」と感想を述べ、「きれいな湖を見た」と具体的な中身を足すのが自然。',
        ),
      ];
    } else if (grade == 'pre2') {
      // 英検準2級 (CEFR A2–B1): 大問2 会話文の文空所補充. Slightly longer
      // social/transactional exchanges; a single best functional response.
      // Content-QA'd 2026-06-08. 大問2 会話 exists ONLY at 5/4/3/準2 — 準2級プラス
      // /2級/準1級 大問2 is 長文空所, so any other grade returns [] (honest 準備中)
      // rather than serving these 準2-level items mislabelled (completeness #7).
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
          explanation:
              '「order now か、more time か」をたずねる選択の質問。まだ決まっていないので「Could you give us a few more minutes(もう少し時間をください)」とていねいにお願いする返事が合う。',
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
          explanation:
              '「締め切りに間に合わず困っている」と打ち明けられた場面。「Would you like me to give you a hand?(手伝おうか?)」と手助けを申し出るのが自然な反応。',
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
          explanation:
              '残念な知らせ（売り切れ）には「That\'s too bad(それは残念)」と共感し、「代わりに別のことをしよう(instead)」と代案を出す流れが自然。',
        ),
        _ConversationProblem(
          context: 'At a clothing shop',
          speakerA:
              'I bought this jacket here last week, but the zipper is broken.',
          speakerB: '(        )',
          choices: [
            "I'm sorry about that. Would you like a refund or an exchange?",
            'That jacket looks warm.',
            'We sell many jackets here.',
            'Last week was very busy.',
          ],
          correctIdx: 0,
          explanation:
              '商品の不具合（ファスナーが壊れた）の苦情には、店員として「I\'m sorry about that(申し訳ありません)」とあやまり、「返金か交換か(refund or exchange)」と解決策を示すのが適切。',
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
          explanation:
              '「Could you 〜?(〜してくれる?)」は依頼。引き受けるなら「Of course(もちろん)」と答え、「かぎを預けておいて」と必要なことを伝える返事が自然。',
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
          explanation:
              '「Am I allowed to 〜?(〜してもいい?)」と許可を求める質問。断るときは「I\'m afraid(残念ながら)」とやわらげ、「ここでしか読めない(持ち出せない)」と決まりを説明するのがていねい。',
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
          explanation:
              '「How do you like it?(どう?気に入ってる?)」は感想をたずねる質問。「駅にずっと近くて(much closer)うれしい」と良い点と気持ちを答えるのが自然。',
        ),
        _ConversationProblem(
          context: 'At school',
          speakerA:
              "I'm thinking of joining the volunteer club. What do you think?",
          speakerB: '(        )',
          choices: [
            "That's a great idea. They do a lot of good work.",
            'Clubs meet after school.',
            'There are many clubs here.',
            'I joined the tennis club.',
          ],
          correctIdx: 0,
          explanation:
              '「What do you think?(どう思う?)」は意見を求める質問。「That\'s a great idea(いい考えだね)」と賛成し、理由（良い活動をしている）を足すのが自然な応答。',
        ),
      ];
    }
    // No authored 大問2 会話 for this grade (準2級プラス/2級/準1級 use 長文空所).
    return const [];
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

/// Post-answer teaching panel (#7): a 💡解説 box explaining why the chosen
/// response fits the conversation (大問2 = match the answer TYPE to the cue).
/// Mirrors the reading/vocab explanation so the suite teaches "why" everywhere.
class _ConvExplanationPanel extends StatelessWidget {
  final String text;
  const _ConvExplanationPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('conv_explanation'),
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

/// Test-only: the choices + correct index + 解説 per conversation item, so the
/// content invariants (4 distinct non-empty choices, valid correctIdx, and a
/// non-empty position-free teach-why 解説) can be asserted in CI without exposing
/// the private problem type.
@visibleForTesting
List<({List<String> choices, int correctIdx, String? explanation})>
    conversationItemsForTest(String grade) =>
        _ConversationPracticeScreenState._getProblems(grade)
            .map((p) => (
                  choices: p.choices,
                  correctIdx: p.correctIdx,
                  explanation: p.explanation,
                ))
            .toList();

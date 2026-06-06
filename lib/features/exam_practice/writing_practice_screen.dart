// lib/features/exam_practice/writing_practice_screen.dart
// A-KEN Quest — 英検 Writing Practice (ライティング練習)
//
// Covers:
//   • Eメール返信 (3級 15-25語 / 準2級 40-50語)
//   • 要約 (準2級プラス/2級 45-55語 / 準1級 60-70語)
//   • 意見論述 (3級〜準1級全級)
//
// Claude AI grading via ClaudeClient (backend proxy). Degrades gracefully to a
// self-check checklist when the API is unavailable — never crashes.
//
// Design: dq_ui — dark atmospheric scene, navy+cream panels, gold serif text.
// No timer pressure (Layton calm), ひらがな-friendly feedback.
//
// R3 compliance: widget smoke test in
//   test/features/exam_practice/writing_screen_smoke_test.dart
// R4 compliance: no Firebase / network in build() or initState(); Claude call
//   fires only from the submit button gesture.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/dialog/claude_client.dart';
import '../quest/ui/dq_ui.dart';
import 'eiken_exam_config.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';

// ── Data models ─────────────────────────────────────────────────────────────

/// The three writing task formats used in 英検 (post-2024 reform).
enum WritingTaskType {
  /// Eメール返信 (3級 15-25語 / 準2級 40-50語)
  email,

  /// 要約 (準2級プラス/2級 45-55語 / 準1級 60-70語)
  summary,

  /// 意見論述 (3級〜全級 2題目)
  opinion,
}

/// One writing prompt with its rubric configuration.
class WritingPrompt {
  final String id;
  final WritingTaskType type;

  /// Task instructions shown to the learner.
  final String instructionJa;
  final String instructionEn;

  /// The email/passage body or discussion topic.
  final String stimulus;

  /// For Eメール: the two underlined questions the reply must answer.
  final List<String> underlinedQuestions;

  /// Word count target range.
  final int wordCountMin;
  final int wordCountMax;

  /// Which 観点 to score (official rubric 観点).
  final List<String> rubricPoints;

  const WritingPrompt({
    required this.id,
    required this.type,
    required this.instructionJa,
    required this.instructionEn,
    required this.stimulus,
    this.underlinedQuestions = const [],
    required this.wordCountMin,
    required this.wordCountMax,
    required this.rubricPoints,
  });
}

// ── Prompt bank ──────────────────────────────────────────────────────────────
// Real 英検 task formats per grade. 2 prompts per grade per task type.
// Content-QA notes: stimuli are in English (task-authentic), instructions are
// bilingual (JP primary for learners, EN for reference). No Japanese mixed into
// English option sets (R1).

const List<WritingPrompt> kWritingPrompts = [
  // ── 3級 Eメール (15-25語) ─────────────────────────────────────────────────
  WritingPrompt(
    id: '3_email_1',
    type: WritingTaskType.email,
    instructionJa:
        '英語で返信メールを書いてください。下線部の2つの質問に必ず答えてください。\n文の数は問いません。15語以上25語以内で書いてください。',
    instructionEn:
        'Write a reply email in English. You must answer BOTH underlined questions.\n'
        'Use 15–25 words.',
    stimulus:
        'Hi! I heard you got a new pet. What kind of animal is it? '
        'What does it like to eat?',
    underlinedQuestions: [
      'What kind of animal is it?',
      'What does it like to eat?',
    ],
    wordCountMin: 15,
    wordCountMax: 25,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
  ),
  WritingPrompt(
    id: '3_email_2',
    type: WritingTaskType.email,
    instructionJa:
        '英語で返信メールを書いてください。下線部の2つの質問に必ず答えてください。\n15語以上25語以内で書いてください。',
    instructionEn:
        'Write a reply email in English. Answer BOTH underlined questions.\n'
        'Use 15–25 words.',
    stimulus:
        'Hi! My family is planning to visit Japan next summer. '
        'What is a good place to visit there? '
        'What food should we try?',
    underlinedQuestions: [
      'What is a good place to visit in Japan?',
      'What food should they try?',
    ],
    wordCountMin: 15,
    wordCountMax: 25,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
  ),

  // ── 準2級 Eメール (40-50語) ──────────────────────────────────────────────
  WritingPrompt(
    id: 'pre2_email_1',
    type: WritingTaskType.email,
    instructionJa:
        '英語で返信メールを書いてください。下線部の2つの質問に必ず答えてください。\n40語以上50語以内で書いてください。',
    instructionEn:
        'Write a reply email in English. Answer BOTH underlined questions.\n'
        'Use 40–50 words.',
    stimulus:
        'Hi! I am thinking of taking up a new hobby. '
        'I heard that you play a musical instrument. '
        'What instrument do you play? '
        'How long did it take you to learn it?',
    underlinedQuestions: [
      'What instrument do you play?',
      'How long did it take you to learn it?',
    ],
    wordCountMin: 40,
    wordCountMax: 50,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
  ),
  WritingPrompt(
    id: 'pre2_email_2',
    type: WritingTaskType.email,
    instructionJa:
        '英語で返信メールを書いてください。下線部の2つの質問に必ず答えてください。\n40語以上50語以内で書いてください。',
    instructionEn:
        'Write a reply email in English. Answer BOTH underlined questions.\n'
        'Use 40–50 words.',
    stimulus:
        'Hi! Our school is having an international food fair next month. '
        'What traditional dish from your country would you recommend? '
        'What are the main ingredients in it?',
    underlinedQuestions: [
      'What traditional dish would you recommend?',
      'What are the main ingredients in it?',
    ],
    wordCountMin: 40,
    wordCountMax: 50,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
  ),

  // ── 2級 要約 (45-55語) ──────────────────────────────────────────────────
  WritingPrompt(
    id: '2_summary_1',
    type: WritingTaskType.summary,
    instructionJa:
        '次の英文を読み、その内容を英語で要約してください。\n45語以上55語以内で書いてください。\n本文の言葉をそのまま書き写すことなく、自分の言葉でまとめてください。',
    instructionEn:
        'Read the following passage and summarize it in English.\n'
        'Use 45–55 words. Do NOT copy sentences verbatim — paraphrase.',
    stimulus:
        'Many cities around the world are facing a serious shortage of affordable housing. '
        'As urban populations grow, property prices and rents rise, making it difficult for '
        'low- and middle-income families to find suitable homes. Some city governments have '
        'introduced policies to address this problem, such as building more public housing or '
        'offering rent subsidies. However, experts argue that these measures alone are '
        'insufficient and that long-term solutions must include increasing the overall '
        'supply of housing through zoning reforms and encouraging private developers to build '
        'more affordable units.',
    underlinedQuestions: [],
    wordCountMin: 45,
    wordCountMax: 55,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
  ),
  WritingPrompt(
    id: '2_summary_2',
    type: WritingTaskType.summary,
    instructionJa:
        '次の英文を読み、その内容を英語で要約してください。\n45語以上55語以内で書いてください。\n本文の言葉をそのまま書き写さずにまとめてください。',
    instructionEn:
        'Summarize the following passage in English (45–55 words). Paraphrase, no verbatim copying.',
    stimulus:
        'The rise of remote work has changed how people think about where they live. '
        'In the past, workers typically lived near their offices in large cities. '
        'Now that many jobs can be done from anywhere with an internet connection, '
        'some employees are choosing to move to smaller towns or rural areas where '
        'housing is cheaper and the quality of life is considered better. '
        'This trend has economic benefits for rural communities but also raises concerns '
        'about the loss of talent and investment in major cities.',
    underlinedQuestions: [],
    wordCountMin: 45,
    wordCountMax: 55,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
  ),

  // ── 準1級 要約 (60-70語) ────────────────────────────────────────────────
  WritingPrompt(
    id: 'pre1_summary_1',
    type: WritingTaskType.summary,
    instructionJa:
        '次の英文を読み、その内容を英語で要約してください。\n60語以上70語以内で書いてください。\n本文の言葉をそのまま書き写すことなく、自分の言葉でまとめてください。',
    instructionEn:
        'Summarize the passage in English (60–70 words). Paraphrase — no verbatim copying.',
    stimulus:
        'Artificial intelligence is increasingly being used in healthcare to assist doctors '
        'with diagnosis and treatment decisions. Machine learning algorithms can analyze '
        'medical images such as X-rays and MRI scans with remarkable accuracy, sometimes '
        'detecting diseases at an earlier stage than human physicians. Proponents argue that '
        'AI will make healthcare more efficient and reduce diagnostic errors. '
        'Critics, however, raise concerns about accountability — when an AI system makes a '
        'mistake, it is unclear who bears responsibility, the hospital, the software developer, '
        'or the doctor who relied on the AI\'s recommendation. '
        'There are also worries about data privacy, as AI systems require access to large '
        'amounts of patient data to function effectively.',
    underlinedQuestions: [],
    wordCountMin: 60,
    wordCountMax: 70,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
  ),
  WritingPrompt(
    id: 'pre1_summary_2',
    type: WritingTaskType.summary,
    instructionJa:
        '次の英文を読み、その内容を英語で要約してください。\n60語以上70語以内で書いてください。',
    instructionEn:
        'Summarize the passage in English (60–70 words). Paraphrase — no verbatim copying.',
    stimulus:
        'The concept of a four-day workweek has gained attention in many countries as a '
        'potential solution to employee burnout and declining productivity. Pilot programs '
        'in Iceland, the United Kingdom, and Japan have shown promising results: participants '
        'reported lower stress levels, improved work-life balance, and maintained or even '
        'increased productivity compared to five-day schedules. '
        'Businesses have also benefited from reduced staff turnover and lower absenteeism. '
        'Nevertheless, implementing a four-day week presents challenges. Not all industries '
        'can easily adapt — healthcare, retail, and emergency services depend on continuous '
        'coverage. Additionally, in competitive global markets, companies worry that working '
        'fewer hours might put them at a disadvantage compared to rivals operating on '
        'traditional schedules.',
    underlinedQuestions: [],
    wordCountMin: 60,
    wordCountMax: 70,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
  ),

  // ── 3級 意見論述 ────────────────────────────────────────────────────────
  WritingPrompt(
    id: '3_opinion_1',
    type: WritingTaskType.opinion,
    instructionJa:
        'あなたは「子どもはスポーツをすべきだ」という意見に賛成ですか。\n理由を2つ以上挙げて、あなたの意見を25語以上35語以内の英語で書いてください。',
    instructionEn:
        'Do you agree that children should play sports?\n'
        'Write your opinion in English (25–35 words) with at least 2 reasons.',
    stimulus: 'TOPIC: Do you agree that children should play sports?',
    underlinedQuestions: [],
    wordCountMin: 25,
    wordCountMax: 35,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
  ),

  // ── 準2級 意見論述 ────────────────────────────────────────────────────────
  WritingPrompt(
    id: 'pre2_opinion_1',
    type: WritingTaskType.opinion,
    instructionJa:
        '以下のTOPICについて、あなたの意見とその理由を英語で書いてください。\n理由を2つ挙げ、50語以上60語以内で書いてください。',
    instructionEn:
        'Write your opinion on the TOPIC below with 2 reasons (50–60 words).',
    stimulus: 'TOPIC: Do you think people should use public transportation more?',
    underlinedQuestions: [],
    wordCountMin: 50,
    wordCountMax: 60,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
  ),

  // ── 2級 意見論述 ──────────────────────────────────────────────────────────
  WritingPrompt(
    id: '2_opinion_1',
    type: WritingTaskType.opinion,
    instructionJa:
        '以下のTOPICについて、あなたの意見とその理由を英語で書いてください。\n理由を2つ挙げ、80語以上100語以内で書いてください。',
    instructionEn:
        'Write your opinion on the TOPIC below with 2 reasons (80–100 words).',
    stimulus:
        'TOPIC: Should companies be required to give employees more paid vacation time?',
    underlinedQuestions: [],
    wordCountMin: 80,
    wordCountMax: 100,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
  ),

  // ── 準1級 意見論述 ────────────────────────────────────────────────────────
  WritingPrompt(
    id: 'pre1_opinion_1',
    type: WritingTaskType.opinion,
    instructionJa:
        '以下のTOPICについて、あなたの意見とその理由を英語で書いてください。\n理由を2つ以上挙げ、120語以上150語以内で書いてください。',
    instructionEn:
        'Write your opinion on the TOPIC below with ≥2 reasons (120–150 words).',
    stimulus:
        'TOPIC: Should governments invest more in renewable energy even if it raises electricity prices?',
    underlinedQuestions: [],
    wordCountMin: 120,
    wordCountMax: 150,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
  ),
];

/// Returns the appropriate prompts for a given Eiken grade + section.
List<WritingPrompt> promptsForGrade(String eikenGrade) {
  switch (eikenGrade) {
    case '3':
      return kWritingPrompts.where((p) => p.id.startsWith('3_')).toList();
    case 'pre2':
      return kWritingPrompts.where((p) => p.id.startsWith('pre2_')).toList();
    case '2':
      return kWritingPrompts.where((p) => p.id.startsWith('2_')).toList();
    case 'pre1':
      return kWritingPrompts.where((p) => p.id.startsWith('pre1_')).toList();
    default:
      // Fallback: opinion prompts for any grade
      return kWritingPrompts
          .where((p) => p.type == WritingTaskType.opinion)
          .toList();
  }
}

// ── Grading result ───────────────────────────────────────────────────────────

/// Scores for each 観点 (0-4 each, per official 英検 rubric).
class WritingRubricResult {
  final Map<String, int> scores; // rubricPoint → 0-4
  final String feedbackJa; // ひらがな-friendly feedback
  final bool apiAvailable;

  const WritingRubricResult({
    required this.scores,
    required this.feedbackJa,
    required this.apiAvailable,
  });

  int get total => scores.values.fold(0, (a, b) => a + b);
  int get maxScore => scores.length * 4;
}

// ── Grading prompt builder ────────────────────────────────────────────────────

String _buildGradingSystemPrompt(WritingPrompt prompt) {
  final rubricLines = prompt.rubricPoints
      .map((p) => '  - $p: 0(unsatisfactory)–1–2–3–4(excellent)')
      .join('\n');

  final taskSpecific = switch (prompt.type) {
    WritingTaskType.email => '''
TASK-SPECIFIC CHECKS (Eメール):
- Did the writer answer BOTH of these underlined questions?
  ${prompt.underlinedQuestions.map((q) => '  • "$q"').join('\n')}
- Does the reply start with a greeting line (e.g. "Dear ...", "Hi ...")?
- Word count: ${prompt.wordCountMin}–${prompt.wordCountMax} words (count the learner's word count honestly).
If either underlined question is NOT answered, 内容/Content = 0.''',
    WritingTaskType.summary => '''
TASK-SPECIFIC CHECKS (要約):
- Does the summary capture the MAIN POINTS of the passage (not minor details)?
- Is there ANY verbatim copying of whole sentences from the passage? If yes, 内容/Content ≤ 1.
- Word count: ${prompt.wordCountMin}–${prompt.wordCountMax} words.
- A good summary paraphrases, uses the learner's own sentence structures.''',
    WritingTaskType.opinion => '''
TASK-SPECIFIC CHECKS (意見論述):
- Does the writer state a clear opinion/position?
- Are there at least 2 reasons/supporting points?
- Is there a logical structure (intro → reasons → conclusion or similar)?
- Word count: ${prompt.wordCountMin}–${prompt.wordCountMax} words.''',
  };

  return '''
You are a strict but kind 英検 writing examiner grading a learner's submission.
The learner is a Japanese child or teenager studying English.

RUBRIC (official 英検 観点, each scored 0–4):
$rubricLines

$taskSpecific

SCORING GUIDELINES:
- 4: Communicates the task completely and clearly; rich vocabulary; minimal errors.
- 3: Mostly communicates the task; adequate vocabulary; a few minor errors.
- 2: Partially communicates; limited vocabulary; noticeable errors.
- 1: Barely communicates; very limited vocabulary; frequent errors.
- 0: Off-task, unintelligible, or violates a key task constraint.

FEEDBACK STYLE:
- Write in Japanese (ひらがなを中心に). Use simple words suitable for middle-school students.
- Be SPECIFIC: name one thing done well, one concrete thing to improve.
- Be KIND but honest: don't give 4s unless genuinely earned.
- Keep feedback under 120 characters.

RESPONSE FORMAT (strict JSON, no markdown, no extra text):
{
  "scores": {
    "内容 / Content": <0-4>,
    ... (repeat for each rubric point)
  },
  "feedbackJa": "<kind, specific, ひらがな-friendly feedback in Japanese>"
}''';
}

// ── Fallback self-check (offline / API error) ────────────────────────────────

Widget _buildOfflineChecklist(WritingPrompt prompt) {
  final checks = switch (prompt.type) {
    WritingTaskType.email => [
        '✅ 下線部の質問1に答えましたか？',
        '✅ 下線部の質問2に答えましたか？',
        '✅ あいさつ文（Dear ... / Hi ...）から始まりましたか？',
        '✅ ${prompt.wordCountMin}〜${prompt.wordCountMax}語の範囲に収まっていますか？',
        '✅ スペルミスを確認しましたか？',
        '✅ 動詞の時制は正しいですか？',
      ],
    WritingTaskType.summary => [
        '✅ 段落の主旨を捉えていますか？',
        '✅ 本文をそのまま写していませんか？',
        '✅ ${prompt.wordCountMin}〜${prompt.wordCountMax}語の範囲に収まっていますか？',
        '✅ 自分の言葉で言い換えができていますか？',
        '✅ 接続表現（however, also, therefore）を使いましたか？',
      ],
    WritingTaskType.opinion => [
        '✅ 自分の意見を明確に述べましたか？',
        '✅ 理由を2つ以上挙げましたか？',
        '✅ 結論の文を書きましたか？',
        '✅ ${prompt.wordCountMin}〜${prompt.wordCountMax}語の範囲に収まっていますか？',
        '✅ 接続語（First, Second, Therefore）を使いましたか？',
      ],
  };

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'セルフチェック / Self-Check',
        style: dqText(size: 14, w: FontWeight.w800, color: dqGold),
      ),
      const SizedBox(height: 8),
      Text(
        'AIが一時的に使えません。下のチェックリストで自分で確認しましょう。',
        style: dqText(size: 12, color: dqInk),
      ),
      const SizedBox(height: 10),
      for (final c in checks) ...[
        Text(c, style: dqText(size: 13, color: dqInk)),
        const SizedBox(height: 5),
      ],
    ],
  );
}

// ── Main screen ───────────────────────────────────────────────────────────────

class WritingPracticeScreen extends StatefulWidget {
  const WritingPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
    this.previewPromptId,
  });

  final String eikenGrade;
  final ExamSection section;

  /// Optional: force a specific prompt by ID (used by preview route).
  final String? previewPromptId;

  @override
  State<WritingPracticeScreen> createState() => _WritingPracticeScreenState();
}

enum _Phase { writing, grading, result }

class _WritingPracticeScreenState extends State<WritingPracticeScreen> {
  late List<WritingPrompt> _prompts;
  late int _promptIdx;
  WritingPrompt get _prompt => _prompts[_promptIdx];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  _Phase _phase = _Phase.writing;
  WritingRubricResult? _result;
  String? _gradingError;

  // Lazy-init to satisfy R4 (no network in build/initState)
  ClaudeClient? _claudeClient;
  ClaudeClient get _claude => _claudeClient ??= ClaudeClient(maxTokens: 400);

  @override
  void initState() {
    super.initState();
    _prompts = promptsForGrade(widget.eikenGrade);
    if (_prompts.isEmpty) {
      // Fallback: use all prompts rather than crashing
      _prompts = kWritingPrompts.toList();
    }
    if (widget.previewPromptId != null) {
      final idx = _prompts.indexWhere((p) => p.id == widget.previewPromptId);
      _promptIdx = idx >= 0 ? idx : 0;
    } else {
      _promptIdx = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  bool get _inRange =>
      _wordCount >= _prompt.wordCountMin && _wordCount <= _prompt.wordCountMax;

  bool get _canSubmit =>
      _wordCount >= _prompt.wordCountMin && _phase == _Phase.writing;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _phase = _Phase.grading;
      _gradingError = null;
    });

    try {
      final systemPrompt = _buildGradingSystemPrompt(_prompt);
      final userMessage =
          'Please grade this submission.\n\n'
          'TASK STIMULUS:\n${_prompt.stimulus}\n\n'
          'LEARNER\'S ANSWER ($_wordCount words):\n${_controller.text.trim()}';

      final response = await _claude.sendMessage(
        systemPrompt: systemPrompt,
        messages: [
          {'role': 'user', 'content': userMessage},
        ],
      );

      final parsed = _parseGradingResponse(response, _prompt);
      if (!mounted) return;
      setState(() {
        _result = parsed;
        _phase = _Phase.result;
      });
    } on ClaudeOfflineException {
      if (!mounted) return;
      setState(() {
        _result = WritingRubricResult(
          scores: {for (final p in _prompt.rubricPoints) p: -1},
          feedbackJa: '',
          apiAvailable: false,
        );
        _phase = _Phase.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gradingError = e.toString();
        _result = WritingRubricResult(
          scores: {for (final p in _prompt.rubricPoints) p: -1},
          feedbackJa: '',
          apiAvailable: false,
        );
        _phase = _Phase.result;
      });
    }
  }

  void _tryAgain() {
    setState(() {
      _phase = _Phase.writing;
      _result = null;
      _gradingError = null;
    });
  }

  /// Records the last AI-graded result into [SkillAccuracyStore].
  /// writing → EikenSkill.writing.
  ///
  /// Scoring: rubric total / maxScore mapped to a binary correct/total pair
  /// (1 correct = total ≥ 50% of maxScore; 0 correct = below 50%).
  /// This gives the CseEstimator a meaningful per-session signal even when
  /// there is only one writing prompt per session.
  ///
  /// Only called when the API was available (apiAvailable == true) so that
  /// ungraded submissions do not pollute the accuracy baseline.
  Future<void> _recordWritingResult() async {
    final result = _result;
    if (result == null || !result.apiAvailable) return;
    if (result.maxScore <= 0) return;
    try {
      final store = await SkillAccuracyStore.getInstance();
      // Binary signal: pass if ≥50% of rubric total earned.
      final correct = result.total >= result.maxScore / 2 ? 1 : 0;
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.writing,
        correct: correct,
        total: 1,
      );
    } catch (_) {
      // Store errors are non-fatal — never interrupt the learner.
    }
  }

  void _nextPrompt() {
    _recordWritingResult(); // fire-and-forget before state change
    if (_promptIdx < _prompts.length - 1) {
      setState(() {
        _promptIdx++;
        _controller.clear();
        _phase = _Phase.writing;
        _result = null;
        _gradingError = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _DqWritingHeader(
              grade: widget.eikenGrade,
              taskType: _prompt.type,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          // Body
          Expanded(
            child: switch (_phase) {
              _Phase.writing => _buildEditor(),
              _Phase.grading => _buildGradingSpinner(),
              _Phase.result => _buildResult(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task type badge
          _TaskTypeBadge(type: _prompt.type),
          const SizedBox(height: 10),

          // Stimulus / instructions
          DqPanel(
            title: '問題 / Task',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_prompt.instructionJa, style: dqText(size: 13, color: dqInk)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dqNight0.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dqGoldDeep, width: 1),
                  ),
                  child: Text(
                    _prompt.stimulus,
                    style: dqText(size: 14, color: dqInk, spacing: 0.3),
                  ),
                ),
                if (_prompt.underlinedQuestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '答えるべき質問 / Questions to answer:',
                    style: dqText(size: 11, color: dqGold, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final q in _prompt.underlinedQuestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('▶ ', style: dqText(size: 12, color: dqGold)),
                          Expanded(
                            child: Text(
                              q,
                              style: dqText(
                                size: 13,
                                color: const Color(0xFFB8F0B8),
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
          const SizedBox(height: 14),

          // Text field
          DqPanel(
            title: 'あなたの答え / Your answer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: dqNight0.withAlpha(230),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _inRange
                          ? const Color(0xFF8BE08B)
                          : dqBorder.withAlpha(180),
                      width: _inRange ? 2 : 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                    maxLines: 8,
                    minLines: 6,
                    style: GoogleFonts.notoSerif(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.7,
                    ),
                    cursorColor: dqGold,
                    decoration: InputDecoration(
                      hintText: 'ここに英語で書いてください…\nWrite your answer here…',
                      hintStyle: dqText(
                        size: 13,
                        color: dqInk.withAlpha(100),
                        spacing: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Word count indicator
                _WordCountBar(
                  count: _wordCount,
                  min: _prompt.wordCountMin,
                  max: _prompt.wordCountMax,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          DqButton(
            label: _canSubmit
                ? 'AIに採点してもらう  /  Get AI feedback'
                : '${_prompt.wordCountMin}語以上書いてから提出 / Write ≥${_prompt.wordCountMin} words',
            onTap: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGradingSpinner() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: dqGold, strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text('採点中…', style: dqText(size: 16, color: dqInk)),
          const SizedBox(height: 6),
          Text('AIが確認しています', style: dqText(size: 13, color: dqGoldDeep)),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!result.apiAvailable) ...[
            DqPanel(child: _buildOfflineChecklist(_prompt)),
          ] else ...[
            // Score summary
            DqPanel(
              title: '採点結果 / Scores',
              child: Column(
                children: [
                  // Total score display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${result.total}',
                            style: GoogleFonts.notoSerifJp(
                              color: dqGold,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '/ ${result.maxScore}点',
                            style: dqText(size: 16, color: dqInk),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Per-観点 scores
                  for (final entry in result.scores.entries)
                    _RubricScoreRow(
                      label: entry.key,
                      score: entry.value,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Feedback
            if (result.feedbackJa.isNotEmpty)
              DqPanel(
                title: 'フィードバック / Feedback',
                child: DqDialogBox(
                  speaker: 'AI先生',
                  child: Text(
                    result.feedbackJa,
                    style: dqText(size: 14, color: dqInk, spacing: 0.3),
                  ),
                ),
              ),
          ],

          if (_gradingError != null) ...[
            const SizedBox(height: 8),
            DqPanel(
              child: Text(
                'AI採点は一時的に使えません。セルフチェックで確認してください。',
                style: dqText(size: 12, color: dqInk),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Your submission (collapsed review)
          DqPanel(
            title: 'あなたの回答 / Your submission',
            child: Text(
              _controller.text.trim(),
              style: dqText(size: 13, color: dqInk.withAlpha(210), spacing: 0.2),
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          DqButton(
            label: 'もう一度書く  /  Try again',
            onTap: _tryAgain,
          ),
          const SizedBox(height: 10),
          DqButton(
            label: _promptIdx < _prompts.length - 1
                ? '次の問題へ  /  Next prompt'
                : '終わる  /  Finish',
            onTap: _nextPrompt,
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Safely parse Claude's JSON grading response. Falls back to offline checklist
/// on any parse error — never throws to the UI (R4 guard).
WritingRubricResult _parseGradingResponse(
    String response, WritingPrompt prompt) {
  try {
    // Claude sometimes wraps JSON in ```json ... ``` — strip it
    final cleaned =
        response.replaceAll(RegExp(r'```json\s*', multiLine: true), '').replaceAll('```', '').trim();
    final Map<String, dynamic> parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    final rawScores = parsed['scores'] as Map<String, dynamic>;
    final scores = <String, int>{};
    for (final rp in prompt.rubricPoints) {
      final val = rawScores[rp];
      scores[rp] = (val is int)
          ? val.clamp(0, 4)
          : (val is num)
              ? val.toInt().clamp(0, 4)
              : 0;
    }
    final feedback = (parsed['feedbackJa'] as String?) ?? '';
    return WritingRubricResult(
      scores: scores,
      feedbackJa: feedback,
      apiAvailable: true,
    );
  } catch (_) {
    // Parse failure → offline mode gracefully
    return WritingRubricResult(
      scores: {for (final p in prompt.rubricPoints) p: -1},
      feedbackJa: '',
      apiAvailable: false,
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DqWritingHeader extends StatelessWidget {
  const _DqWritingHeader({
    required this.grade,
    required this.taskType,
    required this.onBack,
  });

  final String grade;
  final WritingTaskType taskType;
  final VoidCallback onBack;

  String get _gradeLabel {
    switch (grade) {
      case '3':
        return '英検3級';
      case 'pre2':
        return '英検準2級';
      case '2':
        return '英検2級';
      case 'pre1':
        return '英検準1級';
      default:
        return '英検';
    }
  }

  String get _taskLabel {
    switch (taskType) {
      case WritingTaskType.email:
        return 'Eメール返信';
      case WritingTaskType.summary:
        return '要約';
      case WritingTaskType.opinion:
        return '意見論述';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dqBox.withAlpha(220),
              shape: BoxShape.circle,
              border: Border.all(color: dqBorder, width: 1.5),
            ),
            child: const Icon(Icons.arrow_back, color: dqInk, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: dqBilingual(
            '$_gradeLabel $_taskLabel',
            'Writing Practice',
            jpSize: 16,
            stacked: true,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dqNight1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dqGoldDeep, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, color: dqGold, size: 16),
              const SizedBox(width: 4),
              Text('ライティング', style: dqText(size: 11, color: dqGold)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskTypeBadge extends StatelessWidget {
  const _TaskTypeBadge({required this.type});
  final WritingTaskType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      WritingTaskType.email => ('Eメール返信', const Color(0xFF4FC3F7)),
      WritingTaskType.summary => ('要約', const Color(0xFFFFB74D)),
      WritingTaskType.opinion => ('意見論述', const Color(0xFFCE93D8)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(160), width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSerifJp(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WordCountBar extends StatelessWidget {
  const _WordCountBar({
    required this.count,
    required this.min,
    required this.max,
  });
  final int count;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final inRange = count >= min && count <= max;
    final overMax = count > max;
    final progress = max > 0 ? (count / max).clamp(0.0, 1.0) : 0.0;

    Color barColor;
    if (overMax) {
      barColor = const Color(0xFFE89090);
    } else if (inRange) {
      barColor = const Color(0xFF8BE08B);
    } else {
      barColor = dqGoldDeep;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '語数 / Word count: $count語',
              style: dqText(size: 12, color: inRange ? barColor : dqInk),
            ),
            Text(
              '目標: $min〜$max語',
              style: dqText(size: 11, color: dqGoldDeep),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: dqNight1,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
        if (overMax)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '語数が多すぎます。${count - max}語減らしてください。',
              style: dqText(size: 11, color: const Color(0xFFE89090)),
            ),
          ),
      ],
    );
  }
}

class _RubricScoreRow extends StatelessWidget {
  const _RubricScoreRow({required this.label, required this.score});
  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: dqText(size: 13, color: dqInk)),
          ),
          // 4 pips
          for (int i = 1; i <= 4; i++)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: score >= i
                    ? _scoreColor(score)
                    : dqNight1.withAlpha(200),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: score >= i
                      ? _scoreColor(score)
                      : dqBorder.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Text(
                '$i',
                style: GoogleFonts.notoSerifJp(
                  color: score >= i
                      ? const Color(0xFF1A2244)
                      : dqInk.withAlpha(80),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _scoreColor(int s) {
    if (s >= 4) return const Color(0xFF8BE08B);
    if (s >= 3) return dqGold;
    if (s >= 2) return const Color(0xFFFFB74D);
    return const Color(0xFFE89090);
  }
}

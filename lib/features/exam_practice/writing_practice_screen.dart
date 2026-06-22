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
import 'package:engquest/core/ui/app_fonts.dart';

import '../../core/dialog/claude_client.dart';
import '../quest/ui/dq_ui.dart';
import '../home/streak_service.dart';
import '../../core/gamification/xp_service.dart';
import 'exam_session_rewards.dart';
import 'eiken_exam_config.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';
import 'practice_encouragement.dart';
import 'writing_readiness.dart';

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

/// One step of the canonical 英検 writing structure for a task type — a
/// child-facing label + a short English sentence-starter (or JP cue). Shown as a
/// "書き方のヒント" scaffold in the write phase: 構成 (organization) is one of the
/// four scored 観点, and a beginner facing a blank box needs the 型 most. Grounded
/// in the 2024-reform structures (uguis.ai 2026 / edic.jp / eslclub.jp): 意見論述
/// = opinion + 2 reasons + conclusion; 要約 = point-per-paragraph → paraphrase →
/// connect; Eメール準2級 = answer the friend's question + ASK 2 questions about the
/// underlined topic. Generic 型 only — never the answer, teaching shape not content.
class WritingStructureStep {
  final String labelJa;
  final String starter;
  const WritingStructureStep(this.labelJa, this.starter);
}

/// The ordered structure scaffold for [type]. Pure + public so it is unit-tested.
/// [emailAsksQuestions] selects the 準2級 ask-format email 型; without it the email
/// case stays empty (the 3級 answer-format has no single safe shared 型).
List<WritingStructureStep> writingStructureGuide(WritingTaskType type,
    {bool emailAsksQuestions = false}) {
  switch (type) {
    case WritingTaskType.email:
      // 準2級 ask-format: react → ask question 1 → ask question 2 → close. This is
      // a SAFE generic 型 (it names no answer; the learner supplies the actual
      // questions about the underlined topic). The 3級 answer-format has no single
      // safe shared 型 and stays empty (better none than a wrong one). #41 —
      // verified vs gakken / 旺文社 / eiken.or.jp 2024-2026.
      if (emailAsksQuestions) {
        return const [
          WritingStructureStep(
              '① あいさつ＋友だちの質問に答える', '"Thank you for your email. Yes, I ..."'),
          WritingStructureStep(
              '② 下線部について 1つ目の質問', '"I have two questions. First, ...?"'),
          WritingStructureStep('③ 2つ目の質問', '"Also, ...?" (「?」で おわる)'),
          WritingStructureStep('④ むすび', '"I hope to hear from you soon."'),
        ];
      }
      return const [];
    case WritingTaskType.summary:
      return const [
        WritingStructureStep(
            '① 各段落の要点を見つける', '段落（だんらく）ごとに いちばん大事（だいじ）な ところを さがす'),
        WritingStructureStep('② 自分のことばで1文に', 'コピーせず、自分（じぶん）の ことばで まとめる'),
        WritingStructureStep(
            '③ つなぎ言葉でつなぐ', '"First, ... Also, ... Finally, ..."'),
      ];
    case WritingTaskType.opinion:
      return const [
        WritingStructureStep('① 意見をはっきり', '"I think that ..." / "I agree ..."'),
        WritingStructureStep('② 1つ目の理由', '"I have two reasons. First, ..."'),
        WritingStructureStep('③ 2つ目の理由', '"Second, ..."'),
        WritingStructureStep('④ まとめ', '"For these reasons, I think ..."'),
      ];
  }
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

  /// For 3級 Eメール (answer-mode): the two underlined questions the reply must
  /// ANSWER. Empty for 準2級 ask-mode (see [emailAsksQuestions]).
  final List<String> underlinedQuestions;

  /// Eメール format flips by grade under the 2024 reform:
  ///   • 3級  — the friend asks 2 underlined questions; the reply ANSWERS them.
  ///   • 準2級 — the friend's mail has an underlined topic; the reply must ASK 2
  ///            of its OWN questions about that topic (+ respond appropriately).
  /// Treating 準2級 like 3級 ("answer both questions") is score-fatal (verified vs
  /// 旺文社 / gakken / eiken.or.jp 2024-2026). When true, this is the ask format.
  final bool emailAsksQuestions;

  /// For 準2級 ask-mode Eメール: the underlined phrase in the received mail that
  /// the learner must ask TWO questions about. Null for answer-mode.
  final String? underlinedTopic;

  /// Word count target range.
  final int wordCountMin;
  final int wordCountMax;

  /// Which 観点 to score (official rubric 観点).
  final List<String> rubricPoints;

  /// One well-written 見本解答 (model answer) for this prompt — a content exemplar
  /// the learner reveals AFTER attempting, to see what a complete, in-range answer
  /// looks like (compare-to-model, distinct from self-grading). Optional: a prompt
  /// without one simply shows no example card.
  final String? modelAnswer;

  const WritingPrompt({
    required this.id,
    required this.type,
    required this.instructionJa,
    required this.instructionEn,
    required this.stimulus,
    this.underlinedQuestions = const [],
    this.emailAsksQuestions = false,
    this.underlinedTopic,
    required this.wordCountMin,
    required this.wordCountMax,
    required this.rubricPoints,
    this.modelAnswer,
  });

  /// Max points per 観点 (official 英検 scale): Eメール is scored 0–3 each
  /// (3 観点 = 9点満点); 要約 and 意見論述 are 0–4 each (16点満点). Using a uniform
  /// ×4 over-counted email by a third — verified vs 旺文社 / eiken.or.jp 2024-reform.
  int get maxPerCriterion => type == WritingTaskType.email ? 3 : 4;
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
    stimulus: 'Hi! I heard you got a new pet. What kind of animal is it? '
        'What does it like to eat?',
    underlinedQuestions: [
      'What kind of animal is it?',
      'What does it like to eat?',
    ],
    wordCountMin: 15,
    wordCountMax: 25,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
    modelAnswer:
        'Hi! Thank you for your message. My new pet is a small brown rabbit '
        'named Momo. She loves to eat carrots and fresh vegetables.',
  ),
  WritingPrompt(
    id: '3_email_2',
    type: WritingTaskType.email,
    instructionJa: '英語で返信メールを書いてください。下線部の2つの質問に必ず答えてください。\n15語以上25語以内で書いてください。',
    instructionEn:
        'Write a reply email in English. Answer BOTH underlined questions.\n'
        'Use 15–25 words.',
    stimulus: 'Hi! My family is planning to visit Japan next summer. '
        'What is a good place to visit there? '
        'What food should we try?',
    underlinedQuestions: [
      'What is a good place to visit in Japan?',
      'What food should they try?',
    ],
    wordCountMin: 15,
    wordCountMax: 25,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
    modelAnswer:
        'Hi! You should visit Kyoto to see beautiful old temples. You should '
        'also try sushi, because it is fresh and delicious.',
  ),

  // ── 準2級 Eメール (40-50語) ──────────────────────────────────────────────
  // 2024-reform format (verified vs 旺文社 / gakken official sample / eiken.or.jp
  // 2024-2026, content-qa 2026-06-15): the friend's mail closes with a question
  // AND contains an underlined topic (【 】). The reply must BOTH (a) answer the
  // friend's question and (b) ASK 2 questions about the underlined part — NOT
  // merely answer 2 questions (that is the score-fatal 3級 format). (#41)
  WritingPrompt(
    id: 'pre2_email_1',
    type: WritingTaskType.email,
    emailAsksQuestions: true,
    instructionJa: '英語で返信メールを書いてください。\n'
        '友だちの質問に答えてから、【　】の部分について あなたから2つ質問してください。\n'
        '40語以上50語以内で書いてください。',
    instructionEn:
        'Write a reply email in English. First answer the question in the email, '
        'then ask TWO questions about the underlined part (in 【 】).\n'
        'Use 40–50 words.',
    stimulus: 'Hi! How are you? Last weekend my family and I went to '
        '【a new aquarium】 that just opened near my house. We had a great time! '
        'Do you like visiting aquariums?',
    underlinedTopic: 'a new aquarium',
    wordCountMin: 40,
    wordCountMax: 50,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
    modelAnswer:
        'Hi! Thank you for your email. Yes, I really like visiting aquariums '
        'because I love sea animals. I have two questions about the new aquarium. '
        'How big is it? And what kind of fish can you see there? '
        'I hope I can go someday!',
  ),
  WritingPrompt(
    id: 'pre2_email_2',
    type: WritingTaskType.email,
    emailAsksQuestions: true,
    instructionJa: '英語で返信メールを書いてください。\n'
        '友だちの質問に答えてから、【　】の部分について あなたから2つ質問してください。\n'
        '40語以上50語以内で書いてください。',
    instructionEn:
        'Write a reply email in English. First answer the question in the email, '
        'then ask TWO questions about the underlined part (in 【 】).\n'
        'Use 40–50 words.',
    stimulus: 'Hi! I have some exciting news. Next month I am going to start '
        '【a part-time job】 at a bakery in my town. '
        'Do you think part-time jobs are good for students?',
    underlinedTopic: 'a part-time job',
    wordCountMin: 40,
    wordCountMax: 50,
    rubricPoints: ['内容 / Content', '語彙 / Vocabulary', '文法 / Grammar'],
    modelAnswer:
        'Hi! Thank you for your email. That is exciting! Yes, I think part-time '
        'jobs are good for students because they teach responsibility. I have two '
        'questions about your part-time job. How many days will you work? '
        'And what will you do there?',
  ),

  // ── 2級 要約 (45-55語) ──────────────────────────────────────────────────
  WritingPrompt(
    id: '2_summary_1',
    type: WritingTaskType.summary,
    instructionJa:
        '次の英文を読み、その内容を英語で要約してください。\n45語以上55語以内で書いてください。\n本文の言葉をそのまま書き写すことなく、自分の言葉でまとめてください。',
    instructionEn: 'Read the following passage and summarize it in English.\n'
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
    modelAnswer:
        'Many cities lack affordable housing because rising urban populations '
        'push prices and rents higher, hurting low- and middle-income families. '
        'Governments have built public housing and offered rent subsidies, but '
        'experts say these are not enough. Increasing the housing supply through '
        'zoning reform and encouraging developers to build affordable units is '
        'the long-term solution.',
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
    modelAnswer:
        'Remote work has changed where people choose to live. Because many jobs '
        'can now be done online, some workers are leaving expensive cities for '
        'the countryside, where homes cost less and daily life feels calmer. '
        'This benefits rural economies, but it also worries large '
        'cities about losing talent and investment.',
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
    modelAnswer:
        'Artificial intelligence is increasingly helping doctors diagnose and '
        'treat patients. Machine learning can analyze medical images very '
        'accurately, sometimes spotting diseases earlier than human doctors. '
        'Supporters believe AI makes healthcare more efficient and reduces '
        'errors. Critics, however, worry about responsibility when an AI makes a '
        'mistake, and about privacy, since these systems must process huge '
        'volumes of personal patient records.',
  ),
  WritingPrompt(
    id: 'pre1_summary_2',
    type: WritingTaskType.summary,
    instructionJa: '次の英文を読み、その内容を英語で要約してください。\n60語以上70語以内で書いてください。',
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
    modelAnswer:
        'The four-day workweek is being considered as a way to reduce burnout and '
        'raise productivity. Trials in Iceland, the United Kingdom, and Japan '
        'reported lower stress, better work-life balance, and stable or higher '
        'productivity, plus less staff turnover. However, some industries like '
        'healthcare and retail cannot easily adapt, and companies fear that '
        'working fewer hours could leave them behind their competitors.',
  ),

  // ── 3級 意見論述 ────────────────────────────────────────────────────────
  WritingPrompt(
    id: '3_opinion_1',
    type: WritingTaskType.opinion,
    instructionJa:
        'あなたは「子どもはスポーツをすべきだ」という意見に賛成ですか。\n理由を2つ以上挙げて、あなたの意見を25語以上35語以内の英語で書いてください。',
    instructionEn: 'Do you agree that children should play sports?\n'
        'Write your opinion in English (25–35 words) with at least 2 reasons.',
    stimulus: 'TOPIC: Do you agree that children should play sports?',
    underlinedQuestions: [],
    wordCountMin: 25,
    wordCountMax: 35,
    // 英検3級 意見論述 is scored on 4 観点 (内容・構成・語彙・文法), 0–4 each = 16点満点
    // — official 英検 rubric (eiken.or.jp 2017scoring_3w; 旺文社 2024-reform guide).
    // This prompt previously carried the EMAIL rubric (3 観点, no 構成), under-counting
    // a child as "writing-ready" while the real exam grades logical structure
    // (主張→理由→まとめ). All sibling opinion prompts (準2/2/準1) already use 4 観点.
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
    modelAnswer:
        'Yes, I agree that children should play sports. First, sports help them '
        'stay healthy and strong. Second, playing on a team teaches them to work '
        'with others and make new friends.',
  ),

  // ── 準2級 意見論述 ────────────────────────────────────────────────────────
  WritingPrompt(
    id: 'pre2_opinion_1',
    type: WritingTaskType.opinion,
    instructionJa:
        '以下のTOPICについて、あなたの意見とその理由を英語で書いてください。\n理由を2つ挙げ、50語以上60語以内で書いてください。',
    instructionEn:
        'Write your opinion on the TOPIC below with 2 reasons (50–60 words).',
    stimulus:
        'TOPIC: Do you think people should use public transportation more?',
    underlinedQuestions: [],
    wordCountMin: 50,
    wordCountMax: 60,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
    modelAnswer:
        'I think people should use public transportation more. First, buses and '
        'trains carry many passengers at once, so they reduce traffic jams and '
        'air pollution in cities. Second, using public transportation is often '
        'cheaper than driving a car every day, which helps people save money. For '
        'these reasons, I believe more people should choose it.',
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
    modelAnswer:
        'I believe companies should be required to give employees more paid '
        'vacation time. First, rest is essential for health. Employees who take '
        'enough time off are less likely to suffer from stress and burnout, which '
        'can lead to serious illness. Second, well-rested workers are usually '
        'more productive and creative when they return, so longer vacations can '
        'actually benefit the company itself. Some managers worry about losing '
        'working hours, but the long-term gains in employee health and motivation '
        'outweigh this concern. For these reasons, I strongly support requiring '
        'more paid vacation.',
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
    modelAnswer:
        'I firmly believe that governments should invest more in renewable '
        'energy, even if doing so temporarily raises electricity prices. The most '
        'important reason is the urgent need to address climate change. Fossil '
        'fuels release large amounts of carbon dioxide, which contributes to '
        'global warming and extreme weather. By shifting to sources such as solar '
        'and wind power, countries can significantly reduce their emissions and '
        'protect the environment for future generations. Secondly, although '
        'renewable energy may be expensive at first, the long-term economic '
        'benefits are considerable. As technology improves and production '
        'expands, the cost of clean energy continues to fall, and nations become '
        'less dependent on imported fuel, whose prices are often unstable. While '
        'higher electricity bills are a genuine concern for some families, '
        'governments can offer subsidies to help them. For these reasons, '
        'investing in renewable energy is a wise and necessary choice.',
  ),

  // ── 準2級プラス 要約 (45-55語) + 意見論述 (50-60語) ──────────────────────────
  // 2025 new grade. Closes the standalone 準備中 gap: pre2plus had a 要約+意見
  // writing section in config (p2p_w1) but no authored prompts. Word counts per
  // eiken.or.jp (要約45-55 / 意見50-60, verified 2026-06-06 — config p2p_w1).
  WritingPrompt(
    id: 'pre2plus_summary_1',
    type: WritingTaskType.summary,
    instructionJa:
        '次の英文を読み、その内容を英語で要約してください。\n45語以上55語以内で書いてください。\n本文の言葉をそのまま書き写すことなく、自分の言葉でまとめてください。',
    instructionEn: 'Read the following passage and summarize it in English.\n'
        'Use 45–55 words. Do NOT copy sentences verbatim — paraphrase.',
    stimulus:
        'Online reviews have become an important part of how people shop today. '
        'Before buying a product or visiting a restaurant, many customers read '
        'what others have written about it. Positive reviews can quickly make a '
        'business popular, while negative ones can drive customers away. However, '
        'not all reviews are honest. Some companies pay people to write good '
        'reviews about their products, and a few even post fake negative reviews '
        'about their competitors. Because of this, experts advise shoppers to '
        'read many reviews and to be careful about trusting any single one.',
    underlinedQuestions: [],
    wordCountMin: 45,
    wordCountMax: 55,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
    modelAnswer:
        'Online reviews strongly influence shopping, since customers read them '
        'before buying. Good reviews help a business, while bad ones hurt it. '
        'However, some reviews are dishonest, because certain companies pay for '
        'fake positive reviews or post fake negative ones about rivals. Experts '
        'therefore advise reading many reviews and trusting no single one.',
  ),
  // Depth/parity 2026-06-14: a 2nd 準2級プラス 要約 so the 2025 grade matches peers
  // (3 writing prompts: 2 of its main type + 1 opinion).
  WritingPrompt(
    id: 'pre2plus_summary_2',
    type: WritingTaskType.summary,
    instructionJa:
        '次の英文を読み、その内容を英語で要約してください。\n45語以上55語以内で書いてください。\n本文の言葉をそのまま書き写すことなく、自分の言葉でまとめてください。',
    instructionEn: 'Read the following passage and summarize it in English.\n'
        'Use 45–55 words. Do NOT copy sentences verbatim — paraphrase.',
    stimulus:
        'Buying secondhand items has become increasingly popular in recent '
        'years. Instead of always buying new products, many people now look for '
        'used clothes, furniture, and electronics in secondhand shops or on '
        'online marketplaces. There are several reasons for this trend. '
        'Secondhand goods are usually much cheaper than new ones, which helps '
        'people save money. In addition, reusing items is good for the '
        'environment, because it reduces waste and the need to produce new '
        'things. Some shoppers also enjoy the fun of searching for unique or '
        'rare items that are no longer sold in stores. As a result, secondhand '
        'shopping is now seen as a smart and responsible choice.',
    underlinedQuestions: [],
    wordCountMin: 45,
    wordCountMax: 55,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
    modelAnswer:
        'Secondhand shopping has grown popular as people choose used clothing, '
        'furniture, and gadgets over new ones. It is cheaper, so shoppers save '
        'money, and reusing things protects the environment by cutting waste. '
        'Some buyers also enjoy hunting for rare finds. Today, many people '
        'consider buying used a wise and eco-friendly habit.',
  ),
  WritingPrompt(
    id: 'pre2plus_opinion_1',
    type: WritingTaskType.opinion,
    instructionJa:
        '以下のTOPICについて、あなたの意見とその理由を英語で書いてください。\n理由を2つ挙げ、50語以上60語以内で書いてください。',
    instructionEn:
        'Write your opinion on the TOPIC below with 2 reasons (50–60 words).',
    stimulus:
        'TOPIC: Do you think students should be allowed to use smartphones at school?',
    underlinedQuestions: [],
    wordCountMin: 50,
    wordCountMax: 60,
    rubricPoints: [
      '内容 / Content',
      '構成 / Organization',
      '語彙 / Vocabulary',
      '文法 / Grammar',
    ],
    modelAnswer:
        'I think students should be allowed to use smartphones at school. First, '
        'smartphones are useful learning tools, because students can quickly look '
        'up information and use educational apps. Second, in an emergency, '
        'students can contact their families right away. For these reasons, I '
        'believe smartphones should be allowed, with clear rules.',
  ),
];

/// Returns the appropriate prompts for a given Eiken grade + section.
/// Writing prompts for a grade — ONLY that grade's own prompts (id prefix
/// `"{grade}_"`). 5級/4級 have NO writing section in 英検 → return empty.
/// 準2級プラス returns its own prompts (empty until authored). Prefixes don't
/// collide: "pre2_" does not match "pre2plus_" (char 5 differs). The previous
/// default returned cross-grade opinion essays — wrong for 5/4級 (no writing)
/// and a grade-mix for pre2plus.
List<WritingPrompt> promptsForGrade(String eikenGrade) {
  return kWritingPrompts
      .where((p) => p.id.startsWith('${eikenGrade}_'))
      .toList();
}

// ── Grading result ───────────────────────────────────────────────────────────

/// Scores for each 観点 (0–[maxPerCriterion] each, per official 英検 rubric:
/// 0–4 for 要約/意見論述, 0–3 for Eメール).
class WritingRubricResult {
  final Map<String, int> scores; // rubricPoint → 0–maxPerCriterion
  final String feedbackJa; // ひらがな-friendly feedback
  final bool apiAvailable;

  /// Points per 観点 — 4 for 要約/意見論述 (16点満点), 3 for Eメール (9点満点).
  final int maxPerCriterion;

  const WritingRubricResult({
    required this.scores,
    required this.feedbackJa,
    required this.apiAvailable,
    this.maxPerCriterion = 4,
  });

  int get total => scores.values.fold(0, (a, b) => a + b);
  int get maxScore => scores.length * maxPerCriterion;
}

/// The (correct, total) signal a graded writing [result] contributes to the
/// 合格率 — or null when it must NOT be recorded.
///
/// Writing is recorded ONLY when the AI grader was available: an offline /
/// ungraded submission must not pollute the baseline with a 0 (that is the #36
/// "未測定, not 0" honesty). A graded result is mapped to a binary pass/fail at
/// 50% of the rubric maximum (one prompt per session → one signal). Pulled out
/// as a pure function so the record-path integrity (#37) is pinned without a
/// live AI grader; [_WritingPracticeScreenState._recordWritingResult] uses it.
({int correct, int total})? writingAccuracySignal(WritingRubricResult result) {
  if (!result.apiAvailable) return null;
  if (result.maxScore <= 0) return null;
  return (correct: result.total >= result.maxScore / 2 ? 1 : 0, total: 1);
}

// ── Grading prompt builder ────────────────────────────────────────────────────

String _buildGradingSystemPrompt(WritingPrompt prompt) {
  // Official 英検 scale per task: Eメール 0–3 (9点満点), 要約/意見論述 0–4 (16点満点).
  final maxPer = prompt.maxPerCriterion;
  final ladder = [
    for (var i = 0; i <= maxPer; i++)
      i == 0
          ? '0(unsatisfactory)'
          : i == maxPer
              ? '$i(excellent)'
              : '$i'
  ].join('–');
  final rubricLines =
      prompt.rubricPoints.map((p) => '  - $p: $ladder').join('\n');

  // Band descriptors must match the scale's top mark (3 for Eメール, 4 otherwise).
  final guidelines = maxPer == 3
      ? '''- 3: Communicates the task completely and clearly; appropriate vocabulary; minimal errors.
- 2: Mostly communicates the task; adequate vocabulary; some errors.
- 1: Barely communicates; very limited vocabulary; frequent errors.
- 0: Off-task, unintelligible, or violates a key task constraint.'''
      : '''- 4: Communicates the task completely and clearly; rich vocabulary; minimal errors.
- 3: Mostly communicates the task; adequate vocabulary; a few minor errors.
- 2: Partially communicates; limited vocabulary; noticeable errors.
- 1: Barely communicates; very limited vocabulary; frequent errors.
- 0: Off-task, unintelligible, or violates a key task constraint.''';

  final taskSpecific = switch (prompt.type) {
    WritingTaskType.email when prompt.emailAsksQuestions => '''
TASK-SPECIFIC CHECKS (Eメール — 準2級 answer+ask format):
- Did the writer ANSWER the question asked in the friend's email (the closing question)?
- Did the writer ASK at least TWO questions about the underlined topic "${prompt.underlinedTopic}"? Each question must end with "?".
- Do the questions genuinely concern that underlined topic (not random questions)?
- Word count: ${prompt.wordCountMin}–${prompt.wordCountMax} words (count the learner's word count honestly).
If the friend's question is NOT answered, OR fewer than two questions about the underlined topic are asked, 内容/Content = 0.''',
    WritingTaskType.email => '''
TASK-SPECIFIC CHECKS (Eメール — 3級 answer format):
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

RUBRIC (official 英検 観点, each scored 0–$maxPer):
$rubricLines

$taskSpecific

SCORING GUIDELINES:
$guidelines

FEEDBACK STYLE:
- Write in Japanese (ひらがなを中心に). Use simple words suitable for middle-school students.
- Be SPECIFIC: name one thing done well, one concrete thing to improve.
- Be KIND but honest: don't give the top mark ($maxPer) unless genuinely earned.
- Keep feedback under 120 characters.

RESPONSE FORMAT (strict JSON, no markdown, no extra text):
{
  "scores": {
    "内容 / Content": <0-$maxPer>,
    ... (repeat for each rubric point)
  },
  "feedbackJa": "<kind, specific, ひらがな-friendly feedback in Japanese>"
}''';
}

// ── Offline readiness report (live, honest — #100) ───────────────────────────
//
// Replaces the old static self-check. When AI grading is unavailable we run the
// offline [evaluateWritingReadiness] engine over the learner's actual text and
// show concrete, actionable results. CRITICAL honesty rule (see
// writing_readiness.dart): this NEVER shows a quality score — only objective
// HARD facts (語数 / 英語として成立) and advisory 目安 HINTs. The 語彙/文法 quality
// stays honestly 未測定 until AI grading is connected.

const Color _wrOk = Color(0xFF8BE08B); // satisfied
const Color _wrWarn = Color(0xFFE0A84A); // advisory — double-check
const Color _wrFail = Color(0xFFE0853A); // must fix (exam-fatal)

Widget _buildReadinessReport(WritingPrompt prompt, String text) {
  final r = evaluateWritingReadiness(prompt, text);

  ({IconData icon, Color color}) glyph(WritingCheckStatus s) => switch (s) {
        WritingCheckStatus.ok => (icon: Icons.check_circle, color: _wrOk),
        WritingCheckStatus.warn => (icon: Icons.error_outline, color: _wrWarn),
        WritingCheckStatus.fail => (icon: Icons.cancel, color: _wrFail),
      };

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DqPanel(
        title: '提出要件チェック（オフライン）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Honesty banner — never claim to grade quality offline.
            Text(
              'AIによる 採点（語彙・文法などの 質）は 接続後に 行います。\n'
              'ここでは 自動で わかる 形式と 要素だけを 確認します。',
              style: dqText(size: 12, color: dqGoldDeep, spacing: 0.2),
            ),
            const SizedBox(height: 12),
            Text(r.headlineJa,
                style: dqText(size: 15, w: FontWeight.w800, color: dqInk)),
            const SizedBox(height: 6),
            Text('必須 = 本番で 必ず 必要 ／ 目安 = AIが 確かめる 前の めやす',
                style: dqText(size: 11, color: dqGoldDeep)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      DqPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in r.checks) ...[
              Semantics(
                label: '${c.kind == WritingCheckKind.hard ? '必須' : '目安'} '
                    '${c.labelJa}: '
                    '${c.status == WritingCheckStatus.ok ? 'OK' : c.status == WritingCheckStatus.warn ? '要確認' : '要修正'}',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(glyph(c.status).icon,
                        color: glyph(c.status).color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: c.kind == WritingCheckKind.hard
                                      ? _wrFail.withAlpha(40)
                                      : dqGoldDeep.withAlpha(40),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  c.kind == WritingCheckKind.hard ? '必須' : '目安',
                                  style: dqText(
                                      size: 10,
                                      w: FontWeight.w700,
                                      color: c.kind == WritingCheckKind.hard
                                          ? _wrFail
                                          : dqGoldDeep),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(c.labelJa,
                                    style: dqText(
                                        size: 13,
                                        w: FontWeight.w700,
                                        color: dqInk)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(c.detailJa,
                              style: dqText(
                                  size: 12,
                                  color: dqInk.withAlpha(210),
                                  spacing: 0.2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ],
  );
}

// ── 見直しチェック / self-check (#100 follow-through) ─────────────────────────
//
// Shown ONLY when the offline readiness engine reports formComplete. Decided by
// a 3-lens expert panel (assessment-validity + pedagogy + product, 2026 evidence):
//   • Framed as a REVISION checklist, never a self-grade. Self-graded *quality*
//     is invalid for children (self-assessment r≈.30 for writing, Dunning-Kruger
//     inflates the weakest writers most) → we use only OBJECTIVE binary facts the
//     learner can verify against their own visible text.
//   • It feeds the 合格率 NOTHING — no SkillAccuracyStore, no CseEstimator. Writing
//     stays honestly 未測定 until AI grading. Inflation is impossible by
//     construction (this widget has no store dependency at all).
//   • The closure NAMES what was NOT checked (語彙・文法 quality → AI先生) to
//     inoculate against over-confidence — the pedagogy panel's key safeguard.
// Public so the honesty invariant (closure copy + no gauge feed) is unit-tested.
class WritingSelfCheckCard extends StatefulWidget {
  const WritingSelfCheckCard({
    super.key,
    required this.taskType,
    this.emailAsksQuestions = false,
  });

  final WritingTaskType taskType;

  /// 準2級 ask-format email → the self-check asks about ASKING 2 questions, not
  /// answering them (the #41 grade-aware fix). Ignored for non-email types.
  final bool emailAsksQuestions;

  @override
  State<WritingSelfCheckCard> createState() => _WritingSelfCheckCardState();
}

class _WritingSelfCheckCardState extends State<WritingSelfCheckCard> {
  late final List<String> _items =
      _itemsFor(widget.taskType, widget.emailAsksQuestions);
  final Set<int> _checked = {};

  static List<String> _itemsFor(WritingTaskType t, bool emailAsksQuestions) =>
      switch (t) {
        // Objective, countable, verifiable-against-own-text facts only — never a
        // quality judgement ("理由はよかった？" is forbidden: it invites inflation).
        WritingTaskType.email when emailAsksQuestions => const [
            '友だちの しつもんに 答えた？',
            '下線部について、しつもんを 2つ 書いた？',
            'しつもんは ぜんぶ「?」で おわっている？',
          ],
        WritingTaskType.email => const [
            '下線の しつもんに、2つとも 答えた？',
            '自分の 言葉で 書いた？',
            '大文字で 始めて、ピリオド(.)を つけた？',
          ],
        WritingTaskType.opinion => const [
            '自分の 意見を はっきり 書いた？',
            '理由を 2つ 書いた？',
            'さいごに まとめ(結論)を 書いた？',
          ],
        WritingTaskType.summary => const [
            '本文の 大事なところを 入れた？',
            '本文を 丸写し していない？',
            '自分の 言葉で まとめた？',
          ],
      };

  @override
  Widget build(BuildContext context) {
    final allDone = _checked.length == _items.length;
    return DqPanel(
      title: '見直しチェック / Self-check',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '出す前に 自分で たしかめよう。できていない ものは 直してから 出そう。',
            style: dqText(size: 12, color: dqGoldDeep),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _items.length; i++) _checkRow(i, _items[i]),
          const SizedBox(height: 8),
          if (allDone)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _wrOk.withAlpha(28),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _wrOk.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '提出準備 OK！（暫定・自己チェック）',
                    style: dqText(size: 14, w: FontWeight.w800, color: _wrOk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '形(かたち)は ととのいました。語彙・文法などの 中身の 質は、'
                    'AI先生が 採点します（接続後）。',
                    style: dqText(size: 12, color: dqInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '※これは 自己チェックです。合格率には まだ 反映しません。',
                    style: dqText(size: 11, color: dqGoldDeep),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _checkRow(int i, String label) {
    final on = _checked.contains(i);
    return Semantics(
      checked: on,
      button: true,
      label: label,
      child: InkWell(
        onTap: () => setState(() {
          if (on) {
            _checked.remove(i);
          } else {
            _checked.add(i);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                  color: on ? _wrOk : dqGoldDeep, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: dqText(size: 13, color: dqInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 見本解答 / model answer (reveal-on-demand content exemplar) ────────────────
//
// Shown on the result screen AFTER the learner has written. Pedagogy: attempt
// first, then compare to ONE good example (compare-to-model — a validated aid,
// distinct from the self-grading we deliberately avoid). Gated behind a reveal
// tap so it never spoils the attempt, and framed honestly as one example (same
// meaning, different wording is also correct). Feeds the 合格率 nothing.
class _ModelAnswerCard extends StatefulWidget {
  const _ModelAnswerCard({required this.modelAnswer});

  final String modelAnswer;

  @override
  State<_ModelAnswerCard> createState() => _ModelAnswerCardState();
}

class _ModelAnswerCardState extends State<_ModelAnswerCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return DqPanel(
      title: '見本解答 / Example answer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'まず じぶんで 書いてから、この 見本と くらべてみよう。これは 一つの 例（れい）。'
            'おなじ いみなら、ちがう 書き方でも せいかいです。',
            style: dqText(size: 12, color: dqGoldDeep),
          ),
          const SizedBox(height: 10),
          if (!_revealed)
            Align(
              alignment: Alignment.centerLeft,
              child: DqButton(
                label: '見本（みほん）を 見る',
                onTap: () => setState(() => _revealed = true),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dqGold.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dqGold.withAlpha(90)),
              ),
              child: Text(
                widget.modelAnswer,
                style: dqText(size: 14, color: dqInk),
              ),
            ),
        ],
      ),
    );
  }
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

  // Word-count as a ValueNotifier so each keystroke rebuilds ONLY the
  // _WordCountBar + submit button (via ValueListenableBuilder), not the whole
  // editor tree (passage, structure steps, text field). Matches the proven
  // timer pattern in mock_exam_screen.dart (R2-F11 class perf fix).
  final _wordCountNotifier = ValueNotifier<int>(0);

  _Phase _phase = _Phase.writing;
  WritingRubricResult? _result;
  String? _gradingError;
  // The streak/daily-goal earned by submitting this essay — shown at the result
  // peak via SessionEndHook, the same daily-return reinforcement every other exam
  // section gives at session end. Recorded even when AI grading is offline (#151).
  StreakState? _earnedStreak;

  /// Whether the 書き方のヒント structure scaffold is expanded. Default open so a
  /// beginner sees the 型 before writing; collapsible to free space once learned.
  bool _structureOpen = true;

  /// True after「もう一度（なおして）」on the result screen: the previous draft is
  /// intentionally kept in the editor so the child REVISES it. Without a cue the
  /// child would re-submit byte-identical text and be re-graded the same (R2-F2).
  /// Cleared when moving to a fresh prompt or submitting. Carries a recap of the
  /// previous score so the revision has a concrete target.
  bool _revisingDraft = false;
  String? _priorScoreRecap;

  // Lazy-init to satisfy R4 (no network in build/initState)
  ClaudeClient? _claudeClient;
  ClaudeClient get _claude => _claudeClient ??= ClaudeClient(maxTokens: 400);

  @override
  void initState() {
    super.initState();
    _prompts = promptsForGrade(widget.eikenGrade);
    // No cross-grade fallback: an empty list means this grade has no writing
    // section (5級/4級) or no prompts authored yet (準2級プラス). build() shows an
    // honest empty-state instead of loading another grade's essays.
    if (widget.previewPromptId != null && _prompts.isNotEmpty) {
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
    _wordCountNotifier.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  bool get _canSubmit =>
      _wordCount >= _prompt.wordCountMin && _phase == _Phase.writing;

  /// ✍️ 書き方のヒント — the canonical 英検 structure (型) for this task type. 構成
  /// is a scored 観点, and a beginner facing a blank box needs the 型 most.
  /// Collapsible (default open); generic structure only, never the answer.
  Widget _buildStructureGuide() {
    final steps = writingStructureGuide(_prompt.type,
        emailAsksQuestions: _prompt.emailAsksQuestions);
    // No scaffold for this task type (e.g. 3級 email — see writingStructureGuide):
    // render nothing rather than an empty panel.
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DqPanel(
          title: '✍️ 書き方（かきかた）のヒント / How to structure',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: _structureOpen ? 'ヒントを とじる' : 'ヒントを ひらく',
                child: GestureDetector(
                  onTap: () => setState(() => _structureOpen = !_structureOpen),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'この型（かた）で 書（か）くと まとまるよ',
                          style: dqText(size: 12, color: dqInk.withAlpha(180)),
                        ),
                      ),
                      Icon(
                          _structureOpen
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: dqGold,
                          size: 22),
                    ],
                  ),
                ),
              ),
              if (_structureOpen) ...[
                const SizedBox(height: 8),
                for (final s in steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.labelJa,
                            style: dqText(
                                size: 13, w: FontWeight.w800, color: dqGold)),
                        const SizedBox(height: 2),
                        Text(s.starter,
                            style: dqText(size: 12.5, color: dqInk)
                                .copyWith(height: 1.4)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    // Writing a full essay is a study session — count it toward the home streak
    // + daily-goal even when offline (AI grading may be unavailable), so writing
    // practice is never invisible to the engagement spine. Capture the resulting
    // StreakState so the result view celebrates it at the completion peak (#151).
    recordExamHabitAndGet(1).then((st) {
      if (mounted && st != null) setState(() => _earnedStreak = st);
    });
    recordExamXp(1);
    recordExamAchievements();
    setState(() {
      _phase = _Phase.grading;
      _gradingError = null;
    });

    try {
      final systemPrompt = _buildGradingSystemPrompt(_prompt);
      final userMessage = 'Please grade this submission.\n\n'
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
          maxPerCriterion: _prompt.maxPerCriterion,
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
          maxPerCriterion: _prompt.maxPerCriterion,
        );
        _phase = _Phase.result;
      });
    }
  }

  void _tryAgain() {
    // Keep the draft so the child revises it (do NOT clear _controller), but
    // flag revise-mode so the editor shows a "edit before resubmitting" cue with
    // the previous score as a target — otherwise an unchanged resubmit re-grades
    // identically and reads as a no-op (R2-F2).
    final prev = _result;
    setState(() {
      if (prev != null && prev.apiAvailable && prev.maxScore > 0) {
        _priorScoreRecap = 'まえは ${prev.total} / ${prev.maxScore}点（てん）だったよ';
      } else {
        _priorScoreRecap = null;
      }
      _revisingDraft = true;
      _structureOpen = true; // re-surface the 型 to support the revision
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
    if (result == null) return;
    final signal = writingAccuracySignal(result);
    if (signal == null) return; // ungraded / no API → 未測定, never a 0
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.writing,
        correct: signal.correct,
        total: signal.total,
      );
    } catch (_) {
      // Store errors are non-fatal — never interrupt the learner.
    }
  }

  void _nextPrompt() {
    _recordWritingResult(); // fire-and-forget before state change
    if (_promptIdx < _prompts.length - 1) {
      _wordCountNotifier.value = 0; // reset before setState (notifier-only)
      setState(() {
        _promptIdx++;
        _controller.clear();
        _revisingDraft = false;
        _priorScoreRecap = null;
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
    // Honest empty-state: 5級/4級 have no writing section; 準2級プラス has no
    // prompts authored yet. Never index _prompt when there are none.
    if (_prompts.isEmpty) {
      return DqScene(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'もどる / Back',
                      icon: const Icon(Icons.arrow_back, color: dqInk),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      // Honest distinction: 5級/4級 have no writing section at all;
                      // a grade WITH a writing skill but no prompts yet (e.g.
                      // 準2級プラス) is "準備中", not "ありません".
                      (CseEstimator.skillsForGrade(widget.eikenGrade)
                                  ?.contains(EikenSkill.writing) ??
                              false)
                          ? 'この級（きゅう）の ライティングは じゅんびちゅうです。\n'
                              'もうしばらく おまちください。'
                          : 'この級（きゅう）には ライティングは ありません。\n'
                              'リーディングと リスニングで れんしゅうしよう！',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: dqInk, fontSize: 16, height: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DqScene(
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
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
          // Revise-mode cue (R2-F2): on「もう一度」the draft is kept on purpose so
          // the child EDITS it before resubmitting — without this banner an
          // unchanged resubmit would be re-graded identically and read as a no-op.
          if (_revisingDraft) ...[
            _ReviseDraftBanner(scoreRecap: _priorScoreRecap),
            const SizedBox(height: 12),
          ],
          // Task type badge
          _TaskTypeBadge(type: _prompt.type),
          const SizedBox(height: 10),

          // Stimulus / instructions
          DqPanel(
            title: '問題 / Task',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_prompt.instructionJa,
                    style: dqText(size: 13, color: dqInk)),
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
                if (_prompt.emailAsksQuestions &&
                    _prompt.underlinedTopic != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '下線部について、あなたから2つ質問しよう / Ask 2 questions about:',
                    style: dqText(size: 11, color: dqGold, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('▶ ', style: dqText(size: 12, color: dqGold)),
                      Expanded(
                        child: Text(
                          _prompt.underlinedTopic!,
                          style: dqText(
                            size: 13,
                            color: const Color(0xFFB8F0B8),
                            w: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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

          // ✍️ Structure scaffold — 構成 is a scored 観点 and a beginner facing a
          // blank box needs the 型 most. Generic structure only (never the answer).
          // Empty for task types without a safe shared 型 (email) → no gap.
          _buildStructureGuide(),

          // Text field
          DqPanel(
            title: 'あなたの答え / Your answer',
            // ValueListenableBuilder scopes rebuilds to this Column: the border
            // color, bar, and submit button all respond to word-count changes
            // without rebuilding the structure guide or DqPanel header above.
            child: ValueListenableBuilder<int>(
              valueListenable: _wordCountNotifier,
              builder: (_, count, __) {
                final inRange = count >= _prompt.wordCountMin &&
                    count <= _prompt.wordCountMax;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: dqNight0.withAlpha(230),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: inRange
                              ? const Color(0xFF8BE08B)
                              : dqBorder.withAlpha(180),
                          width: inRange ? 2 : 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: (text) {
                          // Count once here; push to notifier so only this
                          // ValueListenableBuilder subtree rebuilds on each
                          // keystroke (not the whole writing phase tree).
                          final t = text.trim();
                          _wordCountNotifier.value = t.isEmpty
                              ? 0
                              : t
                                  .split(RegExp(r'\s+'))
                                  .where((w) => w.isNotEmpty)
                                  .length;
                        },
                        maxLines: 8,
                        minLines: 6,
                        style: notoSerif(
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
                    _WordCountBar(
                      count: count,
                      min: _prompt.wordCountMin,
                      max: _prompt.wordCountMax,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Submit button also listens to the notifier so its enabled/disabled
          // state reflects word-count changes without a full-screen rebuild.
          ValueListenableBuilder<int>(
            valueListenable: _wordCountNotifier,
            builder: (_, count, __) {
              final canSubmit =
                  count >= _prompt.wordCountMin && _phase == _Phase.writing;
              return DqButton(
                label: canSubmit
                    ? 'AIに採点してもらう  /  Get AI feedback'
                    : '${_prompt.wordCountMin}語以上書いてから提出 / Write ≥${_prompt.wordCountMin} words',
                onTap: canSubmit ? _submit : null,
              );
            },
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
          // Daily-return reward at the completion peak (#151) — shown above the
          // detailed result for BOTH the scored and the offline-readiness branch,
          // since the habit is recorded either way.
          if (_earnedStreak != null) ...[
            SessionEndHook(streak: _earnedStreak!),
            const SizedBox(height: 14),
          ],
          if (!result.apiAvailable) ...[
            _buildReadinessReport(_prompt, _controller.text),
            // Offer the learner-confirmed 見直しチェック ONLY when the objective
            // machine checks all pass (no HARD violation, no advisory warn). It
            // drives revision + closure; it records NOTHING to the 合格率 (#100).
            if (evaluateWritingReadiness(_prompt, _controller.text)
                .formComplete) ...[
              const SizedBox(height: 12),
              WritingSelfCheckCard(
                taskType: _prompt.type,
                emailAsksQuestions: _prompt.emailAsksQuestions,
              ),
            ],
            // 見本解答: a content exemplar to compare against (reveal-on-demand).
            if (_prompt.modelAnswer != null) ...[
              const SizedBox(height: 12),
              _ModelAnswerCard(modelAnswer: _prompt.modelAnswer!),
            ],
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
                            style: notoSerifJp(
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
              style:
                  dqText(size: 13, color: dqInk.withAlpha(210), spacing: 0.2),
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
    final cleaned = response
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll('```', '')
        .trim();
    final Map<String, dynamic> parsed =
        jsonDecode(cleaned) as Map<String, dynamic>;
    final rawScores = parsed['scores'] as Map<String, dynamic>;
    final scores = <String, int>{};
    final maxPer = prompt.maxPerCriterion; // 4 (要約/意見) or 3 (Eメール)
    for (final rp in prompt.rubricPoints) {
      final val = rawScores[rp];
      scores[rp] = (val is int)
          ? val.clamp(0, maxPer)
          : (val is num)
              ? val.toInt().clamp(0, maxPer)
              : 0;
    }
    final feedback = (parsed['feedbackJa'] as String?) ?? '';
    return WritingRubricResult(
      scores: scores,
      feedbackJa: feedback,
      apiAvailable: true,
      maxPerCriterion: prompt.maxPerCriterion,
    );
  } catch (_) {
    // Parse failure → offline mode gracefully
    return WritingRubricResult(
      scores: {for (final p in prompt.rubricPoints) p: -1},
      feedbackJa: '',
      apiAvailable: false,
      maxPerCriterion: prompt.maxPerCriterion,
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

  // Canonical label — the old switch was missing pre2plus (→ bare "英検").
  String get _gradeLabel => gradeLabelJa(grade);

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

/// Revise-mode banner shown above the editor after「もう一度（なおして）」(R2-F2).
/// The previous draft is intentionally kept in the box; this tells the child to
/// EDIT it (with the previous score as a concrete target) before resubmitting,
/// so a re-grade reflects real revision rather than an identical resubmit.
class _ReviseDraftBanner extends StatelessWidget {
  const _ReviseDraftBanner({this.scoreRecap});
  final String? scoreRecap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: dqGold.withAlpha(28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dqGold.withAlpha(140), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note_rounded, color: dqGold, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('なおして だしなおそう',
                      style:
                          dqText(size: 14, w: FontWeight.w800, color: dqGold)),
                  const SizedBox(height: 3),
                  Text(
                    'まえの ぶんを のこしてあるよ。ヒントを みて なおしてから、'
                    'もういちど ていしゅつ しよう。',
                    style: dqText(
                        size: 12, color: dqInk.withAlpha(210), spacing: 0.2),
                  ),
                  if (scoreRecap != null) ...[
                    const SizedBox(height: 5),
                    Text(scoreRecap!,
                        style: dqText(
                            size: 12, w: FontWeight.w700, color: dqGoldDeep)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
        style: notoSerifJp(
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
        // #114/WCAG SC 1.4.4: these two labels together exceeded the width at
        // textScaler 2.0 (overflowed ~399px — spaceBetween can't shrink fixed
        // Texts). Flexible lets each wrap within its half instead of clipping.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                '語数 / Word count: $count語',
                style: dqText(size: 12, color: inRange ? barColor : dqInk),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '目標: $min〜$max語',
                textAlign: TextAlign.end,
                style: dqText(size: 11, color: dqGoldDeep),
              ),
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

  /// Returns a short, warm, criterion-specific ひらがな fix-hint for a child
  /// aged 6+ who scored 0 or 1 on this 観点. English nouns are fine; scolding
  /// is not. The hint teaches the NEXT concrete step.
  ///
  /// Matching is prefix-based (e.g. '内容 / Content' starts with '内容') so the
  /// bilingual label strings used in rubricPoints never break the match.
  String? _fixHint() {
    if (score > 1) return null; // only shown for weak rows
    if (label.startsWith('内容')) {
      // Task-type-agnostic (email asks Qs / opinion needs reasons / summary
      // needs the main points) — content-qa corrected the email-only original.
      return 'しつもんや だいもんを よみなおして、つたえたいことを もっと くわしく かこう！';
    } else if (label.startsWith('構成')) {
      return 'はじめ・なか・おわり の じゅんに かいてみよう！';
    } else if (label.startsWith('語彙')) {
      return 'おなじ ことば より、ちがう いいかた も つかってみよう！';
    } else if (label.startsWith('文法')) {
      // Whole-sentence grammar, not just capitals/periods — content-qa flagged
      // the original as too narrow (false reassurance when structure is wrong).
      return 'ひとつひとつの ぶんを よみなおして、えいごの かたちが ただしいか たしかめよう！';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hint = _fixHint();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    style: notoSerifJp(
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
          // Error-driven learning: show a criterion-specific next-step cue only
          // when the child scored 0 or 1 — a concrete warm nudge, never a scold.
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                hint,
                style: dqText(size: 11.5, color: dqInk.withAlpha(160)),
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

// lib/features/exam_practice/eiken_exam_config.dart
// A-KEN Quest — Eiken Exam Configuration
//
// Defines the structure of each Eiken grade's exam:
// sections, question types, time limits, pass criteria.

/// A section of the Eiken exam (e.g. Reading Part 1, Listening Part 2, Writing).
class ExamSection {
  final String id;
  final String nameJa;
  final String nameEn;
  final ExamSectionType type;
  final int questionCount;
  final int timeLimitMinutes;
  final String description;

  const ExamSection({
    required this.id,
    required this.nameJa,
    required this.nameEn,
    required this.type,
    required this.questionCount,
    required this.timeLimitMinutes,
    required this.description,
  });
}

enum ExamSectionType {
  /// 4-choice vocabulary/grammar fill-in-the-blank
  vocabGrammar,

  /// Conversation completion (4-choice)
  conversationComplete,

  /// Reading comprehension (passages + questions)
  readingComprehension,

  /// Word ordering / sentence construction
  wordOrdering,

  /// Listening (dialogue + monologue)
  listening,

  /// Writing (opinion essay, email, summary) — 2024 reform
  writing,

  /// Speaking (interview-style)
  speaking,
}

/// Full exam definition for each Eiken grade.
class EikenExamDef {
  final String grade;
  final String labelJa;
  final String cefrLevel;
  final int totalMinutes;
  final int passingScore; // CSE score threshold
  final int maxScore;
  final List<ExamSection> sections;

  const EikenExamDef({
    required this.grade,
    required this.labelJa,
    required this.cefrLevel,
    required this.totalMinutes,
    required this.passingScore,
    required this.maxScore,
    required this.sections,
  });
}

/// All Eiken exam definitions (post-2024 reform).
const Map<String, EikenExamDef> kEikenExams = {
  '5': EikenExamDef(
    grade: '5',
    labelJa: '英検5級',
    cefrLevel: 'A1',
    totalMinutes: 25,
    passingScore: 419,
    maxScore: 850,
    sections: [
      ExamSection(
        id: '5_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        questionCount: 15,
        timeLimitMinutes: 10,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: '5_r2',
        nameJa: '筆記2: 会話文の文空所補充',
        nameEn: 'Reading 2: Conversation',
        type: ExamSectionType.conversationComplete,
        questionCount: 5,
        timeLimitMinutes: 5,
        description: '会話の空所に入る適切な文を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: '5_r3',
        nameJa: '筆記3: 語句の並びかえ',
        nameEn: 'Reading 3: Word Ordering',
        type: ExamSectionType.wordOrdering,
        questionCount: 5,
        timeLimitMinutes: 5,
        description: '日本語の意味になるように語句を並びかえる',
      ),
      ExamSection(
        id: '5_l',
        nameJa: 'リスニング (第1部〜第3部)',
        nameEn: 'Listening (Parts 1–3)',
        type: ExamSectionType.listening,
        questionCount: 25,
        timeLimitMinutes: 20,
        description: '第1部: 応答選択10問 / 第2部: 会話内容一致5問 / 第3部: 文内容一致10問',
      ),
    ],
  ),
  '4': EikenExamDef(
    grade: '4',
    labelJa: '英検4級',
    cefrLevel: 'A1-A2',
    totalMinutes: 35,
    passingScore: 622,
    maxScore: 1000,
    sections: [
      ExamSection(
        id: '4_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        questionCount: 15,
        timeLimitMinutes: 10,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: '4_r2',
        nameJa: '筆記2: 会話文の文空所補充',
        nameEn: 'Reading 2: Conversation',
        type: ExamSectionType.conversationComplete,
        questionCount: 5,
        timeLimitMinutes: 5,
        description: '会話の空所に入る適切な文を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: '4_r3',
        nameJa: '筆記3: 語句の並びかえ',
        nameEn: 'Reading 3: Word Ordering',
        type: ExamSectionType.wordOrdering,
        questionCount: 5,
        timeLimitMinutes: 5,
        description: '日本語の意味になるように語句を並びかえる',
      ),
      ExamSection(
        id: '4_r4',
        nameJa: '筆記4: 長文の内容一致選択',
        nameEn: 'Reading 4: Reading Comprehension',
        type: ExamSectionType.readingComprehension,
        questionCount: 5,
        timeLimitMinutes: 10,
        description: 'パッセージを読んで質問に答える',
      ),
      ExamSection(
        id: '4_l',
        nameJa: 'リスニング (第1部〜第3部)',
        nameEn: 'Listening (Parts 1–3)',
        type: ExamSectionType.listening,
        questionCount: 30,
        timeLimitMinutes: 30,
        description: '第1部: 応答選択10問 / 第2部: 会話内容一致10問 / 第3部: 文内容一致10問',
      ),
    ],
  ),
  '3': EikenExamDef(
    grade: '3',
    labelJa: '英検3級',
    cefrLevel: 'A2',
    totalMinutes: 50,
    passingScore: 1103,
    maxScore: 1650,
    sections: [
      ExamSection(
        id: '3_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        questionCount: 15,
        timeLimitMinutes: 10,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: '3_r2',
        nameJa: '筆記2: 会話文の文空所補充',
        nameEn: 'Reading 2: Conversation',
        type: ExamSectionType.conversationComplete,
        questionCount: 5,
        timeLimitMinutes: 5,
        description: '会話の空所に入る適切な文を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: '3_r3',
        nameJa: '筆記3: 長文の内容一致選択',
        nameEn: 'Reading 3: Reading Comprehension',
        type: ExamSectionType.readingComprehension,
        questionCount: 10,
        timeLimitMinutes: 15,
        description: '掲示・手紙・説明文を読んで質問に答える',
      ),
      ExamSection(
        id: '3_w1',
        nameJa: '筆記4: ライティング（Eメール）',
        nameEn: 'Writing: Email Reply',
        type: ExamSectionType.writing,
        questionCount: 1,
        timeLimitMinutes: 15,
        description: '外国人の友達からのEメールに対する返信を書く（2024年新形式）',
      ),
      ExamSection(
        id: '3_l',
        nameJa: 'リスニング (第1部〜第3部)',
        nameEn: 'Listening (Parts 1–3)',
        type: ExamSectionType.listening,
        questionCount: 30,
        timeLimitMinutes: 25,
        description: '第1部: 会話内容一致10問 / 第2部: 会話内容一致10問 / 第3部: 文内容一致10問',
      ),
    ],
  ),
  'pre2': EikenExamDef(
    grade: 'pre2',
    labelJa: '英検準2級',
    cefrLevel: 'B1',
    totalMinutes: 75,
    passingScore: 1322,
    maxScore: 1800, // 一次満点 = 600×3 (corrected 2026-06-07; was inflated 1980)
    sections: [
      ExamSection(
        id: 'p2_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        questionCount: 20,
        timeLimitMinutes: 12,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: 'p2_r2',
        nameJa: '筆記2: 会話文の文空所補充',
        nameEn: 'Reading 2: Conversation',
        type: ExamSectionType.conversationComplete,
        questionCount: 5,
        timeLimitMinutes: 5,
        description: '会話の空所に入る適切な文を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: 'p2_r3',
        nameJa: '筆記3: 長文の内容一致選択',
        nameEn: 'Reading 3: Reading Comprehension',
        type: ExamSectionType.readingComprehension,
        questionCount: 7,
        timeLimitMinutes: 20,
        description: '長文を読んで質問に答える',
      ),
      ExamSection(
        id: 'p2_w1',
        nameJa: '筆記4: ライティング（Eメール＋意見）',
        nameEn: 'Writing: Email + Opinion',
        type: ExamSectionType.writing,
        questionCount: 2,
        timeLimitMinutes: 25,
        description: 'Eメール返信＋与えられたトピックについて意見を書く（2024年新形式）',
      ),
      ExamSection(
        id: 'p2_l',
        nameJa: 'リスニング (第1部〜第2部)',
        nameEn: 'Listening (Parts 1–2)',
        type: ExamSectionType.listening,
        questionCount: 30,
        timeLimitMinutes: 25,
        description: '第1部: 会話応答選択15問 / 第2部: 文内容一致15問',
      ),
    ],
  ),
  // 準2級プラス (2025新設). Verified eiken.or.jp 2025newgrade (2026-06-07):
  // R31 (大問1=17, 大問2 長文空所=6, 大問3 内容一致=8), W2 (要約+意見), L30 (15+15);
  // 一次満点 1875 (625×3), 合格基準 1402.
  'pre2plus': EikenExamDef(
    grade: 'pre2plus',
    labelJa: '英検準2級プラス',
    cefrLevel: 'B1',
    totalMinutes: 110, // 一次 = 筆記85分 + リスニング約25分 (eiken.or.jp, 2026-06-07)
    passingScore: 1402,
    maxScore: 1875,
    sections: [
      ExamSection(
        id: 'p2p_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        questionCount: 17,
        timeLimitMinutes: 12,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: 'p2p_r2',
        nameJa: '筆記2: 長文の語句空所補充',
        nameEn: 'Reading 2: Passage Cloze',
        type: ExamSectionType.readingComprehension,
        questionCount: 6,
        timeLimitMinutes: 12,
        description: '長文の空所に入る適切な語句を選ぶ',
      ),
      ExamSection(
        id: 'p2p_r3',
        nameJa: '筆記3: 長文の内容一致選択',
        nameEn: 'Reading 3: Reading Comprehension',
        type: ExamSectionType.readingComprehension,
        questionCount: 8,
        timeLimitMinutes: 22,
        description: '長文を読んで質問に答える',
      ),
      ExamSection(
        id: 'p2p_w1',
        nameJa: '筆記4: ライティング（要約＋意見）',
        nameEn: 'Writing: Summary + Opinion',
        type: ExamSectionType.writing,
        questionCount: 2,
        timeLimitMinutes: 34,
        description: '英文要約（45〜55語）＋与えられたトピックについて意見を書く（50〜60語）',
      ),
      ExamSection(
        id: 'p2p_l',
        nameJa: 'リスニング (第1部〜第2部)',
        nameEn: 'Listening (Parts 1–2)',
        type: ExamSectionType.listening,
        questionCount: 30,
        timeLimitMinutes: 24,
        description: '第1部: 会話内容一致15問 / 第2部: 文章内容一致15問',
      ),
    ],
  ),
  '2': EikenExamDef(
    grade: '2',
    labelJa: '英検2級',
    cefrLevel: 'B1-B2',
    totalMinutes: 85,
    passingScore: 1520,
    maxScore: 1950, // 一次満点 = 650×3 (corrected 2026-06-07; was inflated 2600)
    sections: [
      ExamSection(
        id: '2_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        questionCount: 17,
        timeLimitMinutes: 12,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: '2_r2',
        nameJa: '筆記2: 長文の語句空所補充',
        nameEn: 'Reading 2: Passage Fill-in',
        type: ExamSectionType.readingComprehension,
        questionCount: 6,
        timeLimitMinutes: 15,
        description: '長文の空所に適切な語句を入れる',
      ),
      ExamSection(
        id: '2_r3',
        nameJa: '筆記3: 長文の内容一致選択',
        nameEn: 'Reading 3: Reading Comprehension',
        type: ExamSectionType.readingComprehension,
        questionCount: 8,
        timeLimitMinutes: 25,
        description: '長文を読んで質問に答える',
      ),
      ExamSection(
        id: '2_w1',
        nameJa: '筆記4: ライティング（要約＋意見）',
        nameEn: 'Writing: Summary + Opinion',
        type: ExamSectionType.writing,
        questionCount: 2,
        timeLimitMinutes: 30,
        description: '英文要約＋与えられたトピックについて意見を書く（2024年新形式）',
      ),
      ExamSection(
        id: '2_l',
        nameJa: 'リスニング (第1部〜第2部)',
        nameEn: 'Listening (Parts 1–2)',
        type: ExamSectionType.listening,
        questionCount: 30,
        timeLimitMinutes: 25,
        description: '第1部: 会話応答選択15問 / 第2部: 文内容一致15問',
      ),
    ],
  ),
  'pre1': EikenExamDef(
    grade: 'pre1',
    labelJa: '英検準1級',
    cefrLevel: 'B2',
    totalMinutes: 90,
    passingScore: 1792,
    maxScore: 2250, // 一次満点 = 750×3 (corrected 2026-06-07; was inflated 3000)
    sections: [
      ExamSection(
        id: 'p1_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        questionCount: 25,
        timeLimitMinutes: 15,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ',
      ),
      ExamSection(
        id: 'p1_r2',
        nameJa: '筆記2: 長文の語句空所補充',
        nameEn: 'Reading 2: Passage Fill-in',
        type: ExamSectionType.readingComprehension,
        questionCount: 6,
        timeLimitMinutes: 15,
        description: '長文の空所に適切な語句を入れる',
      ),
      ExamSection(
        id: 'p1_r3',
        nameJa: '筆記3: 長文の内容一致選択',
        nameEn: 'Reading 3: Reading Comprehension',
        type: ExamSectionType.readingComprehension,
        questionCount: 10,
        timeLimitMinutes: 25,
        description: '長文を読んで質問に答える',
      ),
      ExamSection(
        id: 'p1_w1',
        nameJa: '筆記4: ライティング（要約＋意見）',
        nameEn: 'Writing: Summary + Opinion',
        type: ExamSectionType.writing,
        questionCount: 2,
        timeLimitMinutes: 30,
        description: '英文要約＋社会性のあるトピックについて意見を書く（2024年新形式）',
      ),
    ],
  ),
};

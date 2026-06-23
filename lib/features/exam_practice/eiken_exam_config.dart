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
    totalMinutes: 45, // 一次 = 筆記25分 + リスニング約20分 (eiken.or.jp, 2026-06)
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
    totalMinutes: 65, // 一次 = リーディング35分 + リスニング約30分 (eiken.or.jp, 2026-06)
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
        // 4級 大問4 is 10問 (4A 掲示2 + 4B Eメール3 + 4C 説明文5), so 筆記 total =
        // 15+5+5+10 = 35 — matching mock_exam/reading-pool targets. Was a stale 5
        // (made the hub show 30, under-stating the exam). Verified eiken.or.jp.
        questionCount: 10,
        timeLimitMinutes: 10,
        description: '掲示・Eメール・説明文の3つの長文を読んで質問に答える（計10問）',
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
    totalMinutes: 90, // 一次 = R/W 65分 + リスニング約25分 (2024改定後, eiken.or.jp 2026-06)
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
        nameJa: '筆記4: ライティング（Eメール＋意見論述）',
        nameEn: 'Writing: Email + Opinion',
        type: ExamSectionType.writing,
        // 英検3級 writing is TWO tasks post-2024 (Eメール + 意見論述) — the app
        // already ships both prompt types (3_email_*, 3_opinion_1) and mock_exam
        // /cse_model already weight 3級 writing as 2. timeLimitMinutes left at 15
        // so totalMinutes stays the official #96-locked value.
        questionCount: 2,
        timeLimitMinutes: 15,
        description: 'Eメール返信＋与えられたTOPICについて自分の意見を書く（2024年新形式・2題）',
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
    // 準2級 = CEFR A2 (official: eiken.or.jp / MEXT 対照表; B1 is 2級). Was 'B1'
    // = one band too high — a parent cross-checking the official table would
    // catch it. Verified 2026-06-23.
    cefrLevel: 'A2',
    totalMinutes:
        105, // 一次 = R/W 80分 + リスニング約25分 (2024改定後, eiken.or.jp 2026-06)
    passingScore: 1322,
    maxScore: 1800, // 一次満点 = 600×3 (corrected 2026-06-07; was inflated 1980)
    sections: [
      ExamSection(
        id: 'p2_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        // 2024 reform: 準2級 大問1 cut 20→15 (reading total 37→29; 大問3B 長文空所
        // dropped −3 → 大問3 is now 2 blanks). Verified eiken.or.jp 2024renewal +
        // eslclub, 2026-06-09/14. 29 = 15(大問1)+5(大問2)+2(大問3 語句空所)+7(大問4
        // 内容一致). The 大問3 長文空所 section below resolves the long-open #60 gap.
        questionCount: 15,
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
        // #60/Task#32: the missing 大問3. content = _pre2FillIn in
        // reading_practice_screen (sectionId 'pre2_r3'). Post-2024-reform = one
        // short passage, 2 blanks (大問3B 設問28-30 was removed).
        id: 'pre2_r3',
        nameJa: '筆記3: 長文の語句空所補充',
        nameEn: 'Reading 3: Passage Cloze',
        type: ExamSectionType.readingComprehension,
        questionCount: 2,
        timeLimitMinutes: 8,
        description: '短い長文の空所2か所に入る適切な語句を選ぶ（2024年改定後）',
      ),
      ExamSection(
        id: 'p2_r3',
        nameJa: '筆記4: 長文の内容一致選択',
        nameEn: 'Reading 4: Reading Comprehension',
        type: ExamSectionType.readingComprehension,
        questionCount: 7,
        timeLimitMinutes: 20,
        description: '長文を読んで質問に答える',
      ),
      ExamSection(
        id: 'p2_w1',
        nameJa: '筆記5: ライティング（Eメール＋意見）',
        nameEn: 'Writing: Email + Opinion',
        type: ExamSectionType.writing,
        questionCount: 2,
        timeLimitMinutes: 25,
        description: 'Eメール返信＋与えられたトピックについて意見を書く（2024年新形式）',
      ),
      ExamSection(
        id: 'p2_l',
        nameJa: 'リスニング (第1部〜第3部)',
        nameEn: 'Listening (Parts 1–3)',
        type: ExamSectionType.listening,
        questionCount: 30,
        timeLimitMinutes: 25,
        description: '第1部: 会話の応答文選択10問 / 第2部: 会話の内容一致10問 / 第3部: 文の内容一致10問',
      ),
    ],
  ),
  // 準2級プラス (2025新設). Verified eiken.or.jp 2025newgrade (2026-06-07):
  // R31 (大問1=17, 大問2 長文空所=6, 大問3 内容一致=8), W2 (要約+意見), L30 (15+15);
  // 一次満点 1875 (625×3), 合格基準 1402.
  'pre2plus': EikenExamDef(
    grade: 'pre2plus',
    labelJa: '英検準2級プラス',
    // 準2級プラス CEFR range = A1–A2; its passing score (1829 CSE) sits in the A2
    // band (eiken.or.jp 2025 新設級 info, verified 2026-06-23). Was 'B1' = same as
    // 2級, wrong for a grade that sits BELOW 2級.
    cefrLevel: 'A2',
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
    totalMinutes: 110, // 一次 = R/W 85分 + リスニング約25分 (eiken.or.jp, 2026-06)
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
    totalMinutes: 120, // 一次 = R/W 90分 + リスニング約30分 (eiken.or.jp, 2026-06)
    passingScore: 1792,
    maxScore: 2250, // 一次満点 = 750×3 (corrected 2026-06-07; was inflated 3000)
    sections: [
      ExamSection(
        id: 'p1_r1',
        nameJa: '筆記1: 短文の語句空所補充',
        nameEn: 'Reading 1: Vocabulary/Grammar',
        type: ExamSectionType.vocabGrammar,
        // 2024 reform: 準1級 大問1 cut 25→18 (14 単語 + 4 熟語); reading total
        // 41→31. The hub tile shows this count AND the vocab screen generates
        // exactly this many items, so the stale 25 over-served + misstated the
        // flagship grade's exam. Verified eiken.or.jp/obunsha 2024renewal,
        // 2026-06.
        questionCount: 18,
        timeLimitMinutes: 15,
        description: '短い文の空所に入る適切な語句を4つの選択肢から選ぶ（単語14・熟語4）',
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
        // 2024 reform: 準1級 大問3 cut 10→7 (long-passage 内容一致). This makes the
        // 準1 筆記 reading total 18+6+7 = 31, matching the official post-2024 count.
        // Verified eiken.or.jp / obunsha・eslclub 2024renewal, 2026-06. Note: the
        // mock 合格率 weighting already used the correct 31 (_kTargetCounts in
        // mock_exam.dart), and the practice screen serves its 2-passage bank (×5 =
        // 10) as BONUS drilling regardless of this count — so this is the hub-tile
        // spec made honest, not a content re-author.
        questionCount: 7,
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
      // Listening was MISSING from 準1 — the marquee grade (the product's stated
      // goal). Without it the exam hub showed no listening tile, so a 準1 child
      // could never practise listening and their 合格率 listening skill stayed
      // 未測定. The 12 'pre1' items in listening_data.dart were unreachable.
      // Verified against eiken.or.jp (2025/26, unchanged): 29 questions, 3 parts.
      ExamSection(
        id: 'p1_l',
        nameJa: 'リスニング (第1部〜第3部)',
        nameEn: 'Listening (Parts 1–3)',
        type: ExamSectionType.listening,
        questionCount: 29,
        timeLimitMinutes: 30,
        description: '第1部: 会話の内容一致12問 / 第2部: 説明文の内容一致12問 / 第3部: Real-Life形式5問',
      ),
    ],
  ),
};

/// Canonical child-facing 漢字 grade label (英検5級 … 英検準1級 / 英検準2級プラス).
/// SINGLE SOURCE OF TRUTH — use this everywhere instead of ad-hoc '英検$grade級',
/// which renders the raw key for the NAMED grades (e.g. "英検pre2plus級",
/// "英検pre1級") and let inconsistent spellings drift (e.g. "英検準2級+" vs
/// "英検準2級プラス"). Accepts the grade keys '5'|'4'|'3'|'pre2'|'pre2plus'|'2'|'pre1'.
String gradeLabelJa(String grade) => kEikenExams[grade]?.labelJa ?? '英検$grade級';

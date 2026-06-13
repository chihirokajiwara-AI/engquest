// lib/features/exam_practice/listening_data.dart
// A-KEN Quest — Eiken Listening item data (seed bank)
//
// SCHEMA:
//   part       : 1 | 2 | 3
//   grade      : '5' | '4' | '3' | 'pre2' | 'pre2plus' | '2' | 'pre1'
//   audioKey   : key relative to assets/audio/listening/, e.g. 'l5_p1_01.mp3'
//   transcripts: lines the TTS pipeline will speak (for QA + generation input)
//                For 2-speaker items, lines alternate Speaker-A / Speaker-B.
//   questionType:
//     応答選択          — hear ONE line → pick the best reply (grades 5/4)
//     会話内容一致      — hear a SHORT dialogue (2–4 turns) → answer a content Q
//     文内容一致        — hear a PASSAGE / announcement → answer a content Q
//                      (grades 5/4 第2部, 3級 第3部)
//     会話応答選択      — hear a dialogue + a question spoken aloud →
//                      pick the best answer (grades 準2級プラス/2級 第1部)
//   question    : the printed/spoken question (JP for child-facing items)
//   choices     : exactly 4 strings
//   correctIndex: 0–3
//   imageHint   : optional (unused at launch — placeholder for 3級 第1部 illust)
//
// CONTENT INTEGRITY (R1):
//   • All choices for a given item must be in the SAME language (EN for EN items).
//   • Exactly one correctIndex per item.
//   • No duplicate choices within an item.
//   • No choice equals the answer key itself (no giveaway repetition).
//
// AUDIO STATUS (R2):
//   All audioKey values below are registered in assets/ALLOWED_MISSING.txt because
//   audio has not yet been generated (Kokoro is CPU-heavy; must run via
//   scripts/safe-job.sh). Run scripts/generate_listening_audio.py to synthesize.
//
// NOTE: 5級/4級 structure per verified spec (EIKEN-MASTERY-AND-GAPS-2026-06-06.json):
//   5級: 第1部10 (応答選択) + 第2部5 (会話内容一致) + 第3部10 (文内容一致) = 25
//   4級: 第1部10 (応答選択) + 第2部10 (会話内容一致) + 第3部10 (文内容一致) = 30
//   3級: 3部 = 30問
//   準2級プラス/2級: 第1部15 (会話応答選択) + 第2部15 (文内容一致) = 30
// Seed bank covers the VERIFIED per-grade 部 structure. Volume is being expanded
// toward the real-exam per-part counts (#10): 英検3級 is COMPLETE at 10/10/10 = 30
// (a full real-exam listening section); the other grades remain at the initial
// ~4-item sample and are visible as shortfalls in reading_pool_integrity_test
// (skip with the exact gap to target).

class ListeningItem {
  final int part;
  final String grade;
  final String audioKey;
  final List<String> transcripts; // ordered lines, alt A/B for dialogues
  final ListeningQuestionType questionType;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String? imageHint;

  /// Optional child-facing 解説 (「なぜこの答えか」) shown after answering, next
  /// to the script reveal — the same "teach why" aid vocab/reading/conversation
  /// already have. Null → the transcript panel alone is shown (graceful, the
  /// prior behavior). Seeded per-grade starting with 5級 (entry learners).
  final String? explanation;

  const ListeningItem({
    required this.part,
    required this.grade,
    required this.audioKey,
    required this.transcripts,
    required this.questionType,
    required this.question,
    required this.choices,
    required this.correctIndex,
    this.imageHint,
    this.explanation,
  });

  ListeningItem copyWith({List<String>? choices, int? correctIndex}) =>
      ListeningItem(
        part: part,
        grade: grade,
        audioKey: audioKey,
        transcripts: transcripts,
        questionType: questionType,
        question: question,
        choices: choices ?? this.choices,
        correctIndex: correctIndex ?? this.correctIndex,
        imageHint: imageHint,
        explanation: explanation,
      );
}

enum ListeningQuestionType {
  /// Hear ONE line → pick the best reply.  5級/4級 第1部 (応答選択)
  responseSelect,

  /// Hear short dialogue → answer a content question.  5/4/3級 第2部 (会話内容一致)
  dialogueContent,

  /// Hear a passage/announcement → answer a content question.  5/4/3 第3部 (文内容一致)
  passageContent,

  /// Hear dialogue + spoken question → pick best answer.  準2+/2級 第1部 (会話応答選択)
  dialogueQA,
}

// ── 英検5級 ─────────────────────────────────────────────────────────────────

const _grade5Part1 = <ListeningItem>[
  // 第1部: 応答選択 — hear ONE line, pick the best response
  ListeningItem(
    part: 1,
    grade: '5',
    audioKey: 'l5_p1_01.mp3',
    transcripts: ['Good morning!'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'Good morning!',
      'Yes, I like it.',
      'It is Tuesday.',
      'I go to school.',
    ],
    correctIndex: 0,
    explanation: 'あさのあいさつ「Good morning!」には、おなじ「Good morning!」とかえすよ。',
  ),
  ListeningItem(
    part: 1,
    grade: '5',
    audioKey: 'l5_p1_02.mp3',
    transcripts: ['How old are you?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'I am fine.',
      'I am ten years old.',
      'My name is Ken.',
      'I like cats.',
    ],
    correctIndex: 1,
    explanation:
        '「How old are you?（なんさい?）」だから、ねんれいをこたえる「I am ten years old.（10さい）」だよ。',
  ),
  ListeningItem(
    part: 1,
    grade: '5',
    audioKey: 'l5_p1_03.mp3',
    transcripts: ['Do you have a dog?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'No, I do not.',
      'It is a big house.',
      'I play tennis.',
      'She is my sister.',
    ],
    correctIndex: 0,
    explanation: '「Do you ～?」できかれたら、Yes か No でこたえるよ。ここは「No, I do not.」だね。',
  ),
  ListeningItem(
    part: 1,
    grade: '5',
    audioKey: 'l5_p1_04.mp3',
    transcripts: ['What color is your bag?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'It is very big.',
      'I use it every day.',
      'It is blue.',
      'I bought it yesterday.',
    ],
    correctIndex: 2,
    explanation: '「What color（なにいろ?）」ときかれているから、いろをこたえる「It is blue.（あおいよ）」だよ。',
  ),
];

const _grade5Part2 = <ListeningItem>[
  // 第2部: 会話内容一致 — short dialogue, answer a content question
  ListeningItem(
    part: 2,
    grade: '5',
    audioKey: 'l5_p2_01.mp3',
    transcripts: [
      'A: What do you want for your birthday?',
      'B: I want a new bike.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What does the boy want for his birthday?',
    choices: [
      'A new book.',
      'A new bike.',
      'A new bag.',
      'A new ball.',
    ],
    correctIndex: 1,
    explanation: 'おとこのこは「I want a new bike.（あたらしいじてんしゃがほしい）」といっているね。',
  ),
  ListeningItem(
    part: 2,
    grade: '5',
    audioKey: 'l5_p2_02.mp3',
    transcripts: [
      'A: Where are you going?',
      'B: I am going to the park.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'Where is the girl going?',
    choices: [
      'To the library.',
      'To the park.',
      'To the store.',
      'To the school.',
    ],
    correctIndex: 1,
    explanation: 'おんなのこは「I am going to the park.（こうえんにいく）」といっているよ。',
  ),
  ListeningItem(
    part: 2,
    grade: '5',
    audioKey: 'l5_p2_03.mp3',
    transcripts: [
      'A: What time does school start?',
      'B: It starts at eight thirty.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What time does school start?',
    choices: [
      'At eight o\'clock.',
      'At eight fifteen.',
      'At eight thirty.',
      'At nine o\'clock.',
    ],
    correctIndex: 2,
    explanation: '「It starts at eight thirty.（8じ30ぷん）」といっているね。',
  ),
  ListeningItem(
    part: 2,
    grade: '5',
    audioKey: 'l5_p2_04.mp3',
    transcripts: [
      'A: Do you like math?',
      'B: No, I like science.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What subject does the girl like?',
    choices: [
      'Math.',
      'English.',
      'Science.',
      'History.',
    ],
    correctIndex: 2,
    explanation: 'おんなのこは「I like science.（りかがすき）」といっているよ。math（さんすう）はすきじゃないね。',
  ),
];

const _grade5Part3 = <ListeningItem>[
  // 第3部: 文内容一致 — short passage, answer a content question
  ListeningItem(
    part: 3,
    grade: '5',
    audioKey: 'l5_p3_01.mp3',
    transcripts: [
      'My name is Yuki. I have a cat. Her name is Mimi. She is white and very cute.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What color is Mimi?',
    choices: [
      'Brown.',
      'Orange.',
      'White.',
      'Black.',
    ],
    correctIndex: 2,
    explanation: 'はなしては「She is white.（しろい）」といっているね。ミミのいろは White だよ。',
  ),
  ListeningItem(
    part: 3,
    grade: '5',
    audioKey: 'l5_p3_02.mp3',
    transcripts: [
      'Tom likes sports. He plays soccer on Saturdays and swims on Sundays.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'When does Tom play soccer?',
    choices: [
      'On Fridays.',
      'On Saturdays.',
      'On Sundays.',
      'On Mondays.',
    ],
    correctIndex: 1,
    explanation: '「He plays soccer on Saturdays.（どようびにサッカー）」といっているよ。',
  ),
  ListeningItem(
    part: 3,
    grade: '5',
    audioKey: 'l5_p3_03.mp3',
    transcripts: [
      'My sister is a teacher. She teaches math at a middle school.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What subject does the sister teach?',
    choices: [
      'English.',
      'Science.',
      'Math.',
      'Music.',
    ],
    correctIndex: 2,
    explanation: '「She teaches math.（すうがくをおしえる）」といっているね。',
  ),
  ListeningItem(
    part: 3,
    grade: '5',
    audioKey: 'l5_p3_04.mp3',
    transcripts: [
      'I have three pets: two cats and one dog. I feed them every morning before school.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'How many cats does the speaker have?',
    choices: [
      'One.',
      'Two.',
      'Three.',
      'Four.',
    ],
    correctIndex: 1,
    explanation: '「two cats and one dog（ねこ2ひきといぬ1ぴき）」だから、ねこは Two だよ。',
  ),
];

// ── 英検4級 ─────────────────────────────────────────────────────────────────

const _grade4Part1 = <ListeningItem>[
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_01.mp3',
    transcripts: ['Could you pass me the salt, please?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'Sure, here you are.',
      'I already ate dinner.',
      'The kitchen is over there.',
      'No, I do not like salt.',
    ],
    correctIndex: 0,
    explanation:
        '「Could you ～?（〜してくれる?）」のおねがいには「Sure, here you are.（はい、どうぞ）」とこたえるよ。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_02.mp3',
    transcripts: ['Have you finished your homework?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'My homework is very difficult.',
      'Not yet. I am still working on it.',
      'I forgot my textbook at school.',
      'Homework is important for students.',
    ],
    correctIndex: 1,
    explanation: '「もうしゅくだいおわった?」にたいして「Not yet.（まだだよ）」がしぜんなこたえだね。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_03.mp3',
    transcripts: ['When did you arrive in Japan?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'I came here two years ago.',
      'Japan is a beautiful country.',
      'I live near the station.',
      'My flight was very long.',
    ],
    correctIndex: 0,
    explanation: '「When（いつ?）」ときかれているから、「two years ago（2ねんまえ）」と"とき"をこたえるよ。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_04.mp3',
    transcripts: ['Would you like to join us for lunch?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'Lunch is at noon.',
      'Thank you, I would love to.',
      'I had breakfast this morning.',
      'The restaurant is nearby.',
    ],
    correctIndex: 1,
    explanation:
        '「Would you like to ～?（〜しない?）」のさそいには「Thank you, I would love to.（よろこんで）」だね。',
  ),
  // ── #10 volume expansion: 4級 第1部 4→10 (応答選択, A2). Audio pending Kokoro;
  //    keys in ALLOWED_MISSING. Content-QA'd 2026-06-09.
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_05.mp3',
    transcripts: ['How was your weekend?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'It was great. I went hiking.',
      'I usually wake up early.',
      'The weekend is too short.',
      'I will visit my aunt tomorrow.',
    ],
    correctIndex: 0,
    explanation: '「How was ～?（〜はどうだった?）」だから、しゅうまつのできごとをこたえる「It was great.」だよ。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_06.mp3',
    transcripts: ['Could you tell me the way to the station?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'Sure. Go straight and turn left.',
      'The train was very crowded.',
      'I take the bus every day.',
      'Stations are usually busy.',
    ],
    correctIndex: 0,
    explanation:
        '「えきへのみちをおしえて」だから、いきかたをこたえる「Go straight and turn left.（まっすぐいってひだり）」だね。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_07.mp3',
    transcripts: ['Would you like some tea or coffee?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'Coffee, please.',
      'I drank water this morning.',
      'The cafe is closed today.',
      'Tea grows in warm places.',
    ],
    correctIndex: 0,
    explanation: '「おちゃとコーヒーどっちがいい?」だから、どちらかをえらぶ「Coffee, please.」だよ。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_08.mp3',
    transcripts: ['I am sorry I am late.'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'That is okay. We just started.',
      'You are always early.',
      'The clock on the wall is new.',
      'I have to leave soon.',
    ],
    correctIndex: 0,
    explanation: '「おくれてごめん」には「That is okay.（だいじょうぶ）」とゆるすこたえがしぜんだね。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_09.mp3',
    transcripts: ['What are you going to do during summer vacation?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'I am going to visit my grandparents.',
      'Summer is very hot this year.',
      'I finished my homework already.',
      'The vacation was fun last year.',
    ],
    correctIndex: 0,
    explanation:
        '「なつやすみになにをする?」だから、よていをこたえる「I am going to visit my grandparents.（そふぼにあいにいく）」だよ。',
  ),
  ListeningItem(
    part: 1,
    grade: '4',
    audioKey: 'l4_p1_10.mp3',
    transcripts: ['Can I borrow your pen?'],
    questionType: ListeningQuestionType.responseSelect,
    question: 'What is the best response?',
    choices: [
      'Of course. Here you go.',
      'I bought a new notebook.',
      'Pens are sold at that store.',
      'I like writing letters.',
    ],
    correctIndex: 0,
    explanation: '「ペンかりていい?」のおねがいには「Of course. Here you go.（もちろん、どうぞ）」だね。',
  ),
];

const _grade4Part2 = <ListeningItem>[
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_01.mp3',
    transcripts: [
      'A: Did you watch the game last night?',
      'B: Yes! Our team won three to one.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What was the score of the game?',
    choices: [
      'One to three.',
      'Three to zero.',
      'Three to one.',
      'Two to one.',
    ],
    correctIndex: 2,
    explanation: 'Bは「won three to one（3たい1でかった）」といっているね。スコアは Three to one だよ。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_02.mp3',
    transcripts: [
      'A: How do you usually go to school?',
      'B: I take the bus. It takes about twenty minutes.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'How does the boy get to school?',
    choices: [
      'He walks.',
      'He rides his bike.',
      'He takes the bus.',
      'He takes the train.',
    ],
    correctIndex: 2,
    explanation:
        'Bは「I take the bus（バスでいく）」といっているよ。about twenty minutes ともいっているね。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_03.mp3',
    transcripts: [
      'A: What are you going to do this weekend?',
      'B: I am going to visit my grandparents in Osaka.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What is the girl going to do this weekend?',
    choices: [
      'Study for exams.',
      'Play in a soccer tournament.',
      'Visit her grandparents in Osaka.',
      'Go to an amusement park.',
    ],
    correctIndex: 2,
    explanation:
        'Bは「visit my grandparents（そふぼに あいにいく）」といっているね。in Osaka（おおさか）だよ。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_04.mp3',
    transcripts: [
      'A: What did you get for your birthday?',
      'B: My parents gave me a new guitar.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What did the boy get for his birthday?',
    choices: [
      'A new computer.',
      'A new guitar.',
      'A new bicycle.',
      'A new phone.',
    ],
    correctIndex: 1,
    explanation: 'Bは「gave me a new guitar（ギターをもらった）」といっているよ。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_05.mp3',
    transcripts: [
      'A: What time does the city library open?',
      'B: It opens at nine in the morning.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'When does the library open?',
    choices: [
      'At eight in the morning.',
      'At nine in the morning.',
      'At ten in the morning.',
      'At noon.',
    ],
    correctIndex: 1,
    explanation: 'Bは「It opens at nine in the morning（あさ9じにあく）」といっているね。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_06.mp3',
    transcripts: [
      'A: Where did you buy that nice jacket?',
      'B: I got it at the department store near the station.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'Where did the girl buy her jacket?',
    choices: [
      'At a shop near her house.',
      'On the internet.',
      'At the department store near the station.',
      'At the shopping mall.',
    ],
    correctIndex: 2,
    explanation:
        'Bは「at the department store near the station（えきの ちかくのデパート）」といっているよ。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_07.mp3',
    transcripts: [
      'A: How many pets do you have?',
      'B: I have two dogs and a cat.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'How many pets does the boy have?',
    choices: [
      'One.',
      'Two.',
      'Three.',
      'Four.',
    ],
    correctIndex: 2,
    explanation: 'Bは「two dogs and a cat（いぬ2ひきと ねこ1ぴき）」といっているね。あわせて 3びき だよ。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_08.mp3',
    transcripts: [
      'A: Why didn\'t you come to practice yesterday?',
      'B: I had a cold, so I stayed home.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'Why did the girl miss practice?',
    choices: [
      'She had a lot of homework.',
      'She had a cold.',
      'She went on a trip.',
      'She forgot about it.',
    ],
    correctIndex: 1,
    explanation: 'Bは「I had a cold（かぜを ひいた）」といっているよ。だから やすんだんだね。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_09.mp3',
    transcripts: [
      'A: What would you like to drink?',
      'B: Orange juice, please.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What does the boy want to drink?',
    choices: [
      'Water.',
      'Tea.',
      'Milk.',
      'Orange juice.',
    ],
    correctIndex: 3,
    explanation: 'Bは「Orange juice, please（オレンジジュース）」といっているね。',
  ),
  ListeningItem(
    part: 2,
    grade: '4',
    audioKey: 'l4_p2_10.mp3',
    transcripts: [
      'A: When is your sister coming back from London?',
      'B: She will be back next month.',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'When will the sister return from London?',
    choices: [
      'Next week.',
      'Next month.',
      'Next year.',
      'This weekend.',
    ],
    correctIndex: 1,
    explanation: 'Bは「She will be back next month（らいげつ もどる）」といっているよ。',
  ),
];

const _grade4Part3 = <ListeningItem>[
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_01.mp3',
    transcripts: [
      'Hello, everyone. Our school festival will be held next Saturday, '
          'November twenty-second. There will be music performances and food stalls. '
          'Please invite your family and friends.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'When will the school festival be held?',
    choices: [
      'Next Friday.',
      'Next Saturday, November twenty-second.',
      'Next Sunday, November twenty-third.',
      'This Saturday.',
    ],
    correctIndex: 1,
    explanation: '本文（ほんぶん）に「つぎの どようび・11月22日」とあるね。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_02.mp3',
    transcripts: [
      'My hobby is cooking. I learned to make sushi from my grandfather last summer. '
          'Now I cook for my family every Sunday.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Who taught the speaker to make sushi?',
    choices: [
      'His mother.',
      'His teacher.',
      'His grandfather.',
      'His older sister.',
    ],
    correctIndex: 2,
    explanation: '本文に「おじいさんに ならった（from my grandfather）」とあるよ。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_03.mp3',
    transcripts: [
      'This is an announcement for passengers on the four-fifteen train to Kyoto. '
          'The train will be delayed by about thirty minutes due to heavy rain.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why is the train delayed?',
    choices: [
      'Due to a technical problem.',
      'Due to an accident on the tracks.',
      'Due to heavy rain.',
      'Due to a signal failure.',
    ],
    correctIndex: 2,
    explanation: '本文に「おおあめ のため」でんしゃが おくれる、とあるね。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_04.mp3',
    transcripts: [
      'Hi, my name is Emma. I am from Canada. I have been studying Japanese for '
          'two years. My favorite Japanese food is ramen.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'How long has Emma been studying Japanese?',
    choices: [
      'For one year.',
      'For two years.',
      'For three years.',
      'For six months.',
    ],
    correctIndex: 1,
    explanation: '本文に「2年（ねん）かん にほんごを べんきょうしている」とあるよ。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_05.mp3',
    transcripts: [
      'Welcome to Green Mart. Today only, all fruit is twenty percent off. '
          'The sale ends at six o\'clock this evening. Thank you for shopping with us.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'When does the fruit sale end?',
    choices: [
      'At three o\'clock.',
      'At five o\'clock.',
      'At six o\'clock this evening.',
      'Tomorrow morning.',
    ],
    correctIndex: 2,
    explanation: '本文に「6じ（this evening）に セールが おわる」とあるね。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_06.mp3',
    transcripts: [
      'Last Sunday I went to the zoo with my family. We saw lions, elephants, '
          'and pandas. The pandas were my favorite.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What was the speaker\'s favorite animal?',
    choices: [
      'The lions.',
      'The elephants.',
      'The pandas.',
      'The monkeys.',
    ],
    correctIndex: 2,
    explanation: '本文に「The pandas were my favorite（パンダが いちばん すき）」とあるよ。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_07.mp3',
    transcripts: [
      'Don\'t forget that tomorrow we have a math test. Please bring two pencils '
          'and an eraser. The test will start at nine o\'clock.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What should the students bring tomorrow?',
    choices: [
      'A dictionary.',
      'Two pencils and an eraser.',
      'A calculator.',
      'Their textbooks.',
    ],
    correctIndex: 1,
    explanation: '本文に「えんぴつ2ほんと けしゴムを もってくる」とあるね。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_08.mp3',
    transcripts: [
      'I joined the tennis club this spring. We practice every Tuesday and '
          'Thursday after school. I want to play in a tournament next year.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'How often does the speaker practice tennis?',
    choices: [
      'Once a week.',
      'Twice a week.',
      'Every day.',
      'Three times a week.',
    ],
    correctIndex: 1,
    explanation: '本文に「かようび と もくようび れんしゅう」＝しゅう2かい だね。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_09.mp3',
    transcripts: [
      'Good morning. Here is today\'s weather. It will be sunny in the morning, '
          'but it will rain in the afternoon. Please take an umbrella.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What will the weather be like in the afternoon?',
    choices: [
      'It will be sunny.',
      'It will be cloudy.',
      'It will rain.',
      'It will snow.',
    ],
    correctIndex: 2,
    explanation: '本文に「ごごは あめ（it will rain in the afternoon）」とあるよ。',
  ),
  ListeningItem(
    part: 3,
    grade: '4',
    audioKey: 'l4_p3_10.mp3',
    transcripts: [
      'During summer vacation, my family traveled to Hokkaido by plane. '
          'We stayed there for five days and ate a lot of fresh seafood.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'How did the speaker\'s family travel to Hokkaido?',
    choices: [
      'By train.',
      'By car.',
      'By plane.',
      'By ship.',
    ],
    correctIndex: 2,
    explanation: '本文に「ひこうきで ほっかいどうへ いった（by plane）」とあるね。',
  ),
];

// ── 英検3級 ─────────────────────────────────────────────────────────────────

const _grade3Part1 = <ListeningItem>[
  // 3級 第1部: 会話内容一致 (2-turn dialogue + Q)
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_01.mp3',
    transcripts: [
      'A: I heard you\'re going to study abroad.',
      'B: Yes, I\'m going to Australia for six months starting in April.',
      'Question: When is the person going to Australia?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'When is the person going to Australia?',
    choices: [
      'In January.',
      'In April.',
      'In June.',
      'In September.',
    ],
    correctIndex: 1,
    explanation: 'B が「starting in April（4月から）」と言っている＝オーストラリアへ行くのは4月。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_02.mp3',
    transcripts: [
      'A: Do you have any plans for the summer holidays?',
      'B: Yes, I\'m going to volunteer at a local animal shelter.',
      'Question: What is the girl going to do during the summer holidays?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What is the girl going to do during the summer holidays?',
    choices: [
      'Take a language course.',
      'Travel overseas.',
      'Volunteer at an animal shelter.',
      'Work part-time at a café.',
    ],
    correctIndex: 2,
    explanation:
        '「volunteer at a local animal shelter（動物保護施設でボランティアする）」が夏休みの予定。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_03.mp3',
    transcripts: [
      'A: How was the math test?',
      'B: It was harder than I expected. I think I failed.',
      'A: Don\'t worry. You can ask the teacher for help next time.',
      'Question: How does the boy feel about the math test?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'How does the boy feel about the math test?',
    choices: [
      'He thinks he did well.',
      'He feels it was too easy.',
      'He thinks he failed.',
      'He has not taken the test yet.',
    ],
    correctIndex: 2,
    explanation: 'B が「I think I failed（落ちたと思う）」＝テストに失敗したと感じている。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_04.mp3',
    transcripts: [
      'A: What kind of movies do you like?',
      'B: I prefer documentaries. I find action movies too loud.',
      'Question: What kind of movies does the girl prefer?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What kind of movies does the girl prefer?',
    choices: [
      'Action movies.',
      'Comedy movies.',
      'Documentaries.',
      'Romance movies.',
    ],
    correctIndex: 2,
    explanation: '「I prefer documentaries（ドキュメンタリーの方が好き）」と言っている。',
  ),
  // ── #10 volume expansion: 3級 第1部 4→10 (会話内容一致, A2–B1). Audio pending
  //    Kokoro gen → keys registered in ALLOWED_MISSING; items work via the
  //    transcript reveal. Content-QA'd 2026-06-09.
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_05.mp3',
    transcripts: [
      'A: Did you finish reading the book I lent you?',
      'B: Not yet. I\'ve been busy with club activities, but I\'ll return it next week.',
      'Question: When will the boy return the book?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'When will the boy return the book?',
    choices: [
      'Today.',
      'Tomorrow.',
      'Next week.',
      'Next month.',
    ],
    correctIndex: 2,
    explanation: '「I will return it next week（来週返す）」と言っている。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_06.mp3',
    transcripts: [
      'A: Excuse me, what time does the next bus to the station leave?',
      'B: The next one is at 3:15, but it is often a few minutes late.',
      'Question: When is the next bus scheduled to leave?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'When is the next bus scheduled to leave?',
    choices: [
      'At 3:00.',
      'At 3:15.',
      'At 3:30.',
      'At 3:50.',
    ],
    correctIndex: 1,
    explanation: '「The next one is at 3:15（次は3時15分）」が予定時刻。よく遅れるが予定は3:15。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_07.mp3',
    transcripts: [
      'A: You look tired today. Did you stay up late?',
      'B: Yeah, I was practicing the piano for the school concert.',
      'Question: Why is the girl tired?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'Why is the girl tired?',
    choices: [
      'She studied all night.',
      'She practiced the piano.',
      'She watched TV late.',
      'She had a fever.',
    ],
    correctIndex: 1,
    explanation:
        '「practicing the piano for the school concert（コンサートのためピアノを練習していた）」ので眠い。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_08.mp3',
    transcripts: [
      'A: I can\'t decide what to give my mother for her birthday.',
      'B: How about flowers? She loves the roses in your garden.',
      'Question: What does the boy suggest as a present?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What does the boy suggest as a present?',
    choices: [
      'A book.',
      'Flowers.',
      'A cake.',
      'A scarf.',
    ],
    correctIndex: 1,
    explanation: 'B が「How about flowers?（花はどう?）」と提案している。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_09.mp3',
    transcripts: [
      'A: Have you ever been to the new science museum downtown?',
      'B: Yes, I went last weekend. The space exhibit was amazing.',
      'Question: What did the girl think of the science museum?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What did the girl think of the science museum?',
    choices: [
      'It was boring.',
      'It was too crowded.',
      'The space exhibit was amazing.',
      'It was closed.',
    ],
    correctIndex: 2,
    explanation: '「The space exhibit was amazing（宇宙の展示がすごかった）」と感想を述べている。',
  ),
  ListeningItem(
    part: 1,
    grade: '3',
    audioKey: 'l3_p1_10.mp3',
    transcripts: [
      'A: Could you help me carry these boxes to the classroom?',
      'B: Sure, but I have to meet my teacher first. Can you wait ten minutes?',
      'Question: What will the boy do first?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What will the boy do first?',
    choices: [
      'Carry the boxes.',
      'Meet his teacher.',
      'Go home.',
      'Call his friend.',
    ],
    correctIndex: 1,
    explanation: '「I have to meet my teacher first（先に先生に会わなければ）」＝まず先生に会う。',
  ),
];

const _grade3Part2 = <ListeningItem>[
  // 3級 第2部: 会話内容一致 (slightly longer, 3–4 turns)
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_01.mp3',
    transcripts: [
      'A: Have you decided on your career path?',
      'B: I want to become a nurse. I love helping people.',
      'A: That\'s wonderful. Are you going to study nursing at university?',
      'B: Yes, I\'ve already applied.',
      'Question: What career does the girl want to pursue?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What career does the girl want to pursue?',
    choices: [
      'A doctor.',
      'A nurse.',
      'A pharmacist.',
      'A social worker.',
    ],
    correctIndex: 1,
    explanation: 'B が「I want to become a nurse（看護師になりたい）」と言っている。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_02.mp3',
    transcripts: [
      'A: Did you join any clubs this year?',
      'B: I joined the photography club. We go out on weekends to take pictures.',
      'A: That sounds fun. What do you usually photograph?',
      'B: Mostly nature and old buildings.',
      'Question: What does the boy usually photograph?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What does the boy usually photograph?',
    choices: [
      'People and portraits.',
      'Sports and events.',
      'Nature and old buildings.',
      'Food and restaurants.',
    ],
    correctIndex: 2,
    explanation: '「Mostly nature and old buildings（主に自然と古い建物）」を撮ると言っている。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_03.mp3',
    transcripts: [
      'A: I heard the city is building a new community center.',
      'B: Yes, it will have a gym, a library, and a café.',
      'A: When is it going to open?',
      'B: Next spring, I think.',
      'Question: What will the new community center have?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What will the new community center have?',
    choices: [
      'A gym, a library, and a café.',
      'A pool, a gym, and a cinema.',
      'A library, a café, and a park.',
      'A gym, a café, and a hotel.',
    ],
    correctIndex: 0,
    explanation: '「a gym, a library, and a café（ジム・図書館・カフェ）」ができる。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_04.mp3',
    transcripts: [
      'A: How do you practice English outside of class?',
      'B: I watch English videos online every day. I also keep a diary in English.',
      'A: That\'s a great idea.',
      'Question: How does the girl practice English outside of class?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'How does the girl practice English outside of class?',
    choices: [
      'She reads English novels.',
      'She watches English videos and keeps a diary.',
      'She listens to English radio programs.',
      'She takes private lessons online.',
    ],
    correctIndex: 1,
    explanation:
        '「watch English videos ... keep a diary in English（英語の動画を見て、英語で日記をつける）」と言っている。',
  ),
  // ── #10 volume expansion: 3級 第2部 4→10 (会話内容一致). Audio pending Kokoro;
  //    keys in ALLOWED_MISSING. Content-QA'd 2026-06-09.
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_05.mp3',
    transcripts: [
      'A: How was your weekend trip to Kyoto?',
      'B: It was great, but the trains were really crowded.',
      'A: Did you visit many temples?',
      'B: Yes, we saw five in one day.',
      'Question: How many temples did they visit?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'How many temples did they visit?',
    choices: [
      'Two temples.',
      'Three temples.',
      'Five temples.',
      'Ten temples.',
    ],
    correctIndex: 2,
    explanation: '「we saw five in one day（1日で5つ見た）」＝お寺は5つ。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_06.mp3',
    transcripts: [
      'A: I\'m thinking of buying a new bicycle.',
      'B: Why? Is something wrong with your old one?',
      'A: The brakes are broken, and it has become too small for me.',
      'B: You should try the shop near the station.',
      'Question: Why does the boy want a new bicycle?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'Why does the boy want a new bicycle?',
    choices: [
      'His old one was stolen.',
      'The brakes are broken and it is too small.',
      'He wants a faster one for racing.',
      'His friend gave him money for it.',
    ],
    correctIndex: 1,
    explanation:
        '「The brakes are broken ... too small for me（ブレーキが壊れ、小さくなった）」が理由。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_07.mp3',
    transcripts: [
      'A: Excuse me, I would like to return this shirt.',
      'B: Sure. Is there a problem with it?',
      'A: Yes, it is the wrong size. Do you have a larger one?',
      'B: Let me check the storeroom.',
      'Question: Why does the woman want to return the shirt?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'Why does the woman want to return the shirt?',
    choices: [
      'It is the wrong color.',
      'It is the wrong size.',
      'It is damaged.',
      'It was too expensive.',
    ],
    correctIndex: 1,
    explanation: '「it is the wrong size（サイズが違う）」ので返品したい。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_08.mp3',
    transcripts: [
      'A: Did you hear that our school festival is next month?',
      'B: Yes! Our class is going to run a food stall.',
      'A: What are we going to sell?',
      'B: We finally decided on takoyaki.',
      'Question: What will the class sell at the festival?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'What will the class sell at the festival?',
    choices: [
      'Drinks.',
      'Takoyaki.',
      'Ice cream.',
      'Sandwiches.',
    ],
    correctIndex: 1,
    explanation: '「decided on takoyaki（たこ焼きに決めた）」と言っている。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_09.mp3',
    transcripts: [
      'A: You look excited. What happened?',
      'B: I won first prize in the speech contest!',
      'A: Congratulations! How did you prepare?',
      'B: I practiced in front of my family every night.',
      'Question: How did the girl prepare for the contest?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'How did the girl prepare for the contest?',
    choices: [
      'She watched videos of other speeches.',
      'She practiced in front of her family.',
      'She took lessons from a teacher.',
      'She wrote many different drafts.',
    ],
    correctIndex: 1,
    explanation: '「practiced in front of my family every night（毎晩家族の前で練習した）」。',
  ),
  ListeningItem(
    part: 2,
    grade: '3',
    audioKey: 'l3_p2_10.mp3',
    transcripts: [
      'A: Are you free this Saturday?',
      'B: I have a piano lesson in the morning, but I am free after lunch.',
      'A: Let\'s go to the new aquarium then.',
      'B: Sounds good!',
      'Question: When will they go to the aquarium?',
    ],
    questionType: ListeningQuestionType.dialogueContent,
    question: 'When will they go to the aquarium?',
    choices: [
      'Saturday morning.',
      'Saturday afternoon.',
      'Sunday morning.',
      'Friday evening.',
    ],
    correctIndex: 1,
    explanation: '土曜の午前はピアノ、「free after lunch（昼食後は空いている）」→午後に水族館へ行く。',
  ),
];

const _grade3Part3 = <ListeningItem>[
  // 3級 第3部: 文内容一致 — passage/announcement
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_01.mp3',
    transcripts: [
      'Recycling is becoming more important in Japan. Many cities now have '
          'separate bins for paper, plastic, and glass. Schools also teach students '
          'about the importance of reducing waste.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What do many Japanese cities now have?',
    choices: [
      'Recycling incentive payments.',
      'Separate bins for paper, plastic, and glass.',
      'Monthly recycling collection days.',
      'Special recycling trucks for schools.',
    ],
    correctIndex: 1,
    explanation:
        '「Many cities now have separate bins for paper, plastic, and glass（紙・プラ・ガラスの分別ごみ箱がある）」。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_02.mp3',
    transcripts: [
      'Good evening. This is a weather update. A strong typhoon is approaching '
          'the Kanto region and is expected to arrive on Friday evening. Residents '
          'are advised to stay indoors and avoid unnecessary travel.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'When is the typhoon expected to arrive?',
    choices: [
      'Thursday morning.',
      'Friday morning.',
      'Friday evening.',
      'Saturday afternoon.',
    ],
    correctIndex: 2,
    explanation: '「expected to arrive on Friday evening（金曜の夜に来る見込み）」。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_03.mp3',
    transcripts: [
      'Maria moved to Japan from Brazil three years ago. At first, she struggled '
          'with the language, but she took Japanese lessons twice a week. Now she '
          'can hold conversations comfortably.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'How did Maria improve her Japanese?',
    choices: [
      'She watched Japanese TV shows every day.',
      'She took Japanese lessons twice a week.',
      'She studied at a Japanese university.',
      'She practiced with her Japanese neighbors.',
    ],
    correctIndex: 1,
    explanation:
        '「she took Japanese lessons twice a week（週2回日本語のレッスンを受けた）」で上達した。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_04.mp3',
    transcripts: [
      'Attention, shoppers. Our store will be closing in ten minutes. Please '
          'bring your items to the cashier. The store will reopen tomorrow '
          'at nine in the morning.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What time will the store reopen tomorrow?',
    choices: [
      'At eight in the morning.',
      'At nine in the morning.',
      'At ten in the morning.',
      'At eleven in the morning.',
    ],
    correctIndex: 1,
    explanation: '「reopen tomorrow at nine in the morning（明日の朝9時に再開する）」。',
  ),
  // ── #10 volume expansion: 3級 第3部 4→10 (文内容一致). Audio pending Kokoro;
  //    keys in ALLOWED_MISSING. Content-QA'd 2026-06-09.
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_05.mp3',
    transcripts: [
      'Tom started a small vegetable garden behind his house last year. He grows '
          'tomatoes, carrots, and beans. Every morning before school, he waters the '
          'plants and checks if any vegetables are ready to pick.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What does Tom do every morning before school?',
    choices: [
      'He sells vegetables at the market.',
      'He waters the plants and checks them.',
      'He cooks breakfast for his family.',
      'He buys seeds at the garden store.',
    ],
    correctIndex: 1,
    explanation:
        '「Every morning before school, he waters the plants and checks（毎朝登校前に水やりと確認をする）」。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_06.mp3',
    transcripts: [
      'Welcome to the Central Library. Please remember that food and drinks are '
          'not allowed inside. If you want to borrow books, you will need a library '
          'card. The card is free for all city residents.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What do you need in order to borrow books?',
    choices: [
      'A student ID.',
      'A library card.',
      'A reservation.',
      'A small fee.',
    ],
    correctIndex: 1,
    explanation: '「you will need a library card（図書館カードが必要）」と言っている。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_07.mp3',
    transcripts: [
      'Last summer, our school held a charity event to help children in need. '
          'Students sold handmade crafts and baked goods. We raised over fifty '
          'thousand yen and sent it to a local children\'s home.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What did the students do at the charity event?',
    choices: [
      'They cleaned a local park.',
      'They sold crafts and baked goods.',
      'They performed a concert.',
      'They collected old clothes.',
    ],
    correctIndex: 1,
    explanation:
        '「Students sold handmade crafts and baked goods（手作りの工芸品と焼き菓子を売った）」。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_08.mp3',
    transcripts: [
      'Attention, passengers. The 10:30 train to Osaka has been delayed by about '
          'twenty minutes because of heavy rain. We are very sorry for the '
          'inconvenience. Please wait on platform three.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why was the train delayed?',
    choices: [
      'There was an accident.',
      'There was heavy rain.',
      'There was a signal problem.',
      'There were too many passengers.',
    ],
    correctIndex: 1,
    explanation: '「delayed ... because of heavy rain（大雨のため遅延）」。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_09.mp3',
    transcripts: [
      'Kenta loves playing soccer, but last month he hurt his leg during a game. '
          'The doctor told him to rest for three weeks. Now he is better and can '
          'play again with his team.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why couldn\'t Kenta play soccer last month?',
    choices: [
      'He was too busy with studying.',
      'He hurt his leg during a game.',
      'He moved to a new city.',
      'His team was already full.',
    ],
    correctIndex: 1,
    explanation: '「last month he hurt his leg during a game（先月、試合で足をけがした）」から。',
  ),
  ListeningItem(
    part: 3,
    grade: '3',
    audioKey: 'l3_p3_10.mp3',
    transcripts: [
      'Thank you for visiting the art museum. The special exhibition on the second '
          'floor closes at five o\'clock today. The museum shop on the first floor '
          'will stay open until six.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What time does the special exhibition close today?',
    choices: [
      'At four o\'clock.',
      'At five o\'clock.',
      'At six o\'clock.',
      'At seven o\'clock.',
    ],
    correctIndex: 1,
    explanation:
        '「the special exhibition ... closes at five today（特別展は今日5時に閉まる）」。',
  ),
];

// ── 英検準2級 ────────────────────────────────────────────────────────────────

const _gradePre2Part1 = <ListeningItem>[
  // 準2級 第1部: 会話内容一致 — hear dialogue + spoken question
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_01.mp3',
    transcripts: [
      'A: I\'m thinking about taking a gap year before university.',
      'B: That sounds interesting. What would you do?',
      'A: I\'d like to travel in Southeast Asia and volunteer at schools.',
      'B: That would certainly broaden your horizons.',
      'Question: What does the boy plan to do during his gap year?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What does the boy plan to do during his gap year?',
    choices: [
      'Study at a foreign university.',
      'Travel and volunteer at schools in Southeast Asia.',
      'Work at an international company.',
      'Take an intensive language course abroad.',
    ],
    correctIndex: 1,
    explanation:
        'A は「travel in Southeast Asia and volunteer at schools（東南アジアを旅して学校でボランティアをする）」と述べている。これが gap year の計画。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_02.mp3',
    transcripts: [
      'A: Have you decided on a major for university?',
      'B: I\'m torn between environmental science and computer science.',
      'A: Those are quite different fields.',
      'B: Yes, but both deal with problems that affect the future.',
      'Question: What two majors is the girl considering?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What two majors is the girl considering?',
    choices: [
      'Biology and chemistry.',
      'Environmental science and computer science.',
      'Physics and mathematics.',
      'Economics and political science.',
    ],
    correctIndex: 1,
    explanation:
        'B の「torn between environmental science and computer science」が答え。be torn between A and B＝AとBの間で迷う、の意味。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_03.mp3',
    transcripts: [
      'A: Our school is planning a cultural exchange with a school in Australia.',
      'B: That\'s exciting! How long will the exchange students stay?',
      'A: Two weeks. They\'ll attend classes and stay with host families.',
      'B: I might apply to be a host.',
      'Question: How long will the exchange students stay?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'How long will the exchange students stay?',
    choices: [
      'One week.',
      'Two weeks.',
      'One month.',
      'One semester.',
    ],
    correctIndex: 1,
    explanation: 'A が「Two weeks（2週間）。授業に出て、ホストファミリーに泊まる」と答えている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_04.mp3',
    transcripts: [
      'A: Did you see the article about electric vehicles?',
      'B: Yes. It said the government plans to ban gasoline cars by 2035.',
      'A: That\'s only about ten years away.',
      'B: Right. The transition will be a big challenge for the auto industry.',
      'Question: What does the article say the government plans to do?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What does the article say the government plans to do?',
    choices: [
      'Build more charging stations by 2030.',
      'Ban gasoline cars by 2035.',
      'Reduce car emissions by fifty percent.',
      'Offer subsidies for electric vehicle buyers.',
    ],
    correctIndex: 1,
    explanation:
        'B が「the government plans to ban gasoline cars by 2035（政府は2035年までにガソリン車を禁止する予定）」と記事の内容を説明している。',
  ),
  // ── Studio expansion 2026-06-13: 準2級 第1部 toward the 30-item target ──────────
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_05.mp3',
    transcripts: [
      'A: Have you decided which club to join this year?',
      'B: I am torn between the photography club and the drama club.',
      'A: You were great in the school play last year, though.',
      'B: True. Maybe I will go with drama after all.',
      'Question: Which club will the girl most likely choose?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Which club will the girl most likely choose?',
    choices: [
      'The photography club.',
      'The drama club.',
      'The tennis club.',
      'The science club.',
    ],
    correctIndex: 1,
    explanation:
        'B は最後に「I will go with drama after all（やっぱり演劇部にする）」と述べている。昨年の school play での活躍も後押し。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_06.mp3',
    transcripts: [
      'A: My parents said I can get a part-time job this summer.',
      'B: That is great. Will you work every day?',
      'A: No, only on weekends. I want to keep studying on weekdays.',
      'B: That sounds like a good balance.',
      'Question: When does the boy plan to work?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'When does the boy plan to work?',
    choices: [
      'Every weekday.',
      'Every day after school.',
      'Only on weekends.',
      'Only during exams.',
    ],
    correctIndex: 2,
    explanation: 'A は「only on weekends（週末だけ）」働き、平日は勉強を続けると述べている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_07.mp3',
    transcripts: [
      'A: I heard the school trip destination was changed.',
      'B: Yes, instead of Kyoto we are going to Hiroshima this year.',
      'A: Really? Why the change?',
      'B: The teachers wanted us to learn about peace and history.',
      'Question: Where will the students go on the school trip?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Where will the students go on the school trip?',
    choices: [
      'Hiroshima.',
      'Kyoto.',
      'Nara.',
      'Tokyo.',
    ],
    correctIndex: 0,
    explanation:
        'B が「instead of Kyoto we are going to Hiroshima（京都の代わりに広島へ行く）」と述べている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_08.mp3',
    transcripts: [
      'A: Excuse me, can I keep this book one more week?',
      'B: Let me check. Yes, I can extend it until next Friday.',
      'A: Thank you. I have not finished reading it yet.',
      'B: No problem. Just return it by then.',
      'Question: What does the woman want to do?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What does the woman want to do?',
    choices: [
      'Return the book today.',
      'Extend the loan of her book.',
      'Borrow a new book.',
      'Pay a late fee.',
    ],
    correctIndex: 1,
    explanation:
        'A は「can I keep this book one more week（あと1週間借りていられますか）」と本の貸出延長を頼んでいる。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_09.mp3',
    transcripts: [
      'A: Should we still go hiking tomorrow?',
      'B: The forecast says it will rain in the afternoon.',
      'A: Then let us start early and come back before lunch.',
      'B: Good idea. I will set my alarm for six.',
      'Question: What will they do because of the weather?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What will they do because of the weather?',
    choices: [
      'Cancel the hike.',
      'Postpone it to next week.',
      'Start the hike early.',
      'Go shopping instead.',
    ],
    correctIndex: 2,
    explanation:
        'A が「start early and come back before lunch（早く出発して昼前に戻る）」と提案し、B も同意。雨は午後の予報。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_10.mp3',
    transcripts: [
      'A: Have you tried that new app for memorizing English words?',
      'B: Yes, it reminds me to review words every day.',
      'A: Does it really help?',
      'B: Definitely. My vocabulary has improved a lot this month.',
      'Question: Why does the girl like the app?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Why does the girl like the app?',
    choices: [
      'It is free to use.',
      'It plays word games.',
      'It translates whole sentences.',
      'It reminds her to review words every day.',
    ],
    correctIndex: 3,
    explanation:
        'B は「it reminds me to review words every day（毎日単語を復習するよう促してくれる）」と述べ、語彙が増えたと言っている。',
  ),
  // ── Studio expansion 2026-06-13 (cont.): 準2級 第1部 to 15 (→30 total) ──────────
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_11.mp3',
    transcripts: [
      'A: Excuse me, how can I get to the city library from here?',
      'B: Go straight for two blocks and turn left at the bank. It is next to the post office.',
      'A: Thank you very much.',
      'B: You are welcome.',
      'Question: Where is the city library?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Where is the city library?',
    choices: [
      'Across from the station.',
      'Next to the post office.',
      'Next to the bank.',
      'Behind the school.',
    ],
    correctIndex: 1,
    explanation: 'B は「It is next to the post office（郵便局のとなり）」と図書館の場所を教えている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_12.mp3',
    transcripts: [
      'A: What do you recommend here?',
      'B: The blueberry pancakes are very popular.',
      'A: That sounds good. I will try them.',
      'B: Great choice. Would you like something to drink?',
      'Question: What will the man order?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What will the man order?',
    choices: [
      'The blueberry pancakes.',
      'A cup of coffee.',
      'A sandwich.',
      'Nothing yet.',
    ],
    correctIndex: 0,
    explanation: 'A は「I will try them（それにします）」と blueberry pancakes を注文している。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_13.mp3',
    transcripts: [
      'A: I cannot find my phone anywhere.',
      'B: Did you check the classroom? You used it during lunch.',
      'A: You are right. I will go back and look.',
      'B: I hope you find it.',
      'Question: What will the girl do next?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What will the girl do next?',
    choices: [
      'Buy a new phone.',
      'Call her parents.',
      'Go back to the classroom.',
      'Borrow a phone.',
    ],
    correctIndex: 2,
    explanation: 'B の助言を受け A は「I will go back and look（戻って探す）」＝教室へ戻ると述べている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_14.mp3',
    transcripts: [
      'A: I want to buy a present for Mika. Any ideas?',
      'B: She loves reading, so how about a book?',
      'A: She already has so many. Maybe a nice bookmark instead.',
      'B: That is a thoughtful idea.',
      'Question: What will the woman probably buy?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What will the woman probably buy?',
    choices: [
      'A book.',
      'A bookmark.',
      'A bag.',
      'A pen.',
    ],
    correctIndex: 1,
    explanation: 'A は本は多いので「a nice bookmark instead（代わりに素敵なしおり）」を買うと述べている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2',
    audioKey: 'lp2_p1_15.mp3',
    transcripts: [
      'A: Do you want to see a movie this Saturday?',
      'B: Actually, there is a science exhibition I really want to visit.',
      'A: That sounds fun. Let us go there instead.',
      'B: Great. It opens at ten.',
      'Question: What will they do on Saturday?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What will they do on Saturday?',
    choices: [
      'See a movie.',
      'Stay home.',
      'Go shopping.',
      'Visit a science exhibition.',
    ],
    correctIndex: 3,
    explanation: 'A が「Let us go there instead（代わりにそこへ行こう）」と科学展に行くことに同意している。',
  ),
];

const _gradePre2Part2 = <ListeningItem>[
  // 準2級 第2部: 文内容一致 — passage/monologue
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_01.mp3',
    transcripts: [
      'Social media has significantly changed how teenagers communicate. '
          'A recent study found that teenagers spend an average of three hours '
          'per day on social media platforms. While it helps them stay connected '
          'with friends, experts warn that excessive use can lead to anxiety and '
          'poor sleep quality.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question:
        'According to the study, how much time do teenagers spend on social media daily?',
    choices: [
      'One hour.',
      'Two hours.',
      'Three hours.',
      'Four hours.',
    ],
    correctIndex: 2,
    explanation:
        '本文に「spend an average of three hours per day on social media（1日平均3時間SNSに費やす）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_02.mp3',
    transcripts: [
      'Okinawa is famous for the longevity of its residents. Many people there '
          'live past the age of one hundred. Researchers believe the reasons '
          'include a healthy plant-based diet, strong social connections, '
          'and a sense of purpose called "ikigai."',
    ],
    questionType: ListeningQuestionType.passageContent,
    question:
        'What do researchers NOT mention as a reason for longevity in Okinawa?',
    choices: [
      'A healthy plant-based diet.',
      'Strong social connections.',
      'A sense of purpose called ikigai.',
      'Regular high-intensity exercise.',
    ],
    correctIndex: 3,
    explanation:
        '本文が挙げる理由は plant-based diet・social connections・ikigai の3つ。high-intensity exercise（激しい運動）は述べられていない＝NOT問題の答え。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_03.mp3',
    transcripts: [
      'This is a notice from Greenfield Public Library. Due to renovations, '
          'the library will be closed from Monday, June ninth to Friday, June '
          'thirteenth. It will reopen on Monday, June sixteenth with extended '
          'hours until nine p.m. on weekdays.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'When will the library reopen?',
    choices: [
      'Friday, June thirteenth.',
      'Saturday, June fourteenth.',
      'Sunday, June fifteenth.',
      'Monday, June sixteenth.',
    ],
    correctIndex: 3,
    explanation:
        '本文に「reopen on Monday, June sixteenth（6月16日月曜に再開）」とある。改装休館は9日〜13日。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_04.mp3',
    transcripts: [
      'Urban farming is growing in popularity in many cities around the world. '
          'Rooftop gardens and vertical farms allow cities to produce fresh '
          'vegetables locally, reducing the need to transport food long distances. '
          'Some cities have created programs to teach residents how to grow their own food.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What is one benefit of urban farming mentioned in the passage?',
    choices: [
      'It creates new job opportunities in the construction sector.',
      'It reduces the need to transport food long distances.',
      'It lowers the overall cost of living in cities.',
      'It eliminates the need for traditional grocery stores.',
    ],
    correctIndex: 1,
    explanation:
        '本文に「reducing the need to transport food long distances（食料を長距離輸送する必要を減らす）」と都市農業の利点が述べられている。',
  ),
  // ── Studio expansion 2026-06-13: 準2級 第2部 toward the 30-item target ──────────
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_05.mp3',
    transcripts: [
      'Online learning has become much more common in recent years. Students '
          'can now take courses from universities around the world without '
          'leaving home. One major advantage is flexibility: learners can study '
          'at their own pace and review lessons as many times as they need. '
          'However, it requires strong self-discipline to stay motivated.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question:
        'According to the passage, what is one advantage of online learning?',
    choices: [
      'It is always completely free.',
      'Learners can study at their own pace.',
      'It does not require the internet.',
      'Teachers visit students at home.',
    ],
    correctIndex: 1,
    explanation:
        '本文に「learners can study at their own pace（自分のペースで学べる）」と利点が述べられている。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_06.mp3',
    transcripts: [
      'Attention residents. Starting next month, the city will collect plastic '
          'bottles every Tuesday instead of every other week. Please remove the '
          'caps and rinse the bottles before putting them out. This change is '
          'part of the city plan to increase its recycling rate.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What change will happen next month?',
    choices: [
      'Plastic bottles will be collected more often.',
      'Recycling will stop completely.',
      'Caps will no longer need to be removed.',
      'Collection will move to Sunday.',
    ],
    correctIndex: 0,
    explanation:
        '放送に「collect plastic bottles every Tuesday instead of every other week（隔週でなく毎週火曜に回収）」とあり、回収の頻度が増える。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_07.mp3',
    transcripts: [
      'Many teenagers do not get enough sleep. Doctors recommend that people '
          'aged thirteen to eighteen sleep about nine hours each night. A lack '
          'of sleep can make it harder to concentrate at school and may affect '
          'mood. Experts suggest avoiding screens before bedtime to sleep better.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What do experts suggest in order to sleep better?',
    choices: [
      'Drinking coffee at night.',
      'Studying until very late.',
      'Avoiding screens before bedtime.',
      'Sleeping only six hours.',
    ],
    correctIndex: 2,
    explanation:
        '本文に「avoiding screens before bedtime（就寝前に画面を避ける）」とよく眠るための助言がある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_08.mp3',
    transcripts: [
      'Welcome to the city science museum. We are pleased to announce a special '
          'exhibition on space exploration, opening this Saturday. Visitors can '
          'see real models of rockets and try a virtual spacewalk. The exhibition '
          'is free for students with a valid school ID.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Who can see the special exhibition for free?',
    choices: [
      'Everyone who visits.',
      'Only adults.',
      'Only museum members.',
      'Students with a valid school ID.',
    ],
    correctIndex: 3,
    explanation:
        '放送に「free for students with a valid school ID（有効な学生証を持つ生徒は無料）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_09.mp3',
    transcripts: [
      'Bees play a vital role in nature. As they move from flower to flower '
          'collecting nectar, they carry pollen, which helps plants produce '
          'fruits and seeds. Without bees, many of the fruits and vegetables we '
          'eat would become much harder to grow. That is why protecting bees is '
          'so important.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why are bees important according to the passage?',
    choices: [
      'They produce honey to sell.',
      'They keep gardens clean.',
      'They help plants produce fruits and seeds.',
      'They scare away other insects.',
    ],
    correctIndex: 2,
    explanation:
        '本文に「carry pollen, which helps plants produce fruits and seeds（花粉を運び、植物が実や種を作るのを助ける）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_10.mp3',
    transcripts: [
      'The school library is holding a reading challenge this summer. Students '
          'who read at least ten books will receive a certificate, and the top '
          'reader in each grade will win a gift card. Librarians hope the '
          'challenge will encourage students to discover new authors and enjoy '
          'reading more.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What will students who read at least ten books receive?',
    choices: [
      'A certificate.',
      'A gift card.',
      'A free book.',
      'Extra homework.',
    ],
    correctIndex: 0,
    explanation:
        '本文に「read at least ten books will receive a certificate（10冊以上読むと賞状がもらえる）」とある。gift card は各学年の最多読者のみ。',
  ),
  // ── Studio expansion 2026-06-13 (cont.): 準2級 第2部 to 15 (→30 total) ──────────
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_11.mp3',
    transcripts: [
      'Attention passengers. Due to a signal check, the express train to Central '
          'Station will be delayed by about fifteen minutes. The local train on '
          'platform three will depart on time. We apologize for any inconvenience.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Which train will leave on time?',
    choices: [
      'The express train.',
      'The local train on platform three.',
      'All of the trains.',
      'None of the trains.',
    ],
    correctIndex: 1,
    explanation:
        '放送に「The local train on platform three will depart on time（3番線の普通列車は定刻に発車）」とある。急行は遅延。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_12.mp3',
    transcripts: [
      'Walking is one of the simplest ways to stay healthy. Just thirty minutes '
          'a day can improve your heart health and reduce stress. Unlike many '
          'sports, walking needs no special equipment and can be done almost '
          'anywhere. Doctors often recommend it for people of all ages.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What is one benefit of walking mentioned in the passage?',
    choices: [
      'It improves heart health and reduces stress.',
      'It builds large muscles quickly.',
      'It requires special equipment.',
      'It can only be done in a gym.',
    ],
    correctIndex: 0,
    explanation:
        '本文に「improve your heart health and reduce stress（心臓の健康を改善しストレスを減らす）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_13.mp3',
    transcripts: [
      'Our school festival will be held next Saturday from ten in the morning. '
          'Each class has prepared games, food stalls, and performances. Visitors '
          'are asked to wear a name tag at the entrance. We look forward to '
          'seeing everyone there.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What are visitors asked to do?',
    choices: [
      'Arrive before nine.',
      'Bring their own food.',
      'Pay an entrance fee.',
      'Wear a name tag at the entrance.',
    ],
    correctIndex: 3,
    explanation: '放送に「wear a name tag at the entrance（入口で名札をつける）」と来場者への依頼がある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_14.mp3',
    transcripts: [
      'Every year, a huge amount of plastic ends up in the ocean. This waste can '
          'harm sea animals that mistake it for food. Some countries have started '
          'banning single-use plastic bags to reduce the problem. Scientists say '
          'that small daily choices can make a big difference.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What have some countries started doing?',
    choices: [
      'Feeding sea animals.',
      'Cleaning every beach daily.',
      'Banning single-use plastic bags.',
      'Building new factories.',
    ],
    correctIndex: 2,
    explanation:
        '本文に「banning single-use plastic bags（使い捨てレジ袋を禁止する）」と一部の国の対策が述べられている。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2',
    audioKey: 'lp2_p2_15.mp3',
    transcripts: [
      'A new bakery café will open downtown next Monday. For the first week, all '
          'customers will receive a free drink with any purchase. The café will '
          'be open from seven in the morning to eight in the evening, every day '
          'except Wednesday.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'When is the café closed?',
    choices: [
      'On Monday.',
      'On Sunday.',
      'On Wednesday.',
      'It is never closed.',
    ],
    correctIndex: 2,
    explanation: '本文に「every day except Wednesday（水曜以外毎日）」とあり、水曜は休み。',
  ),
];

// ── 英検2級 ─────────────────────────────────────────────────────────────────

const _grade2Part1 = <ListeningItem>[
  // 2級 第1部: 会話応答選択 — hear dialogue + spoken question
  ListeningItem(
    part: 1,
    grade: '2',
    audioKey: 'l2_p1_01.mp3',
    transcripts: [
      'A: The city council voted against the new park development proposal.',
      'B: That\'s disappointing. There are so few green spaces downtown.',
      'A: Apparently, budget constraints were the main reason.',
      'B: They should reconsider. Green spaces improve residents\' mental health.',
      'Question: Why did the city council vote against the proposal?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Why did the city council vote against the proposal?',
    choices: [
      'Because residents opposed the plan.',
      'Because budget constraints were the main reason.',
      'Because the location was unsuitable.',
      'Because the environmental impact was too great.',
    ],
    correctIndex: 1,
    explanation:
        'A が「budget constraints were the main reason（予算の制約が主な理由）」と説明している。',
  ),
  ListeningItem(
    part: 1,
    grade: '2',
    audioKey: 'l2_p1_02.mp3',
    transcripts: [
      'A: I\'ve been thinking about switching to a vegetarian diet.',
      'B: Really? What\'s prompting that?',
      'A: Mostly environmental concerns. Meat production has a huge carbon footprint.',
      'B: That\'s true. Though you\'ll need to make sure you get enough protein.',
      'Question: Why is the person considering becoming vegetarian?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Why is the person considering becoming vegetarian?',
    choices: [
      'For health reasons.',
      'Due to food allergies.',
      'Because of environmental concerns.',
      'To save money on groceries.',
    ],
    correctIndex: 2,
    explanation:
        'A が「Mostly environmental concerns（主に環境への懸念）。食肉生産は炭素排出が大きい」と理由を述べている。',
  ),
  ListeningItem(
    part: 1,
    grade: '2',
    audioKey: 'l2_p1_03.mp3',
    transcripts: [
      'A: Have you heard about the new language exchange app?',
      'B: Yes, I tried it last month. It connects you with native speakers worldwide.',
      'A: Did you find it useful for improving your speaking skills?',
      'B: Definitely. I speak with a French partner every Tuesday evening.',
      'Question: How often does the boy speak with his French partner?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'How often does the boy speak with his French partner?',
    choices: [
      'Every day.',
      'Twice a week.',
      'Every Tuesday evening.',
      'On weekends only.',
    ],
    correctIndex: 2,
    explanation:
        'B が「I speak with a French partner every Tuesday evening（毎週火曜の夜にフランス人の相手と話す）」と答えている。Twice a week は誤り。',
  ),
  ListeningItem(
    part: 1,
    grade: '2',
    audioKey: 'l2_p1_04.mp3',
    transcripts: [
      'A: Our company is considering introducing a four-day workweek.',
      'B: That\'s an interesting idea. Do you think productivity would drop?',
      'A: Studies suggest it actually improves productivity and employee well-being.',
      'B: If the evidence supports it, I\'d be in favor.',
      'Question: What do studies suggest about a four-day workweek?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What do studies suggest about a four-day workweek?',
    choices: [
      'It reduces company profits significantly.',
      'It causes employee dissatisfaction.',
      'It improves productivity and employee well-being.',
      'It is only effective in technology companies.',
    ],
    correctIndex: 2,
    explanation:
        'A が「it actually improves productivity and employee well-being（実際は生産性と従業員の幸福度を高める）」と研究結果を述べている。',
  ),
];

const _grade2Part2 = <ListeningItem>[
  // 2級 第2部: 文内容一致 — passage/lecture
  ListeningItem(
    part: 2,
    grade: '2',
    audioKey: 'l2_p2_01.mp3',
    transcripts: [
      'Artificial intelligence is transforming the healthcare industry in '
          'remarkable ways. AI systems can now analyze medical images with '
          'accuracy comparable to experienced doctors. In some hospitals, '
          'AI is being used to predict patient deterioration before symptoms '
          'become critical, allowing for earlier intervention.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'How is AI being used in some hospitals?',
    choices: [
      'To replace all medical staff.',
      'To predict patient deterioration before symptoms become critical.',
      'To reduce the cost of medical equipment.',
      'To manage hospital scheduling systems.',
    ],
    correctIndex: 1,
    explanation:
        '本文に「AI is being used to predict patient deterioration before symptoms become critical（症状が深刻化する前に患者の悪化を予測する）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: '2',
    audioKey: 'l2_p2_02.mp3',
    transcripts: [
      'The concept of "slow travel" is gaining traction among a new generation '
          'of tourists. Rather than rushing to visit as many destinations as '
          'possible, slow travelers spend extended periods in one location. '
          'They prioritize meaningful connections with local communities and '
          'a deeper understanding of the culture.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What do slow travelers prioritize?',
    choices: [
      'Visiting as many destinations as possible.',
      'Finding the cheapest accommodation.',
      'Meaningful connections with local communities.',
      'Collecting travel points for frequent flyers.',
    ],
    correctIndex: 2,
    explanation:
        '本文に「prioritize meaningful connections with local communities（地域社会との有意義なつながりを優先する）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: '2',
    audioKey: 'l2_p2_03.mp3',
    transcripts: [
      'Good afternoon. This is an announcement from Westfield University. '
          'The registration deadline for next semester\'s courses has been '
          'extended to Friday, March fifteenth. Students who have not yet '
          'registered should log in to the student portal and complete '
          'their course selection by midnight.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'When is the new registration deadline?',
    choices: [
      'Thursday, March fourteenth.',
      'Friday, March fifteenth.',
      'Saturday, March sixteenth.',
      'Monday, March eighteenth.',
    ],
    correctIndex: 1,
    explanation: '放送に「extended to Friday, March fifteenth（3月15日金曜まで延長）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: '2',
    audioKey: 'l2_p2_04.mp3',
    transcripts: [
      'Microplastics have been found in some of the most remote locations on '
          'Earth, from the deepest ocean trenches to the tops of mountains. '
          'Scientists are concerned because these tiny particles can be ingested '
          'by marine animals and eventually enter the human food chain. '
          'Reducing single-use plastic consumption is considered a key step '
          'in addressing this problem.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question:
        'What do scientists consider a key step in addressing the microplastics problem?',
    choices: [
      'Developing better ocean filtration systems.',
      'Banning all forms of plastic packaging worldwide.',
      'Reducing single-use plastic consumption.',
      'Educating marine biologists about contamination.',
    ],
    correctIndex: 2,
    explanation:
        '本文に「Reducing single-use plastic consumption is considered a key step（使い捨てプラスチックの消費削減が重要な一歩）」とある。',
  ),
];

// ── Merged lookup table ───────────────────────────────────────────────────────

/// All listening items grouped by grade.
/// Key format: grade string as used in kEikenExams.
// ── 英検準2級プラス (2025新設, CEFR A2–B1) ──────────────────────────────────────
// Listening is 2 部 (第1部 会話応答選択 / 第2部 文内容一致), between 準2級 and 2級.
// Representative seed (4 items/部); audio via scripts/generate_listening_audio.py.
const _gradePre2PlusPart1 = <ListeningItem>[
  // 第1部: 会話応答選択 — hear a short dialogue + a spoken question, pick the answer.
  ListeningItem(
    part: 1,
    grade: 'pre2plus',
    audioKey: 'lpp_p1_01.mp3',
    transcripts: [
      'A: Excuse me, what time does the library close today?',
      'B: On weekdays it closes at eight, but today is Saturday, so it closes at six.',
      'A: Oh, I see. Thank you.',
      'Question: What time does the library close today?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What time does the library close today?',
    choices: [
      'At six.',
      'At eight.',
      'At seven.',
      'It is closed all day.',
    ],
    correctIndex: 0,
    explanation:
        'B が「today is Saturday, so it closes at six（今日は土曜なので6時に閉まる）」と述べている。平日の8時は誤り。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2plus',
    audioKey: 'lpp_p1_02.mp3',
    transcripts: [
      'A: Are you free this Sunday? I am thinking of going hiking.',
      'B: I would love to, but I promised to help my brother move.',
      'A: No problem. Maybe next time.',
      'Question: Why can the man not go hiking?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Why can the man not go hiking?',
    choices: [
      'He promised to help his brother move.',
      'He does not enjoy hiking.',
      'He has to work on Sunday.',
      'The weather will be bad.',
    ],
    correctIndex: 0,
    explanation:
        'B が「I promised to help my brother move（兄/弟の引っ越しを手伝うと約束した）」と理由を述べている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2plus',
    audioKey: 'lpp_p1_03.mp3',
    transcripts: [
      'A: I think I left my umbrella on the train.',
      'B: You should call the station\'s lost and found. They often keep items for a few days.',
      'A: Good idea. I will do that.',
      'Question: What does the man suggest the woman do?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What does the man suggest the woman do?',
    choices: [
      'Call the station\'s lost and found.',
      'Buy a new umbrella.',
      'Get off at the next station.',
      'Check the train schedule.',
    ],
    correctIndex: 0,
    explanation:
        'B が「call the station ... lost and found（駅の遺失物取扱所に電話するとよい）」と勧めている。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre2plus',
    audioKey: 'lpp_p1_04.mp3',
    transcripts: [
      'A: This restaurant is really crowded tonight.',
      'B: Yes, their seafood pasta is supposed to be excellent.',
      'A: Then I will order that.',
      'Question: What will the woman order?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What will the woman order?',
    choices: [
      'The seafood pasta.',
      'A green salad.',
      'Nothing — they will leave.',
      'The same as the man.',
    ],
    correctIndex: 0,
    explanation:
        'A が seafood pasta を勧められ「Then I will order that（ではそれを注文する）」と答えている。',
  ),
];

const _gradePre2PlusPart2 = <ListeningItem>[
  // 第2部: 文内容一致 — hear a short announcement/passage, answer a content question.
  ListeningItem(
    part: 2,
    grade: 'pre2plus',
    audioKey: 'lpp_p2_01.mp3',
    transcripts: [
      'Attention shoppers. The supermarket will close thirty minutes early '
          'today, at eight thirty, for cleaning. Please bring your items to the '
          'checkout by eight fifteen. We are sorry for any inconvenience.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What time should shoppers finish at the checkout?',
    choices: [
      'By eight fifteen.',
      'By eight thirty.',
      'By nine o\'clock.',
      'By eight o\'clock.',
    ],
    correctIndex: 0,
    explanation:
        '放送に「bring your items to the checkout by eight fifteen（8時15分までにレジへ）」とある。閉店は8時30分。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2plus',
    audioKey: 'lpp_p2_02.mp3',
    transcripts: [
      'This weekend\'s outdoor music festival has been moved indoors to the '
          'city hall because rain is forecast. Tickets bought online are still '
          'valid. The festival will start at noon on Saturday.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why was the festival moved indoors?',
    choices: [
      'Because rain is forecast.',
      'Because the tickets sold out.',
      'Because the city hall is larger.',
      'Because it now starts earlier.',
    ],
    correctIndex: 0,
    explanation:
        '放送に「moved indoors ... because rain is forecast（雨の予報のため屋内に変更）」とある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2plus',
    audioKey: 'lpp_p2_03.mp3',
    transcripts: [
      'Many people enjoy growing vegetables at home. Tomatoes are a popular '
          'choice because they grow quickly and need only sunlight and water. '
          'Beginners are often surprised at how much one small plant can produce.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why are tomatoes popular with beginners?',
    choices: [
      'They grow quickly and need only sunlight and water.',
      'They are cheaper than other vegetables.',
      'They taste better than any other vegetable.',
      'They can grow without any sunlight.',
    ],
    correctIndex: 0,
    explanation:
        '本文に「they grow quickly and need only sunlight and water（早く育ち、日光と水だけでよい）」とトマトが初心者に人気の理由がある。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre2plus',
    audioKey: 'lpp_p2_04.mp3',
    transcripts: [
      'The school library is starting a new program next month. Students will '
          'be able to borrow up to five books at a time, instead of three. The '
          'loan period will also be extended from two weeks to three weeks.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What is one change in the new program?',
    choices: [
      'Students can borrow more books at a time.',
      'The library will open earlier each day.',
      'Books must be returned within one week.',
      'The library will buy more computers.',
    ],
    correctIndex: 0,
    explanation:
        '本文に「borrow up to five books at a time, instead of three（一度に3冊でなく5冊まで借りられる）」と新制度の変更点がある。',
  ),
];

// ── 英検準1級 (CEFR B2) ───────────────────────────────────────────────────────
// Listening is 3 部 / 29問: 第1部 会話内容一致(12) / 第2部 文内容一致(~150語 学術
// パッセージ, 12) / 第3部 Real-Life形式(状況設定が印刷, 5). Representative seed
// (4 items/部); B2 themes (business/academic/social). Audio via Kokoro.
const _gradePre1Part1 = <ListeningItem>[
  // 第1部: 会話の内容一致 — longer B2 dialogue + a spoken question.
  ListeningItem(
    part: 1,
    grade: 'pre1',
    audioKey: 'lpre1_p1_01.mp3',
    transcripts: [
      'A: Have you had a chance to review the quarterly figures I sent?',
      'B: I skimmed them, but I am concerned the marketing costs have risen sharply.',
      'A: That is because we expanded into two new regions.',
      'B: I see. Then it might pay off next quarter.',
      'Question: Why have the marketing costs risen?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'Why have the marketing costs risen?',
    choices: [
      'Because the company expanded into new regions.',
      'Because the quarterly figures were wrong.',
      'Because the marketing campaign failed.',
      'Because of next quarter\'s budget cuts.',
    ],
    correctIndex: 0,
    explanation:
        'A の「That is because we expanded into two new regions（2つの新しい地域に進出したからだ）」が理由。マーケティング費の増加は新地域への進出が原因。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre1',
    audioKey: 'lpre1_p1_02.mp3',
    transcripts: [
      'A: Professor, I am struggling to narrow down my thesis topic.',
      'B: That is common. Try focusing on a single case study rather than the whole field.',
      'A: That makes sense. I will look at one company in depth.',
      'Question: What does the professor advise the student to do?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What does the professor advise the student to do?',
    choices: [
      'Focus on a single case study.',
      'Change her field of study.',
      'Read everything in the whole field.',
      'Find a different professor.',
    ],
    correctIndex: 0,
    explanation:
        '教授の助言は「focus on a single case study rather than the whole field（分野全体でなく一つの事例研究に絞る）」。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre1',
    audioKey: 'lpre1_p1_03.mp3',
    transcripts: [
      'A: I would like to change my flight to an earlier one on Friday.',
      'B: There is a seat on the nine a.m., but there is a change fee of fifty dollars.',
      'A: That is fine. Please go ahead.',
      'Question: What will the woman most likely do?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What will the woman most likely do?',
    choices: [
      'Pay the fee and take the earlier flight.',
      'Cancel her trip entirely.',
      'Keep her original flight.',
      'Fly on Saturday instead.',
    ],
    correctIndex: 0,
    explanation:
        '変更手数料50ドルと言われ「That is fine. Please go ahead.」と答えた＝手数料を払って早い便に変える。',
  ),
  ListeningItem(
    part: 1,
    grade: 'pre1',
    audioKey: 'lpre1_p1_04.mp3',
    transcripts: [
      'A: Did you hear they are turning the old factory into a community center?',
      'B: Yes, though some residents worry about the increased traffic.',
      'A: True, but it will create jobs and a space for local events.',
      'Question: What is one concern some residents have?',
    ],
    questionType: ListeningQuestionType.dialogueQA,
    question: 'What is one concern some residents have?',
    choices: [
      'The increased traffic.',
      'The loss of local jobs.',
      'A rise in their taxes.',
      'The closing of the factory.',
    ],
    correctIndex: 0,
    explanation:
        'B が「some residents worry about the increased traffic（交通量の増加を心配する住民がいる）」と述べている。',
  ),
];

const _gradePre1Part2 = <ListeningItem>[
  // 第2部: 文内容一致 — short academic passage (B2) + a content question.
  ListeningItem(
    part: 2,
    grade: 'pre1',
    audioKey: 'lpre1_p2_01.mp3',
    transcripts: [
      'Coral reefs support roughly a quarter of all marine species, yet they '
          'cover less than one percent of the ocean floor. Rising sea '
          'temperatures cause corals to expel the algae that give them both '
          'their color and their food, a process called bleaching. If the water '
          'cools in time, the coral can recover, but repeated bleaching often '
          'proves fatal. Scientists are now breeding heat-resistant corals to '
          'give reefs a better chance of survival.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What are scientists doing to help coral reefs?',
    choices: [
      'Breeding heat-resistant corals.',
      'Lowering the ocean temperature.',
      'Moving reefs into deeper water.',
      'Removing all algae from the corals.',
    ],
    correctIndex: 0,
    explanation:
        '最後の文「breeding heat-resistant corals（熱に強いサンゴを繁殖させている）」が科学者の取り組み。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre1',
    audioKey: 'lpre1_p2_02.mp3',
    transcripts: [
      'The popularity of tea in Britain owes much to the seventeenth century, '
          'when it arrived from China as an expensive luxury. At first only the '
          'wealthy could afford it, but as trade increased, prices fell and tea '
          'spread to ordinary households. By the nineteenth century it had '
          'become the national drink, served at every level of society and even '
          'shaping daily routines such as the afternoon tea break.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why did tea spread to ordinary households?',
    choices: [
      'Increased trade lowered its price.',
      'The wealthy stopped drinking it.',
      'It began to be grown in Britain.',
      'The government encouraged people to drink it.',
    ],
    correctIndex: 0,
    explanation:
        '「as trade increased, prices fell（貿易が増えて価格が下がった）」ことで一般家庭に広まった。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre1',
    audioKey: 'lpre1_p2_03.mp3',
    transcripts: [
      'Recent studies suggest that the brain does much of its housekeeping '
          'during sleep. While we rest, it clears away waste that builds up '
          'during waking hours and strengthens the connections involved in '
          'learning. This may explain why students who sleep well after '
          'studying tend to remember more than those who stay up late. Far from '
          'being wasted time, sleep appears to be an active and essential part '
          'of how we learn.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'Why do well-rested students tend to remember more?',
    choices: [
      'Sleep strengthens the connections used in learning.',
      'They simply study for longer hours.',
      'They wake up earlier in the morning.',
      'They eat a healthier breakfast.',
    ],
    correctIndex: 0,
    explanation:
        '睡眠が「strengthens the connections involved in learning（学習に関わる結合を強める）」ため、よく眠った学生はよく覚える。',
  ),
  ListeningItem(
    part: 2,
    grade: 'pre1',
    audioKey: 'lpre1_p2_04.mp3',
    transcripts: [
      'Machine translation has improved dramatically in the past decade. Early '
          'systems translated word by word and often produced awkward results. '
          'Modern systems, trained on vast amounts of text, can capture context '
          'and produce far more natural sentences. Still, they struggle with '
          'humor, cultural references, and ambiguity, areas where human '
          'translators remain essential. Experts believe the two will '
          'increasingly work together rather than one replacing the other.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: 'What do experts believe about the future of translation?',
    choices: [
      'Humans and machines will increasingly work together.',
      'Machines will completely replace human translators.',
      'Human translators will soon disappear.',
      'Machine translation will stop improving.',
    ],
    correctIndex: 0,
    explanation:
        '専門家は「the two will increasingly work together（人間と機械はますます協働する）」と考えている。',
  ),
];

const _gradePre1Part3 = <ListeningItem>[
  // 第3部: Real-Life形式 — a printed situation, then an announcement is heard.
  ListeningItem(
    part: 3,
    grade: 'pre1',
    audioKey: 'lpre1_p3_01.mp3',
    transcripts: [
      'Attention passengers on Flight 207 to Seattle. Because of a mechanical '
          'issue, departure has been delayed by about two hours. Passengers may '
          'collect a meal voucher at the service desk near Gate 12. We will '
          'announce the new boarding time as soon as it is confirmed.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: '状況: あなたは空港の乗客です。\nWhat should passengers do now?',
    choices: [
      'Collect a meal voucher at the service desk.',
      'Board the plane immediately at Gate 12.',
      'Rebook on a different airline.',
      'Leave the airport and go home.',
    ],
    correctIndex: 0,
    explanation:
        'アナウンスは「collect a meal voucher at the service desk（サービスデスクで食事券を受け取れる）」と案内している。',
  ),
  ListeningItem(
    part: 3,
    grade: 'pre1',
    audioKey: 'lpre1_p3_02.mp3',
    transcripts: [
      'Welcome to the team. Your first week will mostly be training. On Monday '
          'and Tuesday you will shadow a senior colleague. From Wednesday, you '
          'will start handling simple tasks on your own, but someone will '
          'always be available if you have questions.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: '状況: あなたは新入社員です。\nWhat will you do on Wednesday?',
    choices: [
      'Start handling simple tasks on your own.',
      'Shadow a senior colleague all day.',
      'Finish all of your training.',
      'Take the day off.',
    ],
    correctIndex: 0,
    explanation:
        '「From Wednesday, you will start handling simple tasks on your own（水曜から簡単な仕事を一人で始める）」。',
  ),
  ListeningItem(
    part: 3,
    grade: 'pre1',
    audioKey: 'lpre1_p3_03.mp3',
    transcripts: [
      'The special exhibition on the second floor closes at four today, half an '
          'hour earlier than usual, to prepare for an evening event. The '
          'permanent galleries on the first and third floors stay open until '
          'six. Photography is allowed everywhere except in the special '
          'exhibition.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: '状況: あなたは美術館にいます。\nWhere is photography NOT allowed?',
    choices: [
      'In the special exhibition.',
      'On the first floor.',
      'On the third floor.',
      'Nowhere — it is allowed everywhere.',
    ],
    correctIndex: 0,
    explanation:
        '「Photography is allowed everywhere except in the special exhibition（特別展以外はどこでも撮影可）」＝特別展だけ撮影禁止。',
  ),
  ListeningItem(
    part: 3,
    grade: 'pre1',
    audioKey: 'lpre1_p3_04.mp3',
    transcripts: [
      'Because of the heavy snow forecast for tomorrow morning, classes will '
          'start two hours late, at ten o\'clock. Club activities scheduled '
          'before school are canceled, but afternoon clubs will run as normal. '
          'Please check the school website tonight in case the schedule changes '
          'again.',
    ],
    questionType: ListeningQuestionType.passageContent,
    question: '状況: あなたは生徒です。\nWhat time will classes start tomorrow?',
    choices: [
      'At ten o\'clock.',
      'At eight o\'clock.',
      'Two hours earlier than usual.',
      'Classes are canceled all day.',
    ],
    correctIndex: 0,
    explanation:
        '「classes will start two hours late, at ten（授業は2時間遅れの10時に始まる）」。',
  ),
];

const Map<String, List<ListeningItem>> kListeningItems = {
  '5': [..._grade5Part1, ..._grade5Part2, ..._grade5Part3],
  '4': [..._grade4Part1, ..._grade4Part2, ..._grade4Part3],
  '3': [..._grade3Part1, ..._grade3Part2, ..._grade3Part3],
  'pre2': [..._gradePre2Part1, ..._gradePre2Part2],
  'pre2plus': [..._gradePre2PlusPart1, ..._gradePre2PlusPart2],
  '2': [..._grade2Part1, ..._grade2Part2],
  'pre1': [..._gradePre1Part1, ..._gradePre1Part2, ..._gradePre1Part3],
};

/// Convenience: get items for a specific grade and part number.
List<ListeningItem> listeningItemsFor(String grade, int part) =>
    (kListeningItems[grade] ?? []).where((it) => it.part == part).toList();

/// The authored transcript (what is spoken) for a listening item, keyed by its
/// [audioKey]. Used by the post-mock 答え合わせ review so a child who missed a
/// listening item can READ what was said — the listening-learning loop, using
/// the same authored transcript the live listening screen reveals. Returns null
/// when the key isn't a listening item (e.g. a reading id). Multi-line dialogues
/// are joined with newlines.
String? transcriptForAudioKey(String audioKey) {
  for (final items in kListeningItems.values) {
    for (final it in items) {
      if (it.audioKey == audioKey) {
        final joined = it.transcripts.join('\n').trim();
        return joined.isEmpty ? null : joined;
      }
    }
  }
  return null;
}

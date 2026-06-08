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
//   4級: same structure as 5級 (3部, 30問 total)
//   3級: 3部 = 30問
//   準2級プラス/2級: 第1部15 (会話応答選択) + 第2部15 (文内容一致) = 30
// Seed bank covers the VERIFIED per-grade 部 structure. Volume is being expanded
// toward the real-exam per-part counts (#10): 3級 第1部 is at 10/10; the other
// parts/grades remain at the initial ~4-item sample and are visible as shortfalls
// in reading_pool_integrity_test (skip with the exact gap to target).

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
  });
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
    question: 'According to the study, how much time do teenagers spend on social media daily?',
    choices: [
      'One hour.',
      'Two hours.',
      'Three hours.',
      'Four hours.',
    ],
    correctIndex: 2,
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
    question: 'What do researchers NOT mention as a reason for longevity in Okinawa?',
    choices: [
      'A healthy plant-based diet.',
      'Strong social connections.',
      'A sense of purpose called ikigai.',
      'Regular high-intensity exercise.',
    ],
    correctIndex: 3,
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
    question: 'What do scientists consider a key step in addressing the microplastics problem?',
    choices: [
      'Developing better ocean filtration systems.',
      'Banning all forms of plastic packaging worldwide.',
      'Reducing single-use plastic consumption.',
      'Educating marine biologists about contamination.',
    ],
    correctIndex: 2,
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

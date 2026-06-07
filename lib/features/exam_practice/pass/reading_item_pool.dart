// lib/features/exam_practice/pass/reading_item_pool.dart
// A-KEN Quest — Public reading item pool for the mock exam assembler.
//
// The existing reading items live in reading_practice_screen.dart as private
// `_ReadingPassage` / `_ComprehensionQuestion` types and are not accessible
// from outside the file. This pool provides a representative PUBLIC seed for
// the mock exam assembler (mock_exam.dart) without duplicating the full
// reading screen's passage bank.
//
// CONTENT INTEGRITY (R1):
//   - All choices are in English.
//   - Exactly one correctIdx per question.
//   - No duplicate choices within a question.
//
// NO dart:io. No Firebase. No network. (R4)

import 'cse_model.dart';
import 'mock_exam.dart';

/// A reading MCQ item for the mock exam assembler.
/// Wraps [MockMcqItem] with reading-specific context.
class ReadingMockItem extends MockMcqItem {
  /// Short passage text (printed above the question in the mock UI).
  final String passageText;

  const ReadingMockItem({
    required super.id,
    required super.questionText,
    required super.choices,
    required super.correctIdx,
    required super.sectionId,
    required this.passageText,
  }) : super(skill: EikenSkill.reading);
}

// ── Seed items (public, R1-compliant) ────────────────────────────────────────

/// Returns reading mock items for [grade].
/// The pool is intentionally small (a representative seed); items are drawn
/// and shuffled by [MockExamAssembler] so repeated mock attempts vary.
List<MockMcqItem> readingItemsFor(String grade) =>
    (_kReadingPool[grade] ?? const <ReadingMockItem>[])
        // Compose the passage/cloze sentence ABOVE the instruction so the rendered
        // MockMcqItem is self-contained. Without this the mock UI shows only
        // "Choose the best word for the blank." with no sentence to answer.
        .map((r) => MockMcqItem(
              id: r.id,
              questionText: '${r.passageText}\n\n${r.questionText}',
              choices: r.choices,
              correctIdx: r.correctIdx,
              skill: EikenSkill.reading,
              sectionId: r.sectionId,
            ))
        .toList();

const Map<String, List<ReadingMockItem>> _kReadingPool = {
  '5': _grade5Reading,
  '4': _grade4Reading,
  '3': _grade3Reading,
  'pre2': _pre2Reading,
  '2': _grade2Reading,
  'pre1': _pre1Reading,
};

// ── 英検5級 ──────────────────────────────────────────────────────────────────
const _grade5Reading = [
  ReadingMockItem(
    id: '5_r_001',
    sectionId: '5_r1',
    passageText: 'Tom has a dog. The dog is big and brown.',
    questionText: 'What does Tom have?',
    choices: ['A dog', 'A cat', 'A bird', 'A fish'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_002',
    sectionId: '5_r2',
    passageText:
        'Anna: "Do you have a pen?" Bob: "Yes, here you are."',
    questionText: 'What does Bob give Anna?',
    choices: ['A pen', 'A book', 'A ruler', 'An eraser'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_003',
    sectionId: '5_r1',
    passageText: 'My sister likes to ( ) pictures.',
    questionText: 'Choose the best word for the blank.',
    choices: ['draw', 'eat', 'swim', 'run'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_004',
    sectionId: '5_r1',
    passageText: 'It is ( ) today. Please take an umbrella.',
    questionText: 'Choose the best word for the blank.',
    choices: ['rainy', 'sunny', 'hot', 'cold'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_005',
    sectionId: '5_r3',
    passageText: 'He ( ) to school by bus every day.',
    questionText: 'Choose the best word for the blank.',
    choices: ['goes', 'go', 'going', 'went'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_006',
    sectionId: '5_r1',
    passageText: 'She ( ) her homework after dinner every day.',
    questionText: 'Choose the best word for the blank.',
    choices: ['do', 'does', 'did', 'done'],
    correctIdx: 1,
  ),
  // ── 大問1 語句空所補充 (vocabulary + basic grammar, CEFR A1) ──────────────
  ReadingMockItem(
    id: '5_r_007',
    sectionId: '5_r1',
    passageText: 'Look at the cats. ( ) are cute.',
    questionText: 'Choose the best word for the blank.',
    choices: ['It', 'He', 'They', 'She'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '5_r_008',
    sectionId: '5_r1',
    passageText: 'This is my mother. ( ) name is Mary.',
    questionText: 'Choose the best word for the blank.',
    choices: ['His', 'Her', 'My', 'Your'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '5_r_009',
    sectionId: '5_r1',
    passageText: '( ) you like apples?',
    questionText: 'Choose the best word for the blank.',
    choices: ['Do', 'Are', 'Is', 'Was'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_010',
    sectionId: '5_r1',
    passageText: 'My father ( ) coffee every morning.',
    questionText: 'Choose the best word for the blank.',
    choices: ['drink', 'drinking', 'drank', 'drinks'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '5_r_011',
    sectionId: '5_r1',
    passageText: 'I go to school ( ) Monday.',
    questionText: 'Choose the best word for the blank.',
    choices: ['in', 'on', 'at', 'to'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '5_r_012',
    sectionId: '5_r1',
    passageText: 'The pen is ( ) the box.',
    questionText: 'Choose the best word for the blank.',
    choices: ['of', 'for', 'in', 'with'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '5_r_013',
    sectionId: '5_r1',
    passageText: 'What time ( ) it now?',
    questionText: 'Choose the best word for the blank.',
    choices: ['is', 'are', 'am', 'do'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_014',
    sectionId: '5_r1',
    passageText: 'A: ( ) is your birthday?  B: In May.',
    questionText: 'Choose the best word for the blank.',
    choices: ['Who', 'What', 'Where', 'When'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '5_r_015',
    sectionId: '5_r1',
    passageText: 'She can ( ) the piano.',
    questionText: 'Choose the best word for the blank.',
    choices: ['plays', 'play', 'playing', 'played'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '5_r_016',
    sectionId: '5_r1',
    passageText: 'We ( ) students. We study English.',
    questionText: 'Choose the best word for the blank.',
    choices: ['is', 'am', 'are', 'be'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '5_r_017',
    sectionId: '5_r1',
    passageText: 'There ( ) a big park near my house.',
    questionText: 'Choose the best word for the blank.',
    choices: ['is', 'are', 'am', 'be'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '5_r_018',
    sectionId: '5_r1',
    passageText: 'I want ( ) apple.',
    questionText: 'Choose the best word for the blank.',
    choices: ['a', 'the', 'some', 'an'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '5_r_019',
    sectionId: '5_r1',
    passageText: 'My bag is ( ). Your bag is small.',
    questionText: 'Choose the best word for the blank.',
    choices: ['big', 'small', 'cold', 'old'],
    correctIdx: 0,
  ),
  // ── 大問2 会話文の文空所補充 (conversation response) ──────────────────────
  ReadingMockItem(
    id: '5_r_020',
    sectionId: '5_r2',
    passageText: 'A: How ( ) you?  B: I am fine, thank you.',
    questionText: 'Choose the best word for the blank.',
    choices: ['is', 'are', 'am', 'do'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '5_r_021',
    sectionId: '5_r2',
    passageText: 'A: ( ) is this?  B: It is my friend, Ken.',
    questionText: 'Choose the best word for the blank.',
    choices: ['What', 'Where', 'Who', 'When'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '5_r_022',
    sectionId: '5_r2',
    passageText: 'A: Let us play soccer.  B: ( )',
    questionText: 'Choose the best response.',
    choices: [
      'Yes, I am.',
      "No, it isn't.",
      'That is a good idea.',
      'You are welcome.',
    ],
    correctIdx: 2,
  ),
  // ── 大問3 長文の内容一致選択 (short passage comprehension) ─────────────────
  ReadingMockItem(
    id: '5_r_023',
    sectionId: '5_r3',
    passageText:
        'My name is Yui. I am ten years old. I like music. I can play the guitar.',
    questionText: 'What can Yui play?',
    choices: ['The piano', 'The guitar', 'Soccer', 'Tennis'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '5_r_024',
    sectionId: '5_r3',
    passageText:
        'Ken gets up at six. He has breakfast at seven. He goes to school at eight.',
    questionText: 'What does Ken do at seven?',
    choices: [
      'He gets up.',
      'He goes to school.',
      'He goes to bed.',
      'He has breakfast.',
    ],
    correctIdx: 3,
  ),
];

// ── 英検4級 ──────────────────────────────────────────────────────────────────
const _grade4Reading = [
  ReadingMockItem(
    id: '4_r_001',
    sectionId: '4_r1',
    passageText:
        'Ken is ( ) in science. He reads many books about it.',
    questionText: 'Choose the best word for the blank.',
    choices: ['interested', 'surprised', 'tired', 'worried'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_002',
    sectionId: '4_r2',
    passageText:
        'Mom: "Did you clean your room?" Lisa: "( ) I forgot."',
    questionText: 'Choose the best response for the blank.',
    choices: ['Sorry,', 'Great,', 'Sure,', 'Hello,'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_003',
    sectionId: '4_r4',
    passageText:
        'Notice: The library will be closed on Saturday for cleaning. '
        'It will open again on Sunday at 10:00.',
    questionText: 'When will the library be closed?',
    choices: ['Saturday', 'Sunday', 'Monday', 'Friday'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_004',
    sectionId: '4_r1',
    passageText:
        'The train was late, so we ( ) to run to catch it.',
    questionText: 'Choose the best word for the blank.',
    choices: ['had', 'have', 'has', 'having'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_005',
    sectionId: '4_r3',
    passageText: 'She wants to be ( ) doctor when she grows up.',
    questionText: 'Choose the best word for the blank.',
    choices: ['a', 'an', 'the', 'one'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_006',
    sectionId: '4_r4',
    passageText:
        'From: Tom  To: Lucy\n'
        '"I am having a birthday party on June 10th. Can you come?"',
    questionText: 'What is the party for?',
    choices: ["Tom's birthday", "Lucy's birthday", 'A holiday', 'A school event'],
    correctIdx: 0,
  ),
  // ── 大問1 語句空所補充 (grammar + vocabulary, CEFR A2) ────────────────────
  ReadingMockItem(
    id: '4_r_007',
    sectionId: '4_r1',
    passageText: 'Yesterday I ( ) to the zoo with my family.',
    questionText: 'Choose the best word for the blank.',
    choices: ['go', 'going', 'goes', 'went'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '4_r_008',
    sectionId: '4_r1',
    passageText: 'She ( ) a letter to her friend last night.',
    questionText: 'Choose the best word for the blank.',
    choices: ['wrote', 'write', 'written', 'writes'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_009',
    sectionId: '4_r1',
    passageText: 'It is cloudy. I think it ( ) rain soon.',
    questionText: 'Choose the best word for the blank.',
    choices: ['will', 'is', 'was', 'does'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    // NOTE: replaced an earlier will/be-going-to item — that distinction is a
    // 3級+ nuance and contradicted 4_r_009's cloudy→will mapping (adversarial
    // audit, 2026-06-07). This tests the clean A2 collocation "good at".
    id: '4_r_010',
    sectionId: '4_r1',
    passageText: 'My sister is very good ( ) playing tennis.',
    questionText: 'Choose the best word for the blank.',
    choices: ['in', 'on', 'at', 'of'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_011',
    sectionId: '4_r1',
    passageText: 'My brother is ( ) than me.',
    questionText: 'Choose the best word for the blank.',
    choices: ['tall', 'taller', 'tallest', 'more tall'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '4_r_012',
    sectionId: '4_r1',
    passageText: 'This is the ( ) mountain in Japan.',
    questionText: 'Choose the best word for the blank.',
    choices: ['higher', 'high', 'highest', 'more high'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_013',
    sectionId: '4_r1',
    passageText: 'I want ( ) a new bike for my birthday.',
    questionText: 'Choose the best word for the blank.',
    choices: ['buying', 'bought', 'to buy', 'buy'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_014',
    sectionId: '4_r1',
    passageText: 'He enjoys ( ) soccer after school.',
    questionText: 'Choose the best word for the blank.',
    choices: ['play', 'to play', 'played', 'playing'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '4_r_015',
    sectionId: '4_r1',
    passageText: 'I have ( ) my homework already.',
    questionText: 'Choose the best word for the blank.',
    choices: ['finishing', 'finish', 'finishes', 'finished'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '4_r_016',
    sectionId: '4_r1',
    passageText: 'You look sick. You ( ) see a doctor.',
    questionText: 'Choose the best word for the blank.',
    choices: ['should', 'can', 'will', 'do'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_017',
    sectionId: '4_r1',
    passageText: 'I was very tired ( ) I worked hard all day.',
    questionText: 'Choose the best word for the blank.',
    choices: ['but', 'so', 'because', 'or'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_018',
    sectionId: '4_r1',
    passageText: '( ) I was a child, I lived in Osaka.',
    questionText: 'Choose the best word for the blank.',
    choices: ['What', 'When', 'Which', 'Who'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '4_r_019',
    sectionId: '4_r1',
    passageText: 'Please ( ) the door. It is cold outside.',
    questionText: 'Choose the best word for the blank.',
    choices: ['close', 'open', 'wash', 'read'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_020',
    sectionId: '4_r1',
    passageText: 'I am thirsty. Let us have some ( ).',
    questionText: 'Choose the best word for the blank.',
    choices: ['bread', 'water', 'rice', 'soup'],
    correctIdx: 1,
  ),
  // ── 大問2 会話文の文空所補充 (conversation response) ──────────────────────
  ReadingMockItem(
    id: '4_r_021',
    sectionId: '4_r2',
    passageText: 'A: How was the movie?  B: ( ) I really liked it.',
    questionText: 'Choose the best response.',
    choices: ['I am fifteen.', 'Yes, I do.', 'On Sunday.', 'It was great.'],
    correctIdx: 3,
  ),
  // ── 大問3 長文の内容一致選択 (notice / email comprehension) ────────────────
  ReadingMockItem(
    id: '4_r_022',
    sectionId: '4_r4',
    passageText:
        'From: Green Park School  To: All students\n'
        'Our school sports day is on October 5th. It will start at 9:00 in the '
        'morning. Please bring your hat and water bottle. Do not bring food, '
        'because lunch will be given to everyone at noon.',
    questionText: 'What should students bring?',
    choices: [
      'A book and pen',
      'Lunch',
      'A hat and water bottle',
      'A camera',
    ],
    correctIdx: 2,
  ),
];

// ── 英検3級 ──────────────────────────────────────────────────────────────────
const _grade3Reading = [
  ReadingMockItem(
    id: '3_r_001',
    sectionId: '3_r1',
    passageText:
        'Maria ( ) to study in Japan next year.',
    questionText: 'Choose the best word for the blank.',
    choices: ['plans', 'plan', 'planning', 'planned'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_002',
    sectionId: '3_r1',
    passageText:
        'He ( ) his wallet at the station yesterday.',
    questionText: 'Choose the best word for the blank.',
    choices: ['lost', 'lose', 'losing', 'loses'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_003',
    sectionId: '3_r3',
    passageText:
        'Notice: "Our school festival will be held on November 3rd. '
        'Students must wear their uniforms. Food stalls will open at 10:00."',
    questionText: 'What must students wear at the festival?',
    choices: ['Their uniforms', 'Casual clothes', 'Sports clothes', 'A costume'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_004',
    sectionId: '3_r3',
    passageText:
        'Dear Amy,\nThank you for the birthday present. I really liked '
        'the book you gave me. I have already read it twice!',
    questionText: 'What does the writer think about the book?',
    choices: ['It is very good.', 'It is too short.', 'It is boring.', 'It is too hard.'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_005',
    sectionId: '3_r1',
    passageText:
        'She has ( ) visited the new museum downtown.',
    questionText: 'Choose the best word for the blank.',
    choices: ['already', 'yet', 'still', 'never'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_006',
    sectionId: '3_r2',
    passageText:
        'A: "Would you like some more tea?" B: "( ) I\'m fine, thank you."',
    questionText: 'Choose the best response.',
    choices: ['No, thanks.', 'Yes, please!', 'I\'m hungry.', 'See you!'],
    correctIdx: 0,
  ),
  // ── 大問1 語句空所補充 (grammar + vocabulary, CEFR A2–B1) ──────────────────
  ReadingMockItem(
    id: '3_r_007',
    sectionId: '3_r1',
    passageText: 'I have lived in this town ( ) 2015.',
    questionText: 'Choose the best word for the blank.',
    choices: ['for', 'since', 'from', 'in'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '3_r_008',
    sectionId: '3_r1',
    passageText: 'This temple ( ) over 1,000 years ago.',
    questionText: 'Choose the best word for the blank.',
    choices: ['built', 'has built', 'was built', 'builds'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '3_r_009',
    sectionId: '3_r1',
    passageText: 'The man ( ) lives next door is a doctor.',
    questionText: 'Choose the best word for the blank.',
    choices: ['who', 'which', 'whose', 'where'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_010',
    sectionId: '3_r1',
    passageText: 'This is the book ( ) won the prize.',
    questionText: 'Choose the best word for the blank.',
    choices: ['who', 'whom', 'which', 'whose'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '3_r_011',
    sectionId: '3_r1',
    passageText: 'I went to the store ( ) some milk.',
    questionText: 'Choose the best word for the blank.',
    choices: ['buy', 'buying', 'bought', 'to buy'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '3_r_012',
    sectionId: '3_r1',
    passageText: 'Thank you for ( ) me with my homework.',
    questionText: 'Choose the best word for the blank.',
    choices: ['help', 'to help', 'helped', 'helping'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '3_r_013',
    sectionId: '3_r1',
    passageText: 'Tom is as ( ) as his brother.',
    questionText: 'Choose the best word for the blank.',
    choices: ['taller', 'tallest', 'more tall', 'tall'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '3_r_014',
    sectionId: '3_r1',
    passageText: 'Do you know ( ) the station is?',
    questionText: 'Choose the best word for the blank.',
    choices: ['where', 'what', 'which', 'when'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_015',
    sectionId: '3_r1',
    passageText: '( ) it rains tomorrow, we will stay home.',
    questionText: 'Choose the best word for the blank.',
    choices: ['If', 'Because', 'Although', 'Before'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_016',
    sectionId: '3_r1',
    passageText: '( ) he was very tired, he finished all his work.',
    questionText: 'Choose the best word for the blank.',
    choices: ['Because', 'So', 'Although', 'If'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '3_r_017',
    sectionId: '3_r1',
    passageText: 'I haven\'t finished my homework ( ).',
    questionText: 'Choose the best word for the blank.',
    choices: ['already', 'yet', 'ever', 'since'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '3_r_018',
    sectionId: '3_r1',
    passageText: 'Look at the ( ) window. Someone threw a ball at it.',
    questionText: 'Choose the best word for the blank.',
    choices: ['break', 'breaking', 'broken', 'breaks'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '3_r_019',
    sectionId: '3_r1',
    passageText: 'The weather was terrible, so the baseball game was ( ).',
    questionText: 'Choose the best word for the blank.',
    choices: ['cancelled', 'started', 'won', 'bought'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_020',
    sectionId: '3_r1',
    passageText: 'Could you ( ) me how to get to the station?',
    questionText: 'Choose the best word for the blank.',
    choices: ['say', 'talk', 'speak', 'tell'],
    correctIdx: 3,
  ),
  // ── 大問2 会話文の文空所補充 (conversation response) ──────────────────────
  ReadingMockItem(
    id: '3_r_021',
    sectionId: '3_r2',
    passageText: 'A: I failed my math test again.  B: ( ) You should study harder.',
    questionText: 'Choose the best response.',
    choices: [
      'Congratulations!',
      'That is great!',
      'That is too bad.',
      'You are welcome.',
    ],
    correctIdx: 2,
  ),
  // ── 大問3 長文の内容一致選択 (passage comprehension) ──────────────────────
  ReadingMockItem(
    id: '3_r_022',
    sectionId: '3_r3',
    passageText:
        'Ken started playing tennis when he was eight. At first he was not '
        'good, but he practiced every day after school. Now he is the best '
        'player on his school team.',
    questionText: 'How did Ken become a good player?',
    choices: [
      'By watching TV.',
      'By reading books.',
      'By resting a lot.',
      'By practicing every day.',
    ],
    correctIdx: 3,
  ),
];

// ── 英検準2級 ─────────────────────────────────────────────────────────────────
const _pre2Reading = [
  ReadingMockItem(
    id: 'p2_r_001',
    sectionId: 'p2_r1',
    passageText:
        'The new program was ( ) for beginners who had no coding experience.',
    questionText: 'Choose the best word for the blank.',
    choices: ['designed', 'decided', 'defeated', 'declared'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2_r_002',
    sectionId: 'p2_r1',
    passageText:
        'It is important to ( ) enough sleep every night for good health.',
    questionText: 'Choose the best word for the blank.',
    choices: ['get', 'give', 'grow', 'gain'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2_r_003',
    sectionId: 'p2_r3',
    passageText:
        'Online learning has become popular in recent years. '
        'Many universities now offer courses that students can take from home. '
        'This trend started growing quickly after 2020.',
    questionText: 'According to the passage, when did online learning grow quickly?',
    choices: [
      'After 2020',
      'Before 2010',
      'In the 1990s',
      'In the early 2000s',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2_r_004',
    sectionId: 'p2_r2',
    passageText:
        'A: "I need to ( ) this project by Friday." '
        'B: "Don\'t worry. I\'ll help you."',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['finish', 'beginning', 'gone', 'start again'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2_r_005',
    sectionId: 'p2_r3',
    passageText:
        'Recycling reduces the amount of waste sent to landfills. '
        'It also saves energy because manufacturing from recycled materials '
        'uses less power than making new products.',
    questionText: 'What is one benefit of recycling mentioned in the passage?',
    choices: [
      'It saves energy.',
      'It creates new jobs.',
      'It lowers food prices.',
      'It reduces noise pollution.',
    ],
    correctIdx: 0,
  ),
];

// ── 英検2級 ──────────────────────────────────────────────────────────────────
const _grade2Reading = [
  ReadingMockItem(
    id: '2_r_001',
    sectionId: '2_r1',
    passageText:
        'The committee ( ) new regulations to reduce carbon emissions.',
    questionText: 'Choose the best word for the blank.',
    choices: ['introduced', 'intervened', 'invested', 'invented'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '2_r_002',
    sectionId: '2_r1',
    passageText:
        'Scientists have ( ) that regular exercise can improve memory.',
    questionText: 'Choose the best word for the blank.',
    choices: ['found', 'funded', 'formed', 'forced'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '2_r_003',
    sectionId: '2_r3',
    passageText:
        'The discovery of penicillin by Alexander Fleming in 1928 '
        'transformed modern medicine. Before antibiotics, even minor '
        'infections could be life-threatening.',
    questionText: 'What was the significance of penicillin?',
    choices: [
      'It made minor infections treatable.',
      'It prevented all diseases.',
      'It replaced surgery.',
      'It cured all cancers.',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '2_r_004',
    sectionId: '2_r2',
    passageText:
        'Deforestation poses a serious threat to biodiversity. When forests '
        'are cleared, animals ( ) their natural habitats and are forced to '
        'move elsewhere or face extinction.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['lose', 'gain', 'protect', 'restore'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '2_r_005',
    sectionId: '2_r3',
    passageText:
        'Social media has changed how young people communicate. '
        'Studies show that teens spend an average of three hours per day '
        'on social platforms, which raises concerns about mental health.',
    questionText: 'What concern does the passage raise about social media?',
    choices: [
      'Its effect on mental health',
      'Its cost to users',
      'Its impact on school grades only',
      'Its effect on physical fitness',
    ],
    correctIdx: 0,
  ),
];

// ── 英検準1級 ─────────────────────────────────────────────────────────────────
const _pre1Reading = [
  ReadingMockItem(
    id: 'p1_r_001',
    sectionId: 'p1_r1',
    passageText:
        'The government\'s plan to ( ) urban areas by expanding public '
        'transport has gained widespread support.',
    questionText: 'Choose the best word for the blank.',
    choices: ['revitalise', 'replicate', 'retrieve', 'regulate'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_002',
    sectionId: 'p1_r1',
    passageText:
        'Her research was ( ) by a major international foundation.',
    questionText: 'Choose the best word for the blank.',
    choices: ['funded', 'found', 'formed', 'framed'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_003',
    sectionId: 'p1_r3',
    passageText:
        'Climate change is altering precipitation patterns worldwide. '
        'Regions that were once reliably wet are experiencing prolonged '
        'droughts, while traditionally arid areas face unprecedented floods. '
        'Scientists attribute these shifts primarily to rising global temperatures.',
    questionText: 'What is causing the changes in precipitation patterns?',
    choices: [
      'Rising global temperatures',
      'Decreased solar activity',
      'Changes in ocean currents only',
      'Volcanic eruptions',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_004',
    sectionId: 'p1_r2',
    passageText:
        'The concept of circular economy aims to ( ) waste by keeping '
        'materials in use for as long as possible through recycling and repair.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['eliminate', 'create', 'ignore', 'transfer'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_005',
    sectionId: 'p1_r3',
    passageText:
        'Artificial intelligence is increasingly being used in medical diagnosis. '
        'Machine learning algorithms can analyse medical images with an accuracy '
        'that rivals or surpasses experienced physicians in some fields.',
    questionText: 'How does AI compare to physicians in some diagnostic fields?',
    choices: [
      'It can be equally or more accurate.',
      'It is always less reliable.',
      'It can only assist with paperwork.',
      'It replaces all clinical judgment.',
    ],
    correctIdx: 0,
  ),
];

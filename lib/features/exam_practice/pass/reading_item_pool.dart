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
/// Raw [ReadingMockItem]s for a grade (passage + instruction kept separate).
/// Exposed for integrity tests that must validate the SOURCE fields rather than
/// the composed [readingItemsFor] output (which concatenates passage+instruction
/// and would mask an empty passage). Returns const empty for unknown grades.
List<ReadingMockItem> rawReadingItemsFor(String grade) =>
    _kReadingPool[grade] ?? const <ReadingMockItem>[];

List<MockMcqItem> readingItemsFor(String grade) => (_kReadingPool[grade] ??
        const <ReadingMockItem>[])
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
          // Authored 解説 (teach-why) surfaced in the post-mock review when one
          // exists for this item; null otherwise (the review never fabricates).
          explanation: _kReadingExplanations[r.id],
        ))
    .toList();

/// Authored per-item 解説 (teach-why) for the post-mock review, keyed by item id.
/// Each points at the passage evidence for the correct answer (content-qa-verified,
/// 英検5級 2026-06-12). Items without an entry show no 解説 (no fabrication).
/// Extend grade-by-grade (5級 done; 4級/3級/… next).
const Map<String, String> _kReadingExplanations = {
  '5_r_001': 'ほんぶんに「Tom has a dog.」とあるね。トムが もっているのは「いぬ（A dog）」だよ。',
  '5_r_002':
      'アンナが ペンをきいて、ボブが「here you are（はい、どうぞ）」とわたしているよ。だからこたえは「A pen（ペン）」。',
  '5_r_003': 'pictures（え）といっしょにつかうことばは draw（かく）。「えを かく」で「draw」がせいかいだよ。',
  '5_r_004': 'あとに「take an umbrella（かさを もって）」とあるね。かさがいるおてんきは rainy（あめ）だよ。',
  '5_r_005': '「He（かれ）」がしゅごで、every day（まいにち）のはなしだから、go に s がついた goes がせいかい。',
  '5_r_006':
      '「She（かのじょ）」がしゅごのときは does をつかうよ。「homework（しゅくだい）を する」で does がせいかい。',
  '5_r_007': 'まえに「cats（ねこたち）」とたくさんいるね。たくさんのものをさすことばは They（かれら・それら）だよ。',
  '5_r_008': '「my mother（おかあさん）」のなまえのはなしだね。おんなのひとには Her（かのじょの）をつかうよ。',
  '5_r_009': '「like（すき）」をつかうしつもんのはじめは Do だよ。「Do you like 〜?」のかたちをおぼえよう。',
  '5_r_010':
      'しゅごが「My father（おとうさん）」で every morning（まいあさ）のはなし。drink に s がついた drinks がせいかい。',
  '5_r_011': 'ようび（Monday）のまえには on をつかうよ。「on Monday（げつようびに）」でおぼえよう。',
  '5_r_012': '「the box（はこ）」のなかにペンがあるね。「〜のなかに」は in をつかうよ。',
  '5_r_013': '「it（それ）」がしゅごのときは is をつかうよ。「What time is it now?（いま なんじ?）」のかたちだね。',
  '5_r_014': 'こたえが「In May（5がつに）」とときをこたえているね。ときをきくことばは When（いつ）だよ。',
  '5_r_015': 'can のあとのことばは、そのままのかたち（play）になるよ。だから「can play」がせいかい。',
  '5_r_016': 'しゅごが「We（わたしたち）」のときは are をつかうよ。「We are students」でおぼえよう。',
  '5_r_017': '「a big park」はひとつだけのものだね。ひとつのときの There 〜 は is をつかうよ。',
  '5_r_018': '「apple」は a・i・u・e・o のおとではじまることばだね。まえには an をつけるよ。',
  '5_r_019': 'あとに「Your bag is small（ちいさい）」とあるね。はんたいのことばだから big（おおきい）がせいかい。',
  '5_r_020': '「you（あなた）」がしゅごだから are をつかうよ。「How are you?（げんき?）」のあいさつだね。',
  '5_r_021': 'こたえが「my friend, Ken（ともだちのケン）」とひとをこたえているね。ひとをきくことばは Who（だれ）だよ。',
  '5_r_022':
      '「Let us play soccer（サッカーしよう）」というさそいだね。さんせいのへんじは「That is a good idea.（いいね）」だよ。',
  '5_r_023': 'ほんぶんに「I can play the guitar.」とあるね。ユイがひけるのは The guitar（ギター）だよ。',
  '5_r_024':
      'ほんぶんに「He has breakfast at seven.」とあるね。7じにすることは「He has breakfast（あさごはんをたべる）」だよ。',
  // ── 英検4級 (content-qa-verified 2026-06-12) ──
  '4_r_001':
      'science の本をたくさん読むので、科学が「interested（きょうみがある）」が正かいだよ。in science とつながるね。',
  '4_r_002': '「I forgot（わすれちゃった）」と言っているので、あやまる「Sorry,」がぴったりだよ。',
  '4_r_003':
      'お知らせに「closed on Saturday」と書いてあるね。だから図書かんが休みなのは「Saturday（土よう日）」だよ。',
  '4_r_004':
      'おくれたので走る必よう（ひつよう）があったね。「had to run」で「〜しなければならなかった」になるから「had」が正かい。',
  '4_r_005': 'doctor は d の音で始まる言葉だから、前につくのは「a」だよ。an は a・i・u・e・o の音の前で使うんだ。',
  '4_r_006':
      'メッセージは Tom から「I am having a birthday party」と言っているので、パーティーは「Tom の birthday（たんじょう日）」だよ。',
  '4_r_007': '「Yesterday（きのう）」とあるから、過去の形「went（go の過去形）」が正かい。go は形がかわる動しなんだ。',
  '4_r_008': '「last night（ゆうべ）」とあるので過去の話。write の過去形「wrote」が正かいだよ。',
  '4_r_009': 'これからの天気の話だから、未来をあらわす「will」が正かい。will のあとは rain のもとの形がくるよ。',
  '4_r_010': '「〜がとくい」は「good at」とセットで使うよ。だから「at」が正かいなんだ。',
  '4_r_011': 'あとに「than（〜より）」があるので、くらべる形「taller」が正かい。tall に -er をつけるよ。',
  '4_r_012': '「in Japan」で一番のものを言っているね。一番をあらわす形「highest」が正かいだよ。前に the もつくんだ。',
  '4_r_013': '「〜したい」は「want to ＋ もとの形」だよ。だから「to buy」が正かいなんだ。',
  '4_r_014': 'enjoy のあとの動しは -ing の形になるよ。だから「playing」が正かいだね。',
  '4_r_015': '「last night（ゆうべ）」だから過去の話。finish の過去形「finished」が正かいだよ。',
  '4_r_016': 'ぐあいが悪い人へのアドバイスだね。「〜したほうがいい」をあらわす「should」が正かい。',
  '4_r_017': '「一日中がんばった」が「つかれた」りゆうだね。りゆうをあらわす「because（〜だから）」が正かいだよ。',
  '4_r_018': '「子どものとき おおさか にすんでいた」という意味。「〜のとき」をあらわす「When」が正かいだね。',
  '4_r_019': 'そとが寒いからドアをしめてほしいんだね。だから「close（しめる）」が正かいだよ。',
  '4_r_020': 'のどがかわいたら飲むものがほしいね。飲めるのは「water（水）」だから正かいだよ。',
  '4_r_021':
      '「I really liked it（とても気に入った）」と言っているので、よいかんそうの「It was great.」が正かい。',
  '4_r_022':
      'お知らせに「bring your hat and water bottle」とあるね。だから持っていくのは「ぼうしと水とう」だよ。',
  // ── 英検3級 (content-qa-verified 2026-06-12) ──
  '3_r_001':
      'こたえは「plans」。Maria は三人称単数で、しかも「to study（〜するつもり）」が後ろにあるので「plans to study」となります。三単現の s を忘れずに。',
  '3_r_002':
      'こたえは「lost」。文の終わりに「yesterday（きのう）」があるので、過去のことだとわかります。lose の過去形「lost」を使います。',
  '3_r_003':
      'こたえは「Their uniforms」。お知らせに「Students must wear their uniforms（生徒は制服を着なければならない）」とはっきり書いてあります。本文をよく見つけられました。',
  '3_r_004':
      'こたえは「It is very good」。「I really liked the book（その本がとても気に入った）」「read it twice（二回も読んだ）」から、本を気に入ったとわかります。',
  '3_r_005':
      'こたえは「already」。「has visited」は現在完了で、もう行ったという経験を表します。肯定文で「もう〜した」は「already」を使います。',
  '3_r_006':
      'こたえは「No, thanks」。「もっとお茶はいかが」と聞かれて、後ろに「I am fine（けっこうです）」と続くので、ことわる返事を選びます。',
  '3_r_007':
      'こたえは「since」。「2015」という始まりの一点があるので「since（〜から）」を使います。期間の長さには「for」を使うので区別しましょう。',
  '3_r_008':
      'こたえは「was built」。お寺は「建てられた」ものなので受け身（be 動詞＋過去分詞）を使います。「ago」があるので過去の「was built」です。',
  '3_r_009':
      'こたえは「who」。前の「The man（人）」を説明する関係代名詞で、後ろが「lives」と動詞なので、主語のはたらきをする「who」を選びます。',
  '3_r_010':
      'こたえは「which」。前の「the book（もの）」を説明する関係代名詞です。人ではなく物なので「who」ではなく「which」を使います。',
  '3_r_011': 'こたえは「to buy」。「ミルクを買うために店へ行った」という目的を表すので、to 不定詞「to buy」を使います。',
  '3_r_012':
      'こたえは「helping」。「for」という前置詞の後ろなので、動詞は -ing の形（動名詞）にします。「Thank you for helping（手伝ってくれてありがとう）」。',
  '3_r_013':
      'こたえは「tall」。「as ... as」で同じくらいだと表すとき、間にはもとの形の形容詞を入れます。比較級の「taller」は入れません。',
  '3_r_014':
      'こたえは「where」。「駅がどこにあるか知っていますか」という意味で、場所をたずねる「where」を文の中に入れた間接疑問です。',
  '3_r_015': 'こたえは「If」。「もし明日雨がふったら、家にいる」という条件を表すので「If（もし〜なら）」を選びます。',
  '3_r_016':
      'こたえは「Although」。「とてもつかれていたが、仕事を全部終えた」という逆の内容がつながるので「Although（〜だけれども）」を使います。',
  '3_r_017':
      'こたえは「yet」。「まだ宿題を終えていない」という否定の現在完了では「yet（まだ）」を使います。肯定文の「already」と区別しましょう。',
  '3_r_018':
      'こたえは「broken」。「割られた窓」という意味で、名詞を説明するときは過去分詞「broken」を使います。「ボールが当たった」という後の文もヒントです。',
  '3_r_019':
      'こたえは「canceled」。「天気がひどかったので」とあるので、試合は中止されたと考えるのが自然です。「canceled（中止された）」を選びます。',
  '3_r_020':
      'こたえは「tell」。「人に〜を教える」と言うときは「tell＋人」を使います。「tell me how to ...（行き方を教えて）」の形です。',
  '3_r_021':
      'こたえは「That is too bad」。「テストにまた落ちた」という残念な話なので、同情する返事を選びます。後ろの「もっと勉強した方がいい」ともつながります。',
  '3_r_022':
      'こたえは「By practicing every day」。本文に「he practiced every day（毎日練習した）」「Now he is the best player（今は一番うまい）」とあります。練習が上達の理由です。',
};

const Map<String, List<ReadingMockItem>> _kReadingPool = {
  '5': _grade5Reading,
  '4': _grade4Reading,
  '3': _grade3Reading,
  'pre2': _pre2Reading,
  'pre2plus': _pre2plusReading,
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
    passageText: 'Anna: "Do you have a pen?" Bob: "Yes, here you are."',
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
    passageText: 'Ken is ( ) in science. He reads many books about it.',
    questionText: 'Choose the best word for the blank.',
    choices: ['interested', 'surprised', 'tired', 'worried'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_002',
    sectionId: '4_r2',
    passageText: 'Mom: "Did you clean your room?" Lisa: "( ) I forgot."',
    questionText: 'Choose the best response for the blank.',
    choices: ['Sorry,', 'Great,', 'Sure,', 'Hello,'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_003',
    sectionId: '4_r4',
    passageText: 'Notice: The library will be closed on Saturday for cleaning. '
        'It will open again on Sunday at 10:00.',
    questionText: 'When will the library be closed?',
    choices: ['Saturday', 'Sunday', 'Monday', 'Friday'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_004',
    sectionId: '4_r1',
    passageText: 'The train was late, so we ( ) to run to catch it.',
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
    passageText: 'From: Tom  To: Lucy\n'
        '"I am having a birthday party on June 10th. Can you come?"',
    questionText: 'What is the party for?',
    choices: [
      "Tom's birthday",
      "Lucy's birthday",
      'A holiday',
      'A school event'
    ],
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
    // #60 grade-scope: was a 現在完了 (have+pp+already) cloze = 3級 grammar in the
    // 4級 section. Re-framed to 過去形 (last night) — same vocab, 4級-legal point.
    id: '4_r_015',
    sectionId: '4_r1',
    passageText: 'I ( ) my homework last night.',
    questionText: 'Choose the best word for the blank.',
    choices: ['finish', 'finishes', 'finished', 'finishing'],
    correctIdx: 2,
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
    passageText: 'From: Green Park School  To: All students\n'
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
    passageText: 'Maria ( ) to study in Japan next year.',
    questionText: 'Choose the best word for the blank.',
    choices: ['plans', 'plan', 'planning', 'planned'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_002',
    sectionId: '3_r1',
    passageText: 'He ( ) his wallet at the station yesterday.',
    questionText: 'Choose the best word for the blank.',
    choices: ['lost', 'lose', 'losing', 'loses'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_003',
    sectionId: '3_r3',
    passageText: 'Notice: "Our school festival will be held on November 3rd. '
        'Students must wear their uniforms. Food stalls will open at 10:00."',
    questionText: 'What must students wear at the festival?',
    choices: [
      'Their uniforms',
      'Casual clothes',
      'Sports clothes',
      'A costume'
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_004',
    sectionId: '3_r3',
    passageText:
        'Dear Amy,\nThank you for the birthday present. I really liked '
        'the book you gave me. I have already read it twice!',
    questionText: 'What does the writer think about the book?',
    choices: [
      'It is very good.',
      'It is too short.',
      'It is boring.',
      'It is too hard.'
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_005',
    sectionId: '3_r1',
    passageText: 'She has ( ) visited the new museum downtown.',
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
    choices: ['canceled', 'started', 'won', 'bought'],
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
    passageText:
        'A: I failed my math test again.  B: ( ) You should study harder.',
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
  // Existing 5 retained; choices reordered to remove the all-correctIdx-0 bias.
  ReadingMockItem(
    id: 'p2_r_001',
    sectionId: 'p2_r1',
    passageText:
        'The new program was ( ) for beginners who had no coding experience.',
    questionText: 'Choose the best word for the blank.',
    choices: ['defeated', 'decided', 'designed', 'declared'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_002',
    sectionId: 'p2_r1',
    passageText:
        'It is important to ( ) enough sleep every night for good health.',
    questionText: 'Choose the best word for the blank.',
    choices: ['give', 'get', 'grow', 'gain'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2_r_003',
    sectionId: 'p2_r3',
    passageText: 'Online learning has become popular in recent years. '
        'Many universities now offer courses that students can take from home. '
        'This trend started growing quickly after 2020.',
    questionText:
        'According to the passage, when did online learning grow quickly?',
    choices: [
      'After 2020',
      'In the 1990s',
      'Before 2010',
      'In the early 2000s',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2_r_004',
    sectionId: 'p2_r2',
    passageText: 'A: "I need to ( ) this project by Friday." '
        'B: "Don\'t worry. I\'ll help you."',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['beginning', 'gone', 'start again', 'finish'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p2_r_005',
    sectionId: 'p2_r3',
    passageText: 'Recycling reduces the amount of waste sent to landfills. '
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
  // ── 大問1 語句空所補充 (grammar + vocabulary, CEFR B1) ─────────────────────
  ReadingMockItem(
    id: 'p2_r_006',
    sectionId: 'p2_r1',
    passageText: 'She has been ( ) English for five years.',
    questionText: 'Choose the best word for the blank.',
    choices: ['studied', 'studies', 'study', 'studying'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p2_r_007',
    sectionId: 'p2_r1',
    passageText: 'When I arrived at the platform, the train had already ( ).',
    questionText: 'Choose the best word for the blank.',
    choices: ['leave', 'leaving', 'left', 'leaves'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_008',
    sectionId: 'p2_r1',
    passageText: 'I met a writer ( ) novels are famous around the world.',
    questionText: 'Choose the best word for the blank.',
    choices: ['who', 'whose', 'whom', 'which'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2_r_009',
    sectionId: 'p2_r1',
    passageText: 'This is the town ( ) I grew up.',
    questionText: 'Choose the best word for the blank.',
    choices: ['where', 'which', 'that', 'when'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    // Reworded: "repaired ... cannot cross" was a semantic contradiction
    // (adversarial audit). "closed" makes meaning coherent, same passive-
    // present-perfect grammar point. Key moved to idx3 (de-cycle, see below).
    id: 'p2_r_010',
    sectionId: 'p2_r1',
    passageText: 'The old bridge ( ) since last year, so we cannot cross it.',
    questionText: 'Choose the best word for the blank.',
    choices: ['closed', 'is closing', 'closes', 'has been closed'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p2_r_011',
    sectionId: 'p2_r1',
    passageText: 'The sad ending of the movie made everyone ( ).',
    questionText: 'Choose the best word for the blank.',
    choices: ['to cry', 'crying', 'cry', 'cried'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_012',
    sectionId: 'p2_r1',
    passageText: 'The ( ) you practice, the better you will become.',
    questionText: 'Choose the best word for the blank.',
    choices: ['most', 'more', 'many', 'much'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2_r_013',
    sectionId: 'p2_r1',
    passageText: 'This box is too heavy ( ) carry by myself.',
    questionText: 'Choose the best word for the blank.',
    choices: ['that', 'for', 'to', 'so'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_014',
    sectionId: 'p2_r1',
    passageText: 'Please call me ( ) you arrive at the airport.',
    questionText: 'Choose the best word for the blank.',
    choices: ['as long as', 'as soon as', 'even if', 'in case'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2_r_015',
    sectionId: 'p2_r1',
    passageText: 'For your health, you should avoid ( ) too much sugar.',
    questionText: 'Choose the best word for the blank.',
    choices: ['eating', 'eat', 'to eat', 'ate'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2_r_016',
    sectionId: 'p2_r1',
    passageText: 'The company decided to ( ) a new smartphone next spring.',
    questionText: 'Choose the best word for the blank.',
    choices: ['lend', 'lock', 'lift', 'launch'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p2_r_017',
    sectionId: 'p2_r1',
    passageText: 'The new medicine had a positive ( ) on her health.',
    questionText: 'Choose the best word for the blank.',
    choices: ['effect', 'affect', 'cause', 'reason'],
    correctIdx: 0,
  ),
  // ── 大問2 会話文の文空所補充 (conversation response) ──────────────────────
  ReadingMockItem(
    id: 'p2_r_018',
    sectionId: 'p2_r2',
    passageText: 'A: Could you tell me how to get to the museum?  B: ( )',
    questionText: 'Choose the best response.',
    choices: [
      'Yes, I am a student.',
      'Sure, go straight and turn left.',
      'No, I do not like it.',
      'It was yesterday.',
    ],
    correctIdx: 1,
  ),
  // ── 大問3 長文の内容一致選択 (passage comprehension) ──────────────────────
  ReadingMockItem(
    id: 'p2_r_019',
    sectionId: 'p2_r3',
    passageText:
        'Volunteering has many benefits. It helps people in need, and it also '
        'gives volunteers a chance to learn new skills and meet new people '
        'from different backgrounds.',
    questionText:
        'According to the passage, what is one benefit for volunteers?',
    choices: [
      'They earn high salaries.',
      'They get free food.',
      'They can learn new skills.',
      'They can travel abroad.',
    ],
    correctIdx: 2,
  ),
];

// ── 英検2級 ──────────────────────────────────────────────────────────────────
const _grade2Reading = [
  // Existing 5 retained; choices reordered to remove the all-correctIdx-0 bias.
  ReadingMockItem(
    id: '2_r_001',
    sectionId: '2_r1',
    passageText:
        'The committee ( ) new regulations to reduce carbon emissions.',
    questionText: 'Choose the best word for the blank.',
    choices: ['intervened', 'invested', 'introduced', 'invented'],
    correctIdx: 2,
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
    passageText: 'The discovery of penicillin by Alexander Fleming in 1928 '
        'transformed modern medicine. Before antibiotics, even minor '
        'infections could be life-threatening.',
    questionText: 'What was the significance of penicillin?',
    choices: [
      'It prevented all diseases.',
      'It made minor infections treatable.',
      'It replaced surgery.',
      'It cured all cancers.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_004',
    sectionId: '2_r2',
    passageText:
        'Deforestation poses a serious threat to biodiversity. When forests '
        'are cleared, animals ( ) their natural habitats and are forced to '
        'move elsewhere or face extinction.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['gain', 'protect', 'restore', 'lose'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '2_r_005',
    sectionId: '2_r3',
    passageText: 'Social media has changed how young people communicate. '
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
  // ── 大問1 短文語句空所補充 (vocabulary, phrasal verbs, grammar; CEFR B1–B2) ─
  ReadingMockItem(
    id: '2_r_006',
    sectionId: '2_r1',
    passageText:
        'We had to ( ) the meeting until next week because of the storm.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['put on', 'put off', 'put up', 'put out'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    // Distractors upgraded (adversarial audit): effort/account/attempt were
    // non-parallel filler eliminable on grammar alone — below 2級. Now all four
    // are abstract nouns; only "impact" collocates with "had a significant ___
    // on", forcing genuine collocation discrimination. ("effect"/"influence"
    // deliberately excluded — both would create a true double-answer.)
    id: '2_r_007',
    sectionId: '2_r1',
    passageText:
        'The new tax policy had a significant ( ) on small businesses.',
    questionText: 'Choose the best word for the blank.',
    choices: ['result', 'response', 'outcome', 'impact'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '2_r_008',
    sectionId: '2_r1',
    passageText: 'If I had studied harder, I ( ) the entrance exam.',
    questionText: 'Choose the best word for the blank.',
    choices: ['will pass', 'would pass', 'would have passed', 'passed'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '2_r_009',
    sectionId: '2_r1',
    passageText: '( ) tired after the long trip, she went straight to bed.',
    questionText: 'Choose the best word for the blank.',
    choices: ['Feeling', 'Felt', 'To feel', 'Feels'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '2_r_010',
    sectionId: '2_r1',
    passageText: 'Please tell me ( ) you want for your birthday.',
    questionText: 'Choose the best word for the blank.',
    choices: ['which', 'that', 'what', 'whose'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '2_r_011',
    sectionId: '2_r1',
    passageText: 'The researchers spent months trying to ( ) the data.',
    questionText: 'Choose the best word for the blank.',
    choices: ['apologize', 'analyze', 'advertise', 'assemble'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_012',
    sectionId: '2_r1',
    passageText:
        'Despite the difficulties, the team decided to ( ) with the plan.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['go off', 'go out', 'go down', 'go ahead'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '2_r_013',
    sectionId: '2_r1',
    passageText: 'The government introduced new measures to ( ) unemployment.',
    questionText: 'Choose the best word for the blank.',
    choices: ['reduce', 'refuse', 'reply', 'remind'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '2_r_014',
    sectionId: '2_r1',
    passageText: 'It was John ( ) broke the window, not his sister.',
    questionText: 'Choose the best word for the blank.',
    choices: ['which', 'who', 'whom', 'whose'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_015',
    sectionId: '2_r1',
    passageText: 'Reading a wide variety of books can ( ) your vocabulary.',
    questionText: 'Choose the best word for the blank.',
    choices: ['expend', 'expose', 'expand', 'expire'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '2_r_016',
    sectionId: '2_r1',
    passageText: 'The two companies finally reached an ( ) after long talks.',
    questionText: 'Choose the best word for the blank.',
    choices: ['argument', 'amount', 'advantage', 'agreement'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: '2_r_017',
    sectionId: '2_r1',
    passageText: 'The famous detective was finally able to ( ) the mystery.',
    questionText: 'Choose the best word for the blank.',
    choices: ['solve', 'melt', 'spend', 'waste'],
    correctIdx: 0,
  ),
  // ── 大問2 長文の語句空所補充 (passage cloze) ──────────────────────────────
  ReadingMockItem(
    id: '2_r_018',
    sectionId: '2_r2',
    passageText:
        'Renewable energy is becoming more important worldwide. Solar and '
        'wind power generate electricity without ( ) harmful gases, which '
        'helps countries fight climate change.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['collecting', 'storing', 'releasing', 'buying'],
    correctIdx: 2,
  ),
  // ── 大問3 長文の内容一致選択 (passage comprehension) ──────────────────────
  ReadingMockItem(
    id: '2_r_019',
    sectionId: '2_r3',
    passageText:
        'Many cities have introduced bike-sharing systems. These programs '
        'reduce traffic and air pollution, and they encourage people to '
        'exercise. However, some cities struggle to maintain the bicycles in '
        'good condition.',
    questionText: 'What is one problem the passage mentions with bike-sharing?',
    choices: [
      'Heavier traffic',
      'Maintaining the bicycles',
      'A lack of exercise',
      'Having too few users',
    ],
    correctIdx: 1,
  ),
];

// ── 英検準1級 ─────────────────────────────────────────────────────────────────
const _pre1Reading = [
  // Existing 5 retained; choices reordered to remove the all-correctIdx-0 bias.
  ReadingMockItem(
    id: 'p1_r_001',
    sectionId: 'p1_r1',
    passageText:
        'The government\'s plan to ( ) urban areas by expanding public '
        'transport has gained widespread support.',
    questionText: 'Choose the best word for the blank.',
    choices: ['replicate', 'retrieve', 'revitalize', 'regulate'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p1_r_002',
    sectionId: 'p1_r1',
    passageText: 'Her research was ( ) by a major international foundation.',
    questionText: 'Choose the best word for the blank.',
    choices: ['funded', 'found', 'formed', 'framed'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_003',
    sectionId: 'p1_r3',
    passageText: 'Climate change is altering precipitation patterns worldwide. '
        'Regions that were once reliably wet are experiencing prolonged '
        'droughts, while traditionally arid areas face unprecedented floods. '
        'Scientists attribute these shifts primarily to rising global temperatures.',
    questionText: 'What is causing the changes in precipitation patterns?',
    choices: [
      'Decreased solar activity',
      'Rising global temperatures',
      'Changes in ocean currents only',
      'Volcanic eruptions',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p1_r_004',
    sectionId: 'p1_r2',
    passageText: 'The concept of circular economy aims to ( ) waste by keeping '
        'materials in use for as long as possible through recycling and repair.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['create', 'ignore', 'transfer', 'eliminate'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p1_r_005',
    sectionId: 'p1_r3',
    passageText:
        'Artificial intelligence is increasingly being used in medical diagnosis. '
        'Machine learning algorithms can analyze medical images with an accuracy '
        'that rivals or surpasses experienced physicians in some fields.',
    questionText:
        'How does AI compare to physicians in some diagnostic fields?',
    choices: [
      'It can be equally or more accurate.',
      'It is always less reliable.',
      'It can only assist with paperwork.',
      'It replaces all clinical judgment.',
    ],
    correctIdx: 0,
  ),
  // ── 大問1 短文語句空所補充 (advanced vocabulary + phrasal verbs, CEFR B2) ──
  ReadingMockItem(
    id: 'p1_r_006',
    sectionId: 'p1_r1',
    passageText:
        'The new evidence completely ( ) the detective\'s theory, so he '
        'had to start the investigation over.',
    questionText: 'Choose the best word for the blank.',
    choices: ['supported', 'ignored', 'repeated', 'undermined'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p1_r_007',
    sectionId: 'p1_r1',
    passageText:
        'During the recession, the company was forced to ( ) hundreds of '
        'workers.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['take on', 'lay off', 'put up', 'look after'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p1_r_008',
    sectionId: 'p1_r1',
    passageText:
        'Despite the serious setback, she remained ( ) and continued her '
        'research.',
    questionText: 'Choose the best word for the blank.',
    choices: ['disheartened', 'indifferent', 'undeterred', 'complacent'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p1_r_009',
    sectionId: 'p1_r1',
    passageText:
        'The politician\'s vague answers only ( ) the public\'s suspicion '
        'rather than easing it.',
    questionText: 'Choose the best word for the blank.',
    choices: ['fueled', 'reduced', 'satisfied', 'ignored'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_010',
    sectionId: 'p1_r1',
    passageText:
        'The ancient manuscript was so ( ) that scholars could barely read '
        'the text.',
    questionText: 'Choose the best word for the blank.',
    choices: ['legible', 'ornate', 'pristine', 'illegible'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p1_r_011',
    sectionId: 'p1_r1',
    passageText:
        'Her argument was so ( ) that no one in the room could find a flaw '
        'in it.',
    questionText: 'Choose the best word for the blank.',
    choices: ['confusing', 'compelling', 'weak', 'vague'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p1_r_012',
    sectionId: 'p1_r1',
    passageText:
        'The team needs to ( ) alternative solutions before the deadline.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['come up with', 'get away with', 'put up with', 'do away with'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_013',
    sectionId: 'p1_r1',
    passageText:
        'For best results, the medicine should be taken at regular ( ).',
    questionText: 'Choose the best word for the blank.',
    choices: ['distances', 'amounts', 'intervals', 'degrees'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p1_r_014',
    sectionId: 'p1_r1',
    passageText:
        'The company decided to ( ) the product launch because of serious '
        'technical problems.',
    questionText: 'Choose the best word for the blank.',
    choices: ['promote', 'pursue', 'produce', 'postpone'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p1_r_015',
    sectionId: 'p1_r1',
    passageText:
        'His extremely rude behavior at the ceremony was completely ( ).',
    questionText: 'Choose the best word for the blank.',
    choices: ['tolerable', 'inexcusable', 'commendable', 'justified'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p1_r_016',
    sectionId: 'p1_r1',
    passageText:
        'Health officials are working around the clock to ( ) the spread of '
        'the disease.',
    questionText: 'Choose the best word for the blank.',
    choices: ['maintain', 'obtain', 'contain', 'retain'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p1_r_017',
    sectionId: 'p1_r1',
    passageText:
        'The two approaches work well together; they ( ) each other\'s '
        'strengths.',
    questionText: 'Choose the best word for the blank.',
    choices: ['complement', 'contradict', 'replace', 'weaken'],
    correctIdx: 0,
  ),
  // ── 大問2 長文の語句空所補充 (passage cloze) ──────────────────────────────
  ReadingMockItem(
    id: 'p1_r_018',
    sectionId: 'p1_r2',
    passageText:
        'Bilingual education has gained popularity in recent decades. Research '
        'suggests that learning two languages from a young age can ( ) '
        'cognitive flexibility and may even delay the onset of certain brain '
        'diseases.',
    questionText: 'Choose the best word for the blank.',
    choices: ['reduce', 'prevent', 'enhance', 'replace'],
    correctIdx: 2,
  ),
  // ── 大問3 長文の内容一致選択 (passage comprehension) ──────────────────────
  ReadingMockItem(
    id: 'p1_r_019',
    sectionId: 'p1_r3',
    passageText:
        'Urban farming is growing in popularity. By growing food within cities, '
        'communities can reduce the distance food must travel, lower '
        'transportation costs, and provide fresh produce to neighborhoods that '
        'lack access to grocery stores.',
    questionText:
        'According to the passage, what is one benefit of urban farming?',
    choices: [
      'It eliminates the need for farms.',
      'It shortens the distance food travels.',
      'It lowers housing prices.',
      'It increases city traffic.',
    ],
    correctIdx: 1,
  ),
];

// ── 英検準2級プラス (2025新設, CEFR B1, between 準2級 and 2級) ──────────────────
// 大問1 短文語句空所補充 (grammar + vocabulary + phrasal verbs) + 大問3 内容一致.
// Single-valid-answer, non-cyclic key distribution, English same-POS distractors.
const _pre2plusReading = [
  ReadingMockItem(
    id: 'p2p_r_001',
    sectionId: 'p2p_r1',
    passageText: 'She ( ) for this company since 2020.',
    questionText: 'Choose the best word for the blank.',
    choices: ['works', 'worked', 'has been working', 'is working'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2p_r_002',
    sectionId: 'p2p_r1',
    passageText: 'The report ( ) by the committee before the meeting started.',
    questionText: 'Choose the best word for the blank.',
    choices: ['had been reviewed', 'reviewed', 'reviews', 'is reviewing'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    // Reworded (adversarial audit): the original was a garden-path sentence.
    // Clean, natural possessive-relative frame.
    id: 'p2p_r_003',
    sectionId: 'p2p_r1',
    passageText: 'Do you know the man ( ) car is parked outside?',
    questionText: 'Choose the best word for the blank.',
    choices: ['who', 'which', 'whom', 'whose'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p2p_r_004',
    sectionId: 'p2p_r1',
    passageText: 'This is the building ( ) the treaty was signed.',
    questionText: 'Choose the best word for the blank.',
    choices: ['which', 'where', 'that', 'when'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_005',
    sectionId: 'p2p_r1',
    passageText: 'You will not pass the exam ( ) you study harder.',
    questionText: 'Choose the best word for the blank.',
    choices: ['if', 'because', 'unless', 'although'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2p_r_006',
    sectionId: 'p2p_r1',
    passageText: '( ) she was very tired, she finished the marathon.',
    questionText: 'Choose the best word for the blank.',
    choices: ['Although', 'Because', 'So', 'Unless'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    // Reworded (adversarial audit): "carry on the mission" was a defensible
    // second answer. "exactly as it was written" forces carry out = execute.
    id: 'p2p_r_007',
    sectionId: 'p2p_r1',
    passageText: 'The team must ( ) the plan exactly as it was written.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['carry on', 'carry out', 'put off', 'take after'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_008',
    sectionId: 'p2p_r1',
    passageText: 'The outdoor concert was ( ) because of the heavy storm.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['put on', 'put up', 'put away', 'put off'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p2p_r_009',
    sectionId: 'p2p_r1',
    passageText: 'Eating vegetables is a good way to ( ) the risk of illness.',
    questionText: 'Choose the best word for the blank.',
    choices: ['reduce', 'raise', 'cause', 'produce'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2p_r_010',
    sectionId: 'p2p_r1',
    passageText: 'The new technology had a major ( ) on daily life.',
    questionText: 'Choose the best word for the blank.',
    choices: ['effort', 'result', 'impact', 'attempt'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2p_r_011',
    sectionId: 'p2p_r1',
    passageText: 'The ( ) you finish, the more free time you will have.',
    questionText: 'Choose the best word for the blank.',
    choices: ['soon', 'sooner', 'soonest', 'more soon'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_012',
    sectionId: 'p2p_r1',
    passageText: 'She is experienced ( ) to lead the whole project.',
    questionText: 'Choose the best word for the blank.',
    choices: ['too', 'very', 'so', 'enough'],
    correctIdx: 3,
  ),
  ReadingMockItem(
    id: 'p2p_r_013',
    sectionId: 'p2p_r1',
    passageText: 'The teacher will ( ) a new topic in tomorrow\'s class.',
    questionText: 'Choose the best word for the blank.',
    choices: ['introduce', 'produce', 'reduce', 'conclude'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2p_r_014',
    sectionId: 'p2p_r1',
    passageText:
        'The novel, ( ) by millions of people worldwide, became a film.',
    questionText: 'Choose the best word for the blank.',
    choices: ['reading', 'reads', 'read', 'to read'],
    correctIdx: 2,
  ),
  // ── 大問3 長文の内容一致選択 ──────────────────────────────────────────────
  ReadingMockItem(
    id: 'p2p_r_015',
    sectionId: 'p2p_r3',
    passageText:
        'Many companies now allow employees to work from home. This flexibility '
        'can improve work-life balance and cut commuting time. However, some '
        'workers report feeling isolated and find it harder to separate work '
        'from their personal lives.',
    questionText:
        'According to the passage, what is one disadvantage of working from home?',
    choices: [
      'Higher commuting costs',
      'Feeling isolated',
      'Lower salaries',
      'Longer working hours',
    ],
    correctIdx: 1,
  ),
];

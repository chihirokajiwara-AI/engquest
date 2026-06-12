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
  '4_r_023': '相手が公園に行きたいかと聞いているので、さんせいする返事「Yes, that sounds fun.（いいね）」が正かい。',
  '4_r_024': '「ありがとう」と言われたので、こたえる「You are welcome.（どういたしまして）」が正かい。',
  '4_r_025': '助けてほしいと聞かれているので「Of course, I will help you.（もちろん手伝うよ）」が正かい。',
  '4_r_026':
      '本文に「Monday to Saturday, 10 a.m. to 5 p.m.」とあるね。図書かんは「月〜土（Monday to Saturday）」に開いてるよ。',
  '4_r_027':
      '本文に「My favorite was the baby elephant」とある。一番気に入ったのは「赤ちゃんぞう（baby elephant）」だよ。',
  '4_r_028': '本文に「His favorite sport is soccer」とある。トムが一番好きなのは「サッカー（soccer）」。',
  '4_r_029':
      '本文の最後に「All meals include milk and fruit」とある。ぜんぶの食事に「ミルクとくだもの（milk and fruit）」がつくよ。',
  '4_r_030':
      '手紙に「your party on Saturday at 2:00 p.m.」とある。たんじょうび パーティーは「土よう日の午後2時」だよ。',
  '4_r_031': '天気よほうに「Please bring an umbrella」とある。明日は「かさ（umbrella）」を持ってくると良いね。',
  '4_r_032': '本文に「We usually go to the park」とある。ピクニックはいつも「公園（the park）」でするよ。',
  '4_r_033':
      'レシピに「Bake for 30 minutes at 180 degrees」とある。焼く温度（おんど）は「180度（180 degrees）」だよ。',
  '4_r_034':
      '本文に「We meet every Saturday at 3:00 p.m.」とある。クラブは「毎週土よう日の午後3時」に集まるね。',
  '4_r_035': '本文に「He is five years old」とある。バディは「5才（five years old）」だよ。',
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
  '3_r_023':
      'こたえは「At 11:00 a.m.」。お知らせに「The lions are fed at 11:00 a.m.」とあり、ライオンにえさをやる時こくが書いてあります。',
  '3_r_024':
      'こたえは「To put in new computers.」。「closed ... because we are putting in new computers」とあり、休む理ゆうは新しいコンピューターを入れるためです。',
  '3_r_025':
      'こたえは「She had a lot of fun.」。「her teacher was kind, so she had a lot of fun」とあり、エマは楽しかったと書いてあります。',
  '3_r_026':
      'こたえは「Their lunch and some water.」。「Please bring your lunch and some water.」とあり、持って行く物が書いてあります。',
  '3_r_027':
      'こたえは「Near the park.」。「She was last seen near the park」とあり、犬が最後に見られた場所は公園の近くです。',
  '3_r_028':
      'こたえは「Because of the rain.」。「it started raining ... decided to move the sports day」とあり、雨のために来週へうつしました。',
  '3_r_029':
      'こたえは「They bought new books.」。「we bought new books for our school library」とあり、お金で新しい本を買いました。',
  '3_r_030':
      'こたえは「He did not know anyone.」。「nervous ... because he knew no one there」とあり、だれも知らなかったからです。',
  // ── 英検準2級 (pre2) — content-qa-verified 2026-06-12 ──
  'p2_r_001':
      '正解は「designed」。「初心者むけに作られた」という意味で、designed for は「〜のために設計された」。空所のあとの for beginners が手がかりだよ。',
  'p2_r_002':
      '正解は「get」。get enough sleep で「じゅうぶんな睡眠をとる」という決まった言い方。健康のために毎ばん「とる」もの、と考えよう。',
  'p2_r_003':
      '正解は「After 2020」。本文に this trend started growing quickly after 2020「2020年のあとに広がった」とそのまま書いてあるよ。',
  'p2_r_004':
      '正解は「finish」。by Friday「金曜までに」終わらせたい、という流れ。Bが手伝うと言っているのも、仕事を仕上げる話だね。',
  'p2_r_005':
      '正解は「It saves energy.」。本文に it also saves energy「エネルギーも節約する」とあるよ。ほかの選択肢は本文に出てこないね。',
  'p2_r_006':
      '正解は「studying」。has been ＋ ing は現在完了進行形で、「5年間ずっと勉強している」という今もつづく動作を表すよ。',
  'p2_r_007':
      '正解は「left」。had already ＋過去分詞で「もう出てしまっていた」。着いたときより前に起きたことだから過去完了になるね。',
  'p2_r_008': '正解は「whose」。「その人の小説が有名」と、人と novels がつながるので所有を表す whose を使うよ。',
  'p2_r_009': '正解は「where」。「育った町」と場所を説明するので関係副詞 where。grew up in が場所を指す手がかりだね。',
  'p2_r_010':
      '正解は「has been closed」。since last year「去年から」ずっと、という現在完了。橋は「閉じられている」側だから受け身の形になるよ。',
  'p2_r_011': '正解は「cry」。make ＋ 人 ＋ 動詞の原形で「人を〜させる」。だから to のつかない cry が入るね。',
  'p2_r_012':
      '正解は「more」。The ＋比較級, the ＋比較級で「〜すればするほど…」。後ろが the better だから前も more になるよ。',
  'p2_r_013': '正解は「to」。too ＋形容詞＋ to ～で「～するには…すぎる」。「重すぎて一人で運べない」という意味だね。',
  'p2_r_014': '正解は「as soon as」。「着いたらすぐ電話して」という流れ。「〜するとすぐに」を表す言い方だよ。',
  'p2_r_015':
      '正解は「eating」。avoid「さける」のあとは動名詞 ～ing をとるよ。avoid to eat とは言わないので注意。',
  'p2_r_016':
      '正解は「launch」。launch a new smartphone で「新しいスマホを発売する」。来年の春に売り出す、という流れだね。',
  'p2_r_017':
      '正解は「effect」。have a positive effect on ～で「〜によい影響をあたえる」。名詞の effect「影響」を選ぼう。動詞の affect とまちがえやすいよ。',
  'p2_r_018':
      '正解は「Sure, go straight and turn left.」。道のたずね方への返事だから、行き方を教える文がぴったり。ほかは質問とかみ合わないね。',
  'p2_r_019':
      '正解は「They can learn new skills.」。本文に learn new skills「新しい技術を学ぶ」とそのまま書いてあるよ。',
  'p2_r_020':
      '正解は「analyze」。analyze the data で「データを分析する」。コンピューターでデータをくわしく調べる、という流れだね。',
  'p2_r_021':
      '正解は「rains」。If ＋ 主語 ＋ 現在形, 主語 ＋ will ～ の形（条件のif）。未来のことでも if のあとは現在形を使うよ。',
  'p2_r_022':
      '正解は「take」。take advantage of ～で「〜を利用する・いかす」。チャンスをいかして留学する、という意味だね。',
  'p2_r_023':
      '正解は「No thanks, I am fine.」。「もっとお茶はいかが？」へのていねいな断り方だよ。ほかは話がかみ合わないね。',
  'p2_r_024':
      '正解は「That sounds like a great idea.」。「テニス部に入ろうと思う」への自然な相づち。That sounds ～「〜そうだね」は会話でよく使うよ。',
  'p2_r_025':
      '正解は「More than fifty.」。本文に now more than fifty families「今は50家族以上」とあるよ。only ten は「はじめは」の数だね。',
  'p2_r_026':
      '正解は「Water and tools.」。本文に provides water and tools for free「水と道具を無料でていきょうする」とそのまま書いてあるよ。',
  'p2_r_027':
      '正解は「He had to speak English.」。本文に nervous about speaking English「英語を話すのがきんちょうした」とあるね。',
  'p2_r_028':
      '正解は「It grew.」。本文の最後に his confidence grew「自信が育った」とあるよ。grow は「育つ・大きくなる」だね。',
  'p2_r_029':
      '正解は「About eight to ten hours.」。本文に need about eight to ten hours「8〜10時間ひつよう」とあるよ。専門家の意見の部分を読み取ろう。',
  // ── 英検準2級プラス (pre2plus) — content-qa-verified 2026-06-12 ──
  'p2p_r_001':
      '正解は「has been working」。since 2020「2020年から」ずっと働いている、と今もつづく動作を表す現在完了進行形だよ。',
  'p2p_r_002':
      '正解は「had been reviewed」。会議が始まるより前に「すでに見直されていた」。前のできごとを表す過去完了の受け身だね。',
  'p2p_r_003': '正解は「whose」。「その人の車が外にとまっている」と、人と car をつなぐので所有を表す whose を使うよ。',
  'p2p_r_004':
      '正解は「where」。「条約が結ばれた建物」と場所を説明するので関係副詞 where。in the building が手がかりだね。',
  'p2p_r_005': '正解は「unless」。「もっと勉強しないかぎり合格しない」。unless は「〜しないかぎり」という意味だよ。',
  'p2p_r_006':
      '正解は「Although」。「とても疲れていたけれど完走した」と前後が逆の内容。「〜だけれど」を表す Although が合うね。',
  'p2p_r_007':
      '正解は「carry out」。carry out the plan で「計画を実行する」。書かれたとおりに「やりとげる」という意味だよ。',
  'p2p_r_008':
      '正解は「put off」。put off で「延期する・中止する」。大あらしのせいでコンサートが見おくられた、という流れだね。',
  'p2p_r_009':
      '正解は「reduce」。reduce the risk で「危険をへらす」。やさいを食べると病気のリスクが下がる、という意味だよ。',
  'p2p_r_010':
      '正解は「impact」。have a major impact on ～で「〜に大きな影響をあたえる」。impact「影響」を選ぼう。',
  'p2p_r_011':
      '正解は「sooner」。The ＋比較級, the ＋比較級で「早く終えるほど、自由時間がふえる」。後ろが more だから前も sooner になるね。',
  'p2p_r_012':
      '正解は「enough」。形容詞 ＋ enough to ～で「～するのにじゅうぶん…」。enough は形容詞の後ろにおくのがポイントだよ。',
  'p2p_r_013':
      '正解は「introduce」。introduce a new topic で「新しい話題をとり上げる・しょうかいする」。あすの授業で出す、という流れだね。',
  'p2p_r_014':
      '正解は「read」。「世界中の人に読まれた小説」と受け身の意味なので過去分詞 read。名詞 the novel を後ろから説明しているよ。',
  'p2p_r_015':
      '正解は「Feeling isolated」。本文に feeling isolated「孤独を感じる」とあり、これが在宅勤務の欠点として書かれているね。',
  'p2p_r_016':
      '正解は「The museum will be closed for repairs.」。本文に has been moved ... because the building will be closed for repairs とあり、修理のための休館が理由だね。',
  'p2p_r_017':
      '正解は「It can kill certain harmful bacteria.」。本文に researchers have discovered that honey can kill ... bacteria とあるよ。今の研究で分かったことを問う問題だね。',
  'p2p_r_018':
      '正解は「Beginners who have never swum before」。本文に for beginners who have never swum before「泳いだことのない初心者向け」と書かれているよ。',
  'p2p_r_019':
      '正解は「To meet people and make friends」。本文に To meet people, she joined a volunteer group とあり、友だちを作るために参加したと分かるね。',
  'p2p_r_020':
      '正解は「They stop water from escaping.」。本文の a waxy layer that keeps water from escaping「水分がにげるのを防ぐ」が手がかりだよ。',
  'p2p_r_021':
      '正解は「To explain that an item is delayed and offer choices」。品物が out of stock で遅れること、色の変更か返金を選べることを伝えるメールだね。',
  'p2p_r_022':
      '正解は「Hotels have been fully booked and cafes have opened.」。Since ... 以降に hotels have been fully booked, new cafes have opened とあるよ。現在完了に注目しよう。',
  'p2p_r_023':
      '正解は「It is a popular myth that is not true.」。最後に The idea ... is simply a popular myth「ただのよくある思いこみ」とあり、本当ではないと述べているね。',
  'p2p_r_024':
      '正解は「He came to enjoy it.」。running became something he actually looked forward to「楽しみになった」とあるから、好きになったと分かるよ。',
  'p2p_r_025':
      '正解は「It saves money and waste over time.」。本文の it saves both money and waste in the long run「長い目で見るとお金もごみも減らせる」が根拠だね。',
  'p2p_r_026':
      '正解は「therefore」。「宿題が終わらなかった、だから時間をもらった」と理由→結果の流れ。therefore は「だから」を表すつなぎ言葉だよ。',
  'p2p_r_027':
      '正解は「look up」。look up ～ in a dictionary で「辞書で～を調べる」。意味を調べる、という熟語だね。',
  'p2p_r_028':
      '正解は「had had」。If ＋過去完了, would have ～で「あのとき～だったら…だっただろう」という仮定法過去完了。過去の事実と反対の話だよ。',
  'p2p_r_029':
      '正解は「comply with」。comply with the rules で「規則を守る・従う」。安全基準を守れなかった、という流れだね。',
  'p2p_r_030':
      '正解は「so」。so ＋副詞 ＋ that ～で「とても…なので～」。fluently は副詞だから such ではなく so を使うよ。',
  'p2p_r_031':
      '正解は「make」。make a decision で「決定をする」という決まった組み合わせ。do や take ではなく make を使うのがポイントだよ。',
  // ── 英検2級 (grade2) — content-qa-verified 2026-06-12 ──
  '2_r_001':
      '正解は introduced「導入した」。新しい規則を「設ける」という意味で、introduce ～ to reduce…の流れに合います。intervened（介入する）や invented（発明する）は規則には合いません。',
  '2_r_002':
      '正解は found「分かった、突き止めた」。found that …で「～ということを発見した」と研究結果を述べる形です。funded（資金を出す）や formed（形づくる）では意味が通りません。',
  '2_r_003':
      '本文に、抗生物質が登場する前は「ささいな感染症さえ命にかかわった」とあります。つまりペニシリンの意義は、そうした感染症を治療できるようにしたこと。idx1 が正解です。',
  '2_r_004':
      '森が切り開かれると動物は生息地を「失う」ので lose が正解。次の and are forced to move…（移動を強いられる）が手がかりです。gain（得る）や protect（守る）では逆の意味になります。',
  '2_r_005':
      '本文の最後に which raises concerns about mental health「心の健康への心配を生む」とあります。よって本文が示す心配は心の健康への影響。idx0 が正解です。',
  '2_r_006':
      '正解は put off「延期する」。until next week「来週まで」とあるので、会議を先に延ばす意味になります。put on（着る）や put out（消す）とは意味が異なります。',
  '2_r_007':
      '正解は impact「影響」。had a significant impact on …で「～に大きな影響を与えた」という決まった言い方です。result や outcome は「結果」でも、この on を使う形には合いません。',
  '2_r_008':
      '正解は would have passed。If I had studied …, I would have …は仮定法過去完了で、過去の事実と反対のことを表します。「もっと勉強していたら合格できたのに」という意味です。',
  '2_r_009':
      '正解は Feeling。文頭で「～して」と理由を表す分詞構文です。Feeling tired …で「疲れていたので」となり、後ろの she went straight to bed につながります。',
  '2_r_010':
      '正解は what。tell me what you want で「あなたが何をほしいか教えて」という意味の名詞のかたまり（間接疑問）を作ります。先行詞がないので which や that では作れません。',
  '2_r_011':
      '正解は analyze「分析する」。研究者がデータに対してする作業として自然です。apologize（謝る）や advertise（宣伝する）は data には合いません。',
  '2_r_012':
      '正解は go ahead「進める」。go ahead with the plan で「計画を進める」という意味です。Despite the difficulties「困難にもかかわらず」の流れにも合います。',
  '2_r_013':
      '正解は reduce「減らす」。reduce unemployment で「失業を減らす」。新しい対策を取る目的として自然です。refuse（断る）や reply（返事する）では意味が通りません。',
  '2_r_014':
      '正解は who。It was John who broke …は強調構文で、「窓を割ったのはほかでもないジョンだ」と人を強調します。人が先行詞で主語の働きなので who を使います。',
  '2_r_015':
      '正解は expand「広げる」。expand your vocabulary で「語彙を増やす」という意味です。つづりの似た expend（費やす）や expire（期限が切れる）と区別しましょう。',
  '2_r_016':
      '正解は agreement「合意」。reach an agreement で「合意に達する」という決まった言い方です。長い話し合いの末という流れにも合います。argument（口論）と混同しないように。',
  '2_r_017':
      '正解は solve「解決する」。solve the mystery で「謎を解く」という決まった言い方です。名探偵がついにできたこととして自然ですね。melt（とかす）では合いません。',
  '2_r_018':
      '正解は releasing「放出すること」。without releasing harmful gases で「有害なガスを出さずに」という意味になり、気候変動と戦う助けになるという流れに合います。',
  '2_r_019':
      '本文の However 以降に、自転車を「良い状態に保つのに苦労する」とあります。これが本文の挙げる問題点。idx1（自転車の整備）が正解です。逆接の However が手がかりです。',
  '2_r_020':
      '本文に these pieces can eventually reach the human food chain「小さな破片がいずれ人の食物連鎖に入る」とあります。よって idx1 が正解です。',
  '2_r_021':
      '本文に the cost of growing food would rise sharply「食料を育てる費用が急に上がる」とあります。ミツバチがいないと食料が高くなる、idx2 が正解。',
  '2_r_022':
      '本文に Scholars from many lands gathered there「多くの土地から学者が集まった」とあります。よって idx1 が正解。建物は destroyed されたので idx0 は誤りです。',
  '2_r_023':
      '本文の Skipping sleep before an exam … can actually lower a score「試験前に睡眠をけずると点が下がる」が根拠。研究者が警告する内容なので idx1 が正解です。',
  '2_r_024':
      '本文の最後に coastal towns that depend on them「サンゴ礁にたよる海辺の町」とあります。地元の人々がたよっている、idx2 が正解です。',
  '2_r_025':
      '本文に the first person ever to win the Nobel Prize in two different fields「2つの分野でノーベル賞を取った最初の人」とあります。idx1 が正解。',
  '2_r_026':
      '本文に so that new exercise machines can be installed「新しい運動機器を入れるため」とあります。休館の理由は機器の設置、idx1 が正解です。',
  '2_r_027':
      '品物が out of stock で遅れること、色ちがいの代替か返金を選べることを伝えるメールです。遅れの説明と選択肢の提示が目的なので idx2 が正解。',
  '2_r_028':
      '正解は had。No sooner had ＋ 主語 ＋ 過去分詞 … than ～は倒置で「～するやいなや」を表します。後ろに過去分詞 begun があるので had が入ります。',
  '2_r_029':
      '正解は drink。recommend that ＋ 主語 ＋ 動詞の原形は提案を表す仮定法現在です。三人称でも s をつけず原形のままにするのがポイントです。',
  '2_r_030':
      '正解は Affected。「雨に影響されて」と受け身の意味なので過去分詞で始める分詞構文です。後ろの the festival was canceled に自然につながります。',
  '2_r_031':
      '正解は but。not only A but also B で「A だけでなく B も」という決まった組み合わせです。and や or では but also の形になりません。',
  // ── 英検準1級 (pre1) — content-qa-verified 2026-06-12 ──
  'p1_r_001':
      '正解は revitalize「再び活気づける」。公共交通を広げて都市部を活性化する計画、という意味で文意に合います。replicate（複製する）や regulate（規制する）では合いません。',
  'p1_r_002':
      '正解は funded「資金を提供された」。be funded by …で「～から資金を得る」。国際的な財団が研究を支援したという受け身の文です。found や formed とつづりが似ているので注意。',
  'p1_r_003':
      '本文の最後に attribute these shifts primarily to rising global temperatures「世界の気温上昇が主な原因」とあります。よって idx1（気温の上昇）が正解です。',
  'p1_r_004':
      '正解は eliminate「なくす」。素材をできるだけ長く使い続けて廃棄物を減らす、という循環型経済の説明に合います。create（生み出す）では逆の意味になってしまいます。',
  'p1_r_005':
      '本文に rivals or surpasses experienced physicians「経験ある医師と同じくらいか、それ以上」とあります。よって AI は同等か、それ以上に正確になりうる。idx0 が正解です。',
  'p1_r_006':
      '正解は undermined「くつがえした、弱めた」。証拠が説をくつがえしたので、so he had to start over「やり直さねばならなかった」と続きます。supported（支持する）では逆です。',
  'p1_r_007':
      '正解は lay off「解雇する」。不況の間、会社が大勢の労働者をやむを得ず解雇したという文脈です。take on（雇い入れる）は逆の意味なので注意しましょう。',
  'p1_r_008':
      '正解は undeterred「ひるまない」。大きな挫折にもかかわらず研究を続けた、という流れに合います。disheartened（落胆した）では and continued「続けた」とつながりません。',
  'p1_r_009':
      '正解は fueled「あおった」。rather than easing it「やわらげるどころか」と対比されているので、疑いを強める意味の語が入ります。reduced や satisfied では対比が崩れます。',
  'p1_r_010':
      '正解は illegible「読めない」。so … that 構文で「あまりに読めないので、学者もほとんど読めなかった」となります。反対語の legible（読みやすい）と取りちがえないように。',
  'p1_r_011':
      '正解は compelling「説得力のある」。so … that で「あまりに説得力があり、誰も欠点を見つけられなかった」。weak（弱い）や vague（あいまい）では後半と矛盾します。',
  'p1_r_012':
      '正解は come up with「思いつく、考え出す」。代わりの解決策を出すという意味です。get away with（うまく逃れる）や put up with（がまんする）とは意味が異なります。',
  'p1_r_013':
      '正解は intervals「間隔」。at regular intervals で「一定の間隔で」という決まった言い方です。薬を規則正しい間隔でのむ、という文意に合います。',
  'p1_r_014':
      '正解は postpone「延期する」。深刻な技術的問題のため発売を延ばす、という流れに合います。promote（宣伝する）や produce（生産する）では理由とかみ合いません。',
  'p1_r_015':
      '正解は inexcusable「許しがたい」。式典での非常に無礼なふるまいを表す語として合います。反対の意味の justified（正当な）や commendable（ほめるべき）では合いません。',
  'p1_r_016':
      '正解は contain「封じ込める」。contain the spread で「広がりを食い止める」という意味です。つづりの似た maintain（維持する）や obtain（手に入れる）と区別しましょう。',
  'p1_r_017':
      '正解は complement「補い合う」。work well together「うまく組み合う」とあるので、互いの強みを補完するという意味になります。contradict（矛盾する）では合いません。',
  'p1_r_018':
      '正解は enhance「高める」。二言語を学ぶことが認知の柔軟性を「高める」という流れに合います。reduce（減らす）や prevent（防ぐ）では好ましい内容と矛盾します。',
  'p1_r_019':
      '本文に reduce the distance food must travel「食料が運ばれる距離を減らせる」とあります。これが都市農業の利点。idx1（食料の移動距離を縮める）が正解です。',
  'p1_r_020':
      '本文に the duration of the waggle signals how far away the food lies「ダンスの長さが食料までの距離を示す」とあります。よって idx0（食料までの距離）が正解です。',
  'p1_r_021':
      '本文で全員が同じ井戸の水をくんでいたとわかり、ポンプを外すと流行が収まりました。水が原因という証拠です。idx0（汚れた水が運んだ）が正解です。',
  'p1_r_022':
      '本文の最後に strike a careful balance between flexibility and connection「柔軟さとつながりの均衡を取る」とあります。idx0（柔軟さと人のつながりの両立）が正解です。',
  'p1_r_023':
      '本文に corals expel the algae … and may eventually starve「藻を失い、やがて飢える」とあります。藻が食料の大半を供給するためです。idx0 が正解です。',
  'p1_r_024':
      '本文に compare it against a placebo to be sure that any benefit comes from the drug itself「効果が薬そのものから来ると確かめるため」とあります。idx0 が正解です。',
  'p1_r_025':
      '本文の最後に combine several of these cues rather than depending on any single one「複数の手がかりを組み合わせる」とあります。idx0 が正解です。',
  'p1_r_026':
      '正解は mitigate「やわらげる」。水路で洪水の被害をやわらげる、という文意に合います。aggravate（悪化させる）は逆の意味なので注意しましょう。',
  'p1_r_027':
      '正解は plausible「もっともらしい」。「一見もっともらしいが後で誤りとわかった」という流れに合います。ambiguous（あいまいな）や arbitrary（勝手な）では合いません。',
  'p1_r_028':
      '正解は scrutinize「細かく調べる」。報告書の一行ごとを精査する、という意味です。反対の disregard（無視する）や summarize（要約する）では合いません。',
  'p1_r_029':
      '正解は resilience「回復力」。けがから素早く立ち直る力を表します。reluctance（気が進まないこと）や negligence（怠慢）では文意に合いません。',
  'p1_r_030':
      '正解は deteriorate「悪化する」。治療にもかかわらず容体が悪化したので医師が心配した、という流れです。反対の flourish（栄える）では合いません。',
  'p1_r_031':
      '正解は comprehensive「包括的な」。あらゆる論点を詳しく検討した報道を表します。反対の superficial（うわべだけの）では後半と矛盾します。',
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
  // ── 大問2 会話応答 + 大問3 長文読解 (studio-expanded 2026-06-12, content-qa) ──
  ReadingMockItem(
    id: '4_r_023',
    sectionId: '4_r2',
    passageText: 'A: "Do you want to go to the park?"  B: "( )"',
    questionText: 'Choose the best response.',
    choices: [
      'Yes, that sounds fun.',
      'I like apples.',
      'It is sunny.',
      'I am tall.'
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_024',
    sectionId: '4_r2',
    passageText: 'A: "Thank you for helping me."  B: "( )"',
    questionText: 'Choose the best response.',
    choices: [
      'Thank you for coming.',
      'You are welcome.',
      'That is great!',
      'Who are you?'
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '4_r_025',
    sectionId: '4_r2',
    passageText: 'A: "Can you help me?"  B: "( )"',
    questionText: 'Choose the best response.',
    choices: [
      'Of course, I will help you.',
      'I like soccer.',
      'It is cold.',
      'See you later.'
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_026',
    sectionId: '4_r3',
    passageText: 'Library Notice: We have new English books for children! '
        'Come and read at our library. It is open Monday to Saturday, 10 a.m. to 5 p.m. '
        'On Sunday, we are closed. Books are free to borrow!',
    questionText: 'When is the library open?',
    choices: [
      'Monday to Sunday',
      'Monday to Saturday',
      'Every day',
      'Only on Saturday'
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '4_r_027',
    sectionId: '4_r3',
    passageText: 'I went to the zoo last week. I saw many animals. '
        'There were lions, elephants, and monkeys. The lions were very big and strong. '
        'My favorite was the baby elephant. It was very cute!',
    questionText: 'What was the writer\'s favorite animal?',
    choices: ['A lion', 'A monkey', 'A baby elephant', 'A big cat'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_028',
    sectionId: '4_r3',
    passageText: 'My friend Tom loves sports. He plays soccer every day. '
        'He also likes tennis and baseball. His favorite sport is soccer. '
        'He dreams of becoming a soccer player when he grows up.',
    questionText: 'What is Tom\'s favorite sport?',
    choices: ['Tennis', 'Baseball', 'Soccer', 'Swimming'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_029',
    sectionId: '4_r3',
    passageText: 'School Lunch Menu: Monday — rice, fish, and vegetables. '
        'Tuesday — curry and rice. Wednesday — spaghetti. Thursday — ramen. '
        'Friday — pizza and salad. All meals include milk and fruit.',
    questionText: 'What do all meals include?',
    choices: ['Fish', 'Vegetables', 'Milk and fruit', 'Rice'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_030',
    sectionId: '4_r3',
    passageText:
        'Dear Lisa, Thank you for the invitation to your birthday party. '
        'I will come to your party on Saturday at 2:00 p.m. I am excited! See you then.',
    questionText: 'When is Lisa\'s birthday party?',
    choices: [
      'Saturday at 2:00 p.m.',
      'Sunday at 3:00 p.m.',
      'Friday',
      'Next week'
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '4_r_031',
    sectionId: '4_r3',
    passageText:
        'Weather Report: Today is sunny and warm. The temperature is 25 degrees. '
        'Tomorrow will be cloudy, and it may rain in the evening. Please bring an umbrella.',
    questionText: 'What should people bring tomorrow?',
    choices: ['A coat', 'An umbrella', 'Sunglasses', 'A hat'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '4_r_032',
    sectionId: '4_r3',
    passageText:
        'My family likes to have a picnic on weekends. We usually go to the park. '
        'My mother makes sandwiches and cookies. My father brings drinks. '
        'We have so much fun playing and eating together.',
    questionText: 'Where does the family usually have a picnic?',
    choices: ['At the beach', 'At home', 'At the park', 'At school'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '4_r_033',
    sectionId: '4_r3',
    passageText:
        'Recipe: To make chocolate cake, you need eggs, flour, sugar, and butter. '
        'Mix all the ingredients. Bake for 30 minutes at 180 degrees. Let it cool before eating.',
    questionText: 'What temperature do you use to bake?',
    choices: ['150 degrees', '180 degrees', '200 degrees', '220 degrees'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '4_r_034',
    sectionId: '4_r3',
    passageText:
        'Adventure Club: We meet every Saturday at 3:00 p.m. in the gym. '
        'We do fun activities like hiking, camping, and rock climbing. '
        'No experience needed. Everyone is welcome! Cost: 500 yen per meeting.',
    questionText: 'When does the Adventure Club meet?',
    choices: [
      'Every Friday',
      'Every Saturday at 3:00 p.m.',
      'Every Sunday',
      'Every Tuesday'
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '4_r_035',
    sectionId: '4_r3',
    passageText: 'My dog\'s name is Buddy. He is a brown and white dog. '
        'He is five years old. Buddy loves to play fetch. He is very friendly and loves everyone.',
    questionText: 'How old is Buddy?',
    choices: [
      'Three years old',
      'Four years old',
      'Five years old',
      'Six years old'
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
  // ── 大問3 長文読解 (studio-expanded to official 30 target, 2026-06-12, content-qa) ──
  ReadingMockItem(
    id: '3_r_023',
    sectionId: '3_r3',
    passageText:
        'Notice: "The city zoo opens at 9:00 a.m. and closes at 5:00 p.m. '
        'The lions are fed at 11:00 a.m. every day. Please do not give food '
        'to the animals."',
    questionText: 'What time are the lions fed?',
    choices: ['At 9:00 a.m.', 'At 11:00 a.m.', 'At 5:00 p.m.', 'At 1:00 p.m.'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '3_r_024',
    sectionId: '3_r3',
    passageText:
        'Dear members,\nThe city library will be closed next Monday because '
        'we are putting in new computers. We will open again on Tuesday. '
        'We are sorry for the trouble.',
    questionText: 'Why will the library be closed on Monday?',
    choices: [
      'To clean the building.',
      'To put in new computers.',
      'Because it is a holiday.',
      'To buy new books.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '3_r_025',
    sectionId: '3_r3',
    passageText:
        'Last Saturday, Emma went to a cooking class for the first time. '
        'She learned how to make pizza. It was difficult, but her teacher '
        'was kind, so she had a lot of fun.',
    questionText: 'How did Emma feel about the cooking class?',
    choices: [
      'She had a lot of fun.',
      'She was bored.',
      'She was angry.',
      'She felt sick.',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_026',
    sectionId: '3_r3',
    passageText:
        'Our class will visit the mountains on Friday. We will leave school '
        'at 8:00 in the morning and walk to the top. Please bring your lunch '
        'and some water.',
    questionText: 'What should students bring on Friday?',
    choices: [
      'A camera and a map.',
      'Their lunch and some water.',
      'Warm gloves.',
      'A tennis racket.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '3_r_027',
    sectionId: '3_r3',
    passageText:
        'Lost: a small brown dog named Coco. She was last seen near the park '
        'on Sunday afternoon. She is very friendly. If you find her, please '
        'call Mr. Brown at the number below.',
    questionText: 'Where was the dog last seen?',
    choices: ['At the station.', 'Near the park.', 'In a shop.', 'At school.'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '3_r_028',
    sectionId: '3_r3',
    passageText:
        'The school sports day was planned for today. However, it started '
        'raining in the morning. The teachers decided to move the sports day '
        'to next week.',
    questionText: 'Why was the sports day moved to next week?',
    choices: [
      'Because of the rain.',
      'Because the field was small.',
      'Because the students were sick.',
      'Because it was a holiday.',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '3_r_029',
    sectionId: '3_r3',
    passageText:
        'Our class collected old newspapers for three weeks. We took them to '
        'a recycling center. With the money we got, we bought new books for '
        'our school library.',
    questionText: 'What did the class do with the money?',
    choices: [
      'They kept it for a trip.',
      'They bought new books.',
      'They gave it to the teacher.',
      'They bought a computer.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '3_r_030',
    sectionId: '3_r3',
    passageText:
        'Daniel was nervous before summer camp because he knew no one there. '
        'But on the first day, he met a boy who liked the same games. By the '
        'end of the week, they were good friends.',
    questionText: 'Why was Daniel nervous at first?',
    choices: [
      'He did not know anyone.',
      'He did not like camping.',
      'He forgot his bag.',
      'He was not feeling well.',
    ],
    correctIdx: 0,
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
  // ── 大問1 語句空所補充 (vocabulary + grammar, CEFR B1) — studio expansion 2026-06-12 ──
  ReadingMockItem(
    id: 'p2_r_020',
    sectionId: 'p2_r1',
    passageText: 'The scientist used a computer to ( ) the data carefully.',
    questionText: 'Choose the best word for the blank.',
    choices: ['announce', 'avoid', 'analyze', 'admire'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_021',
    sectionId: 'p2_r1',
    passageText: 'If it ( ) tomorrow, we will cancel the picnic.',
    questionText: 'Choose the best word for the blank.',
    choices: ['will rain', 'rained', 'rains', 'raining'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_022',
    sectionId: 'p2_r1',
    passageText: 'You should ( ) advantage of this chance to study abroad.',
    questionText: 'Choose the best word for the blank.',
    choices: ['make', 'take', 'do', 'get'],
    correctIdx: 1,
  ),
  // ── 大問2 会話文の文空所補充 (conversation response) ──────────────────────
  ReadingMockItem(
    id: 'p2_r_023',
    sectionId: 'p2_r2',
    passageText: 'A: Would you like some more tea?  B: ( )',
    questionText: 'Choose the best response.',
    choices: [
      'Yes, please turn it off.',
      'No thanks, I am fine.',
      'It is on the table.',
      'I went there last week.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2_r_024',
    sectionId: 'p2_r2',
    passageText: 'A: I am thinking of joining the tennis club.  B: ( )',
    questionText: 'Choose the best response.',
    choices: [
      'You should not have.',
      'That sounds like a great idea.',
      'No, I am not tired.',
      'Because it was raining.',
    ],
    correctIdx: 1,
  ),
  // ── 大問3 長文の内容一致選択 (passage comprehension) ──────────────────────
  ReadingMockItem(
    id: 'p2_r_025',
    sectionId: 'p2_r3',
    passageText: 'Greenfield Town started a community garden three years ago. '
        'At first, only ten families joined, but now more than fifty families '
        'grow vegetables there. The town provides water and tools for free, '
        'and members share their harvest with a local food bank.',
    questionText:
        'According to the passage, how many families grow vegetables now?',
    choices: [
      'Exactly ten.',
      'About thirty.',
      'More than fifty.',
      'Fewer than ten.',
    ],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_026',
    sectionId: 'p2_r3',
    passageText: 'Greenfield Town started a community garden three years ago. '
        'At first, only ten families joined, but now more than fifty families '
        'grow vegetables there. The town provides water and tools for free, '
        'and members share their harvest with a local food bank.',
    questionText: 'What does the town provide for free?',
    choices: [
      'Seeds and money.',
      'Water and tools.',
      'Food and clothes.',
      'Land and houses.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2_r_027',
    sectionId: 'p2_r3',
    passageText: 'Last summer, Kenji spent two weeks in Australia as part of a '
        'student exchange program. He stayed with a host family and attended a '
        'local high school. Although he was nervous about speaking English at '
        'first, he soon made many friends and his confidence grew.',
    questionText: 'Why was Kenji nervous at first?',
    choices: [
      'He missed his family.',
      'He could not find the school.',
      'He had to speak English.',
      'He did not like the food.',
    ],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2_r_028',
    sectionId: 'p2_r3',
    passageText: 'Last summer, Kenji spent two weeks in Australia as part of a '
        'student exchange program. He stayed with a host family and attended a '
        'local high school. Although he was nervous about speaking English at '
        'first, he soon made many friends and his confidence grew.',
    questionText: "What happened to Kenji's confidence during the trip?",
    choices: [
      'It grew.',
      'It disappeared.',
      'It stayed the same.',
      'It made him tired.',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2_r_029',
    sectionId: 'p2_r3',
    passageText: 'Many high school students do not get enough sleep. Experts '
        'say teenagers need about eight to ten hours each night, but many sleep '
        'far less because of homework and smartphones. Lack of sleep can make '
        'it harder to concentrate in class.',
    questionText:
        'According to experts, how many hours of sleep do teenagers need?',
    choices: [
      'About four hours.',
      'About eight to ten hours.',
      'Exactly twelve hours.',
      'Less than six hours.',
    ],
    correctIdx: 1,
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
  // ── 長文内容一致 + 語い/文法 — studio-expanded to official 31 target
  //    (2026-06-12, content-qa, §VII-verified) ──
  ReadingMockItem(
    id: '2_r_020',
    sectionId: '2_r3',
    passageText:
        'Plastic waste in the ocean has become a global crisis. Scientists '
        'estimate that millions of tons of plastic enter the sea every year. '
        'Much of it breaks down into tiny pieces that fish mistake for food, '
        'and these pieces can eventually reach the human food chain.',
    questionText:
        'According to the passage, why is ocean plastic a danger to people?',
    choices: [
      'It makes seawater taste bad.',
      'Tiny pieces can reach the food we eat.',
      'It raises the price of fish.',
      'It blocks ships from sailing.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_021',
    sectionId: '2_r3',
    passageText:
        'Honeybees play a vital role in agriculture. By carrying pollen from '
        'one flower to another, they allow many crops to produce fruit. If '
        'these insects were to disappear, the cost of growing food would rise '
        'sharply, and some foods might become rare.',
    questionText: 'What does the passage say would happen without honeybees?',
    choices: [
      'Flowers would grow faster.',
      'Farms would need fewer workers.',
      'Food would become more expensive.',
      'Bees would move to the city.',
    ],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '2_r_022',
    sectionId: '2_r3',
    passageText:
        'The ancient Library of Alexandria was one of the greatest centers of '
        'learning in the ancient world. Scholars from many lands gathered '
        'there to study and copy thousands of scrolls. Although the building '
        'was eventually destroyed, its reputation still inspires libraries '
        'today.',
    questionText: 'What is true about the Library of Alexandria?',
    choices: [
      'It still stands in its original form.',
      'It welcomed scholars from many places.',
      'It was used only by local students.',
      'It refused to lend out its scrolls.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_023',
    sectionId: '2_r3',
    passageText:
        'A recent study suggests that students who sleep at least eight hours '
        'perform better on tests. Researchers found that sleep helps the brain '
        'organize and store new information. Skipping sleep before an exam, '
        'they warn, can actually lower a student score.',
    questionText: 'What do the researchers warn against?',
    choices: [
      'Studying in a quiet room',
      'Losing sleep before an exam',
      'Taking too many tests',
      'Eating before bed',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_024',
    sectionId: '2_r3',
    passageText:
        'Coral reefs support about a quarter of all ocean species, yet they '
        'cover less than one percent of the sea floor. When water becomes too '
        'warm, corals lose their color and may die. Protecting reefs is '
        'therefore important not only for fish but also for coastal towns that '
        'depend on them.',
    questionText: 'Why are coral reefs important for coastal towns?',
    choices: [
      'They make the water warmer.',
      'They cover most of the sea floor.',
      'Local communities rely on them.',
      'They produce most of the world oxygen.',
    ],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '2_r_025',
    sectionId: '2_r3',
    passageText:
        'Marie Curie was a scientist who studied radioactivity. Working in a '
        'poorly equipped laboratory, she discovered two new elements. She '
        'became the first person ever to win the Nobel Prize in two different '
        'fields of science.',
    questionText: 'What was special about Marie Curie?',
    choices: [
      'She built her own large laboratory.',
      'She won the Nobel Prize in two fields.',
      'She refused to share her discoveries.',
      'She studied only one chemical element.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_026',
    sectionId: '2_r3',
    passageText:
        'Notice to all members: The community gym will be closed next Monday '
        'and Tuesday so that new exercise machines can be installed. The pool '
        'will stay open as usual. We are sorry for any trouble this may cause '
        'and thank you for your patience.',
    questionText: 'Why will the gym be closed for two days?',
    choices: [
      'To clean the swimming pool',
      'To install new machines',
      'To train new staff members',
      'To hold a sports event',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_027',
    sectionId: '2_r3',
    passageText:
        'Dear Mr. Tanaka, Thank you for your order. Unfortunately, the desk '
        'you chose is out of stock and will not arrive for three weeks. If you '
        'cannot wait, we can offer you a similar model in a different color, '
        'or give you a full refund. Please let us know which you prefer.',
    questionText: 'What is the main purpose of this email?',
    choices: [
      'To advertise a new desk',
      'To cancel the customer account',
      'To explain a delay and offer choices',
      'To ask the customer to pay again',
    ],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '2_r_028',
    sectionId: '2_r1',
    passageText:
        'No sooner ( ) the concert begun than the power suddenly went out.',
    questionText: 'Choose the best word for the blank.',
    choices: ['had', 'has', 'was', 'did'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: '2_r_029',
    sectionId: '2_r1',
    passageText:
        'The doctor strongly recommended that he ( ) more water every day.',
    questionText: 'Choose the best word for the blank.',
    choices: ['drinks', 'drank', 'drink', 'drinking'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: '2_r_030',
    sectionId: '2_r1',
    passageText: '( ) by heavy rain, the outdoor festival had to be canceled.',
    questionText: 'Choose the best word for the blank.',
    choices: ['Affecting', 'Affected', 'To affect', 'Affects'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: '2_r_031',
    sectionId: '2_r1',
    passageText:
        'She is not only a talented painter ( ) also a gifted musician.',
    questionText: 'Choose the best word for the blank.',
    choices: ['and', 'but', 'or', 'so'],
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
  // ── 長文 + 上級語い空所 — studio-expanded to official 31 target
  //    (2026-06-12, content-qa, §VII-verified) ──
  ReadingMockItem(
    id: 'p1_r_020',
    sectionId: 'p1_r3',
    passageText:
        'Honeybees communicate the location of food through a behavior known as '
        'the waggle dance. By moving in a figure-eight pattern and vibrating '
        'their bodies, a foraging bee tells the rest of the hive both the '
        'direction and the distance of a flower patch. The angle of the dance '
        'relative to the vertical indicates the direction relative to the sun, '
        'while the duration of the waggle signals how far away the food lies.',
    questionText: 'What does the duration of the waggle dance indicate?',
    choices: [
      'How far away the food source is',
      'The exact species of the flower',
      'The number of bees in the hive',
      'The temperature outside the hive',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_021',
    sectionId: 'p1_r3',
    passageText:
        'In the nineteenth century, many cities suffered repeated outbreaks of '
        'cholera. People widely believed the disease spread through foul air. '
        'A physician named John Snow doubted this idea. By mapping the homes of '
        'the victims, he discovered that nearly all of them had drawn water '
        'from a single public pump. When officials removed the pump handle, the '
        'outbreak faded, offering early evidence that contaminated water, not '
        'air, carried the disease.',
    questionText: 'What did John Snow conclude about the cause of cholera?',
    choices: [
      'It was carried by contaminated water',
      'It was spread by foul air',
      'It was caused by overcrowded housing',
      'It could not be traced to any source',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_022',
    sectionId: 'p1_r3',
    passageText:
        'Many companies now allow employees to work remotely, and the trend '
        'shows no sign of fading. Supporters argue that it saves commuting time '
        'and widens the pool of available talent. Critics, however, warn that '
        'it can weaken the bonds between colleagues and make it harder for new '
        'staff to absorb the culture of a workplace. The author suggests that '
        'the most successful firms will be those that strike a careful balance '
        'between flexibility and connection.',
    questionText: 'What does the author suggest about successful firms?',
    choices: [
      'They will balance flexibility with personal connection',
      'They will abandon remote work entirely',
      'They will hire only experienced staff',
      'They will ignore the concerns of critics',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_023',
    sectionId: 'p1_r3',
    passageText:
        'Coral reefs are among the most diverse ecosystems on the planet, yet '
        'they are remarkably fragile. When ocean temperatures rise even '
        'slightly, corals expel the tiny algae that live within them and supply '
        'most of their food. Without these algae, the coral turns white, a '
        'process called bleaching, and may eventually starve. Although bleached '
        'reefs can recover if cooler conditions return quickly, repeated events '
        'leave them little time to heal.',
    questionText: 'Why does coral bleaching threaten the survival of reefs?',
    choices: [
      'The coral loses the algae that provide most of its food',
      'The coral becomes too heavy to remain attached',
      'Warmer water makes the coral grow too quickly',
      'The white color attracts more predators',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_024',
    sectionId: 'p1_r3',
    passageText:
        'The placebo effect describes how patients sometimes improve after '
        'taking a treatment that contains no active medicine at all. Researchers '
        'believe the effect arises partly from expectation: when people trust '
        'that they will get better, the brain may release chemicals that ease '
        'symptoms. Because of this, scientists testing a new drug must compare '
        'it against a placebo to be sure that any benefit comes from the drug '
        'itself rather than from belief.',
    questionText: 'Why must scientists compare a new drug against a placebo?',
    choices: [
      'To confirm the benefit comes from the drug, not from belief',
      'To make the new drug cheaper to produce',
      'To prove that the placebo contains active medicine',
      'To speed up the approval of the treatment',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_025',
    sectionId: 'p1_r3',
    passageText:
        'For centuries, the precise mechanism of bird migration puzzled '
        'naturalists. Recent studies suggest that some species can sense the '
        'magnetic field of the Earth, using it as an internal compass during '
        'long flights across featureless ocean. Other birds appear to rely on '
        'the position of the stars or on landmarks learned from older members '
        'of the flock. Most likely, migrating birds combine several of these '
        'cues rather than depending on any single one.',
    questionText: 'What does the passage conclude about how birds navigate?',
    choices: [
      'They probably combine several different cues',
      'They depend solely on the magnetic field',
      'They follow only the oldest bird in the flock',
      'They are unable to cross open ocean',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_026',
    sectionId: 'p1_r3',
    passageText:
        'The city built a series of wide drainage canals in an effort to ( ) '
        'the damage caused by seasonal floods.',
    questionText: 'Choose the best word for the blank.',
    choices: ['mitigate', 'aggravate', 'accumulate', 'allocate'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_027',
    sectionId: 'p1_r3',
    passageText:
        'The witness offered a ( ) account of the accident, but later evidence '
        'showed that several of the details were false.',
    questionText: 'Choose the best word for the blank.',
    choices: ['plausible', 'arbitrary', 'redundant', 'ambiguous'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_028',
    sectionId: 'p1_r3',
    passageText:
        'Before approving the budget, the committee asked an independent team '
        'to ( ) every line of the financial report.',
    questionText: 'Choose the best word for the blank.',
    choices: ['scrutinize', 'disregard', 'summarize', 'postpone'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_029',
    sectionId: 'p1_r3',
    passageText:
        'The young athlete showed remarkable ( ), recovering quickly from each '
        'injury and returning stronger than before.',
    questionText: 'Choose the best word for the blank.',
    choices: ['resilience', 'reluctance', 'negligence', 'indifference'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_030',
    sectionId: 'p1_r3',
    passageText:
        'Despite the new treatment, the patient continued to ( ), and the '
        'doctors grew increasingly worried.',
    questionText: 'Choose the best word for the blank.',
    choices: ['deteriorate', 'flourish', 'stabilize', 'accelerate'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p1_r_031',
    sectionId: 'p1_r3',
    passageText:
        'The journalist was praised for her ( ) coverage of the election, '
        'which examined every major issue in thorough detail.',
    questionText: 'Choose the best word for the blank.',
    choices: ['comprehensive', 'superficial', 'reluctant', 'tentative'],
    correctIdx: 0,
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
  // ── 大問3 長文の内容一致 (B1) + 語い/文法 空所補充 — studio-expanded to official
  //    31 target (2026-06-12, content-qa, §VII-verified) ──
  ReadingMockItem(
    id: 'p2p_r_016',
    sectionId: 'p2p_r3',
    passageText:
        'Subject: School Trip\n\nDear students,\nThe museum visit planned for '
        'Thursday has been moved to the following Monday because the building '
        'will be closed for repairs. The bus will still leave from the main '
        'gate at 8:30 a.m. Please bring the form your parents have signed.',
    questionText: 'Why was the museum visit changed to a different day?',
    choices: [
      'The bus broke down.',
      'The museum will be closed for repairs.',
      'The students were not ready.',
      'The teachers were busy on Thursday.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_017',
    sectionId: 'p2p_r3',
    passageText:
        'Honey has been used as a natural medicine for thousands of years. '
        'Long before modern science, people put it on wounds because it helped '
        'them heal. Today, researchers have discovered that honey can kill '
        'certain harmful bacteria, which explains why those early treatments '
        'often worked.',
    questionText: 'What have modern researchers discovered about honey?',
    choices: [
      'It tastes better than sugar.',
      'It can kill certain harmful bacteria.',
      'It was invented by scientists.',
      'It should never be put on wounds.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_018',
    sectionId: 'p2p_r3',
    passageText:
        'Notice: The community pool will offer free swimming lessons every '
        'Saturday in July. The lessons are designed for beginners who have '
        'never swum before. Spaces are limited, so anyone who wants to join '
        'must sign up at the front desk by June 30.',
    questionText: 'Who are these lessons mainly intended for?',
    choices: [
      'People who already swim well',
      'Beginners who have never swum before',
      'Children under three years old',
      'Visitors from other towns only',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_019',
    sectionId: 'p2p_r3',
    passageText:
        'When Mia moved to a new town, she was worried that she would not make '
        'any friends. To meet people, she joined a volunteer group that cleaned '
        'the local park every weekend. Although the work was tiring, she soon '
        'felt that she belonged, and the other members became like a second '
        'family to her.',
    questionText: 'Why did Mia join the volunteer group?',
    choices: [
      'To earn some extra money',
      'To get exercise on weekends',
      'To meet people and make friends',
      'Because her teacher told her to',
    ],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2p_r_020',
    sectionId: 'p2p_r3',
    passageText:
        'Some plants are able to survive in deserts where almost no rain falls. '
        'Their leaves are often thin and covered with a waxy layer that keeps '
        'water from escaping. In addition, their roots spread widely so that '
        'they can absorb any water as soon as it reaches the ground.',
    questionText: 'How do the waxy leaves help these desert plants?',
    choices: [
      'They make the plants grow taller.',
      'They stop water from escaping.',
      'They attract more insects.',
      'They protect the plants from the cold.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_021',
    sectionId: 'p2p_r3',
    passageText:
        'Subject: Order Update\n\nThank you for your order. Unfortunately, the '
        'blue jacket you chose is currently out of stock and will not arrive '
        'until next month. If you do not wish to wait, you may either choose a '
        'different color or cancel your order for a full refund.',
    questionText: 'What is the main reason for this email?',
    choices: [
      'To thank the customer for visiting the store',
      'To explain that an item is delayed and offer choices',
      'To advertise a new jacket on sale',
      'To remind the customer to pay',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_022',
    sectionId: 'p2p_r3',
    passageText:
        'For years, the small town of Riverton had been losing visitors. Then '
        'the local council decided to hold a music festival each autumn. Since '
        'the first festival was held, hotels have been fully booked and many '
        'new cafes have opened. The event has brought new life to the whole '
        'area.',
    questionText: 'What has happened since the festival began?',
    choices: [
      'The town has become quieter than before.',
      'Hotels have been fully booked and cafes have opened.',
      'The council has cancelled all future events.',
      'Visitors have stopped coming to the town.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_023',
    sectionId: 'p2p_r3',
    passageText:
        'Many people believe that we only use a small part of our brains, but '
        'this is not true. Scientists who study the brain have shown that '
        'almost every region is active at some point during a normal day. The '
        'idea that most of the brain is unused is simply a popular myth.',
    questionText:
        'What does the passage say about the idea that we use only a small part of our brains?',
    choices: [
      'It has been proven by scientists.',
      'It is true only while we sleep.',
      'It is a popular myth that is not true.',
      'It applies to children but not adults.',
    ],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2p_r_024',
    sectionId: 'p2p_r3',
    passageText:
        'Tom had always wanted to run a marathon, but he kept finding reasons '
        'to put it off. After a friend signed up with him, he finally began '
        'training every morning. The early starts were hard at first; however, '
        'as the weeks passed, running became something he actually looked '
        'forward to.',
    questionText: 'How did Tom feel about running by the end of the passage?',
    choices: [
      'He came to enjoy it.',
      'He decided to give it up.',
      'He found it more boring than before.',
      'He was too tired to continue.',
    ],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2p_r_025',
    sectionId: 'p2p_r3',
    passageText:
        'Reusing shopping bags is one simple way to help the environment. A '
        'single cloth bag can replace hundreds of plastic ones over its life. '
        'While a cloth bag costs more at first, it saves both money and waste '
        'in the long run, which is why many stores now encourage shoppers to '
        'bring their own.',
    questionText:
        'According to the passage, what is one benefit of using a cloth bag?',
    choices: [
      'It is cheaper to buy than a plastic bag.',
      'It saves money and waste over time.',
      'It can only be used a few times.',
      'It is given away free at every store.',
    ],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_026',
    sectionId: 'p2p_r3',
    passageText:
        'I could not finish the homework; ( ), I asked my teacher for more time.',
    questionText: 'Choose the best word for the blank.',
    choices: ['therefore', 'however', 'although', 'unless'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2p_r_027',
    sectionId: 'p2p_r3',
    passageText:
        'Please ( ) these difficult words in a dictionary before class.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['look after', 'look up', 'look for', 'look into'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_028',
    sectionId: 'p2p_r3',
    passageText:
        'If I ( ) more time yesterday, I would have visited the castle.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['have had', 'had had', 'have', 'would have'],
    correctIdx: 1,
  ),
  ReadingMockItem(
    id: 'p2p_r_029',
    sectionId: 'p2p_r3',
    passageText:
        'The factory was closed down because it failed to ( ) the new safety rules.',
    questionText: 'Choose the best phrase for the blank.',
    choices: ['comply with', 'depend on', 'give up', 'take part'],
    correctIdx: 0,
  ),
  ReadingMockItem(
    id: 'p2p_r_030',
    sectionId: 'p2p_r3',
    passageText:
        'She speaks English ( ) fluently that people think she grew up abroad.',
    questionText: 'Choose the best word for the blank.',
    choices: ['such', 'too', 'so', 'very'],
    correctIdx: 2,
  ),
  ReadingMockItem(
    id: 'p2p_r_031',
    sectionId: 'p2p_r3',
    passageText: 'We need to ( ) a decision soon, or we will miss the chance.',
    questionText: 'Choose the best word for the blank.',
    choices: ['make', 'do', 'take', 'give'],
    correctIdx: 0,
  ),
];

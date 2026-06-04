// lib/features/quest/quest_data.dart
// A-KEN Quest — the Adventure (ドラクエ型 英語クエスト)
//
// The hero is secretly a prince/princess. They travel town to town; the people
// they meet speak English at that town's 英検 level. The player advances by
// choosing the correct English reply. A student starts at the town matching
// their own 英検 level (e.g. a 準2級 holder starts in the 準2級 town).

/// One conversational encounter: an NPC speaks, the player picks the right reply.
class QuestEncounter {
  final String npcName;
  final String npcEmoji;

  /// What the NPC says (English, at the town's level).
  final String npcLine;

  /// Optional Japanese gloss for young learners (shown small).
  final String? npcLineJa;

  /// Reply options the player chooses from.
  final List<String> choices;

  /// Index into [choices] of the correct, natural reply.
  final int correctIndex;

  /// The NPC's response / story beat shown after a correct reply.
  final String onCorrect;

  const QuestEncounter({
    required this.npcName,
    required this.npcEmoji,
    required this.npcLine,
    this.npcLineJa,
    required this.choices,
    required this.correctIndex,
    required this.onCorrect,
  });
}

/// A town on the quest, gated to one 英検 grade / CEFR level.
class QuestTown {
  final String id;
  final String eikenLevel; // '5','4','3','pre2','2','pre1'
  final String cefr; // 'A1'...
  final String name; // 日本語の街名
  final String tagline; // short flavor line
  final String intro; // story text shown on entering the town
  final List<QuestEncounter> encounters;

  /// Story payoff shown on the cleared screen: the recovered 声の石 and the
  /// arc beat for this town. Optional so existing literals stay valid.
  final String? cleared;

  const QuestTown({
    required this.id,
    required this.eikenLevel,
    required this.cefr,
    required this.name,
    required this.tagline,
    required this.intro,
    required this.encounters,
    this.cleared,
  });
}

/// The hero's opening — revealed once, at the very start of the quest.
const String kQuestPrologue =
    'あなたは、じつは王子（おうじ）／王女（おうじょ）。\n'
    '魔王（まおう）サイレントが、世界（せかい）の「ことば」を食（た）べ、色（いろ）が消（き）えていく。\n'
    'むねの石（いし）を手（て）に、声（こえ）の石（いし）を集（あつ）める旅（たび）へ。\n'
    'ことばの力（ちから）で、世界（せかい）を取（と）りもどそう。';

/// Towns in order, easiest → hardest. A player enters at the town matching
/// their placement level; clearing a town unlocks the next.
const List<QuestTown> kQuestTowns = [
  QuestTown(
    id: 'town_eiken5',
    eikenLevel: '5',
    cefr: 'A1',
    name: 'はじまりの村',
    tagline: 'やさしいあいさつの村',
    intro: 'ここは旅（たび）のはじまりの村（むら）。けれど、みんな「ハロー」を忘（わす）れてしまった。'
        '正（ただ）しいあいさつで、村（むら）に「ことば」をとりもどそう。',
    cleared: '村（むら）に声（こえ）がもどった！ 最初（さいしょ）の〈声（こえ）の石（いし）〉がひかる。'
        'スラが「ハロー！」と、はじめて言（い）えた。',
    encounters: [
      // 1 — Greeting. スラ re-learns 'Hello'. (大問2型)
      QuestEncounter(
        npcName: 'スラ',
        npcEmoji: '🟢',
        npcLine: '... ... (A small slime opens its mouth, but no word comes out.)',
        npcLineJa: 'ちいさなスライムが口（くち）をひらくけれど、ことばが出（で）てこない…',
        choices: ['Goodbye.', 'Hello!', 'Thank you.', 'I am sorry.'],
        correctIndex: 1,
        onCorrect:
            "H...Hello! ...I remember it now — Hello! You gave me back my first word. I'm Sura. Can I come with you?",
      ),
      // 2 — be動詞 I am + 定型応答. (大問2型)
      QuestEncounter(
        npcName: 'むらびと',
        npcEmoji: '🧑‍🌾',
        npcLine: 'How are you?',
        npcLineJa: 'お元気（げんき）ですか？',
        choices: ["I'm a village.", 'I am Tuesday.', "I'm fine, thank you.", 'You are fine.'],
        correctIndex: 2,
        onCorrect: 'Good! Welcome to our village, traveller.',
      ),
      // 3 — be動詞 + 所有格 my. (大問1型)
      QuestEncounter(
        npcName: 'おんなのこ',
        npcEmoji: '👧',
        npcLine: "What's your name?",
        npcLineJa: 'お名前（なまえ）は、なんですか？',
        choices: ['My name is Leo.', 'Your name is Leo.', 'I name is Leo.', "It's three o'clock."],
        correctIndex: 0,
        onCorrect: 'Leo! Nice to meet you, Leo. Sura likes you too!',
      ),
      // 4 — be動詞の人称一致 (You are). (大問1 文法型)
      QuestEncounter(
        npcName: 'もんばん',
        npcEmoji: '💂',
        npcLine: 'You ___ a traveller. Welcome.',
        npcLineJa: 'あなた「は」旅人（たびびと）ですね。 ___ に入（はい）るのは？',
        choices: ['am', 'are', 'is', 'be'],
        correctIndex: 1,
        onCorrect: 'Yes — you ARE a traveller. Pass through, friend.',
      ),
      // 5 — be動詞 3人称 + 代名詞 he/she. (大問1 文法型)
      QuestEncounter(
        npcName: 'おとこのこ',
        npcEmoji: '👦',
        npcLine: 'Look, that is my sister. ___ is kind.',
        npcLineJa: 'ほら、あれは妹（いもうと）です。「彼女（かのじょ）は」やさしいよ。 ___ は？',
        choices: ['He', 'It', 'She', 'You'],
        correctIndex: 2,
        onCorrect: 'Yes! She is very kind. You speak well, traveller!',
      ),
      // 6 — this / that + be動詞. (大問1型)
      QuestEncounter(
        npcName: 'おばあさん',
        npcEmoji: '👵',
        npcLine: '(pointing far away) What is that on the hill?',
        npcLineJa: '（遠（とお）くを指（ゆび）さして）あの丘（おか）の上（うえ）にあるのは、何（なん）ですか？',
        choices: ['This is a castle.', 'That is a castle.', 'That is castle.', 'These is a castle.'],
        correctIndex: 1,
        onCorrect:
            'That is the old castle... where a prince was born, they say. Strange — your eyes look just like his.',
      ),
      // 7 — 冠詞 a / an. (大問1型)
      QuestEncounter(
        npcName: 'パンやさん',
        npcEmoji: '🥐',
        npcLine: 'Are you hungry? Here, this is ___ apple.',
        npcLineJa: 'おなか、すいてる？ ほら、これは ___ りんごだよ。 ___ は？',
        choices: ['a', 'an', 'the', 'one'],
        correctIndex: 1,
        onCorrect: "An apple — well said! Take it. A growing traveller must eat.",
      ),
      // 8 — 複数形 -s. (大問1型)
      QuestEncounter(
        npcName: 'はなやさん',
        npcEmoji: '💐',
        npcLine: 'I have one flower here, and over there I have many ___.',
        npcLineJa: 'ここに花（はな）が1本（ぽん）、あそこには、たくさんの ___ があるの。 ___ は？',
        choices: ['flower', 'flowers', 'a flower', 'flower s'],
        correctIndex: 1,
        onCorrect: 'Yes, many flowers! Take one for luck on your journey.',
      ),
      // 9 — 一般動詞 現在形（1人称）. (大問1型)
      QuestEncounter(
        npcName: 'こども',
        npcEmoji: '🧒',
        npcLine: 'Do you like games? I ___ soccer every day!',
        npcLineJa: 'ゲームは好（す）き？ ぼくは毎日（まいにち）サッカーを ___ よ！ ___ は？',
        choices: ['am play', 'play', 'plays', 'playing'],
        correctIndex: 1,
        onCorrect: 'You play soccer too? Let’s play after you save our village!',
      ),
      // 10 — 3単現 s/es（頻出トラップ）. (大問1 文法型)
      QuestEncounter(
        npcName: 'いぬのかいぬし',
        npcEmoji: '🐕',
        npcLine: 'My dog is happy with you! He ___ new friends.',
        npcLineJa: 'うちの犬（いぬ）、あなたが好（す）きみたい！ 新（あたら）しい友（とも）だちが ___ んだ。 ___ は？',
        choices: ['like', 'likes', 'am like', 'is like'],
        correctIndex: 1,
        onCorrect: 'He likes you a lot! See? Even animals trust a kind heart.',
      ),
      // 11 — 否定文 don't. (大問1 文法型)
      QuestEncounter(
        npcName: 'りょうし',
        npcEmoji: '🎣',
        npcLine: 'Do you eat fish? Some travellers ___ eat fish.',
        npcLineJa: '魚（さかな）は食（た）べる？ 旅人（たびびと）の中（なか）には、魚を食べ ___ 人（ひと）もいるよ。 ___ は？',
        choices: ['not', "doesn't", "don't", 'no'],
        correctIndex: 2,
        onCorrect: "Right — some don't. But you'll eat anything, eh? Good. A traveller needs strength.",
      ),
      // 12 — 助動詞 can. (大問1 文法型)
      QuestEncounter(
        npcName: 'おんがくか',
        npcEmoji: '🎻',
        npcLine: 'The song is lost. ___ you sing with me?',
        npcLineJa: '歌（うた）が消（き）えてしまった。いっしょに歌（うた）って ___ ？ ___ は？',
        choices: ['Are', 'Do', 'Can', 'Is'],
        correctIndex: 2,
        onCorrect: "Yes! Together — la la la! See, words come back when we are not afraid to use them.",
      ),
      // 13 — 疑問詞 what + be動詞. (大問2型)
      QuestEncounter(
        npcName: 'こどものスラ',
        npcEmoji: '🟢',
        npcLine: '(Sura points at a strange fruit) ___ is this?',
        npcLineJa: '（スラがふしぎな果物（くだもの）を指（ゆび）さして）これは ___ ？ ___ は？',
        choices: ['Who', 'Where', 'What', 'How'],
        correctIndex: 2,
        onCorrect: "It's a peach! What is this, what is that — Sura wants to learn every word now!",
      ),
      // 14 — 疑問詞 who + 代名詞. (大問2型)
      QuestEncounter(
        npcName: 'むらおさ',
        npcEmoji: '🧓',
        npcLine: 'A knight stands at the gate. Who is he?',
        npcLineJa: '門（もん）に騎士（きし）が立（た）っている。彼（かれ）は誰（だれ）ですか？',
        choices: ['It is a gate.', 'He is my guard.', 'She is my guard.', 'Who is my guard.'],
        correctIndex: 1,
        onCorrect:
            'He is my guard, yes. He has waited years for a true prince to return... I wonder.',
      ),
      // 15 — 疑問詞 where + 前置詞 in/on/under. (大問1 前置詞型)
      QuestEncounter(
        npcName: 'ねこ',
        npcEmoji: '🐈',
        npcLine: 'My ball is gone! Where is it? ...Oh, it is ___ the box.',
        npcLineJa: 'ボールがない！ どこ？ …あ、箱（はこ）「の中（なか）」に ___ あった。 ___ は？',
        choices: ['on', 'in', 'to', 'at'],
        correctIndex: 1,
        onCorrect: 'In the box — meow, thank you! You found my words AND my ball!',
      ),
      // 16 — how many + 複数形 → 数で答える. (大問2型)
      QuestEncounter(
        npcName: 'やおやさん',
        npcEmoji: '🧺',
        npcLine: 'How many apples do you want?',
        npcLineJa: 'りんごは、いくつ ほしいですか？',
        choices: ['I want three apples.', 'I am three.', "It's red.", 'Yes, I want.'],
        correctIndex: 0,
        onCorrect: 'Three apples! Here you are. A good traveller knows their numbers.',
      ),
      // 17 — 現在進行形 be + ~ing. (大問1 文法型)
      QuestEncounter(
        npcName: 'がか',
        npcEmoji: '🎨',
        npcLine: 'Look at me! I am ___ a picture of the castle now.',
        npcLineJa: '見（み）て！ いま、お城（しろ）の絵（え）を ___ いるところ。 ___ は？',
        choices: ['paint', 'paints', 'painting', 'painted'],
        correctIndex: 2,
        onCorrect: "I'm painting the castle, yes. ...They say its true prince is on the road again.",
      ),
      // 18 — 命令文 / Let's. (大問2型)
      QuestEncounter(
        npcName: 'こどもたち',
        npcEmoji: '🧒',
        npcLine: 'We want to play together! What do we say?',
        npcLineJa: 'みんなで遊（あそ）びたい！ なんて言（い）えばいい？',
        choices: ['We are play.', "Let's play!", 'You play me.', 'Do play?'],
        correctIndex: 1,
        onCorrect: "Let's play! Hooray! The village sounds alive again — listen!",
      ),
      // 19 — 疑問文の語順（語句整序の感覚）. (大問3型)
      QuestEncounter(
        npcName: 'たびのしょうにん',
        npcEmoji: '🧳',
        npcLine: '「あなたは地図を持っていますか？」 Choose the correct order.',
        npcLineJa: '正（ただ）しい語順（ごじゅん）をえらぼう：「あなたは地図（ちず）を持（も）っていますか？」',
        choices: ['You do have a map?', 'Do have you a map?', 'Do you have a map?', 'Have you a map do?'],
        correctIndex: 2,
        onCorrect: "Do you have a map? — perfect order! Here, take mine. The road ahead is dark.",
      ),
      // 20 — Boss gate. 総合運用 + 魔王サイレント. (大問2 総合)
      QuestEncounter(
        npcName: '魔王（まおう）サイレントの影（かげ）',
        npcEmoji: '🌑',
        npcLine: "Silence... is peace. Why do you bring words back, little prince?",
        npcLineJa: 'しずけさ…こそ、へいわ。なぜ言葉（ことば）をもどす、小（ちい）さな王子（おうじ）よ？',
        choices: [
          'I am peace.',
          'You are silent.',
          'I can speak, and I am not afraid.',
          'Silence is a box.',
        ],
        correctIndex: 2,
        onCorrect:
            "...You are not afraid. Hmph. The first stone is yours, prince. But the world has six more silences... and I will be at the last.",
      ),
    ],
  ),
  // Higher towns: structure in place; encounters authored per level next.
  QuestTown(
    id: 'town_eiken4',
    eikenLevel: '4',
    cefr: 'A2',
    name: '風（かぜ）の街',
    tagline: '毎日のくらしの街',
    intro: '風（かぜ）の街（まち）。毎日（まいにち）のくらしの言葉（ことば）が、風（かぜ）にさらわれて消（き）えかけている。'
        '人々（ひとびと）の一日（いちにち）を、英語（えいご）でつないであげよう。',
    cleared: '街（まち）に毎日（まいにち）のおしゃべりがもどった。二（ふた）つ目（め）の〈声（こえ）の石（いし）〉を手（て）に。'
        '「魔王（まおう）は、しずけさを“へいわ”だと思（おも）っているらしい」とスラがつぶやく。',
    encounters: [
      // 1 — be動詞 過去 was/were. 5級の現在から「昨日」へ。(大問1 文法型)
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "You were not in class yesterday. Where ___ you?",
        npcLineJa: "きのう、じゅぎょうにいませんでしたね。あなたは どこに ___ ？",
        choices: ["are", "was", "were", "did"],
        correctIndex: 2,
        onCorrect: "Ah, you WERE sick. I hope you feel better now. Welcome back to the Wind Town.",
      ),
      // 2 — 規則過去 -ed。現在→過去への一歩。(大問1 文法型)
      QuestEncounter(
        npcName: "おかあさん",
        npcEmoji: "👩",
        npcLine: "You look tired! What did you do last night?",
        npcLineJa: "つかれた かおね！ ゆうべ、なにを したの？",
        choices: ["I study hard.", "I studied until late.", "I am studying.", "I will study."],
        correctIndex: 1,
        onCorrect: "You studied that hard? Good child. But sleep well tonight, my dear.",
      ),
      // 3 — 不規則過去 go→went（最頻出トラップ）。(大問1 文法型)
      QuestEncounter(
        npcName: "ともだち",
        npcEmoji: "🧒",
        npcLine: "I didn't see you on Sunday. Where did you go?",
        npcLineJa: "にちようび、あなたを みなかったよ。どこへ いったの？",
        choices: ["I goed to the zoo.", "I go to the zoo.", "I went to the zoo.", "I am go to the zoo."],
        correctIndex: 2,
        onCorrect: "You went to the zoo! Lucky you. I stayed home and the wind took my words away...",
      ),
      // 4 — 過去疑問 Did + 動詞の原形（応答の整合）。(大問2 会話応答型)
      QuestEncounter(
        npcName: "みせのひと",
        npcEmoji: "🛒",
        npcLine: "Did you buy the bread this morning?",
        npcLineJa: "けさ、パンは かいましたか？",
        choices: ["Yes, I am.", "No, I don't.", "Yes, I do buy.", "No, I didn't. I forgot."],
        correctIndex: 3,
        onCorrect: "You forgot? Ha, no problem. Take this loaf — a traveller must not go hungry.",
      ),
      // 5 — 未来 will。過去→未来へ時制を広げる。(大問1 文法型)
      QuestEncounter(
        npcName: "おじいさん",
        npcEmoji: "👴",
        npcLine: "The sky is dark. I think it ___ rain soon.",
        npcLineJa: "そらが くらい。もうすぐ あめが ___ と おもうよ。",
        choices: ["rained", "will", "is", "rains"],
        correctIndex: 1,
        onCorrect: "Yes, it will rain. Take my umbrella, young traveller. The wind here is unkind.",
      ),
      // 6 — be going to（予定の未来。will との別形トラップ）。(大問1 文法型)
      QuestEncounter(
        npcName: "ともだち",
        npcEmoji: "🧒",
        npcLine: "You have your bag and shoes. What are you going ___ do now?",
        npcLineJa: "かばんと くつを もってるね。これから なにを ___ つもり？",
        choices: ["to", "for", "will", "going"],
        correctIndex: 0,
        onCorrect: "Going TO climb the hill? Then go before the rain! I'll wait for you here.",
      ),
      // 7 — 比較級 -er + than。(大問1 文法型)
      QuestEncounter(
        npcName: "おとこのこ",
        npcEmoji: "👦",
        npcLine: "My brother is tall. But you are ___ than him!",
        npcLineJa: "ぼくの あには せが たかい。でも きみは あにより ___ ！",
        choices: ["tall", "taller", "more tall", "tallest"],
        correctIndex: 1,
        onCorrect: "You ARE taller! When you grow up, will you be a knight? You stand like a prince...",
      ),
      // 8 — 比較級 more + 長い形容詞（-er との使い分けトラップ）。(大問1 文法型)
      QuestEncounter(
        npcName: "がか",
        npcEmoji: "🎨",
        npcLine: "Two paintings here. Which is ___ beautiful, the sea or the sky?",
        npcLineJa: "えが 2まい。うみと そら、どちらが ___ うつくしい？",
        choices: ["beautifuler", "beautiful", "more", "most"],
        correctIndex: 2,
        onCorrect: "The sky is MORE beautiful, you say? A fine eye. Long words take 'more', remember that.",
      ),
      // 9 — 最上級 the -est。(大問1 文法型)
      QuestEncounter(
        npcName: "むらおさ",
        npcEmoji: "🧓",
        npcLine: "This is the ___ tower in our whole town. No tower is higher.",
        npcLineJa: "これは まちで いちばん ___ とう。これより たかい とうは ない。",
        choices: ["high", "higher", "highest", "more high"],
        correctIndex: 2,
        onCorrect: "The highest tower, yes. From the top, they say, you can see your true home.",
      ),
      // 10 — to不定詞（副詞用法・目的）。(大問1 文法型)
      QuestEncounter(
        npcName: "りょうし",
        npcEmoji: "🎣",
        npcLine: "Why are you at the river? Did you come here ___ fish?",
        npcLineJa: "なぜ かわに いるの？ さかなを ___ ために きたの？",
        choices: ["catch", "to catch", "catching", "caught"],
        correctIndex: 1,
        onCorrect: "You came TO catch fish! Sit with me. Patience, traveller — fish and words both take time.",
      ),
      // 11 — 動名詞（enjoy ~ing。to との動詞別パターン・トラップ）。(大問1 文法型)
      QuestEncounter(
        npcName: "おんがくか",
        npcEmoji: "🎻",
        npcLine: "Music came back to this street! Do you enjoy ___ to songs?",
        npcLineJa: "おんがくが まちに もどった！ うたを きくのは すき？（enjoy の あとは？）",
        choices: ["listen", "to listen", "listening", "listened"],
        correctIndex: 2,
        onCorrect: "You enjoy listening! 'Enjoy' always wants ~ing. Here, listen — the town hums again.",
      ),
      // 12 — 接続詞 because（因果の向きトラップ）。(大問2 会話空所型)
      QuestEncounter(
        npcName: "おかあさん",
        npcEmoji: "👩",
        npcLine: "You're wet! Why? — \"I'm wet ___ it rained on the hill.\"",
        npcLineJa: "ぬれてる！ なぜ？ —「おかの うえで あめが ふった ___ ぬれた。」",
        choices: ["so", "but", "because", "and"],
        correctIndex: 2,
        onCorrect: "Wet BECAUSE it rained — yes, that's the reason. Come, dry by the fire, dear one.",
      ),
      // 13 — 接続詞 when / if。(大問1 文法型)
      QuestEncounter(
        npcName: "もんばん",
        npcEmoji: "💂",
        npcLine: "The gate is closed now. ___ the sun rises, I will open it.",
        npcLineJa: "もんは いま しまっている。たいようが のぼった ___、あける。",
        choices: ["When", "Because", "But", "So"],
        correctIndex: 0,
        onCorrect: "When the sun rises — wait until then, friend. The road by night is full of silence.",
      ),
      // 14 — 助動詞 must / should（義務・助言）。(大問2 会話応答型)
      QuestEncounter(
        npcName: "いしゃ",
        npcEmoji: "🩺",
        npcLine: "You have a cough. You ___ rest at home today, not travel.",
        npcLineJa: "せきが でてるね。きょうは たびを せず、いえで ___ 。",
        choices: ["can't", "should", "are", "were"],
        correctIndex: 1,
        onCorrect: "You should rest — listen to me. One day's rest, then the road. Your quest can wait a day.",
      ),
      // 15 — 助動詞 may（許可をたずねる）。(大問2 会話応答型)
      QuestEncounter(
        npcName: "ずしょかん",
        npcEmoji: "📚",
        npcLine: "Welcome to the library. ___ I help you find a book?",
        npcLineJa: "としょかんへ ようこそ。ほんを さがすのを ___ ？（てつだっても いい？）",
        choices: ["Must", "Should", "May", "Do"],
        correctIndex: 2,
        onCorrect: "Of course I may help! Here — an old book about a lost prince. ...It looks like you.",
      ),
      // 16 — There is / There are 単複一致。(大問1 文法型)
      QuestEncounter(
        npcName: "やおやさん",
        npcEmoji: "🧺",
        npcLine: "Look at my shop! ___ many apples on the table today.",
        npcLineJa: "みせを みて！ きょうは テーブルに たくさんの りんごが ___ 。",
        choices: ["There is", "There are", "It is", "They is"],
        correctIndex: 1,
        onCorrect: "There ARE many apples — well counted! Many things need 'are'. Take three for the road.",
      ),
      // 17 — 5W1H 疑問文語順（how long）。(大問2 会話応答型)
      QuestEncounter(
        npcName: "たびのしょうにん",
        npcEmoji: "🧳",
        npcLine: "How long will you stay in our Wind Town?",
        npcLineJa: "この かぜの まちに、どのくらい たいざいしますか？",
        choices: ["I stay here.", "By bus and train.", "Two cities away.", "For about three days."],
        correctIndex: 3,
        onCorrect: "Three days! Then let me sell you a good map. The next town lies beyond the mountains.",
      ),
      // 18 — 語句整序：疑問詞 + 助動詞の語順。(大問3 語句整序型)
      QuestEncounter(
        npcName: "こども",
        npcEmoji: "🧒",
        npcLine: "「あなたは どこで バスに のるつもりですか？」 Choose the correct order.",
        npcLineJa: "ただしい ごじゅんを えらぼう：「あなたは どこで バスに のるつもりですか？」",
        choices: [
          "Where you will catch the bus?",
          "Where will catch you the bus?",
          "Where the bus will you catch?",
          "Where will you catch the bus?",
        ],
        correctIndex: 3,
        onCorrect: "\"Where will you catch the bus?\" — perfect! The stop is by the windmill. Hurry, it comes soon!",
      ),
      // 19 — 長文の代名詞参照・内容一致（4級で初登場の大問4）。(大問4 長文内容一致型)
      QuestEncounter(
        npcName: "ずしょかんのこ",
        npcEmoji: "📖",
        npcLine: "Read this: \"Mika lost her dog. Her brother found it in the park. He was very happy.\" — Who was happy?",
        npcLineJa: "よんでね：「ミカは いぬを なくした。おにいさんが こうえんで みつけた。かれは とても よろこんだ。」 だれが よろこんだ？",
        choices: ["Mika was happy.", "The dog was happy.", "Her brother was happy.", "The park was happy."],
        correctIndex: 2,
        onCorrect: "Her brother — yes! 'He' means the brother. You read carefully. That is a rare gift here.",
      ),
      // 20 — Boss gate. 過去・未来・比較・接続詞の総合 + 魔王サイレント。(大問4＋総合)
      QuestEncounter(
        npcName: "魔王（まおう）サイレントの影（かげ）",
        npcEmoji: "🌑",
        npcLine: "You woke this town with noise. But silence is stronger than words. Why do you fight me?",
        npcLineJa: "おまえは おとで まちを おこした。だが しずけさは ことばより つよい。なぜ わたしと たたかう？",
        choices: [
          "Yesterday I am quiet.",
          "Silence is more strong.",
          "Words are warmer than silence, and I will not stop.",
          "I will fought you tomorrow.",
        ],
        correctIndex: 2,
        onCorrect: "\"Warmer than silence...\" Tch. Your grammar grows sharp, little prince. Take the second stone — five silences remain, and I wait at the last.",
      ),
    ],
  ),
  QuestTown(
    id: 'town_eiken3',
    eikenLevel: '3',
    cefr: 'A2-B1',
    name: '学（まな）びの都（みやこ）',
    tagline: '学校と旅の都',
    intro: '学（まな）びの都（みやこ）。学校（がっこう）や旅（たび）の物語（ものがたり）が語（かた）られる場所（ばしょ）。'
        'けれど、思（おも）い出（で）を語（かた）る言葉（ことば）が、少（すこ）しずつ抜（ぬ）け落（お）ちている。',
    cleared: '人々（ひとびと）が、また自分（じぶん）の物語（ものがたり）を語（かた）り出（だ）した。三（みっ）つ目（め）の〈声（こえ）の石（いし）〉。'
        '吟遊詩人（ぎんゆうしじん）ハーモニーが、とりもどした言葉（ことば）を歌（うた）にして空（そら）へ放（はな）つ。',
    encounters: [
      // 1 — スラ再会。過去形での応答（4級の復習）。手がかり語 last night。(大問2 会話応答型)
      QuestEncounter(
        npcName: "スラ",
        npcEmoji: "🟢",
        npcLine: "We made it to the city! I practiced my words all night. Where did you sleep last night?",
        npcLineJa: "都（みやこ）に着（つ）いたね！ ぼく、ひとばんじゅう言葉（ことば）を練習（れんしゅう）したよ。きのうの夜（よる）はどこで寝（ね）たの？",
        choices: [
          "I sleep at an inn every day.",
          "I slept at a small inn near the gate.",
          "I have slept for a long time.",
          "I am sleeping at the inn now.",
        ],
        correctIndex: 1,
        onCorrect: "An inn by the gate — got it! This is the City of Learning. People here tell their stories... but the stories are fading.",
      ),
      // 2 — 現在完了〈経験〉ever。(大問1 文法型)
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "Welcome, young scholar. ___ you ever read an old legend of this city?",
        npcLineJa: "ようこそ、若（わか）き学徒（がくと）よ。この都（みやこ）の古（ふる）い伝説（でんせつ）を、今（いま）までに読（よ）んだことが ___ ？",
        choices: ["Did", "Have", "Were", "Do"],
        correctIndex: 1,
        onCorrect: "'Have you ever read...' — yes! Experience needs the present perfect. The legend speaks of a lost prince, you know.",
      ),
      // 3 — 現在完了 vs 過去形。ago は過去形の手がかり（頻出トラップ）。(大問1 文法型)
      QuestEncounter(
        npcName: "れきしか",
        npcEmoji: "📜",
        npcLine: "The great library lost its books. It ___ three years ago.",
        npcLineJa: "大（だい）図書館（としょかん）は本（ほん）を失（うしな）った。それは三年（さんねん）前（まえ）に ___ 。 ___ は？",
        choices: ["has happened", "happened", "has been happening", "happens"],
        correctIndex: 1,
        onCorrect: "'happened' — right! 'ago' points to a finished past, never the present perfect. A common trap, well avoided.",
      ),
      // 4 — 現在完了〈継続〉for/since。(大問1 文法型)
      QuestEncounter(
        npcName: "としょかんいん",
        npcEmoji: "📚",
        npcLine: "I have worked in this library ___ ten years, and I won't let its words die.",
        npcLineJa: "わたしはこの図書館（としょかん）で十年（じゅうねん）___ 働（はたら）いてきた。言葉（ことば）を消（き）えさせはしない。 ___ は？",
        choices: ["since", "from", "for", "during"],
        correctIndex: 2,
        onCorrect: "'for ten years' — perfect. 'for' takes a length of time, 'since' takes a starting point. You learn fast.",
      ),
      // 5 — 現在完了〈完了〉already/yet。否定文では yet。(大問1 文法型)
      QuestEncounter(
        npcName: "がくせい",
        npcEmoji: "🧑‍🎓",
        npcLine: "I have to return this book, but I haven't finished it ___.",
        npcLineJa: "この本（ほん）を返（かえ）さなきゃ。でも、まだ読（よ）み終（お）えて ___ んだ。 ___ は？",
        choices: ["already", "yet", "ever", "soon"],
        correctIndex: 1,
        onCorrect: "'haven't finished it yet' — exactly. 'yet' lives in questions and negatives; 'already' lives in positives.",
      ),
      // 6 — 受動態 be + 過去分詞。(大問1 文法型)
      QuestEncounter(
        npcName: "けんちくか",
        npcEmoji: "🏛️",
        npcLine: "Look at this hall. It is very old. It ___ five hundred years ago.",
        npcLineJa: "この広間（ひろま）を見（み）て。とても古（ふる）い。五百年（ごひゃくねん）前（まえ）に ___ んだ。 ___ は？",
        choices: ["built", "was built", "has built", "is building"],
        correctIndex: 1,
        onCorrect: "'was built' — yes! The hall didn't build itself; it WAS built. That's the passive voice.",
      ),
      // 7 — 受動態 by + 動作主。動作主を表す前置詞。(大問1 文法型)
      QuestEncounter(
        npcName: "がか",
        npcEmoji: "🎨",
        npcLine: "This portrait of the royal family was painted ___ a famous artist long ago.",
        npcLineJa: "この王家（おうけ）の肖像画（しょうぞうが）は、むかし有名（ゆうめい）な画家（がか）___ 描（か）かれたものだ。 ___ は？",
        choices: ["from", "with", "by", "of"],
        correctIndex: 2,
        onCorrect: "'painted by a famous artist' — correct! 'by' marks who did the action. ...The child in this painting has your eyes.",
      ),
      // 8 — 不定詞〈名詞用法〉decide / want to + 動詞の原形。(大問1 文法型)
      QuestEncounter(
        npcName: "りょこうしゃ",
        npcEmoji: "🧳",
        npcLine: "I came a long way to study here. I decided ___ history in this city.",
        npcLineJa: "わたしは遠（とお）くからここへ学（まな）びに来（き）た。この都（みやこ）で歴史（れきし）を ___ ことに決（き）めたの。 ___ は？",
        choices: ["studying", "to study", "studied", "study"],
        correctIndex: 1,
        onCorrect: "'decided to study' — yes! 'decide', 'want', 'hope' all take the to-infinitive. Good instinct.",
      ),
      // 9 — 動名詞 vs 不定詞。enjoy は動名詞をとる（動詞別パターンのトラップ）。(大問1 文法型)
      QuestEncounter(
        npcName: "おんがくか",
        npcEmoji: "🎻",
        npcLine: "Music fills these halls again. I really enjoy ___ for the students here.",
        npcLineJa: "音楽（おんがく）がまた広間（ひろま）に満（み）ちる。わたしは学生（がくせい）たちのために ___ のが大好（だいす）きなの。 ___ は？",
        choices: ["to play", "play", "playing", "played"],
        correctIndex: 2,
        onCorrect: "'enjoy playing' — exactly! 'enjoy', 'finish', 'stop' take the ~ing form, not 'to'. That trips up many.",
      ),
      // 10 — 接続詞 that（think (that)…）。(大問2 会話型)
      QuestEncounter(
        npcName: "ともだち",
        npcEmoji: "🧒",
        npcLine: "The teacher gave us hard homework. Do you think we can finish it today?",
        npcLineJa: "先生（せんせい）が難（むずか）しい宿題（しゅくだい）を出（だ）したね。今日中（きょうじゅう）に終（お）わると思（おも）う？",
        choices: [
          "I think that we can do it if we work together.",
          "I think can we do it today.",
          "Homework is given by the teacher.",
          "Yes, the homework is very long and hard.",
        ],
        correctIndex: 0,
        onCorrect: "'I think that we can do it together' — well put! And you're right. Let's help each other.",
      ),
      // 11 — 間接疑問文の語順。I know where he is（疑問文の語順にしない頻出トラップ）。(大問1 文法型)
      QuestEncounter(
        npcName: "もんばん",
        npcEmoji: "💂",
        npcLine: "A traveller is lost in the city. Can you tell me ___?",
        npcLineJa: "旅人（たびびと）が都（みやこ）で迷（まよ）っている。どこにいるか、教（おし）えてもらえるか？ ___ は？",
        choices: [
          "where is the traveller",
          "where the traveller is",
          "where is the traveller now",
          "the traveller where is",
        ],
        correctIndex: 1,
        onCorrect: "'where the traveller is' — perfect! Inside a sentence, the question word order disappears. A real test favourite.",
      ),
      // 12 — 関係代名詞〈主格〉who（人を先行詞に）。(大問1 文法型)
      QuestEncounter(
        npcName: "ハーモニー",
        npcEmoji: "🎶",
        npcLine: "I'm a bard who sings lost words. I'm looking for a hero ___ can bring stories back.",
        npcLineJa: "わたしは失（うしな）われた言葉（ことば）を歌（うた）う吟遊詩人（ぎんゆうしじん）。物語（ものがたり）を取（と）りもどせる英雄（えいゆう）を探（さが）しているの。 ___ は？",
        choices: ["which", "who", "where", "what"],
        correctIndex: 1,
        onCorrect: "'a hero who can bring stories back' — yes! 'who' for people as the subject. ...And here you are, hero.",
      ),
      // 13 — 関係代名詞〈目的格〉which/that（物を先行詞・目的格）。格選択のトラップ。(大問1 文法型)
      QuestEncounter(
        npcName: "としょかんいん",
        npcEmoji: "📚",
        npcLine: "Here is the very book ___ the lost prince once read as a child.",
        npcLineJa: "これこそ、失（うしな）われた王子（おうじ）が幼（おさな）い頃（ころ）に読（よ）んだ、あの本（ほん）です。 ___ は？",
        choices: ["who", "where", "which", "what"],
        correctIndex: 2,
        onCorrect: "'the book which the prince read' — correct! 'which' for things; here it's the object of 'read'. You chose the case well.",
      ),
      // 14 — 比較 as ~ as（同等比較）。(大問1 文法型)
      QuestEncounter(
        npcName: "スポーツせんしゅ",
        npcEmoji: "⚽",
        npcLine: "You run well! But I can run as ___ as the wind, you know.",
        npcLineJa: "きみ、走（はし）るのが上手（じょうず）だね！ でもぼくは風（かぜ）と同（おな）じくらい速（はや）く走（はし）れるんだ。 ___ は？",
        choices: ["faster", "fast", "fastest", "more fast"],
        correctIndex: 1,
        onCorrect: "'as fast as the wind' — right! Between 'as ... as' we keep the plain form, never the comparative.",
      ),
      // 15 — 分詞の形容詞用法（過去分詞が名詞を修飾）。(大問1 文法型)
      QuestEncounter(
        npcName: "けんちくか",
        npcEmoji: "🏛️",
        npcLine: "Be careful near that ___ window — Lord Silentus's shadow passed through it.",
        npcLineJa: "あの ___ 窓（まど）に近（ちか）づくな――魔王（まおう）サイレントの影（かげ）が通（とお）り抜（ぬ）けたのだ。「こわされた窓」。 ___ は？",
        choices: ["breaking", "broke", "broken", "breaks"],
        correctIndex: 2,
        onCorrect: "'broken window' — exactly! A past participle can describe a noun: the window that was broken. Sharp eye.",
      ),
      // 16 — 長文の内容一致。言い換え(paraphrase)が正解、本文語そのままは distractor。(大問3 長文型)
      QuestEncounter(
        npcName: "れきしか",
        npcEmoji: "📜",
        npcLine: "The scroll reads: 'When the prince left the castle, the city's words slowly disappeared.' What does this mean?",
        npcLineJa: "巻物（まきもの）にはこうある――「王子（おうじ）が城（しろ）を去（さ）ったとき、都（みやこ）の言葉（ことば）は少（すこ）しずつ消（き）えていった」。これはどういう意味（いみ）？",
        choices: [
          "The prince disappeared from the castle.",
          "After the prince left, the city gradually began to lose its words.",
          "The words left the castle with the prince.",
          "The city's words appeared slowly in the castle.",
        ],
        correctIndex: 1,
        onCorrect: "Correct — and you chose the paraphrase, not the words copied straight from the text. That's the real reading skill.",
      ),
      // 17 — Eメール返信。相手の「2つの質問に必ず答える」要件。(Writing Eメール型, 2024新設)
      QuestEncounter(
        npcName: "ペンフレンド",
        npcEmoji: "✉️",
        npcLine: "I got your letter! I have two questions: What club are you in, and how often do you practice?",
        npcLineJa: "手紙（てがみ）ありがとう！ 質問（しつもん）が二（ふた）つあるの。何部（なにぶ）に入（はい）っている？ そして、どのくらいの頻度（ひんど）で練習（れんしゅう）するの？",
        choices: [
          "I'm in the art club. Thank you for writing to me!",
          "I'm in the art club, and I practice three times a week.",
          "How often do you practice your club?",
          "Yes, I have a club and I practice it.",
        ],
        correctIndex: 1,
        onCorrect: "Both questions answered — the club AND how often! That's exactly what an email reply must do. Many forget the second one.",
      ),
      // 18 — 意見論述。意見を述べ、理由を添える（理由が必須）。(Writing 意見論述型)
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "Here is today's question: 'Is it good for students to study abroad?' Give me your opinion with a reason.",
        npcLineJa: "今日（きょう）の問題（もんだい）です――「学生（がくせい）が外国（がいこく）で学（まな）ぶのは良（よ）いことか？」 理由（りゆう）をそえて、あなたの意見（いけん）を。",
        choices: [
          "Studying abroad is when you study in another country.",
          "Yes, I think it is good.",
          "I think it is good, because they can learn a new language and meet new people.",
          "Some students study abroad and some study at home.",
        ],
        correctIndex: 2,
        onCorrect: "An opinion AND a clear reason — that's the heart of the essay task. Without a reason, an opinion scores nothing.",
      ),
      // 19 — 二次面接 イラスト描写。今まさに起きている動作は現在進行形。(Speaking 二次・イラスト描写型)
      QuestEncounter(
        npcName: "めんせつかん",
        npcEmoji: "🎓",
        npcLine: "Now, please look at the picture and tell me: what is the boy doing?",
        npcLineJa: "では、絵（え）を見（み）て答（こた）えてください――男（おとこ）の子（こ）は何（なに）をしていますか？",
        choices: [
          "The boy is reading a book under a tree.",
          "The boy reads a book every day.",
          "The boy read a book under a tree.",
          "The boy will read a book under a tree.",
        ],
        correctIndex: 0,
        onCorrect: "'The boy is reading' — perfect! In the interview, describe a picture with the present continuous: what's happening right now.",
      ),
      // 20 — Boss gate。完了・関係詞・意見の総合運用 + 魔王サイレント。(大問総合)
      QuestEncounter(
        npcName: "魔王（まおう）サイレントの影（かげ）",
        npcEmoji: "🌑",
        npcLine: "You have grown, little prince. Tell me — why do you fight for words that have only ever brought pain?",
        npcLineJa: "大（おお）きくなったな、小（ちい）さな王子（おうじ）よ。言（い）え――ただ苦（くる）しみだけをもたらしてきた言葉（ことば）のために、なぜ戦（たたか）う？",
        choices: [
          "Words have brought pain since long ago.",
          "Because words, which we have shared since we were born, are how we understand each other.",
          "I fight because to win the stones is good.",
          "Words are which people speak and write.",
        ],
        correctIndex: 1,
        onCorrect: "...A relative clause, a present perfect, a reason — and a truth I cannot answer. The third stone is yours, prince. But the harder roads still lie ahead... and I will be waiting.",
      ),
    ],
  ),
  QuestTown(
    id: 'town_pre2',
    eikenLevel: 'pre2',
    cefr: 'B1',
    name: '社会（しゃかい）の港町（みなとまち）',
    tagline: '世の中を語る港町',
    intro: '社会（しゃかい）の港町（みなとまち）。世（よ）の中（なか）を語（かた）り合（あ）う場所（ばしょ）。'
        'ここで、魔王（まおう）の手（て）の者（もの）クワイエトが、人々（ひとびと）から「意見（いけん）」そのものを奪（うば）おうとしている。',
    cleared: '港町（みなとまち）の人々（ひとびと）が、また「自分（じぶん）はこう思（おも）う」と言（い）えるようになった。四（よっ）つ目（め）の〈声（こえ）の石（いし）〉。'
        'クワイエトは去（さ）りぎわ、ふり返（かえ）った――「…おまえの言葉（ことば）は、なぜ消（き）えない？」 遠（とお）くで魔王（まおう）サイレントの影（かげ）がうごめく。',
    encounters: [
      // 1 — 大問1 短文空所補充: past tense + because (3級→準2級 bridge review)
      QuestEncounter(
        npcName: "ハーモニー",
        npcEmoji: "🎶",
        npcLine:
            "I'm a bard. I came here last week because the town had lost its voice. Why did you come?",
        npcLineJa:
            "私（わたし）は吟遊詩人（ぎんゆうしじん）。町（まち）が声（こえ）を失（うしな）ったから、先週（せんしゅう）来（き）たの。あなたは、なぜ来（き）たの？",
        choices: [
          "I come because the town is losing words now.",
          "Because I am searching for the Stones of Voice every day.",
          "I came because the people here needed their words back.",
          "I will come because words are important to everyone.",
        ],
        correctIndex: 2,
        onCorrect:
            "Then our songs share one purpose. I'll travel beside you, hero.",
      ),
      // 2 — 大問1 短文空所補充: present perfect 継続 vs past (since/for cue)
      QuestEncounter(
        npcName: "りょうし",
        npcEmoji: "🎣",
        npcLine:
            "I have lived by this harbour for thirty years. How long have you been a traveller?",
        npcLineJa:
            "わしはこの港（みなと）で三十年（さんじゅうねん）暮（く）らしてきた。おまえは、どれくらい旅（たび）をしているのだ？",
        choices: [
          "I have travelled since I was a child.",
          "I travelled for many years ago.",
          "I am a traveller last spring.",
          "I have been a traveller yesterday.",
        ],
        correctIndex: 0,
        onCorrect:
            "Since childhood — a long road indeed. The sea respects a patient soul.",
      ),
      // 3 — 大問1 短文空所補充: passive voice (be + past participle)
      QuestEncounter(
        npcName: "しょうにん",
        npcEmoji: "🛍️",
        npcLine:
            "These spices come from far away. Do you know where they are grown?",
        npcLineJa:
            "この香辛料（こうしんりょう）は遠（とお）くから来（く）る。どこで育（そだ）てられているか知（し）っているか？",
        choices: [
          "Yes, people grow them in the south.",
          "They are grown on islands in the warm south.",
          "Yes, the south grows them every year.",
          "They grow on islands by the farmers there.",
        ],
        correctIndex: 1,
        onCorrect:
            "Correct! Few travellers know that. You have a merchant's sharp eye.",
      ),
      // 4 — 大問1 短文空所補充: relative pronoun (subject who/which)
      QuestEncounter(
        npcName: "せんちょう",
        npcEmoji: "⚓",
        npcLine:
            "A captain needs a crew he can trust. What kind of sailor do you respect?",
        npcLineJa:
            "船長（せんちょう）には信（しん）じられる仲間（なかま）がいる。おまえは、どんな船乗（ふなの）りを尊敬（そんけい）する？",
        choices: [
          "A sailor what never leaves a friend behind.",
          "A sailor who he works hard in every storm.",
          "A sailor which keeps calm in danger.",
          "A sailor who never gives up in a storm.",
        ],
        correctIndex: 3,
        onCorrect:
            "Spoken like one of us. Such sailors are rare — and so are travellers like you.",
      ),
      // 5 — 大問1 短文空所補充: relative adverb (where) vs relative pronoun
      QuestEncounter(
        npcName: "とうだいもり",
        npcEmoji: "🗼",
        npcLine:
            "This is the lighthouse. Can you describe the place ships feel safe again?",
        npcLineJa:
            "ここが灯台（とうだい）だ。船（ふね）がふたたび安心（あんしん）できる場所（ばしょ）を、言（い）い表（あらわ）せるか？",
        choices: [
          "It is the harbour where the storms cannot reach them.",
          "It is the harbour which the storms cannot reach there.",
          "It is the harbour when ships come home safely.",
          "It is the harbour who keeps the ships safe.",
        ],
        correctIndex: 0,
        onCorrect:
            "Beautifully said. My light and your words guide the lost the same way.",
      ),
      // 6 — 大問2A 会話文空所補充: indirect question word order
      QuestEncounter(
        npcName: "やどのしゅじん",
        npcEmoji: "🛎️",
        npcLine:
            "A guest asked about the festival, but I couldn't answer. Do you know ( )?",
        npcLineJa:
            "お客（きゃく）さんがお祭（まつ）りのことを聞（き）いたが、答（こた）えられなかった。（　）を知（し）っているか？",
        choices: [
          "when does the festival begin",
          "when the festival begins",
          "when begins the festival",
          "when is the festival begin",
        ],
        correctIndex: 1,
        onCorrect:
            "Of course — 'when the festival begins.' Now I can answer my guests. Thank you!",
      ),
      // 7 — 大問1 短文空所補充: past perfect (had + p.p.)
      QuestEncounter(
        npcName: "おいたしょうにん",
        npcEmoji: "🧓",
        npcLine:
            "When the silence reached us, what had the town been like before?",
        npcLineJa:
            "しずけさが来（き）たとき、その前（まえ）の町（まち）はどんなふうだった？",
        choices: [
          "The town has been full of laughter before.",
          "The town is loud before the silence comes.",
          "The town had been full of music before the silence came.",
          "The town will be quiet after the silence came.",
        ],
        correctIndex: 2,
        onCorrect:
            "Yes... it had been full of music. You speak of the past as if you saw it.",
      ),
      // 8 — 大問2B 長文語句空所補充: logical connective however/therefore
      QuestEncounter(
        npcName: "きょうしのおんな",
        npcEmoji: "👩‍🏫",
        npcLine:
            "I tell my students reading is hard. ( ), it opens every door in the world.",
        npcLineJa:
            "生徒（せいと）たちに、読（よ）むことは大変（たいへん）だと言（い）う。（　）、それは世界（せかい）のすべての扉（とびら）を開（ひら）くの。",
        choices: [
          "For example",
          "However",
          "Because",
          "After that",
        ],
        correctIndex: 1,
        onCorrect:
            "'However' — the perfect turn. You understand how ideas push against each other.",
      ),
      // 9 — 大問2B 長文語句空所補充: logical connective for example/because
      QuestEncounter(
        npcName: "しんぶんうり",
        npcEmoji: "📰",
        npcLine:
            "News brings a town together. ( ), people share their worries at the market.",
        npcLineJa:
            "知（し）らせは町（まち）を一（ひと）つにする。（　）、人々（ひとびと）は市場（いちば）で心配事（しんぱいごと）を分（わ）かち合（あ）う。",
        choices: [
          "However",
          "For example",
          "Therefore",
          "Although",
        ],
        correctIndex: 1,
        onCorrect:
            "'For example' — exactly. A clear case makes any idea easier to trust.",
      ),
      // 10 — 大問1 短文空所補充: causative/perception verb + base form
      QuestEncounter(
        npcName: "がくしゃ",
        npcEmoji: "🧑‍🔬",
        npcLine:
            "I study how voices return. Yesterday I saw something strange. What did it do?",
        npcLineJa:
            "声（こえ）がどう戻（もど）るかを研究（けんきゅう）している。きのう、ふしぎなものを見（み）た。それは何（なに）をした？",
        choices: [
          "It made the children to sing again.",
          "I saw the children sang in the square.",
          "It let the children singing all day.",
          "It made the children sing in the square again.",
        ],
        correctIndex: 3,
        onCorrect:
            "'Made the children sing' — flawless. The cure may be language itself.",
      ),
      // 11 — 大問1 短文空所補充: infinitive with meaning-subject (for + person to V)
      QuestEncounter(
        npcName: "わかいしょくにん",
        npcEmoji: "🪚",
        npcLine:
            "I'm building a stage for the festival. Is the wood strong enough?",
        npcLineJa:
            "お祭（まつ）りのために舞台（ぶたい）を作（つく）っている。この木（き）は十分（じゅうぶん）じょうぶか？",
        choices: [
          "Yes, it is strong enough for the dancers to stand on.",
          "Yes, it is strong enough for the dancers stand on.",
          "Yes, it is strong enough of the dancers to stand on.",
          "Yes, it is enough strong for the dancers to stand.",
        ],
        correctIndex: 0,
        onCorrect:
            "'For the dancers to stand on' — perfect. The festival will be safe, thanks to you.",
      ),
      // 12 — 大問1 短文空所補充: subjunctive past (If I were…)
      QuestEncounter(
        npcName: "ゆめみるこども",
        npcEmoji: "🧒",
        npcLine:
            "If you could be anything, what would you be? I'd be a captain!",
        npcLineJa:
            "もし何（なに）にでもなれるなら、何（なに）になりたい？ ぼくは船長（せんちょう）！",
        choices: [
          "If I was a bird, I will fly over the sea.",
          "If I am a bird, I would fly over the sea.",
          "If I were a bird, I would fly over the whole sea.",
          "If I were a bird, I will fly over the sea.",
        ],
        correctIndex: 2,
        onCorrect:
            "'If I were a bird'! Even grown-ups forget that one. You'd make a fine captain too.",
      ),
      // 13 — 面接 イラスト描写: present continuous (picture description)
      QuestEncounter(
        npcName: "がか",
        npcEmoji: "🎨",
        npcLine:
            "Look at my painting of the harbour. Tell me what the people are doing.",
        npcLineJa:
            "港（みなと）の絵（え）を見（み）て。人々（ひとびと）が何（なに）をしているか、言（い）ってみて。",
        choices: [
          "A woman sells fish, and a boy ran to the boat.",
          "A woman is selling fish, and a boy is running to the boat.",
          "A woman sold fish while a boy is running there.",
          "A woman is sell fish, and a boy run to the boat.",
        ],
        correctIndex: 1,
        onCorrect:
            "Yes — 'is selling,' 'is running'! You see the moment alive. That is a true eye.",
      ),
      // 14 — Writing Eメール: appropriate opening (書き出し要件)
      QuestEncounter(
        npcName: "ゆうびんやさん",
        npcEmoji: "📮",
        npcLine:
            "A friend sent you an email about a school trip. How should your reply begin?",
        npcLineJa:
            "友（とも）だちが学校（がっこう）の遠足（えんそく）についてメールをくれた。返事（へんじ）は、どう書（か）き始（はじ）める？",
        choices: [
          "Goodbye for now, see you soon.",
          "Here are my two answers to you.",
          "Thank you for your email. I'm glad to hear about your school trip.",
          "Dear sir or madam, I am writing to complain.",
        ],
        correctIndex: 2,
        onCorrect:
            "A warm, polite opening — exactly right for a friend. Now the reader feels welcome.",
      ),
      // 15 — Writing Eメール: answer the TWO questions (2つの質問要件)
      QuestEncounter(
        npcName: "ゆうびんやさん",
        npcEmoji: "📮",
        npcLine:
            "Your friend asked two things: where the trip is, and what to bring. What must your email do?",
        npcLineJa:
            "友（とも）だちは二（ふた）つたずねた――どこへ行（い）くか、何（なに）を持（も）っていくか。メールは何（なに）をしなければならない？",
        choices: [
          "Answer only the question I find most interesting.",
          "Answer both questions: where the trip is and what to bring.",
          "Ask my friend two new questions instead.",
          "Write about my own holiday plans instead.",
        ],
        correctIndex: 1,
        onCorrect:
            "Both questions — never miss one! That is the rule graders check first.",
      ),
      // 16 — Writing Eメール: appropriate closing (結びの定型)
      QuestEncounter(
        npcName: "ゆうびんやさん",
        npcEmoji: "📮",
        npcLine:
            "You've answered everything. How should you close the email politely?",
        npcLineJa:
            "ぜんぶ答（こた）えた。メールは、どうていねいに結（むす）ぶ？",
        choices: [
          "That's all I have to say, the end.",
          "Please answer me right now, it's urgent.",
          "I have no more time, sorry about that.",
          "I hope you have a great trip. Write back soon!",
        ],
        correctIndex: 3,
        onCorrect:
            "A kind, natural closing. Your email is complete — opening, two answers, and ending. Perfect form!",
      ),
      // 17 — Writing 意見論述: state opinion + give two reasons (理由2つ展開)
      QuestEncounter(
        npcName: "ろうじんのけんじゃ",
        npcEmoji: "🧙",
        npcLine:
            "Some say children should help with town work. What do you think, and why?",
        npcLineJa:
            "子（こ）どもも町（まち）の仕事（しごと）を手伝（てつだ）うべきだ、と言（い）う者（もの）がいる。おまえはどう思（おも）い、それはなぜか？",
        choices: [
          "I think it is good. It is good because it is good for everyone.",
          "Children should help. First, they learn useful skills. Second, the town grows closer together.",
          "Maybe yes, maybe no. I am not really sure about it.",
          "I think children are young, and the town is by the sea.",
        ],
        correctIndex: 1,
        onCorrect:
            "A clear opinion and two solid reasons. That is how a strong argument stands.",
      ),
      // 18 — 大問3 長文内容一致 (BOSS): paraphrase-correct vs same-word trap
      QuestEncounter(
        npcName: "クワイエト",
        npcEmoji: "🌑",
        npcLine:
            "I serve Lord Silentus. He believes a world without words has no lies and no quarrels — that silence is peace. After all you've heard in this town, what do you say to that?",
        npcLineJa:
            "私（わたし）は魔王（まおう）サイレントに仕（つか）える者（もの）。彼（かれ）は、言葉（ことば）なき世界（せかい）には嘘（うそ）も争（あらそ）いもない――しずけさこそ平和（へいわ）だと信（しん）じる。この町（まち）で聞（き）いたすべてのあと、それに何（なに）と答（こた）える？",
        choices: [
          "A silent world has no lies and no quarrels at all.",
          "Yes, silence is peace, just as Lord Silentus believes.",
          "Without shared words, people can never understand one another or show that they care.",
          "Lord Silentus serves a world that is peaceful and quiet.",
        ],
        correctIndex: 2,
        onCorrect:
            "...That was not the line you were told. You found your own words — and they will not leave my mind. This isn't over, traveller. We meet again at the King's City.",
      ),
    ],
  ),
  QuestTown(
    id: 'town_pre2plus',
    eikenLevel: 'pre2plus',
    cefr: 'A2-B1',
    name: '試練（しれん）の橋（はし）',
    tagline: '2級への橋をわたる町',
    intro: '準2級（じゅんにきゅう）の先（さき）、2級（にきゅう）へつづく長（なが）い橋（はし）。'
        '2025年（ねん）に新（あら）たにかけられた橋（はし）だ。ここでは「理由（りゆう）」と「まとめ（要約・ようやく）」を語（かた）る力（ちから）がためされる。',
    cleared: '橋（はし）の向（む）こうに、城（しろ）の灯（あか）りが見（み）えた。五（いつ）つ目（め）の〈声（こえ）の石（いし）〉を手（て）に。'
        'ハーモニーが言（い）う――「のこる石（いし）はあと一（ひと）つ。王都（おうと）に、魔王（まおう）がいる」。',
    encounters: [
      // 1 — 準2確実化: 現在完了 vs 過去 (since の手がかり). (大問1 文法型)
      QuestEncounter(
        npcName: "はしの番人",
        npcEmoji: "🌉",
        npcLine: "I ___ on this bridge since the new grade was added in 2025. Show me your purpose.",
        npcLineJa: "2025年（ねん）に新（あら）しい級（きゅう）ができてから、ずっとこの橋（はし）にいます。 ___ に入（はい）るのは？",
        choices: ["work", "have worked", "worked", "am working"],
        correctIndex: 1,
        onCorrect: "Yes — \"have worked ... since 2025.\" A keeper of the bridge knows his tenses. Step on.",
      ),
      // 2 — 関係副詞 where (vs 関係代名詞). (大問1 文法型)
      QuestEncounter(
        npcName: "渡し守",
        npcEmoji: "⛵",
        npcLine: "This is the place ___ many travellers turn back. Will you go on?",
        npcLineJa: "ここは、多（おお）くの旅人（たびびと）が引（ひ）き返（かえ）す場所（ばしょ）です。 ___ に入（はい）るのは？",
        choices: ["which", "who", "where", "what"],
        correctIndex: 2,
        onCorrect: "\"The place WHERE...\" — you chose the relative adverb, not the pronoun. Few get that right. Cross on.",
      ),
      // 3 — 使役動詞 make + 原形不定詞. (大問1 文法型)
      QuestEncounter(
        npcName: "橋守の弟子",
        npcEmoji: "🛠️",
        npcLine: "The strong wind here can make a traveller ___ their balance. Stay alert.",
        npcLineJa: "ここの強風（きょうふう）は、旅人（たびびと）にバランスを ___ ことがあります。",
        choices: ["to lose", "lose", "lost", "losing"],
        correctIndex: 1,
        onCorrect: "\"Make ... LOSE\" — a bare infinitive after make. Good. The wind won't fool you.",
      ),
      // 4 — 句動詞 carry on (高頻度・社会語彙の入口). (大問1 語彙型)
      QuestEncounter(
        npcName: "旅の楽師",
        npcEmoji: "🎻",
        npcLine: "Even when the road got hard, I decided to ___ and never quit. What kept me going was music.",
        npcLineJa: "道（みち）がつらくなっても、 ___ ことに決（き）めました。やめなかったのです。",
        choices: ["carry on", "carry out", "carry away", "carry off"],
        correctIndex: 0,
        onCorrect: "\"Carry ON\" — to continue. The phrasal verbs are sneaky here, but you knew it. Play on, traveller!",
      ),
      // 5 — 接続副詞 however (逆接の論理). (大問1 語彙/論理型)
      QuestEncounter(
        npcName: "学びの巡礼者",
        npcEmoji: "🧳",
        npcLine: "I studied hard for years. ___, I still find this bridge difficult. Which word fits my meaning?",
        npcLineJa: "何年（なんねん）も勉強（べんきょう）しました。 ___ 、それでもこの橋（はし）は難（むずか）しい。意味（いみ）に合（あ）う語（ご）は？",
        choices: ["Therefore", "However", "For example", "Because"],
        correctIndex: 1,
        onCorrect: "\"However\" — you read the contrast, not just the words. That logic-sense is exactly what 2級 rewards.",
      ),
      // 6 — 仮定法過去 If I were (人称無視の罠). (大問1 文法型)
      QuestEncounter(
        npcName: "迷いの精霊",
        npcEmoji: "🧚",
        npcLine: "If I ___ you, I would cross before nightfall. The fog grows thicker after dark.",
        npcLineJa: "もし私（わたし）があなた ___ 、日（ひ）が暮（く）れる前（まえ）に渡（わた）るでしょう。",
        choices: ["am", "was", "were", "be"],
        correctIndex: 2,
        onCorrect: "\"If I WERE you\" — subjunctive 'were' for every person. You didn't fall for 'was.' Hurry on!",
      ),
      // 7 — 仮定法過去完了 If I had + p.p. (帰結節 would have). (大問1 文法型)
      QuestEncounter(
        npcName: "老いた旅人",
        npcEmoji: "🧓",
        npcLine: "If I had trained harder in my youth, I ___ this bridge years ago. Learn from my regret.",
        npcLineJa: "若（わか）いころもっと鍛（きた）えていたら、何年（なんねん）も前（まえ）にこの橋（はし）を ___ のに。",
        choices: ["would cross", "will have crossed", "would have crossed", "had crossed"],
        correctIndex: 2,
        onCorrect: "\"Would HAVE crossed\" — past unreal needs 'would have + p.p.' Wise. Don't repeat my mistake.",
      ),
      // 8 — 分詞構文 (主語一致・態). (大問1 文法型)
      QuestEncounter(
        npcName: "見張りの兵",
        npcEmoji: "💂",
        npcLine: "___ from the tower, the whole valley looks small. Come, see it with me.",
        npcLineJa: "塔（とう）から ___ と、谷（たに）ぜんたいが小（ちい）さく見（み）えます。",
        choices: ["Seen", "Seeing", "To see", "See"],
        correctIndex: 1,
        onCorrect: "\"Seeing ...\" — the participle shares the subject 'you' who looks. Clean. The view is yours.",
      ),
      // 9 — 強調構文 It is ~ that (形式主語との区別). (大問1 文法型)
      QuestEncounter(
        npcName: "橋の詩人",
        npcEmoji: "📜",
        npcLine: "It ___ courage, not speed, that carries a traveller across. Which word completes my verse?",
        npcLineJa: "旅人（たびびと）を渡（わた）らせるのは速（はや）さではなく、勇気（ゆうき） ___ のです。",
        choices: ["is", "has", "does", "was being"],
        correctIndex: 0,
        onCorrect: "\"It IS courage ... that...\" — a cleft sentence for emphasis. Beautifully done. The bridge listens.",
      ),
      // 10 — 関係詞 非制限用法 (, which). (大問1 文法型)
      QuestEncounter(
        npcName: "地図学者",
        npcEmoji: "🗺️",
        npcLine: "This bridge, ___ was built in 2025, links two great grades. Note it on your map.",
        npcLineJa: "この橋（はし）は、2025年（ねん）にかけられ、二（ふた）つの大（おお）きな級（きゅう）をつなぎます。 ___ に入（はい）るのは？",
        choices: ["that", "which", "where", "what"],
        correctIndex: 1,
        onCorrect: "\"...,WHICH was built...\" — non-defining clauses take 'which,' never 'that.' Precise. Mapped!",
      ),
      // 11 — 長文の語句空所: nevertheless (逆接マーカー). (大問2 長文語句空所型)
      QuestEncounter(
        npcName: "記録係",
        npcEmoji: "✍️",
        npcLine: "My notes read: 'The repairs cost a fortune. ___, the bridge still cracks.' Choose the linker.",
        npcLineJa: "私（わたし）のメモ――「修理（しゅうり）は大金（たいきん）がかかった。 ___ 、橋（はし）はまだひび割（わ）れる。」",
        choices: ["As a result", "Nevertheless", "In addition", "For instance"],
        correctIndex: 1,
        onCorrect: "\"Nevertheless\" — money spent, yet still cracking: a contrast. Your discourse-sense is ready for 2級.",
      ),
      // 12 — 長文の語句空所: as a result (因果 vs 追加). (大問2 長文語句空所型)
      QuestEncounter(
        npcName: "橋の技師",
        npcEmoji: "⚙️",
        npcLine: "We added steel supports last spring. ___, the bridge has not shaken once since. Which fits?",
        npcLineJa: "去年（きょねん）の春（はる）、鋼鉄（こうてつ）の支柱（しちゅう）を足（た）しました。 ___ 、それ以来（いらい）一度（いちど）も揺（ゆ）れていません。",
        choices: ["As a result", "However", "In addition", "On the other hand"],
        correctIndex: 0,
        onCorrect: "\"As a result\" — support added, so it stopped shaking: cause and effect, not mere addition. Sharp!",
      ),
      // 13 — 長文の語句空所: 社会的話題語彙 (environment). (大問2 語彙型)
      QuestEncounter(
        npcName: "自然観察員",
        npcEmoji: "🌿",
        npcLine: "We built this bridge from local stone to protect the river ___. Pick the word my report needs.",
        npcLineJa: "川（かわ）の ___ を守（まも）るため、地元（じもと）の石（いし）で橋（はし）を作（つく）りました。",
        choices: ["entrance", "environment", "experiment", "entertainment"],
        correctIndex: 1,
        onCorrect: "\"Environment\" — the social-topic vocabulary 2級 leans on. You picked it from look-alikes. Well read!",
      ),
      // 14 — 長文内容一致: 言い換え正解 vs 本文語そのまま distractor. (大問3 内容一致型)
      QuestEncounter(
        npcName: "案内人ハーモニー",
        npcEmoji: "🎼",
        npcLine: "My sign says: 'The bridge is closed on rainy days because the stone becomes slippery.' What does it mean?",
        npcLineJa: "看板（かんばん）――「石（いし）がすべりやすくなるので、雨（あめ）の日（ひ）は橋（はし）を閉（と）じます。」どういう意味（いみ）？",
        choices: ["You cannot cross when it rains, for safety.", "The stone is slippery on every day.", "The bridge is closed because it is rainy and slippery and stone.", "The bridge becomes slippery so people like rainy days."],
        correctIndex: 0,
        onCorrect: "Right — the paraphrase, not the words copied straight from the sign. That's how 内容一致 traps work. Pass!",
      ),
      // 15 — 長文内容一致: 推論 (明示されない結論). (大問3 内容一致型)
      QuestEncounter(
        npcName: "茶屋の主人",
        npcEmoji: "🍵",
        npcLine: "My note: 'More travellers stop here than a year ago, yet I sell less tea.' What can we infer?",
        npcLineJa: "メモ――「一年前（いちねんまえ）より立（た）ち寄（よ）る旅人（たびびと）は増（ふ）えたのに、お茶（ちゃ）は売（う）れない。」何（なに）が分（わ）かる？",
        choices: ["Travellers now buy something other than tea here.", "Nobody stops at the tea house anymore.", "The owner sells more tea than last year.", "Travellers dislike the tea house this year."],
        correctIndex: 0,
        onCorrect: "Exactly — more visitors but less tea means they buy other things. You inferred what wasn't stated. Brilliant!",
      ),
      // 16 — Writing 要約: 本文情報のみ (意見・例を入れない). (要約型)
      QuestEncounter(
        npcName: "写本の魔導士",
        npcEmoji: "🪄",
        npcLine: "Summarise this: 'The bridge was rebuilt in 2025. It is stronger, but the toll is higher.' Best summary?",
        npcLineJa: "要約（ようやく）しなさい――「橋（はし）は2025年（ねん）に建（た）て直（なお）された。丈夫（じょうぶ）になったが、通行料（つうこうりょう）は高（たか）くなった。」最（もっと）も良（よ）い要約（ようやく）は？",
        choices: ["The new 2025 bridge is stronger but costs more to cross.", "I think the bridge is too expensive and unfair.", "The bridge is great and everyone should visit it someday.", "Bridges in 2025 are the best bridges ever built by people."],
        correctIndex: 0,
        onCorrect: "Yes — only the text's facts, no opinion, no extra praise. That restraint is what 要約 demands. Inscribed!",
      ),
      // 17 — Writing 要約: パラフレーズ (本文丸写しを避ける). (要約型)
      QuestEncounter(
        npcName: "言いかえの賢者",
        npcEmoji: "📖",
        npcLine: "The text: 'Many people use the bridge daily to reach their jobs.' Summarise it in your OWN words.",
        npcLineJa: "本文（ほんぶん）――「多（おお）くの人（ひと）が仕事（しごと）に行（い）くため、毎日（まいにち）この橋（はし）を使（つか）う。」自分（じぶん）のことばで言（い）いかえると？",
        choices: ["Many people use the bridge daily to reach their jobs.", "The bridge is a daily route to work for many commuters.", "I love using this bridge to go to my own job every day.", "People reach their jobs and use the bridge daily many people."],
        correctIndex: 1,
        onCorrect: "\"A daily route to work for commuters\" — same idea, fresh words. Paraphrase, not copy. That's 2級-level writing!",
      ),
      // 18 — Writing 意見論述: 理由を2つ展開 (構成). (意見論述型)
      QuestEncounter(
        npcName: "問いかける守人",
        npcEmoji: "🗝️",
        npcLine: "Should students learn a second language? Give the answer that states an opinion AND two reasons.",
        npcLineJa: "生徒（せいと）は第二言語（だいにげんご）を学（まな）ぶべき？ 意見（いけん）と理由（りゆう）二（ふた）つを述（の）べた答（こた）えは？",
        choices: ["Yes. It opens jobs abroad, and it helps people understand other cultures.", "Yes, because languages are good and also nice to learn.", "I think maybe yes or no, it depends on the person really.", "Languages are spoken in many countries around the whole world."],
        correctIndex: 0,
        onCorrect: "A clear opinion with TWO distinct reasons — jobs and culture. That structure scores on 意見論述. The gate opens!",
      ),
      // 19 — 面接 3コマ展開: 物語化・時制の一貫 (過去で語る). (二次 3コマ説明型)
      QuestEncounter(
        npcName: "絵巻の番人",
        npcEmoji: "🖼️",
        npcLine: "Tell my three-panel tale in order: first a girl saw a broken plank, then... How does panel two go?",
        npcLineJa: "三（み）コマの話（はなし）を順（じゅん）に語（かた）って。まず女（おんな）の子（こ）が壊（こわ）れた板（いた）を見（み）て、それから…二（ふた）コマ目（め）は？",
        choices: ["She fixed it, so travellers could cross safely again.", "She is fixing it now and travellers cross safely.", "Fix the plank and then the people can cross it.", "A plank is a flat piece of wood used in bridges."],
        correctIndex: 0,
        onCorrect: "\"She FIXED it, so...\" — past tense kept consistent, and the story moves forward. That's how 3コマ narration works!",
      ),
      // 20 — ボス: 仮定法 + 逆接マーカー + 理由展開の統合 (魔王の手先). (統合・意見論述型)
      QuestEncounter(
        npcName: "橋の影 (サイレントの手先)",
        npcEmoji: "🌑",
        npcLine: "If words truly mattered, you would have crossed already. Nevertheless you hesitate — so WHY cross at all?",
        npcLineJa: "ことばに本当（ほんとう）に意味（いみ）があるなら、もう渡（わた）り終（お）えていたはず。それでも迷（まよ）う――なぜ渡（わた）る？",
        choices: ["Words DO matter; even if I stumble, I cross to bring the world's voice back, and to prove I belong.", "If words mattered, the bridge would be crossed by me already long.", "I hesitate because the bridge is high and the wind is very strong today.", "Nevertheless is a word that shows a contrast between two ideas."],
        correctIndex: 0,
        onCorrect: "The shadow recoils — your reply held an opinion, two reasons, and never broke under its trap. The bridge's voice returns!",
      ),
    ],
  ),
  QuestTown(
    id: 'town_eiken2',
    eikenLevel: '2',
    cefr: 'B1-B2',
    name: '学者（がくしゃ）の城下町（じょうかまち）',
    tagline: '学問とビジネスの町',
    intro: '学者（がくしゃ）の城下町（じょうかまち）。学問（がくもん）とビジネスの言葉（ことば）が交（か）わされる町（まち）。'
        'ここまで来（こ）られる勇者（ゆうしゃ）は少（すく）ない。最後（さいご）の〈声（こえ）の石（いし）〉が、城（しろ）の奥（おく）に眠（ねむ）る。',
    cleared: '六（むっ）つ目（め）――最後（さいご）の〈声（こえ）の石（いし）〉がそろった！ むねの石（いし）と合（あ）わせ、〈ことばの紋章（もんしょう）〉が完成（かんせい）する。'
        'それは、あなたが王家（おうけ）の血（ち）をひく真（しん）の証（あかし）。王都（おうと）の門（もん）が、ひとりでに開（ひら）いた。',
    encounters: [
      // 1 — Academic-register appropriate response. (大問1会話/Listening応答型)
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "I've been teaching here for ten years, though the number of students keeps declining.",
        npcLineJa: "10年間（ねんかん）ここで教（おし）えています。でも生徒（せいと）の数（かず）はずっと減（へ）り続（つづ）けているのです。",
        choices: ["Yes, I like cats very much.", "I don't have any money, sorry.", "That must be quite challenging for you.", "The weather is nice today, isn't it?"],
        correctIndex: 2,
        onCorrect: "Exactly — but I still love teaching. Thank you for understanding.",
      ),
      // 2 — 現在完了の継続用法 (since が手がかり; 過去形distractorが罠). (大問1 文法空所型)
      QuestEncounter(
        npcName: "しょうにん",
        npcEmoji: "🧑‍💼",
        npcLine: "Trade in this town ___ slow ever since the new tax was introduced last spring.",
        npcLineJa: "この町（まち）の商売（しょうばい）は、去年（きょねん）の春（はる）に新（あたら）しい税（ぜい）が導入（どうにゅう）されて以来（いらい）、ずっと不振（ふしん）です。",
        choices: ["has been", "was", "is being", "will be"],
        correctIndex: 0,
        onCorrect: "Right — 'has been', because 'ever since' means it continues to now. You know your grammar.",
      ),
      // 3 — 受動態 (be + 過去分詞). (大問1 文法空所型)
      QuestEncounter(
        npcName: "やくにん",
        npcEmoji: "🧑‍⚖️",
        npcLine: "The new library ___ by the city council two years ago and is now open to all.",
        npcLineJa: "新（あたら）しい図書館（としょかん）は2年前（ねんまえ）に市議会（しぎかい）によって建（た）てられ、今（いま）はだれでも利用（りよう）できます。",
        choices: ["built", "has built", "was building", "was built"],
        correctIndex: 3,
        onCorrect: "Yes — 'was built'. The library received the action, so we need the passive. Well done.",
      ),
      // 4 — 関係代名詞 主格 (人=who). (大問1 文法空所型)
      QuestEncounter(
        npcName: "がくせい",
        npcEmoji: "🧑‍🎓",
        npcLine: "The professor ___ wrote this book is giving a lecture in the castle hall tonight.",
        npcLineJa: "この本（ほん）を書（か）いた教授（きょうじゅ）が、今夜（こんや）お城（しろ）の大広間（おおひろま）で講義（こうぎ）をします。",
        choices: ["which", "who", "whose", "whom"],
        correctIndex: 1,
        onCorrect: "Correct — 'who', a subject relative pronoun for a person. You'd enjoy that lecture.",
      ),
      // 5 — 前置詞 + 関係代名詞 (in which). (大問1 文法空所型 — 高度関係詞)
      QuestEncounter(
        npcName: "けんきゅういん",
        npcEmoji: "🔬",
        npcLine: "This is the laboratory ___ the cure for the grey sickness was discovered.",
        npcLineJa: "ここが、灰色病（はいいろびょう）の治療法（ちりょうほう）が発見（はっけん）された研究室（けんきゅうしつ）です。",
        choices: ["which", "that", "in which", "who"],
        correctIndex: 2,
        onCorrect: "Precisely — 'in which', because the cure was discovered *in* this place. Sharp.",
      ),
      // 6 — 分詞構文 (理由・付帯状況). (大問1 文法空所型)
      QuestEncounter(
        npcName: "がくしゃ",
        npcEmoji: "🧙‍♂️",
        npcLine: "___ from a noble family, she had access to books most children never saw.",
        npcLineJa: "貴族（きぞく）の家（いえ）に生（う）まれたので、彼女（かのじょ）はふつうの子（こ）が決（けっ）して目（め）にしない本（ほん）を読（よ）めたのです。",
        choices: ["Coming", "Came", "To come", "Come"],
        correctIndex: 0,
        onCorrect: "Yes — 'Coming from...' is a participle clause giving the reason. Elegant.",
      ),
      // 7 — 仮定法過去 (If I were…, 人称無視の罠). (大問1 文法空所型)
      QuestEncounter(
        npcName: "せいじか",
        npcEmoji: "🗣️",
        npcLine: "If I ___ the mayor, I would spend far more on schools than on walls.",
        npcLineJa: "もし私（わたし）が町長（ちょうちょう）なら、城壁（じょうへき）よりも学校（がっこう）にずっと多（おお）くを使（つか）うでしょう。",
        choices: ["am", "was being", "will be", "were"],
        correctIndex: 3,
        onCorrect: "Exactly — 'were', even with 'I'. That's the subjunctive. You'd make a fine advisor.",
      ),
      // 8 — 仮定法過去完了 (過去の事実に反する仮定). (大問1 文法空所型)
      QuestEncounter(
        npcName: "へいし",
        npcEmoji: "💂",
        npcLine: "If the gate ___ locked that night, the thief would never have escaped.",
        npcLineJa: "もしあの夜（よる）、門（もん）が閉（し）まっていたら、泥棒（どろぼう）は逃（に）げられなかったでしょうに。",
        choices: ["was", "had been", "is", "would be"],
        correctIndex: 1,
        onCorrect: "Right — 'had been', for a past situation that didn't happen. A regret made grammar.",
      ),
      // 9 — 無生物主語 + allow O to do. (大問1 文法空所型)
      QuestEncounter(
        npcName: "はつめいか",
        npcEmoji: "⚙️",
        npcLine: "This new printing machine ___ scholars to copy a whole book in a single day.",
        npcLineJa: "この新（あたら）しい印刷機（いんさつき）のおかげで、学者（がくしゃ）は1日（にち）で本（ほん）を1冊（さつ）まるごと写（うつ）せるのです。",
        choices: ["lets to", "makes that", "allows", "wishes"],
        correctIndex: 2,
        onCorrect: "Yes — 'allows scholars to copy...'. The machine is the subject. Brilliant phrasing.",
      ),
      // 10 — コロケーション/派生語 (make a decision型). (大問1 語彙空所型)
      QuestEncounter(
        npcName: "しちょう",
        npcEmoji: "🎩",
        npcLine: "The council must ___ a decision about the harbour tax before winter arrives.",
        npcLineJa: "議会（ぎかい）は冬（ふゆ）が来（く）る前（まえ）に、港（みなと）の税（ぜい）についての決定（けってい）をしなければなりません。",
        choices: ["make", "do", "take", "give"],
        correctIndex: 0,
        onCorrect: "Correct — we 'make a decision', never 'do' one. Collocation matters at this level.",
      ),
      // 11 — 句動詞 (carry out = 実行する). (大問1 語彙空所型)
      QuestEncounter(
        npcName: "けんきゅうせい",
        npcEmoji: "📐",
        npcLine: "It took three years to ___ the experiment, but the results changed everything.",
        npcLineJa: "その実験（じっけん）を実行（じっこう）するのに3年（ねん）かかりましたが、結果（けっか）はすべてを変（か）えました。",
        choices: ["carry on", "carry away", "carry off", "carry out"],
        correctIndex: 3,
        onCorrect: "Yes — 'carry out an experiment' means to conduct it. Phrasal verbs are tricky; you nailed it.",
      ),
      // 12 — ディスコースマーカー however (逆接). (大問2 長文空所型)
      QuestEncounter(
        npcName: "ひひょうか",
        npcEmoji: "✍️",
        npcLine: "The plan looked perfect on paper. ___, it failed the moment it met the real world.",
        npcLineJa: "その計画（けいかく）は紙（かみ）の上（うえ）では完璧（かんぺき）に見（み）えました。___、現実（げんじつ）に出会（であ）ったとたん失敗（しっぱい）したのです。",
        choices: ["Therefore", "However", "For example", "In addition"],
        correctIndex: 1,
        onCorrect: "Right — 'However' signals the contrast between the plan and the failure. Good logic.",
      ),
      // 13 — ディスコースマーカー as a result (帰結). (大問2 長文空所型)
      QuestEncounter(
        npcName: "のうふ",
        npcEmoji: "🧑‍🌾",
        npcLine: "The rains failed for two summers. ___, grain prices in the market doubled.",
        npcLineJa: "2年（ねん）続（つづ）けて雨（あめ）が降（ふ）りませんでした。___、市場（いちば）の穀物（こくもつ）の値段（ねだん）は2倍（ばい）になりました。",
        choices: ["Nevertheless", "On the other hand", "As a result", "By contrast"],
        correctIndex: 2,
        onCorrect: "Exactly — 'As a result' shows cause and effect. You read the logic well.",
      ),
      // 14 — ディスコースマーカー for instance (例示). (大問2 長文空所型)
      QuestEncounter(
        npcName: "としょかんいん",
        npcEmoji: "📚",
        npcLine: "Reading widely builds the mind in many ways. ___, history teaches us how others solved problems.",
        npcLineJa: "幅広（はばひろ）く読（よ）むことは、いろいろな形（かたち）で心（こころ）を育（そだ）てます。___、歴史（れきし）は、ほかの人々（ひとびと）がどう問題（もんだい）を解決（かいけつ）したかを教（おし）えてくれます。",
        choices: ["For instance", "In conclusion", "Otherwise", "Instead"],
        correctIndex: 0,
        onCorrect: "Yes — 'For instance' introduces an example of those 'many ways'. Precisely placed.",
      ),
      // 15 — 強調構文 It is ... that. (大問1 文法空所型)
      QuestEncounter(
        npcName: "れきしか",
        npcEmoji: "📜",
        npcLine: "It was not the army ___ saved this city, but a single librarian who hid the books.",
        npcLineJa: "この町（まち）を救（すく）ったのは軍隊（ぐんたい）ではなく、本（ほん）を隠（かく）した一人（ひとり）の図書館員（としょかんいん）だったのです。",
        choices: ["which", "what", "who", "that"],
        correctIndex: 3,
        onCorrect: "Correct — the cleft 'It was ... that ...' uses 'that' to emphasise the subject. Masterful.",
      ),
      // 16 — 倒置 Not only ... but also (基礎). (大問1 文法空所型)
      QuestEncounter(
        npcName: "がくちょう",
        npcEmoji: "🎓",
        npcLine: "Not only ___ she master five languages, but she also wrote the kingdom's first dictionary.",
        npcLineJa: "彼女（かのじょ）は5つの言語（げんご）を習得（しゅうとく）しただけでなく、王国（おうこく）初（はじ）めての辞書（じしょ）まで書（か）いたのです。",
        choices: ["she did", "did", "she had", "does"],
        correctIndex: 1,
        onCorrect: "Yes — after 'Not only' at the front, we invert: 'did she master'. Few travellers know that.",
      ),
      // 17 — 内容一致: 言い換え正解 vs 本文語そのまま distractor. (大問3 内容一致型)
      QuestEncounter(
        npcName: "きょうじゅ",
        npcEmoji: "🧑‍🏫",
        npcLine: "My lecture's point: cities that welcomed foreign traders grew rich, while those that shut their gates slowly declined. What did I argue?",
        npcLineJa: "私（わたし）の講義（こうぎ）の要点（ようてん）です。外国（がいこく）の商人（しょうにん）を受（う）け入（い）れた都市（とし）は豊（ゆた）かになり、門（もん）を閉（と）ざした都市（とし）は少（すこ）しずつ衰（おとろ）えた、と。私（わたし）は何（なに）を論（ろん）じましたか？",
        choices: ["That all cities shut their gates to foreign traders.", "That foreign traders made every city poor.", "That openness to outsiders helped cities prosper.", "That cities grew rich by welcoming foreign traders and never declined."],
        correctIndex: 2,
        onCorrect: "Exactly — 'openness helped them prosper' is the paraphrase, not the word-matching trap. You read for meaning.",
      ),
      // 18 — 内容一致: 明示されない結論の推論. (大問3 内容一致型 — 推論)
      QuestEncounter(
        npcName: "けんじゃ",
        npcEmoji: "🧙",
        npcLine: "The records show the city's scholars all left in the same year the great library burned. What can we reasonably infer?",
        npcLineJa: "記録（きろく）によれば、町（まち）の学者（がくしゃ）たちは、大（おお）きな図書館（としょかん）が焼（や）けたのと同（おな）じ年（とし）にみな去（さ）った、とあります。何（なに）が合理的（ごうりてき）に推測（すいそく）できますか？",
        choices: ["The fire likely drove the scholars to leave.", "The scholars set fire to the library themselves.", "Libraries are dangerous places for scholars.", "The scholars left because the city had too many books."],
        correctIndex: 0,
        onCorrect: "Yes — the text doesn't state the cause outright, but the timing makes that the soundest inference. A true scholar's mind.",
      ),
      // 19 — 要約タスク: 本文の要点のみ・意見/具体例/丸写しを排除. (Writing 要約型)
      QuestEncounter(
        npcName: "しょきかん",
        npcEmoji: "🖋️",
        npcLine: "Summarise this passage: 'Many towns once feared books, thinking they spread dangerous ideas. Over time, however, people saw that books also spread knowledge that improved farming, medicine, and trade. Most towns came to value them.' Which is the best summary?",
        npcLineJa: "この文章（ぶんしょう）を要約（ようやく）してください。『多（おお）くの町（まち）はかつて、本（ほん）が危険（きけん）な考（かんが）えを広（ひろ）めると恐（おそ）れていた。しかし時（とき）とともに、本（ほん）は農業（のうぎょう）・医療（いりょう）・商売（しょうばい）を良（よ）くする知識（ちしき）も広（ひろ）めると人々（ひとびと）は気（き）づき、ほとんどの町（まち）が本（ほん）を大切（たいせつ）にするようになった。』 最（もっと）も良（よ）い要約（ようやく）は？",
        choices: ["Books are the most important thing in the world, and everyone should read them daily.", "One town feared a book about farming, but a wise doctor proved it was useful and safe.", "Books spread dangerous ideas, so towns were right to fear and ban them everywhere.", "Towns once feared books but later valued them for the useful knowledge they spread."],
        correctIndex: 3,
        onCorrect: "Perfect — you kept only the passage's main points, with no opinion, no invented example, and no copied sentence. That is a true summary.",
      ),
      // 20 — Mini-boss「論駁（ろんばく）の番人」: 要約の本質を見抜く. (要約タスク総合)
      QuestEncounter(
        npcName: "論駁の番人",
        npcEmoji: "🗿",
        npcLine: "(A stone guardian blocks the keep.) Silentus ate the world's words because he thought them noise. Prove you can hold meaning, not mere noise: which choice truly summarises an argument — capturing its point without copying its words or adding your own?",
        npcLineJa: "（石（いし）の番人（ばんにん）が天守（てんしゅ）をふさいでいる。）魔王（まおう）サイレントは、ことばを「ただの雑音（ざつおん）」と思（おも）い、世界（せかい）から食（た）べてしまった。お前（まえ）が雑音（ざつおん）ではなく「意味（いみ）」を扱（あつか）える証（あかし）を見（み）せよ。本当（ほんとう）に論（ろん）を要約（ようやく）しているのは――言葉（ことば）を写（うつ）さず、自分（じぶん）の意見（いけん）も足（た）さず、要点（ようてん）をつかむのは、どれだ？",
        choices: ["Repeating the author's strongest sentence word for word, exactly as written.", "Adding your own opinion about whether the author was right or wrong.", "Restating the author's main idea in fewer, different words, with nothing added.", "Listing every example the author gave, in the same order, leaving none out."],
        correctIndex: 2,
        onCorrect: "(The guardian's stone eyes glow, then still.) ...You hold meaning, not noise. A summary is the idea, reborn in your own words. Pass, heir — the sixth Stone of Voice is yours, and the keep doors open.",
      ),
    ],
  ),
  QuestTown(
    id: 'town_pre1',
    eikenLevel: 'pre1',
    cefr: 'B2-C1',
    name: '王都（おうと）',
    tagline: '王の待つ都',
    intro: 'すべての旅（たび）の果（は）て、灰色（はいいろ）に沈（しず）んだ王都（おうと）。'
        '玉座（ぎょくざ）に、口（くち）のない魔王（まおう）サイレントが座（すわ）っている。最後（さいご）の戦（たたか）いは――剣（けん）ではなく、言葉（ことば）。',
    cleared: 'あなたの言葉（ことば）が、サイレントの胸（むね）に届（とど）いた。彼（かれ）に「声（こえ）」が返（かえ）り、灰色（はいいろ）の世界（せかい）に色（いろ）がもどっていく。'
        'ことばは、しずけさより強（つよ）い。勇者（ゆうしゃ）よ――あなたの旅（たび）が、世界（せかい）を救（すく）った。',
    encounters: [
      // 1 — Advanced collocation (verb+noun). 「決断を下す」= make, not do/take/give. (大問1型)
      QuestEncounter(
        npcName: '門の守り手',
        npcEmoji: '🛡️',
        npcLine:
            'Traveller, the capital is under siege. Before you enter, you must ___ a decision: fight, or flee.',
        npcLineJa:
            '旅人（たびびと）よ、王都（おうと）は包囲（ほうい）されている。入（はい）る前（まえ）に、戦（たたか）うか逃（に）げるか、決断（けつだん）を ___ ねばならぬ。',
        choices: ['do', 'take', 'make', 'give'],
        correctIndex: 2,
        onCorrect:
            'You "make" a decision — never "do" one. Spoken like one born to rule. The gate opens.',
      ),
      // 2 — Low-frequency synonym nuance (deliberate vs hasty/reluctant/accidental). (大問1型)
      QuestEncounter(
        npcName: '王都の書記',
        npcEmoji: '📜',
        npcLine:
            'The Silent King did not act by chance. His erasure of all words was slow and ___ — every page chosen on purpose.',
        npcLineJa:
            'サイレント王（おう）は偶然（ぐうぜん）に動（うご）いたのではない。言葉（ことば）の消去（しょうきょ）は緩（ゆる）やかで ___ ── 一頁（ひとぺーじ）ずつ意図（いと）して選（えら）ばれた。',
        choices: ['accidental', 'deliberate', 'reluctant', 'hasty'],
        correctIndex: 1,
        onCorrect:
            '"Deliberate" — done on purpose. The nuance escapes most; not you.',
      ),
      // 3 — Phrasal verb precision (carry out = execute). (大問1型)
      QuestEncounter(
        npcName: '元・宰相',
        npcEmoji: '🎩',
        npcLine:
            'The plan to seal the King\'s library was sound. The trouble was, no one dared to ___ it ___.',
        npcLineJa:
            '王（おう）の書庫（しょこ）を封（ふう）じる計画（けいかく）は健全（けんぜん）だった。問題（もんだい）は、それを ___ 者（もの）がいなかったことだ。',
        choices: ['carry / on', 'carry / out', 'put / off', 'take / after'],
        correctIndex: 1,
        onCorrect:
            '"Carry it out" — to execute it. "Carry on" would mean continue. Precision wins wars.',
      ),
      // 4 — Derivational / abstract noun (resilience). (大問1型)
      QuestEncounter(
        npcName: '城の治癒師',
        npcEmoji: '⚕️',
        npcLine:
            'The people lost their language, yet they endured. Such ___ in the face of ruin is rare.',
        npcLineJa:
            '民（たみ）は言葉（ことば）を失（うしな）っても耐（た）え抜（ぬ）いた。破滅（はめつ）を前（まえ）にしたその ___ は稀（まれ）だ。',
        choices: ['resilient', 'resilience', 'resiliently', 'resile'],
        correctIndex: 1,
        onCorrect:
            'The noun "resilience" — after "such" we need a noun, not the adjective. Grammar and meaning, both yours.',
      ),
      // 5 — Subjunctive present (insist (that) S (should) be). (大問1 文法型)
      QuestEncounter(
        npcName: '王都の将軍',
        npcEmoji: '⚔️',
        npcLine:
            'The council insists that every gate ___ guarded tonight. No exceptions, even for a prince.',
        npcLineJa:
            '評議会（ひょうぎかい）は、今夜（こんや）すべての門（もん）が守（まも）られる「べきだ」と強（つよ）く求（もと）めている。王子（おうじ）であっても例外（れいがい）はない。',
        choices: ['is', 'be', 'was', 'will be'],
        correctIndex: 1,
        onCorrect:
            'Bare "be" — the subjunctive after "insist that." A demand, not a fact. You know the old grammar.',
      ),
      // 6 — Mixed conditional (past condition → present result). (大問1 文法型)
      QuestEncounter(
        npcName: 'スラ',
        npcEmoji: '🟢',
        npcLine:
            'If the King had never eaten the words, the world ___ full of voices right now.',
        npcLineJa:
            'もしサイレント王（おう）が言葉（ことば）を食（た）べていなかったら、世界（せかい）は今（いま）ごろ声（こえ）に満（み）ちて ___ のに。',
        choices: ['would be', 'would have been', 'will be', 'had been'],
        correctIndex: 0,
        onCorrect:
            '"would be" — past cause, present result. A mixed conditional. Even I, a slime, feel that sorrow.',
      ),
      // 7 — Inversion after negative adverbial (Hardly had…when). (大問1 文法型)
      QuestEncounter(
        npcName: '見張りの兵',
        npcEmoji: '🪖',
        npcLine:
            'Hardly ___ we shut the inner gate when the silence struck the upper halls.',
        npcLineJa:
            '内門（ないもん）を閉（と）じるか閉（と）じないかのうちに、静寂（せいじゃく）が上層（じょうそう）の広間（ひろま）を襲（おそ）った。「___」に入（はい）るのは？',
        choices: ['did', 'have', 'had', 'were'],
        correctIndex: 2,
        onCorrect:
            '"Hardly HAD we shut..." — negative-adverbial inversion with the past perfect. Textbook B2.',
      ),
      // 8 — Inversion: Only after / focus fronting. (大問1 文法型)
      QuestEncounter(
        npcName: '老騎士',
        npcEmoji: '🐴',
        npcLine:
            'Only after the last word vanished ___ the people understand what they had taken for granted.',
        npcLineJa:
            '最後（さいご）の言葉（ことば）が消（き）えて初（はじ）めて、民（たみ）は当（あ）たり前（まえ）と思（おも）っていたものを理解（りかい）した。「___」に入（はい）るのは？',
        choices: ['the people did', 'did the people', 'the people', 'they had'],
        correctIndex: 1,
        onCorrect:
            'Front a "Only after…" clause and the subject and auxiliary invert: "did the people understand." Well drawn, knight.',
      ),
      // 9 — Cleft / emphatic (It was X that…). (大問1 文法型)
      QuestEncounter(
        npcName: '吟遊詩人',
        npcEmoji: '🎻',
        npcLine:
            'It was not gold that the King hungered for — it ___ the silence between every word.',
        npcLineJa:
            '王（おう）が渇望（かつぼう）したのは黄金（おうごん）ではなかった ── それは、すべての言葉（ことば）の間（あいだ）の静寂（せいじゃく）「だった」のだ。「___」に入（はい）るのは？',
        choices: ['was', 'were', 'had', 'did'],
        correctIndex: 0,
        onCorrect:
            'The cleft "It was … that" stays singular — "it was." You hear the music of emphasis.',
      ),
      // 10 — Compound relative (whatever, concession). (大問1 文法型)
      QuestEncounter(
        npcName: '城門の魔術師',
        npcEmoji: '🪄',
        npcLine:
            '___ you say to the Silent King, he will twist it into emptiness. Choose your words like blades.',
        npcLineJa:
            'サイレント王（おう）に「何（なに）を言（い）おうとも」、彼（かれ）はそれを虚無（きょむ）へとねじ曲（ま）げる。言葉（ことば）を刃（やいば）のように選（えら）べ。「___」に入（はい）るのは？',
        choices: ['However', 'Whatever', 'Whoever', 'Wherever'],
        correctIndex: 1,
        onCorrect:
            '"Whatever you say" — the object of "say," so the -ever pronoun, not the adverb. Sharp.',
      ),
      // 11 — Concession (No matter how + adjective). (大問1 文法型)
      QuestEncounter(
        npcName: '王妃の侍女',
        npcEmoji: '👗',
        npcLine:
            'No matter ___ powerful the King grows, a true heir is bound to no fear. Are you that heir?',
        npcLineJa:
            '王（おう）がどれほど強大（きょうだい）になろうとも、真（しん）の世継（よつ）ぎは恐（おそ）れに縛（しば）られぬ。「どれほど ___ うとも」の「___」は？',
        choices: ['how', 'what', 'that', 'than'],
        correctIndex: 0,
        onCorrect:
            '"No matter HOW powerful" — "how" before an adjective. The court bows; they know your blood now.',
      ),
      // 12 — Inanimate subject + high-register verb (witnessed). (大問1 / 長文型)
      QuestEncounter(
        npcName: '王都の歴史家',
        npcEmoji: '🏛️',
        npcLine:
            'These walls have ___ the rise and fall of three dynasties — and tonight, perhaps, a fourth.',
        npcLineJa:
            'この城壁（じょうへき）は三（みっ）つの王朝（おうちょう）の興亡（こうぼう）を「見（み）てきた」── そして今夜（こんや）、おそらく四（よっ）つ目（め）を。「___」は？',
        choices: ['watched over by', 'witnessed', 'looked', 'seen to'],
        correctIndex: 1,
        onCorrect:
            'Walls cannot "watch," but they can "witness" — the inanimate subject takes the higher verb. Eloquent.',
      ),
      // 13 — Discourse connective: contrast (Nevertheless). (長文の語句空所補充型)
      QuestEncounter(
        npcName: '反乱軍の使者',
        npcEmoji: '🗡️',
        npcLine:
            'Our army is small and weary. ___, we will stand at the throne room tonight — retreat is not a word we keep.',
        npcLineJa:
            '我（わ）が軍（ぐん）は小（ちい）さく疲（つか）れている。___、今夜（こんや）我々（われわれ）は王座（おうざ）の間（ま）に立（た）つ ── 退却（たいきゃく）という語（ご）は持（も）たぬ。',
        choices: ['Therefore', 'Nevertheless', 'For example', 'Likewise'],
        correctIndex: 1,
        onCorrect:
            '"Nevertheless" — concession against the weakness just stated. You read the logic, not the words.',
      ),
      // 14 — Discourse connective: addition (Moreover). (長文の語句空所補充型)
      QuestEncounter(
        npcName: '城の参謀',
        npcEmoji: '🧭',
        npcLine:
            'The King\'s power feeds on spoken fear. ___, every word we still dare to say weakens him further.',
        npcLineJa:
            '王（おう）の力（ちから）は口（くち）にされた恐怖（きょうふ）を糧（かて）とする。___、我々（われわれ）が今（いま）なお語（かた）る言葉（ことば）の一（ひと）つ一（ひと）つが、彼（かれ）をさらに弱（よわ）める。',
        choices: ['However', 'In contrast', 'Moreover', 'Otherwise'],
        correctIndex: 2,
        onCorrect:
            '"Moreover" — a second supporting point added to the first. The strategist nods at your ear for logic.',
      ),
      // 15 — Discourse connective: concessive result (Even so). (長文の語句空所補充型)
      QuestEncounter(
        npcName: 'スラ',
        npcEmoji: '🟢',
        npcLine:
            'I know the throne room takes our voices the moment we step in. ___, I\'m going with you. I won\'t let you go silent alone.',
        npcLineJa:
            '王座（おうざ）の間（ま）は、踏（ふ）み入（い）れた瞬間（しゅんかん）に声（こえ）を奪（うば）うって知（し）ってる。___、ぼくは一緒（いっしょ）に行（い）く。きみひとりを静寂（せいじゃく）にはさせない。',
        choices: ['Even so', 'As a result', 'In other words', 'For instance'],
        correctIndex: 0,
        onCorrect:
            '"Even so" — acknowledging the danger, yet acting against it. ...Sura squeezes your hand.',
      ),
      // 16 — Inference of an UNSTATED conclusion. (長文の内容一致選択型)
      QuestEncounter(
        npcName: '幽閉された学者',
        npcEmoji: '🔒',
        npcLine:
            '"The King has not spoken in a hundred years, yet his decrees still arrive, sealed in fresh ink each dawn." What does this most strongly imply?',
        npcLineJa:
            '「王（おう）は百年（ひゃくねん）口（くち）をきいていないのに、その勅令（ちょくれい）は毎朝（まいあさ）新（あたら）しい墨（すみ）で封（ふう）じられて届（とど）く。」これが最（もっと）も強（つよ）く示唆（しさ）するのは？',
        choices: [
          'The King writes his decrees by hand each morning.',
          'Someone, or something, still acts in the silent King\'s name.',
          'The King died exactly one hundred years ago.',
          'The decrees are old letters found by chance.'
        ],
        correctIndex: 1,
        onCorrect:
            'Fresh ink + a silent King ⇒ another hand moves for him. You infer what the text never says outright.',
      ),
      // 17 — Paraphrase = answer; verbatim = trap. (長文の内容一致選択型)
      QuestEncounter(
        npcName: '王都の哲学者',
        npcEmoji: '🦉',
        npcLine:
            '"To rob a people of their words is to rob them of the means to imagine a better world." Which choice best restates this?',
        npcLineJa:
            '「民（たみ）から言葉（ことば）を奪（うば）うことは、より良（よ）い世界（せかい）を想像（そうぞう）する手段（しゅだん）を奪（うば）うことだ。」本文（ほんぶん）を最（もっと）もよく言（い）い換（か）えているのは？',
        choices: [
          'Robbing people of words robs them of a better world.',
          'Without language, people lose the ability to envision a better future.',
          'A better world is the means to give people their words.',
          'People rob words to imagine a better world.'
        ],
        correctIndex: 1,
        onCorrect:
            'The genuine paraphrase wins; option A merely echoes the surface words. You see meaning, not vocabulary.',
      ),
      // 18 — Summary: main idea ONLY, no opinion / no detail. (英文要約型)
      QuestEncounter(
        npcName: '王の図書館の番人',
        npcEmoji: '📚',
        npcLine:
            '"Long ago the capital thrived on open debate. When the King began erasing dissenting words, fear spread, scholars fled, and the city fell silent." Pick the best one-line summary.',
        npcLineJa:
            '「かつて王都（おうと）は自由（じゆう）な議論（ぎろん）で栄（さか）えた。王（おう）が異論（いろん）の言葉（ことば）を消（け）し始（はじ）めると、恐怖（きょうふ）が広（ひろ）がり、学者（がくしゃ）は逃（に）げ、都（みやこ）は沈黙（ちんもく）した。」最（もっと）も良（よ）い一文（いちぶん）の要約（ようやく）は？',
        choices: [
          'I think the King was wrong to erase words from the city.',
          'Scholars fled the capital because they were afraid of fear.',
          'Suppressing free speech turned a thriving capital into a silent one.',
          'The capital had many open debates and famous scholars.'
        ],
        correctIndex: 2,
        onCorrect:
            'Cause to effect, no opinion, no stray detail — the discipline of a true summary. Option A added YOUR view; a summary never does.',
      ),
      // 19 — Opinion essay: the reason that actually supports the claim. (意見論述型)
      QuestEncounter(
        npcName: 'スラ',
        npcEmoji: '🟢',
        npcLine:
            'Before the doors, you must declare your cause: "Words should be free." Which reason best SUPPORTS that claim in an essay?',
        npcLineJa:
            '扉（とびら）の前（まえ）で、きみは主張（しゅちょう）を述（の）べねばならない ──「言葉（ことば）は自由（じゆう）であるべきだ」。小論文（しょうろんぶん）でその主張（しゅちょう）を最（もっと）もよく「支（ささ）える」理由（りゆう）は？',
        choices: [
          'Free expression lets people share ideas that improve society.',
          'Some words are difficult to spell correctly.',
          'The King is very powerful and lives in the capital.',
          'Many people enjoy staying silent sometimes.'
        ],
        correctIndex: 0,
        onCorrect:
            'A reason that directly props up the claim — relevant, not random. Your argument has a spine now.',
      ),
      // 20 — FINALE: 魔王サイレント. Integrate nuance + logic + inference under pressure. (統合型)
      QuestEncounter(
        npcName: '魔王サイレント',
        npcEmoji: '👑',
        npcLine:
            '(A crowned shadow on the throne; the air swallows every sound.) "...If silence is peace, then speech is mere noise. Why should I ever give the world its words back?" Your single reply must break him.',
        npcLineJa:
            '（王座（おうざ）の上（うえ）、冠（かんむり）をかぶった影（かげ）。空気（くうき）があらゆる音（おと）を呑（の）み込（こ）む。）「…静寂（せいじゃく）が平和（へいわ）だというなら、言葉（ことば）はただの雑音（ざつおん）だ。なぜ私（わたし）が世界（せかい）に言葉（ことば）を返（かえ）さねばならぬ？」きみのただ一言（ひとこと）が彼（かれ）を打（う）ち破（やぶ）る。',
        choices: [
          'Silence is quiet, and quiet is nice, so you are a little right.',
          'You are powerful, and powerful people should do whatever they want.',
          'Peace built on stolen words is not peace but a cage; only free speech lets people heal, dissent, and imagine — that is why the world\'s words must return.',
          'Noise is loud and words are noise, therefore words are bad and you win.'
        ],
        correctIndex: 2,
        onCorrect:
            'The crown cracks. "...A cage. You name it true." Light floods the throne room, and a thousand voices return at once. "Then take them back, my heir — and never let them be eaten again." The world remembers how to speak.',
      ),
    ],
  ),
];

/// Map a placement level to the index of the town a student starts in.
/// A 準2級 holder begins in the 準2級 town, etc.
int startingTownIndex(String eikenLevel) {
  final i = kQuestTowns.indexWhere((t) => t.eikenLevel == eikenLevel);
  return i < 0 ? 0 : i;
}

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
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "What subject do you like the best at school?",
        npcLineJa: "学校でどの教科が一番好きですか？",
        choices: ["I like math the best.", "I go to school by bus.", "School starts at eight.", "Yes, I have a pencil."],
        correctIndex: 0,
        onCorrect: "Math is great! Keep studying hard and you'll go far!",
      ),
      QuestEncounter(
        npcName: "おかあさん",
        npcEmoji: "👩",
        npcLine: "Did you eat breakfast this morning?",
        npcLineJa: "今朝、朝ごはんは食べましたか？",
        choices: ["I usually wake up early.", "Yes, I had toast and eggs.", "Breakfast is in the kitchen.", "I like orange juice."],
        correctIndex: 1,
        onCorrect: "Good! A healthy breakfast gives you energy for the day!",
      ),
      QuestEncounter(
        npcName: "みせのひと",
        npcEmoji: "🛒",
        npcLine: "Can I help you? Are you looking for something?",
        npcLineJa: "いらっしゃいませ。何かお探しですか？",
        choices: ["The store is very big.", "I bought a new bag yesterday.", "Yes, I'm looking for a birthday card.", "Shopping is fun with friends."],
        correctIndex: 2,
        onCorrect: "Of course! The cards are right over there. Follow me!",
      ),
      QuestEncounter(
        npcName: "おじいさん",
        npcEmoji: "👴",
        npcLine: "It's cold today, isn't it? How is the weather in your town?",
        npcLineJa: "今日は寒いですね。あなたの街のお天気はどうですか？",
        choices: ["I wear a coat in winter.", "My town is near the mountains.", "It is sunny and warm there.", "The weather report was wrong."],
        correctIndex: 2,
        onCorrect: "How lucky! Warm weather is wonderful. I hope you enjoy it!",
      ),
      QuestEncounter(
        npcName: "ともだち",
        npcEmoji: "🧒",
        npcLine: "What are you going to do this weekend?",
        npcLineJa: "この週末、何をするつもりですか？",
        choices: ["Last weekend was really fun.", "I went to the park with my dad.", "I'm going to visit my grandparents.", "Weekends are always too short."],
        correctIndex: 2,
        onCorrect: "That sounds wonderful! I'm sure your grandparents will be so happy!",
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
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "Did you study for the test last night?",
        npcLineJa: "昨夜、テストの勉強をしましたか？",
        choices: ["Yes, I studied for two hours.", "Yes, I am studying now.", "No, I don't like tests tomorrow.", "I study English every Sunday."],
        correctIndex: 0,
        onCorrect: "Wonderful! Hard work always pays off. Good luck today!",
      ),
      QuestEncounter(
        npcName: "りょこうしゃ",
        npcEmoji: "🧳",
        npcLine: "Have you ever been to another country?",
        npcLineJa: "外国に行ったことがありますか？",
        choices: ["I want to go to France someday.", "Yes, I went to Canada last summer.", "No, I don't have a passport yet.", "My country is very beautiful."],
        correctIndex: 1,
        onCorrect: "Canada is amazing! What did you enjoy the most there?",
      ),
      QuestEncounter(
        npcName: "としょかんいん",
        npcEmoji: "📚",
        npcLine: "What kind of books do you like to read?",
        npcLineJa: "どんな本を読むのが好きですか？",
        choices: ["I read books very fast.", "The library opens at nine.", "I love adventure stories because they are exciting.", "Books are on the second floor."],
        correctIndex: 2,
        onCorrect: "Adventure stories are the best! Let me recommend one for you.",
      ),
      QuestEncounter(
        npcName: "スポーツせんしゅ",
        npcEmoji: "⚽",
        npcLine: "How long have you been playing soccer?",
        npcLineJa: "サッカーはどれくらいやっていますか？",
        choices: ["I play soccer at the big park.", "Soccer is my favorite sport.", "I have been playing for about three years.", "My team won the game yesterday."],
        correctIndex: 2,
        onCorrect: "Three years — you must be really skilled! Keep it up!",
      ),
      QuestEncounter(
        npcName: "やおやさん",
        npcEmoji: "🥦",
        npcLine: "Can you help me carry these vegetables to the market?",
        npcLineJa: "この野菜を市場まで運ぶのを手伝ってもらえますか？",
        choices: ["Vegetables are very healthy for us.", "Sure, I'd be happy to help you!", "The market is closed on Mondays.", "I usually buy vegetables with my mom."],
        correctIndex: 1,
        onCorrect: "Thank you so much! You are very kind. Here, take some carrots!",
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
      QuestEncounter(
        npcName: "ハーモニー",
        npcEmoji: "🎶",
        npcLine:
            "I'm a bard. I sing the words people have lost. Why have you come to this harbour town?",
        npcLineJa:
            "私（わたし）は吟遊詩人（ぎんゆうしじん）。失（うしな）われた言葉（ことば）を歌（うた）にするの。なぜこの港町（みなとまち）へ？",
        choices: [
          "A bard is a person who sings songs for money.",
          "I'm searching for the Stones of Voice to bring words back to the world.",
          "Yes, harbours have many ships.",
          "I came because to find the reason of stones.",
        ],
        correctIndex: 1,
        onCorrect:
            "Then our paths are one. I'll sing for you, hero. When you free a town's words, I'll carry them to the sky.",
      ),
      QuestEncounter(
        npcName: "りょうし",
        npcEmoji: "🎣",
        npcLine:
            "These days, people argue instead of talking. What do you think makes a good conversation?",
        npcLineJa:
            "このごろ、人（ひと）は話（はな）し合（あ）わずに言（い）い争（あらそ）う。よい会話（かいわ）に大切（たいせつ）なものは何（なん）だと思（おも）う？",
        choices: [
          "Listening to the other person before you answer.",
          "A conversation is when two people talk together.",
          "I think fishing is harder than talking.",
          "Because good, so people are happy always.",
        ],
        correctIndex: 0,
        onCorrect:
            "Wise beyond your years. If more people listened, this town wouldn't be losing its voice.",
      ),
      QuestEncounter(
        npcName: "しょうにん",
        npcEmoji: "🛍️",
        npcLine:
            "Trade has been slow since people stopped sharing news. How could we bring the town together again?",
        npcLineJa:
            "人（ひと）が知（し）らせを伝（つた）え合（あ）わなくなってから、商売（しょうばい）が落（お）ちこんでいる。町（まち）をまた一（ひと）つにするには？",
        choices: [
          "Trade means buying and selling goods.",
          "I don't have any money to buy your spices.",
          "We could hold a market day where everyone meets and talks.",
          "The town is together because it is one town.",
        ],
        correctIndex: 2,
        onCorrect:
            "A market day — brilliant! When people gather, words return. You have the heart of a leader.",
      ),
      QuestEncounter(
        npcName: "おかあさん",
        npcEmoji: "👩",
        npcLine:
            "My son hasn't spoken a word in days. Do you think his silence will pass?",
        npcLineJa:
            "息子（むすこ）が何日（なんにち）も口（くち）をきかないの。このしずけさは、いつか終（お）わると思（おも）う？",
        choices: [
          "Silence is when there is no sound at all.",
          "No, because boys are usually very loud.",
          "Yes, your son will pass the test next week.",
          "I believe it will, if we keep speaking to him with kindness.",
        ],
        correctIndex: 3,
        onCorrect:
            "Thank you. I won't give up on him. Kind words are stronger than any silence... aren't they?",
      ),
      QuestEncounter(
        npcName: "クワイエト",
        npcEmoji: "🌑",
        npcLine:
            "Stop. I serve Lord Silentus. He believes a silent world is a peaceful world — no lies, no quarrels. Why do you fight to bring words back?",
        npcLineJa:
            "止（と）まれ。私（わたし）は魔王（まおう）サイレントに仕（つか）える者（もの）。彼（かれ）は、しずかな世界（せかい）こそ平和（へいわ）だと信（しん）じている――嘘（うそ）も、争（あらそ）いもない。なぜ言葉（ことば）を取（と）りもどそうとする？",
        choices: [
          "Quiet is the opposite of loud.",
          "Because without words, we can't share kindness, or say 'I love you', or ever be understood.",
          "Because I want to win and get a big prize.",
          "Yes, a silent world is very peaceful indeed.",
        ],
        correctIndex: 1,
        onCorrect:
            "...That answer should be easy to dismiss. Why does it linger in my mind? ...This isn't over, traveller. We will meet again — at the King's City.",
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
      QuestEncounter(
        npcName: "はしの番人",
        npcEmoji: "🌉",
        npcLine: "This bridge leads to much harder roads ahead. Why do you want to cross it?",
        npcLineJa: "この橋の先には、もっと厳しい道が続いています。なぜ渡りたいのですか？",
        choices: ["Because I want to challenge myself and become stronger.", "Bridges are usually made of wood or stone.", "I want to cross because I am very tired now.", "No, I don't want to answer your question."],
        correctIndex: 0,
        onCorrect: "A strong reason indeed. Those who cross with purpose rarely turn back. Go on!",
      ),
      QuestEncounter(
        npcName: "じゅけんせい",
        npcEmoji: "📖",
        npcLine: "I'm studying for a tougher test than ever before. Do you have any advice for staying motivated?",
        npcLineJa: "今までで一番難しい試験のために勉強しています。やる気を保つコツはありますか？",
        choices: ["Tests are usually held in large, quiet rooms.", "Try setting small goals — reaching them keeps you going.", "You should stop studying and rest forever.", "Motivated is just the past tense of motivate."],
        correctIndex: 1,
        onCorrect: "That's practical advice — small wins really do add up. Thank you, traveller!",
      ),
      QuestEncounter(
        npcName: "たびびと",
        npcEmoji: "🧭",
        npcLine: "If you could master any language instantly, which would you choose, and why?",
        npcLineJa: "もしどんな言語でも一瞬で習得できるなら、どれを選び、なぜですか？",
        choices: ["English, because it would let me talk with people all over the world.", "Languages are spoken by people in many countries.", "I choose because why not, the thing is good.", "Instantly means the bridge is very long."],
        correctIndex: 0,
        onCorrect: "A thoughtful choice! A shared language can open more doors than any key.",
      ),
      QuestEncounter(
        npcName: "はしをなおす人",
        npcEmoji: "🔧",
        npcLine: "This bridge keeps cracking, and I think the heavy rain is the cause. What do you think we should do about it?",
        npcLineJa: "この橋はひび割れが続きます。原因は大雨だと思います。どうすればいいと思いますか？",
        choices: ["Maybe you could build a roof to protect it from the rain.", "Rain falls from the clouds in the sky.", "I think the bridge is a beautiful colour.", "A cause is something you fight for, like a hero."],
        correctIndex: 0,
        onCorrect: "Brilliant! A roof might be exactly what we need. You think like a real problem-solver!",
      ),
      QuestEncounter(
        npcName: "みちしるべの老人",
        npcEmoji: "🧓",
        npcLine: "Some say that failing is just a step toward success. Do you agree, and why?",
        npcLineJa: "失敗は成功への一歩にすぎない、と言う人もいます。あなたは賛成ですか、その理由は？",
        choices: ["Yes — every mistake teaches us something we couldn't learn otherwise.", "Success is when you win and get a big prize.", "No, because failing means the bridge is broken.", "A step is a part of a staircase you walk on."],
        correctIndex: 0,
        onCorrect: "Wisely said. The ones who keep crossing after a fall are the ones who reach the far side.",
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
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "I've been teaching here for ten years, though the number of students keeps declining.",
        npcLineJa: "10年間ここで教えています。でも生徒数はずっと減っています。",
        choices: ["That must be quite challenging for you.", "Yes, I like cats very much.", "The weather is nice today, isn't it?", "I don't have any money, sorry."],
        correctIndex: 0,
        onCorrect: "Exactly — but I still love teaching. Thank you for understanding!",
      ),
      QuestEncounter(
        npcName: "しょうにん",
        npcEmoji: "🧑‍💼",
        npcLine: "Business has slowed down since the new trade regulations came into effect last month.",
        npcLineJa: "先月から新しい貿易規制が始まって、商売が落ち込んでいます。",
        choices: ["I used to live in a castle.", "Have you considered selling different products instead?", "My sword is very sharp.", "Dinner smells delicious tonight."],
        correctIndex: 1,
        onCorrect: "Great idea! I had not thought of that. You are quite wise for a young traveller!",
      ),
      QuestEncounter(
        npcName: "いしゃ",
        npcEmoji: "👨‍⚕️",
        npcLine: "Although modern medicine has advanced greatly, many people still prefer traditional remedies.",
        npcLineJa: "現代医学はかなり進歩しましたが、それでも昔ながらの治療を好む人は多いですね。",
        choices: ["I agree — both approaches have their own merits.", "The dragon lives in the eastern forest.", "Please close the window.", "I finished my homework yesterday."],
        correctIndex: 0,
        onCorrect: "Well said! A balanced view is the mark of a thoughtful mind.",
      ),
      QuestEncounter(
        npcName: "としょかんいん",
        npcEmoji: "📚",
        npcLine: "If you want to improve your vocabulary, reading widely is far more effective than memorizing word lists.",
        npcLineJa: "語彙力を伸ばしたいなら、単語帳を暗記するより幅広く読むほうがずっと効果的ですよ。",
        choices: ["That makes sense — variety in reading builds deeper understanding.", "I prefer to sleep in the afternoon.", "The castle gate is closed on Sundays.", "Can I borrow your umbrella?"],
        correctIndex: 0,
        onCorrect: "Precisely! Come by anytime — we have books on every subject imaginable.",
      ),
      QuestEncounter(
        npcName: "がくしゃ",
        npcEmoji: "🧙‍♂️",
        npcLine: "The climate in this region has changed significantly over the past few decades.",
        npcLineJa: "この地域の気候はここ数十年でかなり変わりました。",
        choices: ["I prefer summer over winter.", "My horse is tired from the long journey.", "Do you think human activity is the main cause?", "The soup is too hot to eat right now."],
        correctIndex: 2,
        onCorrect: "An excellent question! That is exactly what researchers are investigating. You have a sharp mind!",
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
      QuestEncounter(
        npcName: "がくしゃ",
        npcEmoji: "🧙‍♂️",
        npcLine:
            "The world has fallen grey and silent. Some scholars argue silence brings order. Where do you stand on that claim?",
        npcLineJa:
            "世界（せかい）は灰色（はいいろ）に沈（しず）み、しずまり返（かえ）った。しずけさが秩序（ちつじょ）をもたらすと説（と）く学者（がくしゃ）もいる。あなたはその主張（しゅちょう）をどう見（み）る？",
        choices: [
          "Order without expression isn't peace — it's a cage that merely looks calm.",
          "Yes, technology is very expensive these days.",
          "Silence simply means the absence of any sound.",
          "I haven't studied that subject, so I cannot read it.",
        ],
        correctIndex: 0,
        onCorrect:
            "A cage that looks calm... I shall remember that phrase. Go on — the throne room awaits a mind like yours.",
      ),
      QuestEncounter(
        npcName: "きぞく",
        npcEmoji: "👸",
        npcLine:
            "Many fled the city in fear. If you reach the throne, will you destroy Silentus, or reason with him?",
        npcLineJa:
            "多（おお）くの者（もの）が恐（おそ）れて都（みやこ）を去（さ）った。玉座（ぎょくざ）にたどり着（つ）いたら、サイレントを滅（ほろ）ぼす？ それとも、語（かた）りかける？",
        choices: [
          "I will destroy him because villains must always be destroyed.",
          "To reason is a verb that means to think carefully.",
          "I'd rather understand why he silenced the world before deciding how to stop him.",
          "Yes, the weather has been quite unpredictable lately.",
        ],
        correctIndex: 2,
        onCorrect:
            "Spoken like the heir this kingdom has prayed for. Show that crest at the gate — they will let you pass.",
      ),
      QuestEncounter(
        npcName: "ハーモニー",
        npcEmoji: "🎶",
        npcLine:
            "This is the final town. Once you walk through that door, there's no turning back. Are you ready to face him with nothing but your words?",
        npcLineJa:
            "ここが最後（さいご）の町（まち）。あの扉（とびら）をくぐれば、もう後（あと）戻（もど）りはできない。言葉（ことば）だけを武器（ぶき）に、彼（かれ）と向（む）き合（あ）う覚悟（かくご）はある？",
        choices: [
          "Ready is an adjective describing preparation.",
          "I am. Words carried me this far — they won't fail me at the end.",
          "No, I think I should bring a sword just in case.",
          "Yes, because the door is made of heavy old wood.",
        ],
        correctIndex: 1,
        onCorrect:
            "Then I'll sing your story whatever happens. Go, hero of words. I'll be right behind you.",
      ),
      QuestEncounter(
        npcName: "クワイエト",
        npcEmoji: "🌫️",
        npcLine:
            "So you came. I've guarded this door for my lord... yet your words in the harbour have haunted me ever since. Tell me honestly — can words really heal what silence has broken?",
        npcLineJa:
            "やはり来（き）たか。私（わたし）はこの扉（とびら）を主（あるじ）のために守（まも）ってきた…だが、あの港町（みなとまち）での君（きみ）の言葉（ことば）が、ずっと胸（むね）を離（はな）れない。正直（しょうじき）に答（こた）えてくれ――言葉（ことば）は、しずけさが壊（こわ）したものを、本当（ほんとう）に癒（いや）せるのか？",
        choices: [
          "Heal is what a doctor does to a sick patient.",
          "No, some things stay broken no matter what you say.",
          "They can — because words let us forgive, and even an enemy can be heard and changed.",
          "Of course, because I am stronger than you are.",
        ],
        correctIndex: 2,
        onCorrect:
            "...Then I was wrong to serve silence. Step aside — no, let me open this door for you myself. Save him, hero. Save us both.",
      ),
      QuestEncounter(
        npcName: "サイレント",
        npcEmoji: "🖤",
        npcLine:
            "(The mouthless king rises. A voice forms in your mind, not the air.) Words bring lies, wars, and grief. I devoured them so the world could finally rest. Tell me — why should the silence I built be undone?",
        npcLineJa:
            "（口（くち）のない王（おう）が立（た）ち上（あ）がる。声（こえ）は空気（くうき）ではなく、心（こころ）に直接（ちょくせつ）ひびく。）ことばは嘘（うそ）と戦（たたか）いと悲（かな）しみを生（う）む。だから私（わたし）はそれを食（た）べ、世界（せかい）を休（やす）ませた。問（と）おう――私（わたし）の築（きず）いたしずけさを、なぜ壊（こわ）すのか？",
        choices: [
          "Because I need the last Stone of Voice to win the game.",
          "Silence is defined as the complete absence of sound.",
          "You are simply an evil monster and you must be defeated.",
          "Because the same words that wound can also comfort, forgive, and say 'I'm sorry' — silence only buries the pain, it never heals it.",
        ],
        correctIndex: 3,
        onCorrect:
            "(A crack of light splits the grey. A mouth — long forgotten — forms upon his face.) ...You... gave me back... my words. I only ever wanted the hurting to stop. Thank you, child. (Color floods back into the world. The ことばの紋章 blazes, and silence ends — not in defeat, but in being finally, truly heard.)",
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

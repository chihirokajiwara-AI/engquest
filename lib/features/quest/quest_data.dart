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

  const QuestTown({
    required this.id,
    required this.eikenLevel,
    required this.cefr,
    required this.name,
    required this.tagline,
    required this.intro,
    required this.encounters,
  });
}

/// The hero's opening — revealed once, at the very start of the quest.
const String kQuestPrologue =
    'あなたは、じつは王子（おうじ）／王女（おうじょ）です。\n'
    'ことばの力をとりもどす旅（たび）に出ました。\n'
    'いろいろな街（まち）で人に出会い、こまったことを乗りこえながら、'
    '英語（えいご）と心を成長させていきましょう。';

/// Towns in order, easiest → hardest. A player enters at the town matching
/// their placement level; clearing a town unlocks the next.
const List<QuestTown> kQuestTowns = [
  QuestTown(
    id: 'town_eiken5',
    eikenLevel: '5',
    cefr: 'A1',
    name: 'はじまりの村',
    tagline: 'やさしいあいさつの村',
    intro: '旅のはじまりの村。村人たちは、かんたんな英語であいさつしてくれます。'
        '正しいことばで答えて、村のみんなと仲よくなりましょう。',
    encounters: [
      QuestEncounter(
        npcName: 'むらびと',
        npcEmoji: '🧑‍🌾',
        npcLine: 'Hello! How are you?',
        npcLineJa: 'こんにちは！ 元気ですか？',
        choices: ["I'm fine, thank you.", 'Goodbye.', 'It is a cat.', 'No, thank you.'],
        correctIndex: 0,
        onCorrect: "Great! Have a nice day!",
      ),
      QuestEncounter(
        npcName: 'おんなのこ',
        npcEmoji: '👧',
        npcLine: "Hi! What's your name?",
        npcLineJa: 'こんにちは！ お名前は？',
        choices: ['My name is Alex.', 'I am fine.', 'It is Monday.', 'You are welcome.'],
        correctIndex: 0,
        onCorrect: 'Nice to meet you, Alex!',
      ),
      QuestEncounter(
        npcName: 'おじいさん',
        npcEmoji: '👴',
        npcLine: 'Where are you from?',
        npcLineJa: 'どこから来たのですか？',
        choices: ["I'm from Japan.", "I'm eleven.", 'It is a dog.', 'Good night.'],
        correctIndex: 0,
        onCorrect: 'Japan! That is far away. Welcome!',
      ),
      QuestEncounter(
        npcName: 'おみせのひと',
        npcEmoji: '🧺',
        npcLine: 'This is a red apple. Do you want it?',
        npcLineJa: 'これは赤いりんごです。ほしいですか？',
        choices: ['Yes, please.', 'I am sorry.', 'See you later.', 'It is raining.'],
        correctIndex: 0,
        onCorrect: 'Here you are! Take care on your journey.',
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
    intro: '少し大きな街。人々は毎日のくらしについて、英語で話しかけてきます。',
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
    intro: '学校や旅の話題が飛びかう、にぎやかな都。',
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
    intro: '世の中の話題を、英語で語り合う港町。',
    encounters: [
      QuestEncounter(
        npcName: "せんせい",
        npcEmoji: "👩‍🏫",
        npcLine: "I think reading books every day is really important. Do you agree?",
        npcLineJa: "毎日本を読むことはとても大切だと思います。あなたはどう思いますか？",
        choices: ["Yes, I agree. Reading helps us learn a lot.", "No, I don't like teachers.", "Books are very heavy to carry.", "I already had breakfast, thanks."],
        correctIndex: 0,
        onCorrect: "Exactly! Reading every day will make you much wiser. Keep it up!",
      ),
      QuestEncounter(
        npcName: "りょうし",
        npcEmoji: "🎣",
        npcLine: "I've been fishing here for twenty years. Have you ever tried fishing before?",
        npcLineJa: "ここで20年間釣りをしています。釣りをしたことがありますか？",
        choices: ["The sea is very blue today.", "Yes, I have. I caught a big fish once!", "No, I don't want any fish.", "Twenty is a big number."],
        correctIndex: 1,
        onCorrect: "Wonderful! Fishing teaches you patience. Come back and we'll fish together sometime!",
      ),
      QuestEncounter(
        npcName: "しょうにん",
        npcEmoji: "🛍️",
        npcLine: "These spices came all the way from a faraway land. Would you like to smell them?",
        npcLineJa: "このスパイスは遠い国からやってきました。においを嗅いでみますか？",
        choices: ["I don't have enough money today.", "Sure, I'd love to! What do they smell like?", "Spices are used in cooking.", "No, I came here by ship."],
        correctIndex: 1,
        onCorrect: "They smell like cinnamon and adventure! You have a curious spirit — I like that!",
      ),
      QuestEncounter(
        npcName: "かいぞく",
        npcEmoji: "🏴‍☠️",
        npcLine: "I used to be a sailor, but I gave it up to live here peacefully. What do you think is more important — adventure or peace?",
        npcLineJa: "昔は船乗りでしたが、ここで平和に暮らすために辞めました。冒険と平和、どちらが大切だと思いますか？",
        choices: ["I prefer peace, but a little adventure makes life exciting.", "Ships are very big and expensive.", "I am looking for the harbor master.", "Peace is a country far away."],
        correctIndex: 0,
        onCorrect: "Ha! A wise answer! Maybe someday you'll find the perfect balance between the two.",
      ),
      QuestEncounter(
        npcName: "おかあさん",
        npcEmoji: "👩",
        npcLine: "My children don't talk to me much anymore. How do you stay close to your family?",
        npcLineJa: "子どもたちがあまり話しかけてくれなくなりました。家族と仲良くするにはどうしていますか？",
        choices: ["Families are usually quite large.", "I don't have any brothers or sisters.", "I try to eat dinner together and share my day with them.", "You should move to a bigger house."],
        correctIndex: 2,
        onCorrect: "That's lovely advice. Sharing meals and stories really does bring families together. Thank you!",
      ),
    ],
  ),
  QuestTown(
    id: 'town_pre2plus',
    eikenLevel: 'pre2plus',
    cefr: 'A2-B1',
    name: '試練（しれん）の橋（はし）',
    tagline: '2級への橋をわたる町',
    intro: '準2級の先、2級へとつづく長い橋。ここでは「理由」や「もしも」を英語で語る力がためされる。'
        '英検が2025年に新設した、準2級と2級のあいだの橋わたりの級です。',
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
    intro: '学問やビジネスの言葉が交わされる、城下の町。',
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
    intro: 'すべての旅の果て、王の待つ大いなる都。',
    encounters: [
      QuestEncounter(
        npcName: "がくしゃ",
        npcEmoji: "🧙‍♂️",
        npcLine: "Do you think technology has made people more connected, or more isolated?",
        npcLineJa: "技術は人々をつなげたと思いますか、それとも孤立させたと思いますか？",
        choices: ["It's a double-edged sword — it connects us globally but can isolate us locally.", "Yes, I think technology is very expensive.", "No, I don't have a smartphone.", "Connected means you use the internet every day."],
        correctIndex: 0,
        onCorrect: "Beautifully put! That nuance is exactly what makes this debate so fascinating.",
      ),
      QuestEncounter(
        npcName: "きぞく",
        npcEmoji: "👸",
        npcLine: "The kingdom's new policy is controversial. What's your take on it?",
        npcLineJa: "王国の新しい政策は議論を呼んでいます。あなたはどう思いますか？",
        choices: ["I haven't formed a firm opinion yet — I'd like to hear both sides first.", "I think policies are made by the king.", "Controversial is a very difficult word to spell.", "Yes, the weather has been quite unpredictable lately."],
        correctIndex: 0,
        onCorrect: "A measured response — wise counsel is always welcome in this court!",
      ),
      QuestEncounter(
        npcName: "しょうにん",
        npcEmoji: "🧳",
        npcLine: "Trade between nations fosters peace, but it also creates dependency. Wouldn't you agree?",
        npcLineJa: "国家間の貿易は平和を促進しますが、依存関係も生み出します。そう思いませんか？",
        choices: ["Merchants travel very long distances to sell goods.", "I agree — interdependence can be both a bridge and a vulnerability.", "Trade means buying and selling things in a market.", "I don't think nations should talk to each other."],
        correctIndex: 1,
        onCorrect: "Precisely! You grasp the paradox perfectly — that thinking will serve you well as a leader.",
      ),
      QuestEncounter(
        npcName: "へいし",
        npcEmoji: "⚔️",
        npcLine: "Courage isn't the absence of fear — it's acting despite it. Have you ever felt that way?",
        npcLineJa: "勇気とは恐れがないことではなく、恐れながらも行動することです。そう感じたことはありますか？",
        choices: ["Fear is a very strong emotion that many people experience.", "I think soldiers should always be brave and never feel afraid.", "Absolutely — every time I've faced something daunting, pushing through changed me.", "Absence means something is not there or missing."],
        correctIndex: 2,
        onCorrect: "That's the spirit of a true hero — growth through adversity. The kingdom needs people like you.",
      ),
      QuestEncounter(
        npcName: "しじん",
        npcEmoji: "📜",
        npcLine: "Literature preserves a culture's soul long after its buildings crumble. Do you believe that?",
        npcLineJa: "文学は建物が崩れた後も、文化の魂を長く保ちます。そう信じますか？",
        choices: ["Buildings are usually made of stone and can last for hundreds of years.", "I prefer reading adventure stories rather than poetry.", "Wholeheartedly — words outlive empires, carrying wisdom across generations.", "Literature is a subject studied in schools around the world."],
        correctIndex: 2,
        onCorrect: "Spoken like a true patron of the arts! Your words could inspire a great poem themselves.",
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

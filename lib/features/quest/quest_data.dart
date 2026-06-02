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
    encounters: [],
  ),
  QuestTown(
    id: 'town_eiken3',
    eikenLevel: '3',
    cefr: 'A2-B1',
    name: '学（まな）びの都（みやこ）',
    tagline: '学校と旅の都',
    intro: '学校や旅の話題が飛びかう、にぎやかな都。',
    encounters: [],
  ),
  QuestTown(
    id: 'town_pre2',
    eikenLevel: 'pre2',
    cefr: 'B1',
    name: '社会（しゃかい）の港町（みなとまち）',
    tagline: '世の中を語る港町',
    intro: '世の中の話題を、英語で語り合う港町。',
    encounters: [],
  ),
  QuestTown(
    id: 'town_eiken2',
    eikenLevel: '2',
    cefr: 'B1-B2',
    name: '学者（がくしゃ）の城下町（じょうかまち）',
    tagline: '学問とビジネスの町',
    intro: '学問やビジネスの言葉が交わされる、城下の町。',
    encounters: [],
  ),
  QuestTown(
    id: 'town_pre1',
    eikenLevel: 'pre1',
    cefr: 'B2-C1',
    name: '王都（おうと）',
    tagline: '王の待つ都',
    intro: 'すべての旅の果て、王の待つ大いなる都。',
    encounters: [],
  ),
];

/// Map a placement level to the index of the town a student starts in.
/// A 準2級 holder begins in the 準2級 town, etc.
int startingTownIndex(String eikenLevel) {
  final i = kQuestTowns.indexWhere((t) => t.eikenLevel == eikenLevel);
  return i < 0 ? 0 : i;
}

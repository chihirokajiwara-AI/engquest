// lib/features/explore/hotspot.dart
// Wave 1 — コトバ探偵 scene model.
//
// Pure-Dart models; NO dart:io, NO Firebase. Every class is const-constructible
// so SceneDef literals live entirely in this file's initialiser.

import 'package:flutter/material.dart';
import '../../core/gamification/hint_coin_service.dart';
import '../quest/quest_data.dart';

// ── Hotspot kind ──────────────────────────────────────────────────────────────

/// What kind of tap-target a Hotspot represents.
enum HotspotKind {
  /// A villager NPC that throws a ナゾ (英検 quiz item).
  npc,

  /// A hidden ひらめきコイン in the scenery.
  coin,

  /// An OBSERVATION point (#90 world-depth, Layton "tap everything → something
  /// happens"): a non-puzzle spot in the scenery that, on tap, reveals a 探偵メモ
  /// line — flavour, a clue, or サイレント micro-lore. Re-tappable; rewards the
  /// curiosity-driven searching that makes a scene feel dense, not a 3-NPC skin.
  observation,
}

// ── TeachCard — the "teach BEFORE you ask" card ────────────────────────────────
//
// CEO 2026-06-09 (致命的欠陥): a true beginner was dropped straight into an
// English multiple-choice ナゾ with NO teaching first ("何も学んでないのに、いきなり
// これが出てきて、誰が答えられるのだ？"). The design assumed the player already
// reads English. For an 英検-passing app that is fatal: the structure must
// TEACH the words, then ASK. A [Hotspot.npc] whose ナゾ is a bare quiz now
// carries a [TeachCard] that NazoScreen shows FIRST — the child reads the
// meanings, taps 「わかった！」, and only THEN sees the quiz. Pure presentation
// model (no audio dependency → works in the offline demo).

/// One taught item: an English form + its Japanese meaning + when it is used.
class TeachItem {
  /// The English word/phrase exactly as it appears in the quiz (e.g. 'Hello!').
  final String en;

  /// The Japanese meaning in ひらがな (e.g. 'こんにちは').
  final String ja;

  /// Optional "when do I use this?" note in ひらがな (e.g. 'であった ときの あいさつ').
  final String? whenJa;

  const TeachItem(this.en, this.ja, [this.whenJa]);
}

/// A short lesson shown BEFORE the ナゾ quiz, so the question is never a surprise.
class TeachCard {
  /// Card title (e.g. 'まず、4つの あいさつを おぼえよう').
  final String titleJa;

  /// Optional intro line under the title.
  final String? leadJa;

  /// The 2–4 items the child must learn before the quiz is fair.
  final List<TeachItem> items;

  const TeachCard({required this.titleJa, this.leadJa, required this.items});
}

// ── Hotspot ───────────────────────────────────────────────────────────────────

/// A single tappable element positioned in the scene.
///
/// [pos] is an [Alignment] relative to the scene container, so (0,0) is the
/// centre, (-1,-1) is top-left, (1,1) is bottom-right.
/// [size] is the tap-target diameter as a fraction of the shortest edge of the
/// scene container (0.0..1.0 — keep hotspots ≥ 0.10 for child fingers).
///
/// For [HotspotKind.npc]: supply [step] (the 英検 QuestStep used as the ナゾ),
/// [clueLineJa] (the voiced JP hint the NPC mutters before the 「？」bubble),
/// [framingJa] (optional in-world framing shown above the stem in NazoScreen),
/// [npcGreyAsset] / [npcColorAsset] (the grey→color restoration pair).
///
/// For [HotspotKind.coin]: supply [coinValue] (usually 1) and optionally
/// [clueLineJa] for タロ the companion's word-clue toward this coin.
class Hotspot {
  final Alignment pos;
  final double size;
  final HotspotKind kind;

  // NPC fields
  final QuestStep? step;
  final String? clueLineJa;
  final String? framingJa;
  final String? npcGreyAsset;
  final String? npcColorAsset;

  /// Optional lesson shown BEFORE the ナゾ quiz (CEO 2026-06-09 teach-first fix).
  /// Set it on hotspots whose [step] is a bare [QuestEncounter] quiz — the child
  /// is taught the words first, then asked. Null = the step already teaches
  /// (TeachSound/BlendWord/Phrase carry their own teachJa) → no card needed.
  final TeachCard? teachCard;

  /// Optional per-hotspot authored hint ladder (H1 model).
  ///
  /// When non-null and non-empty, [NazoScreen._hintLadder] uses these hints
  /// (sorted by [NazoHint.tier]) instead of [defaultHintsForLevel]. When null,
  /// the generic fallback is used — so all existing hotspots (null) behave
  /// identically to before.
  ///
  /// All authored hints MUST pass [hintViolatesAnswerRail] == false before
  /// commit; the rail function guards against any hint that names the answer
  /// or eliminates a distractor by text.
  final List<NazoHint>? hints;

  /// One fragment of サイレント lore, dripped when THIS ナゾ is solved
  /// (COMPOSITION-ARCHITECTURE.md §3: "every ナゾ solve drops one fragment of
  /// サイレント lore"). Transcribed/adapted from STORY-BIBLE-KOTOBA-TANTEI.json
  /// canon so the 7-case detective arc stays FELT, not a bare quiz wrapper. Null
  /// → no beat (prior behaviour). Shown as a brief diegetic 探偵メモ banner,
  /// EXCEPT on the scene-clearing solve where the colour-flood payoff (which
  /// carries [SceneDef.cleared]'s finale text) subsumes it.
  final String? mysteryFragmentJa;

  // Coin fields
  final int coinValue;

  const Hotspot.npc({
    required this.pos,
    this.size = 0.18,
    required QuestStep this.step,
    this.clueLineJa,
    this.framingJa,
    this.npcGreyAsset,
    this.npcColorAsset,
    this.teachCard,
    this.hints,
    this.mysteryFragmentJa,
    this.coinValue = 0,
  }) : kind = HotspotKind.npc;

  const Hotspot.coin({
    required this.pos,
    this.size = 0.12,
    this.coinValue = 1,
    this.clueLineJa,
    this.step,
    this.framingJa,
    this.npcGreyAsset,
    this.npcColorAsset,
  })  : teachCard = null,
        hints = null,
        mysteryFragmentJa = null,
        kind = HotspotKind.coin;

  /// An observation point (#90): tap reveals [clueLineJa] as a 探偵メモ beat, no
  /// puzzle. Small + subtle (Layton-style); re-tappable. Reuses [clueLineJa] for
  /// the line so no model field is added.
  const Hotspot.observation({
    required this.pos,
    this.size = 0.09,
    required this.clueLineJa,
  })  : step = null,
        framingJa = null,
        npcGreyAsset = null,
        npcColorAsset = null,
        teachCard = null,
        hints = null,
        mysteryFragmentJa = null,
        coinValue = 0,
        kind = HotspotKind.observation;
}

// ── SceneDef ──────────────────────────────────────────────────────────────────

/// Full definition of an explorable painted scene.
///
/// [backgroundAsset] — the main scene plate (1536×640, Layton-style). Must be
/// declared in pubspec.yaml under assets/art/scenes_layton/.
/// [parallaxLayers] — 2–3 layer asset paths (far → near) for the parallax Stack.
///   May be empty; SceneView falls back to [backgroundAsset] as a single layer.
/// [hotspots] — all tap-targets for this scene.
/// [titleJa] — displayed in the scene header bar (JP town name).
/// [cleared] — story payoff shown when the last ナゾ is solved (sourced from the
///   matching [QuestTown.cleared] in kQuestTowns). Null → generic fallback text.
/// [companionArrivalJa] — optional short タロ line (1–2 sentences) shown as a
///   brief dismissible banner when the player ENTERS this scene.  Null → no banner.
///   Purpose: gives each case a small in-media-res hook and makes タロ a recurring
///   companion rather than a passive hotspot.  Canon-consistent; no アイラ name.
class SceneDef {
  final String backgroundAsset;
  final List<String> parallaxLayers;
  final List<Hotspot> hotspots;
  final String titleJa;
  final String? cleared;

  /// Optional タロ arrival line — shown once on scene entry, skippable via tap
  /// or auto-dismissed after a short delay.  Null → no arrival banner.
  final String? companionArrivalJa;

  const SceneDef({
    required this.backgroundAsset,
    this.parallaxLayers = const [],
    required this.hotspots,
    required this.titleJa,
    this.cleared,
    this.companionArrivalJa,
  });
}

// ── 英検5級 scene — ことばを失った村 ─────────────────────────────────────────────

/// Wave 1 vertical-slice scene: ONE town, 3 NPC hotspots (referencing real
/// QuestEncounter/teach steps from kQuestTowns[0]) + 1 hidden coin.
///
/// NPC ナゾ steps are REFERENCED from kQuestTowns[0].encounters — the content
/// (choices / correctIndex) is byte-identical. framingJa adds in-world flavour
/// above the stem without changing the exam item.
///
/// Background + NPC art is generated separately via scripts/safe-job.sh.
/// Image.asset in SceneView uses errorBuilder → dq night-gradient fallback
/// so the scene renders gracefully before art exists.
/// Teach-first lesson for タロ's greeting ナゾ (_kStep(12), choices Goodbye /
/// Hello! / Thank you / I am sorry). A true beginner can't pick こんにちは out of
/// four untaught English phrases — so we teach all four meanings first.
const TeachCard kGreetingTeach = TeachCard(
  titleJa: 'まず、4つの あいさつを おぼえよう',
  leadJa: 'タロに ことばを かえす まえに、いみを たしかめよう。',
  items: [
    TeachItem('Hello!', 'こんにちは', 'ひとに であった ときの あいさつ'),
    TeachItem('Goodbye.', 'さようなら', 'わかれる ときの あいさつ'),
    TeachItem('Thank you.', 'ありがとう', 'おれいを いう ことば'),
    TeachItem('I am sorry.', 'ごめんなさい', 'あやまる ときの ことば'),
  ],
);

// ── 英検4級 teach-cards ───────────────────────────────────────────────────────

/// Teach-first lesson for タロ's irregular-past ナゾ (_kStep4(2),
/// 「Where did you go?」 → 「I ___ to the zoo.」, choices goed / go / went /
/// am go). Teaches the concept that some verbs change shape completely in the
/// past — WITHOUT naming "went" as the answer. The child learns the rule
/// (go は きのうになると ちがうかたち), sees worked examples with OTHER verbs,
/// and can then reason to the right choice.
const TeachCard kIrregularPastTeach = TeachCard(
  titleJa: 'きのうの ことを いう とき — むかしのかたち（かこけい）',
  leadJa: 'えいごの どうしは「きのう〜した」と いうとき、かたちが かわる。'
      'なかには ぜんぜん ちがう かたちに なる ことばも あるよ！',
  items: [
    TeachItem(
      'play → played',
      'あそぶ → あそんだ',
      'おわりに「-ed」を つける ふつうの かたち',
    ),
    TeachItem(
      'eat → ate',
      'たべる → たべた',
      'かたちが がらっと かわる ことばの れいその１',
    ),
    TeachItem(
      'see → saw',
      'みる → みた',
      'かたちが がらっと かわる ことばの れいその２',
    ),
    TeachItem(
      'come → came',
      'くる → きた',
      'かたちが がらっと かわる ことばの れいその３',
    ),
  ],
);

/// Teach-first lesson for the 灯台守's future-will ナゾ (_kStep4(4),
/// 「I think it ___ rain soon.」, choices rained / will / is / rains).
/// Teaches that "will + どうしのもとのかたち" = これから おきること, WITHOUT
/// naming "will" as the answer to the specific slot. The child learns the
/// pattern, sees examples, and reasons which word fits a blank meaning "soon".
const TeachCard kFutureWillTeach = TeachCard(
  titleJa: 'これから おきる こと — will（ウィル）を つかおう',
  leadJa: '「これから〜する」「きっと〜になる」というとき、えいごでは will を つかうよ。\n'
      '「will」の あとは、どうしの もとのかたち（げんけい）。',
  items: [
    TeachItem(
      'It will snow.',
      'ゆきが ふるでしょう',
      'これからのことを いうとき',
    ),
    TeachItem(
      'I will help you.',
      'てつだいます',
      '「will」のあとは もとのかたち（snow, help, eat…）',
    ),
    TeachItem(
      'She will be here soon.',
      'かのじょは もうすぐ くる',
      'じんぶつにも つかえる',
    ),
  ],
);

/// Teach-first lesson for the りょうし's to-infinitive ナゾ (_kStep4(9),
/// 「Did you come here ___ fish?」, choices catch / to catch / catching /
/// caught). Teaches that "to + どうし" answers "なんのために？（もくてき）",
/// WITHOUT naming the phrase "to catch". Examples use other verbs so the
/// child learns the rule and can apply it.
const TeachCard kToInfinitiveTeach = TeachCard(
  titleJa: '「なんのために？」を いう — to＋どうし',
  leadJa: '「〜するために」「〜しに」というとき、えいごでは「to ＋ どうしの もとのかたち」を つかう。\n'
      'もくてき（目的）を あらわす つかいかた だよ。',
  items: [
    TeachItem(
      'I came here to learn.',
      'まなぶために ここへ きた',
      'to のあとは もとのかたち（learn, play, buy…）',
    ),
    TeachItem(
      'She went to the shop to buy bread.',
      'パンを かいに みせへ いった',
      'なぜ いったか ＝ to ＋ どうし',
    ),
    TeachItem(
      'He runs every day to stay healthy.',
      'けんこうで いるために まいにち はしる',
      'もくてきが あとに つく',
    ),
  ],
);

// ── 英検3級 teach-cards ───────────────────────────────────────────────────────

/// Teach-first lesson for としょかんいん's 現在完了 for/since ナゾ (_kStep3(3),
/// 「I have worked in this library ___ ten years.」, choices since/from/for/during).
/// Teaches the for vs since distinction (span vs point-in-time) WITHOUT
/// naming "for" as the answer. Example durations use "school", "town", "music"
/// — none of the stem's words (library, years, worked).
const TeachCard kPresentPerfectForSinceTeach = TeachCard(
  titleJa: '「ずっと〜してきた」― for と since のちがい',
  leadJa: '現在完了（げんざいかんりょう）で「いままで どのくらい つづいているか」を いうとき、\n'
      '「どのくらいの時間（じかん）か」なら for、「いつから か」なら since を つかうよ。',
  items: [
    TeachItem(
      'for + 時間（じかん）の長（なが）さ',
      'どのくらい → 期間（きかん）の長さ',
      'for three days・for two months・for a long time',
    ),
    TeachItem(
      'since + 時点（じてん）',
      'いつから → 起点（きてん）',
      'since Monday・since 2020・since I was a child',
    ),
    TeachItem(
      'I have studied music for six months.',
      'わたしは 六（む）ヶ月（かげつ） 音楽（おんがく）を 勉強（べんきょう）してきた',
      '「六ヶ月という長さ」だから for',
    ),
    TeachItem(
      'She has lived in that town since spring.',
      'かのじょは はるから あの まちに すんでいる',
      '「はるという時点」だから since',
    ),
  ],
);

/// Teach-first lesson for がくせい's 現在完了 yet ナゾ (_kStep3(4),
/// 「I haven't finished it ___.」, choices already/yet/ever/soon).
/// Teaches that yet lives in negatives/questions and already lives in
/// positive statements, WITHOUT naming "yet" as the quiz answer.
/// Examples use "homework", "dinner", "film" — no overlap with
/// the stem words (return, book, finished).
const TeachCard kPerfectYetAlreadyTeach = TeachCard(
  titleJa: '「まだ〜していない」「もう〜した」― yet と already',
  leadJa: 'already は「もう〜した」というとき（ふつう文）に つかい、\n'
      'yet は「まだ〜していない」や「もう〜した？」に つかうよ。',
  items: [
    TeachItem(
      'already（ふつう文・肯定文（こうていぶん））',
      'もう〜した',
      'I have already done my homework. ／ もう しゅくだいを やった。',
    ),
    TeachItem(
      'yet（否定文（ひていぶん）・疑問文（ぎもんぶん））',
      'まだ〜していない ／ もう〜した？',
      'I haven\'t eaten dinner yet. ／ まだ ゆうしょくを たべていない。',
    ),
    TeachItem(
      'Have you seen that film yet?',
      'もう あの えいがを みた？',
      'ぎもんぶんでも yet を つかう',
    ),
  ],
);

/// Teach-first lesson for タロ's past-tense reunion ナゾ (_kStep3(0),
/// 「Where did you sleep last night?」, choices including "I slept…").
/// Teaches that "last night / yesterday" is the cue to use the simple past,
/// NOT the present perfect or present tense. Uses verbs eat/walk/read
/// — none of the stem's key words (sleep, city, practiced, night).
const TeachCard kSimplePastCuedTeach = TeachCard(
  titleJa: '「きのう〜した」― last night は かこけい（過去形）の サイン',
  leadJa: '「last night（ゆうべ）」「yesterday（きのう）」「ago（まえ）」が あったら、\n'
      'かこけい（simple past）を つかうよ。'
      '現在完了（げんざいかんりょう）は つかわない！',
  items: [
    TeachItem(
      'last night → simple past',
      'ゆうべ → かこけい',
      'I ate pizza last night. ／ ゆうべ ピザを たべた。',
    ),
    TeachItem(
      'yesterday → simple past',
      'きのう → かこけい',
      'He walked to school yesterday. ／ かれは きのう がっこうへ あるいた。',
    ),
    TeachItem(
      'I read that book last week.',
      'わたしは せんしゅう あの ほんを よんだ',
      '「last week（せんしゅう）」も かこけいの サイン',
    ),
  ],
);

// ── 英検準2級 teach-cards ─────────────────────────────────────────────────────

/// Teach-first lesson for しょうにん's passive-voice ナゾ (_kStepPre2(2),
/// 「Do you know where they are grown?」, answer "They are grown on islands…").
/// Teaches that be＋過去分詞 = 受動態（〜される/〜されている）, WITHOUT using
/// "grow/grown" as an example — uses "make/build/teach" instead.
const TeachCard kPassiveVoiceTeach = TeachCard(
  titleJa: '「〜される」「〜されている」― 受動態（じゅどうたい）',
  leadJa: '「だれかに よって〜される」というとき、えいごでは\n'
      '「be どうし ＋ 過去分詞（かこぶんし）」の かたちを つかうよ。',
  items: [
    TeachItem(
      'be どうし ＋ 過去分詞',
      '〜される・〜されている',
      '能動（のうどう）: They make cars here. → 受動（じゅどう）: Cars are made here.',
    ),
    TeachItem(
      'The bridge was built fifty years ago.',
      'その はしは 五十年（ごじゅうねん）まえに つくられた',
      'was built = be のかこけい ＋ build の かこぶんし',
    ),
    TeachItem(
      'English is taught in many schools.',
      'えいごは たくさんの がっこうで おしえられている',
      'is taught = be の現在形（げんざいけい） ＋ teach の かこぶんし',
    ),
  ],
);

/// Teach-first lesson for せんちょう's relative-pronoun-who ナゾ (_kStepPre2(3),
/// answer "A sailor who never gives up in a storm.").
/// Teaches that who connects a clause to a PERSON noun, and the rule for
/// who vs which vs where, WITHOUT using "give up / storm / sailor" as examples.
const TeachCard kRelativePronounWhoTeach = TeachCard(
  titleJa: '「〜な 人（ひと）」をつなぐ ― 関係代名詞（かんけいだいめいし）who',
  leadJa: '「〜する 人（ひと）」「〜した 人（ひと）」のように、「人（ひと）」を くわしく するとき\n'
      '「who（フー）」を つかうよ。もの・ことには which を つかう。',
  items: [
    TeachItem(
      'who → 人（ひと）を さす',
      'a teacher who ／ a friend who',
      'a teacher who speaks kindly ／ やさしく はなす せんせい',
    ),
    TeachItem(
      'which → もの・こと を さす',
      'a book which ／ a song which',
      'a book which changed my life ／ わたしの じんせいを かえた ほん',
    ),
    TeachItem(
      'She is a doctor who helps children every day.',
      'かのじょは まいにち こどもを たすける いしゃです',
      'who の あとに 動詞（どうし）が くる（主格（しゅかく））',
    ),
  ],
);

/// Teach-first lesson for とうだいもり's relative-adverb-where ナゾ (_kStepPre2(4),
/// answer "the harbour where the storms cannot reach them").
/// Teaches the where/which distinction: where REPLACES "in/at which" for
/// places. Example place: café, market. NO use of "harbour/storm/ship/reach".
const TeachCard kRelativeAdverbWhereTeach = TeachCard(
  titleJa: '「〜する 場所（ばしょ）」をつなぐ ― 関係副詞（かんけいふくし）where',
  leadJa: '「〜する 場所（ばしょ）」と いいたいとき、場所（ばしょ）の 名詞（めいし）の あとに\n'
      '「where（フェア）」を つかうよ。「in which」の かわりになる かたちだよ。',
  items: [
    TeachItem(
      'where → ばしょの 名詞（めいし）に つく',
      'the town where ／ the park where',
      'the town where I was born ／ わたしが うまれた まち',
    ),
    TeachItem(
      'This is the café where we always meet.',
      'ここが わたしたちが いつも あう カフェです',
      'café（場所）＋ where … always meet',
    ),
    TeachItem(
      'She found a market where fresh fruit is sold every morning.',
      'かのじょは まいあさ しんせんな くだものが うられる いちばを みつけた',
      'where の あとは かんぜんな 文（ぶん）',
    ),
  ],
);

// ── 英検準2級プラス teach-cards ──────────────────────────────────────────────

/// Teach-first lesson for はしの番人's present-perfect-have-worked ナゾ
/// (_kStepPre2Plus(0), 「I ___ on this bridge since 2025.」,
/// choices work/have worked/worked/am working).
/// Teaches that since ＋ point-in-time triggers the present perfect
/// (have/has ＋ p.p.), not simple past. Examples use "live/study/serve"
/// — NO use of "bridge/work/2025".
const TeachCard kPresentPerfectSinceTeach = TeachCard(
  titleJa: '「since（〜から ずっと）」= 現在完了（げんざいかんりょう）のサイン',
  leadJa: '「since ＋ 時点（じてん）」の ある 文（ぶん）では、「have ／ has ＋ 過去分詞（かこぶんし）」\n'
      'を つかうよ。ふつうの かこけい（worked, lived）は まちがい！',
  items: [
    TeachItem(
      'have / has ＋ p.p. ＋ since',
      '〜から ずっと〜している',
      'She has lived here since last spring. ／ かのじょは きょねんの はるから ここに すんでいる。',
    ),
    TeachItem(
      'I have studied French since I was twelve.',
      'わたしは じゅうにさいの ときから フランスごを べんきょうしてきた',
      'since ＋ 過去の時点 → 現在完了',
    ),
    TeachItem(
      'He has served on the council since the new rules were set.',
      'かれは あたらしい きまりが できてから ずっと ぎかいに つとめている',
      'was/were は かこけい。has ＋ p.p. が 現在完了',
    ),
  ],
);

/// Teach-first lesson for 渡し守's relative-adverb-where ナゾ
/// (_kStepPre2Plus(1), 「This is the place ___ many travellers turn back.」,
/// choices which/who/where/what).
/// Revisits where vs which at B1 level — emphasises that which needs an
/// antecedent WITHIN the clause while where stands in for "at/in which" for
/// place nouns. Examples: school, valley. NO use of "place/traveller/turn/back".
const TeachCard kRelativeWhereVsWhichTeach = TeachCard(
  titleJa: '「場所（ばしょ）の 名詞（めいし）＋ where」― which との ちがいを おさえよう',
  leadJa: '関係副詞（かんけいふくし）where と 関係代名詞（かんけいだいめいし）which は、\n'
      'どちらも「それが さっき 言（い）った ___」と つなぐけど、つかいかたが ちがう。',
  items: [
    TeachItem(
      'place-noun ＋ where ＋ 完全（かんぜん）な 文',
      '場所の名詞に つくとき',
      'the school where she teaches every morning ／ かのじょが まいあさ おしえる がっこう',
    ),
    TeachItem(
      'thing-noun ＋ which ＋ 不完全（ふかんぜん）な 文',
      'ものの名詞に つくとき',
      'the letter which arrived yesterday ／ きのう とどいた てがみ',
    ),
    TeachItem(
      'This is the valley where the old stories were first told.',
      'ここが むかしばなしが はじめて かたられた たにだ',
      'valley（場所）＋ where … first told',
    ),
  ],
);

// ── 英検2級 teach-cards ───────────────────────────────────────────────────────

/// Teach-first lesson for せんせい's academic-empathy response ナゾ (_kStep2(0),
/// 「I've been teaching here for ten years, though the number of students keeps
/// declining.」, correct: "That must be quite challenging for you.").
/// Teaches the register of acknowledging someone's difficulty with empathic
/// language. Examples use "long commute" and "heavy workload"
/// — NO use of "teach / students / declining / ten / years".
const TeachCard kEmpathyResponseTeach = TeachCard(
  titleJa: '相手（あいて）の 苦労（くろう）に 共感（きょうかん）する ― 英語（えいご）の ていねいな こたえ方（かた）',
  leadJa: '英語（えいご）で 大人（おとな）どうし 話（はな）すとき、「それは たいへんですね」と\n'
      '共感（きょうかん）するには、ていねいな かたちを つかうよ。',
  items: [
    TeachItem(
      'That must be really exhausting for you.',
      'それは ほんとうに くたびれますね',
      '「must be ＋ 形容詞（けいようし）」= きっと〜にちがいない。共感（きょうかん）のていねいな いいかた',
    ),
    TeachItem(
      'That sounds really difficult.',
      'それは ほんとうに むずかしそうですね',
      '「sounds ＋ 形容詞（けいようし）」で やわらかく 共感（きょうかん）',
    ),
    TeachItem(
      'A: I have a really long commute every day. — B: That must be exhausting.',
      'A：まいにち とても とおい かよいで。 B：それは つかれますね。',
      '話題（わだい）に あった 形容詞（けいようし）を えらぶ',
    ),
  ],
);

/// Teach-first lesson for やくにん's passive-voice (was built) ナゾ (_kStep2(2),
/// 「The new library ___ by the city council two years ago.」,
/// choices built/has built/was building/was built).
/// Re-teaches passive at 2級 level: past passive = was/were ＋ p.p.,
/// and the by-phrase marks the agent. NO use of "library/build/council/ago".
const TeachCard kPastPassiveTeach = TeachCard(
  titleJa: '「〜された」― かこの 受動態（じゅどうたい）was ／ were ＋ 過去分詞（かこぶんし）',
  leadJa: '「（だれかに よって）〜された」というとき、かこの 受動態（じゅどうたい）を つかうよ。\n'
      'かたちは「was ／ were ＋ 過去分詞（かこぶんし）」。行為者（こういしゃ）は by で しめす。',
  items: [
    TeachItem(
      'was ／ were ＋ 過去分詞',
      '〜された（かこ）',
      'This road was repaired last month. ／ この みちは せんげつ しゅうりされた。',
    ),
    TeachItem(
      'by ＋ 行為者（こういしゃ）',
      '〜によって',
      'The painting was made by a local artist. ／ その えは ちいきの がかに よって かかれた。',
    ),
    TeachItem(
      'The old clock tower was designed by a famous engineer.',
      'その ふるい とけいとうは ゆうめいな こうがくしゃに よって せっけいされた',
      '行為者（こういしゃ）＋ by が ポイント',
    ),
  ],
);

/// Teach-first lesson for がくせい's relative-pronoun-who ナゾ (_kStep2(3),
/// 「The professor ___ wrote this book is giving a lecture tonight.」,
/// choices which/who/whose/whom).
/// Teaches who (subject) vs whose (possessive) vs whom (object) at 2級 level.
/// Examples use "doctor/musician/colleague" — NO use of "professor/lecture/book/wrote/tonight".
const TeachCard kRelativeWhoSubjectTeach = TeachCard(
  titleJa: '「〜した 人（ひと）が…」― 関係代名詞（かんけいだいめいし）who の つかいかた',
  leadJa: '関係代名詞（かんけいだいめいし）who は「人（ひと）」を くわしくするとき つかう。\n'
      '主格（しゅかく）＝ who、所有格（しょゆうかく）＝ whose、目的格（もくてきかく）＝ whom だよ。',
  items: [
    TeachItem(
      'who ＋ 動詞（どうし） → 主格（しゅかく）',
      '〜する 人（ひと）が',
      'the doctor who treated many patients ／ おおくの かんじゃを みた いしゃ',
    ),
    TeachItem(
      'whose ＋ 名詞（めいし） → 所有格（しょゆうかく）',
      '〜の 人（ひと）',
      'a musician whose songs I love ／ わたしが すきな うたを うたう おんがくか',
    ),
    TeachItem(
      'The colleague who leads the morning meeting is very organised.',
      'あさのかいぎを しきる どうりょうは とても せいりされている',
      'leads が どうし → 主格（しゅかく）who',
    ),
  ],
);

// ── 英検準1級 teach-cards ─────────────────────────────────────────────────────

/// Teach-first lesson for 門の守り手's collocation ナゾ (_kStepPre1(0),
/// 「you must ___ a decision」, choices do/take/make/give).
/// Teaches that "make" collocates with decision/choice/effort/mistake,
/// while "do" collocates with homework/work/damage.
/// NO use of "decision" as a worked example (that would leak the answer);
/// uses "mistake/effort/promise" instead.
const TeachCard kCollocationMakeDoTeach = TeachCard(
  titleJa: '「make」と「do」― コロケーション（よく いっしょに つかう ことば）',
  leadJa: '英語（えいご）では 決（き）まった 名詞（めいし）と いっしょに つかう 動詞（どうし）が ある。\n'
      '「make」は「何（なに）かを 生（う）みだす・おこなう」ものに、\n'
      '「do」は「作業（さぎょう）・やること」に つきやすい。',
  items: [
    TeachItem(
      'make ＋ mistake / effort / choice / promise',
      'あやまちをおかす・努力（どりょく）する・えらぶ・やくそくする',
      'She made a great effort to finish on time. ／ かのじょは じかんどおりに おわらせようと ずいぶん 努力（どりょく）した。',
    ),
    TeachItem(
      'do ＋ homework / research / work / damage',
      'しゅくだいをする・研究（けんきゅう）をする・しごとをする・ダメージをあたえる',
      'He did his research carefully. ／ かれは ていねいに 研究（けんきゅう）をした。',
    ),
    TeachItem(
      'They made a promise to keep in touch.',
      'かれらは れんらくを とりつづける やくそくをした',
      '「promise」は make とともに つかう',
    ),
  ],
);

/// Teach-first lesson for 元・宰相's phrasal-verb (carry out) ナゾ (_kStepPre1(2),
/// answer "carry / out"). Teaches the meaning distinction among
/// carry on/out/away/off at B2-C1 level. NO examples that use
/// "plan/heart/library" (stem words); uses "experiment/order/task/speech" instead.
const TeachCard kPhrasalVerbCarryTeach = TeachCard(
  titleJa: '「carry ＋ ___」― 句動詞（くどうし）の いみを くらべよう',
  leadJa: '「carry」に つく ことばで いみが がらっと かわる。\n'
      '英検（えいけん）準1級（きゅう）では いみの ちがいを えらぶ 問題（もんだい）が よく でる。',
  items: [
    TeachItem(
      'carry out ＋ task / experiment / order',
      '〜を やりとげる・実行（じっこう）する',
      'The team carried out the experiment over two months. ／ チームは 二（ふた）ヶ月（かげつ）かけて その じっけんを じっこうした。',
    ),
    TeachItem(
      'carry on ＋ (with) activity',
      '〜を つづける',
      'Carry on with your speech — do not stop. ／ スピーチを つづけて ― とまらないで。',
    ),
    TeachItem(
      'carry away → be carried away by',
      '（感情（かんじょう）に）ながされる',
      'Don\'t be carried away by your excitement. ／ こうふんに ながされないで。',
    ),
  ],
);

/// Teach-first lesson for 城の治癒師's derivational-noun (resilience) ナゾ
/// (_kStepPre1(3), 「Such ___ in the face of so much quiet is rare.」,
/// choices resilient/resilience/resiliently/resile).
/// Teaches word-family awareness: after "such" we need a NOUN.
/// Uses "persist→persistence/patient→patience" as worked examples
/// — NO use of "resilience/resilient/quiet/rare/endure/wait" (stem words).
const TeachCard kDerivationalNounTeach = TeachCard(
  titleJa: '「such ＋ 名詞（めいし）」― はたらきから 品詞（ひんし）を えらぶ',
  leadJa: '「such ＋ ___」の かたちでは、___には 名詞（めいし）が はいる。\n'
      '形容詞（けいようし）や 副詞（ふくし）ではない。語尾（ごび）で 品詞（ひんし）を みわけよう。',
  items: [
    TeachItem(
      '-ence / -ance → 名詞（めいし）',
      'ことば の はたらき を あらわす',
      'persist（動詞）→ persistence（名詞）: such persistence ／ patient（形容詞）→ patience（名詞）: such patience',
    ),
    TeachItem(
      '-ent / -ant → 形容詞（けいようし）',
      'ものごとの ようすを あらわす',
      'persistent（かんじょうし） → does NOT follow "such ___" as the head noun',
    ),
    TeachItem(
      'Such patience in a difficult situation is admirable.',
      'むずかしい じょうきょうで そのような にんたいりょくは りっぱだ',
      '「such」のあとは 名詞（めいし）patience ← 形容詞（けいようし）patient ではない',
    ),
  ],
);

/// Teach-first lesson for the 門番's be動詞 ナゾ (_kStep(15), 'You ___ a
/// traveller.', choices am / are / is / be). Teach how「〜です」changes with the
/// subject BEFORE asking the child to fill the blank.
const TeachCard kBeVerbTeach = TeachCard(
  titleJa: 'まず、be どうし（is・are・am）を おぼえよう',
  leadJa: '「…です」は、しゅご（だれの こと か）で かたちが かわる。',
  items: [
    TeachItem('I am ...', 'わたしは …です', 'しゅごが I のとき'),
    TeachItem('You are ...', 'あなたは …です', 'しゅごが You のとき'),
    TeachItem('He / She is ...', 'かれ／かのじょは …です', 'しゅごが かれ・かのじょ・それ の とき'),
  ],
);

/// Teach-first lesson for 灰守セルの a/an ナゾ. Teach a vs an (an before a vowel
/// SOUND) before asking. (CEO 1891/1893: the 5級 scene ナゾ are real 英検5級
/// questions, not phonics — the 英検 item IS the puzzle, intrinsic integration.
/// A 6+ 5級 candidate already decodes; the s·a·t blend was off-target.)
const TeachCard kArticleTeach = TeachCard(
  titleJa: 'まず、a と an の つかいわけを おぼえよう',
  leadJa: 'ひとつの ものに つける「a／an」。つぎの ことばの おとで かたちが かわる。',
  items: [
    TeachItem('a cat', 'ねこ １ぴき', 'つぎが「し音（ぼいんで ない おと）」の とき'),
    TeachItem('an apple', 'りんご １こ', 'つぎが「ぼいん（ア・イ・ウ・エ・オ）の おと」の とき'),
    TeachItem('an egg', 'たまご １こ', 'エの おとで はじまる → an'),
  ],
);

/// 灰守セルの a/an 大問1 ナゾ — AUTHORED for セル (NOT reused from the linear quest,
/// which would put another villager's name/line on her hotspot and break the
/// case-identity header). Real 英検5級 article grammar (an before a vowel sound),
/// staged at セルの never-dying hearth. autoPlayAudio derives from npcLine; the
/// cloze blank renders as a gap, so the line never gives away the answer.
const QuestEncounter kCelArticleNazo = QuestEncounter(
  npcName: '灰守（はいもり）セル',
  npcEmoji: '🔥',
  npcLine: 'The hearth still burns. Here — this is ___ apple. Eat, and listen.',
  npcLineJa: 'かまどは まだ もえている。ほら、これは ___ りんご。たべて、きいて。',
  choices: ['a', 'an', 'the', 'one'],
  correctIndex: 1,
  onCorrect:
      "An apple — yes. 'apple' begins with a vowel sound, so it is AN, not A. "
      "The ember flared bright as you spoke. Cel smiles: 'You can still hear. "
      "I kept the fire for someone like you.'",
);

final SceneDef kTown5Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town5_lane.webp',
  // Single painted plate for now (parallax drifts the whole plate); sliced
  // far/mid/near bands are a later generation pass.
  parallaxLayers: const [],
  titleJa: 'ことばを失（うしな）った村（むら）',
  // タロ arrival line — 5級, case 1: bright/curious newcomer, one word just won.
  companionArrivalJa: '…あっ。この むら、いろが うすい…っ。\n'
      'なにかが、ことばを とっていった みたい……',
  // Sourced from kQuestTowns[0].cleared (英検5級 — ことばを失った村).
  cleared: '村（むら）に声（こえ）がもどった！ 最初（さいしょ）の〈声（こえ）の石（いし）〉が、あたたかく ひかる。\n'
      'タロが「Hello！」と、はじめて言（い）えた。あおい 光（ひかり）が、タロの からだを つつんだ。\n'
      '灰守（はいもり）セルが、きみの てに 小（ちい）さな しおりを おしつけた。'
      '「これは…むかし、やさしい ひとが かいた おはなしの さいしょの 1ページ。'
      '〈サイレント〉は、ずっと まえは やさしい ひとだった。'
      'しずけさは、そとから きたんじゃない。まんなかから、あるいて きたんだよ。」\n'
      'しおりには、ほんの すこしだけ、ことばが のこっていた――「Once, I」',
  hotspots: [
    // ── NPC 1: 灰守（はいもり）セル — the Ember-Keeper / 大問1 article ナゾ ──
    // step = kCelArticleNazo (a/an: 'this is ___ apple'), AUTHORED for セル so the
    // case-identity header reads 「灰守（はいもり）セル の ナゾ」. CEO 1891/1893: the
    // 5級 scene ナゾ are real 英検5級 questions, not phonics — the 英検 item IS the
    // puzzle (intrinsic integration). A 6+ 5級 candidate already decodes.
    // セル tends the village hearth and offers a roasted apple whose naming-word
    // (a/an) the child restores. Her mystery: she waited for a listener.
    Hotspot.npc(
      pos: const Alignment(-0.45, 0.10),
      size: 0.20,
      step: kCelArticleNazo,
      teachCard: kArticleTeach,
      // Per-case hint ladder for the a/an article cloze. Scaffold toward the rule
      // (the next word starts with a vowel SOUND → the longer form), never naming
      // the answer ('an') or a distractor ('a'/'the'/'one'); kept pure kana so no
      // Latin leaks (hintViolatesAnswerRail stays false; nazo_hint_rail_test).
      hints: const [
        NazoHint(
            tier: 1,
            textJa: '【ヒント T1】ひとつの ものに つける ことば を えらぶ もんだい。'
                '「りんご」を えいごで いう とき、どんな おとで はじまる？'),
        NazoHint(
            tier: 2,
            textJa: '【ヒント T2】「ア・イ・ウ・エ・オ」の ような おと（ぼいん）で '
                'はじまる ことばの まえでは、おとを つなぐ かたち を つかうよ。'),
        NazoHint(
            tier: 3,
            textJa: '【ヒント T3】「りんご」は『ア』の おとで はじまる。だから、'
                'ぼいんの まえに つかう かたち を えらぼう。'),
      ],
      clueLineJa: '「かまどの ひで、りんごを やいた。'
          'でも、これを よぶ ことばが、ひとつ たりないんだ。」',
      framingJa: '灰守（はいもり）セルは、きえない かまどを まもってきた。\n'
          'サイレントに ことばを うばわれても、まちつづけた――\n'
          'まだ ことばを いれられる、きける ひとを。\n'
          'セルが やきたての りんごを さしだす。ひとつ、ことばが たりない。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_clockmaker_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_clockmaker_color.webp',
      // §3 lore drip — CH.1 ember/listener canon (STORY-BIBLE: Cel kept the
      // hearth lit "waiting for a listener").
      mysteryFragmentJa: 'たんていメモ：かまどの ひは、きえなかった。\n'
          'セル――「まだ きける ひとを、まっていたんだ。」',
    ),
    // ── NPC 2: タロ — きみの かがみ、いちほ うしろの なかま ─────────────────
    // Encounter index 12 = first QuestEncounter (「Hello!」greeting).
    // タロ is always one step behind: きみが いえたから、ぼくも いえる。
    Hotspot.npc(
      pos: const Alignment(0.30, 0.30),
      size: 0.16,
      step: _kStep(12),
      teachCard: kGreetingTeach,
      // Per-case hint ladder. The generic 5級 fallback is a SUBJECT-VERB word-
      // order hint — meaningless for this greeting-RECOGNITION ナゾ. These scaffold
      // the greeting recall toward the answer's MEANING/situation, never naming
      // the answer ("Hello!") or the distractor ("cat"), so hintViolatesAnswerRail
      // stays false (locked by nazo_hint_rail_test).
      hints: const [
        NazoHint(
            tier: 1,
            textJa: '【ヒント T1】であった ときに いう「あいさつ」の ことば を '
                'えらぶ もんだい だよ。'),
        NazoHint(
            tier: 2,
            textJa: '【ヒント T2】さっき タロに おしえた「あいさつ」だよ。ひとに '
                'あった ときに いう ことば を おもいだそう。'),
        NazoHint(
            tier: 3,
            textJa: '【ヒント T3】「こんにちは」と おなじ いみ の えいご の '
                'あいさつ を えらぼう。'),
      ],
      clueLineJa: 'ちいさな たんていの こいぬが口（くち）をひらく… 「…ヘッ…ど…？」\n'
          'ことばが、もうすこしのところで 出（で）てこない。',
      framingJa: 'この こいぬの名前（なまえ）は まだ ない。\n'
          'きみが いえたとき、はじめて ぼくも いえる。\n'
          'あいさつの ことばを、きみから おしえてあげよう。\n'
          'タロは いつも、きみの いちほ うしろに いる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.webp',
      // §3 lore drip — CH.1 タロ "one step behind" canon (words return WITH
      // someone, never alone).
      mysteryFragmentJa: 'たんていメモ：きみが いえたから、タロも いえた。\n'
          'ことばは、だれかと いっしょに もどってくる。',
    ),
    // ── NPC 3: 門番（もんばん） と 時計じい — be動詞 are (Quiz, cloze) ─────────
    // Encounter index 15 = be動詞 人称一致「You ___ a traveller.」cloze.
    // 時計じい stands beside the frozen gate-clock; the gate guard echoes his mystery.
    Hotspot.npc(
      pos: const Alignment(0.68, -0.20),
      size: 0.17,
      step: _kStep(15),
      teachCard: kBeVerbTeach,
      clueLineJa: '「ここを通（とお）りたいなら……正（ただ）しい言葉（ことば）で答（こた）えてみよ。」\n'
          '門（もん）の かたわらで、おじいさんが とまった 時計（とけい）を みつめている。',
      framingJa: '村（むら）の門（もん）。門番（もんばん）が 立（た）ちはだかる。\n'
          '「You ___ a traveller.」— ことばの かたちを えらべ。\n'
          'かたわらの 時計（とけい）は サイレントが きてから ずっと とまったまま。\n'
          '正（ただ）しい ことばが もどれば、とけいも うごきだす かもしれない。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_gatekeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_gatekeeper_color.webp',
      // §3 lore drip — the KEY season-mystery clue (silence spread centre→edge),
      // seeded here in ch.1 and paid off at 準1級. STORY-BIBLE Clue #1.
      mysteryFragmentJa: 'たんていメモ：とまった とけいが、コチ…と ひとつ うごいた。\n'
          'じいさん――「しずけさは そとからじゃない。まんなかから、あるいて きたんだ。」',
    ),
    // ── Coin: hidden on the lamppost ────────────────────────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.75, -0.35),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'タロ：「…あれ？ ひかりが どこかに…！ ランプの ちかくかな？ '
          'ぼく、まだ うまく いえないけど… あっち！」',
    ),
    // ── Coin 2: hidden up on a rooftop ──────────────────────────────────────
    Hotspot.coin(
      pos: const Alignment(0.80, -0.58),
      size: 0.10,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ もう ひとつ、ひかってる… やねの うえ かな？」',
    ),
    // ── Observation points (#90 density): tap-to-look 探偵メモ, no puzzle ─────
    Hotspot.observation(
      pos: const Alignment(0.05, -0.46),
      clueLineJa: 'たんていメモ：とじた まどの むこうで、だれかが ちいさく '
          'うたっている。でも、ことばに なっていない。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.62, 0.46),
      clueLineJa: 'たんていメモ：やぶれた はりがみ。もじが かすれて、なにが '
          'かいてあったか もう よめない。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.02, 0.62),
      clueLineJa: 'たんていメモ：いしだたみに、ちいさな くつの あと。だれかが '
          'ここで ことばを おとして いったのかな。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.58, 0.50),
      clueLineJa: 'たんていメモ：からっぽの たる。なかから かすかに '
          '「…す…」と きこえた きが した。',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[0] at const-eval time.
/// Using a top-level function keeps the SceneDef final initialiser clean while
/// confirming the index is valid. Throws at startup (not runtime) if the town
/// changes structure — an intentional safety trip.
QuestStep _kStep(int i) => kQuestTowns[0].encounters[i];

// ── 英検4級 scene — 風（かぜ）の街（港町） ─────────────────────────────────────

/// Wave 2 vertical-slice scene: the second コトバ探偵 district.
///
/// 風の街 is a windy harbour town where the words for everyday life — the past
/// tense of yesterday, the future of tomorrow's weather — were carried off by
/// the サイレント. NPC ナゾ steps are REFERENCED from kQuestTowns[1].encounters,
/// so the exam content (choices / correctIndex) is byte-identical to the quest;
/// framingJa only adds in-world flavour above the stem.
///
/// Art: town4_harbor.webp + the fisher/lampkeeper grey→colour pairs (generated by
/// scripts/generate_scene_art.py). タロ the companion reuses the 5級 slime art —
/// she travels with the player across every district. SceneView's errorBuilder
/// falls back to the dq night-gradient so the scene renders before art exists.
final SceneDef kTown4Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town4_harbor.webp',
  parallaxLayers: const [],
  titleJa: '風（かぜ）の街（まち）',
  // タロ arrival line — 4級, case 2: notices time is wrong, still eager.
  companionArrivalJa: 'かぜが つめたい…！ でも とけいが ぜんぶ、とまってる。\n'
      '「きのう」も「あした」も、この街（まち）から きえちゃったのかな？',
  // Sourced from kQuestTowns[1].cleared (英検4級 — 風の街).
  cleared: 'トックの時計（とけい）が、コチコチと動（うご）き出（だ）した――'
      '「きのう、ありがとう。あした、また会（あ）おう」。\n'
      '街（まち）に毎日（まいにち）のおしゃべりがもどった。二（ふた）つ目（め）の〈声（こえ）の石（いし）〉を手（て）に。'
      '「サイレントは、しずけさを"へいわ"だと思（おも）っているらしい」とタロがつぶやく。',
  hotspots: [
    // ── NPC 1: りょうし — 川（かわ）べりの漁師（りょうし） / to不定詞 ──────────
    // Encounter index 9: 「Did you come here ___ fish?」(to catch).
    // The harbour's nets hang empty: the word for "why" he came blew away too.
    Hotspot.npc(
      pos: const Alignment(-0.50, 0.18),
      size: 0.19,
      step: _kStep4(9),
      teachCard: kToInfinitiveTeach,
      clueLineJa: '「なぜ ここに いるか、だって…？ '
          'それを いう ことばが、かぜに さらわれて しまったんだ。」',
      framingJa: '風（かぜ）の街（まち）の 港（みなと）。あみは からっぽ、ふねは とまったまま。\n'
          'サイレントが きてから、漁師（りょうし）は「なぜ」つりに きたのか'
          '言（い）えなくなった。\n'
          '「Did you come here ___ fish?」— ただしい かたちを えらべ。\n'
          'ことばが もどれば、また うみへ こぎだせる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_fisher_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_fisher_color.webp',
      // §3 lore drip — CH.2: the words are CARRIED off, not destroyed.
      mysteryFragmentJa: 'たんていメモ：ことばは きえたんじゃない。\n'
          'かぜに のって、どこかへ はこばれている。',
    ),
    // ── NPC 2: 灯台（とうだい）守（もり）の おじいさん / 未来 will ─────────────
    // Encounter index 4: 「I think it ___ rain soon.」(will).
    // He watches the storm wind from the lighthouse; he lost the word for what
    // the sky is about to do.
    Hotspot.npc(
      pos: const Alignment(0.55, -0.28),
      size: 0.18,
      step: _kStep4(4),
      teachCard: kFutureWillTeach,
      clueLineJa: '「そらが くらい。なにかが おきる…と わかるのに、'
          'それを いう ことばが でてこない。」',
      framingJa: '灯台（とうだい）の うえ。おじいさんが くろい そらを みあげている。\n'
          '「あした」を かたる ことば — 未来（みらい）を あらわす かたち — が きえかけている。\n'
          '「I think it ___ rain soon.」— これから おきる ことを いう かたちは？\n'
          '正（ただ）しく いえたら、おじいさんは かさを かしてくれる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_lampkeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_lampkeeper_color.webp',
      // §3 lore drip — CH.2: the windmills all face the centre (はいいろの ひろば).
      mysteryFragmentJa: 'たんていメモ：かざぐるまは みんな、\n'
          'とおくの「はいいろの ひろば」の ほうを むいて まわっている。',
    ),
    // ── NPC 3: タロ — きみの いちほ うしろの なかま / 過去 -ed ────────────────
    // Encounter index 2: 「Where did you go?」→「I went to the zoo.」
    // タロ has travelled with you from 5級. Now she tries to tell you where SHE
    // went yesterday — learning the past tense one step behind you, as always.
    Hotspot.npc(
      pos: const Alignment(0.05, 0.34),
      size: 0.15,
      step: _kStep4(2),
      teachCard: kIrregularPastTeach,
      clueLineJa: 'タロ：「…きのう、ぼく、どこかへ いった。'
          'でも それを いう ことばが… きみ、おしえて？」',
      framingJa: 'タロは 5級（きゅう）の村（むら）から ずっと きみと あるいてきた。\n'
          'いまは「きのう」を かたる ことば — 過去（かこ）の かたち — を'
          'おぼえようとしている。\n'
          'きみが いえたら、タロも いえる。いつものように、いちほ うしろで。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.webp',
      // §3 lore drip — CH.2: Bookmark #2 ("told a story,") + the mercy motive.
      mysteryFragmentJa: 'たんていメモ：かぜが しおりを はこんできた。「told a story,」\n'
          'サイレントは、だれかを きずつけたくなかった だけ なのかも。',
    ),
    // ── Coin: hidden by the lighthouse lamp ─────────────────────────────────
    Hotspot.coin(
      pos: const Alignment(0.78, -0.55),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ とうだいの あかりの ちかくで、'
          'なにかが きらっと… あそこ、たかいところ！」',
    ),
    // ── Coin 2: hidden among the moored boats ───────────────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.18, 0.60),
      size: 0.10,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ ふねの ほばしらの うえ… '
          'あそこにも、ちいさく ひかってる！」',
    ),
    // ── Observation points (#90 density): tap-to-look 探偵メモ, no puzzle ─────
    Hotspot.observation(
      pos: const Alignment(0.10, -0.62),
      clueLineJa: 'たんていメモ：とけいの はりが ぜんぶ、おなじ じこくで '
          'とまっている。とき までも かぜに さらわれたのか。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.70, -0.10),
      clueLineJa: 'たんていメモ：ほされた あみは からっぽ。'
          'なにも とれない うみに なって、どれくらい たつのだろう。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.40, 0.40),
      clueLineJa: 'たんていメモ：かざぐるまが ぎいっと きしむ。'
          'やはり とおくの「はいいろの ひろば」の ほうを むいている。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.40, 0.58),
      clueLineJa: 'たんていメモ：くいに ひっかかった しおり。'
          'かぜに ふるえて、かすかに「…story,」と よめた。',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[1] (英検4級) at const-eval time.
QuestStep _kStep4(int i) => kQuestTowns[1].encounters[i];

// ── 英検3級 scene — 学（まな）びの都（みやこ） ────────────────────────────────

/// Wave 2 vertical-slice scene: the third コトバ探偵 district.
///
/// 学びの都 is a scholarly old university quarter whose great library lost its
/// words — the present perfect that holds the past into now (for/since, yet).
/// NPC ナゾ steps are REFERENCED from kQuestTowns[2].encounters, so the exam
/// content is byte-identical; framingJa only adds in-world flavour.
///
/// Art: town3_academy.webp + the librarian/scholar grey→colour pairs. タロ the
/// companion reuses the slime art (she has travelled here from 5級→4級→3級).
final SceneDef kTown3Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town3_academy.webp',
  parallaxLayers: const [],
  titleJa: '学（まな）びの都（みやこ）',
  // タロ arrival line — 3級, case 3: archives silent, タロ notices memory fading.
  companionArrivalJa: 'としょかんの たなが、ぜんぶ しずか……\n'
      'ここの ひとたち、「ずっと まえから」を つたえる ことばを なくしたのかも。',
  // Sourced from kQuestTowns[2].cleared (英検3級 — 学びの都).
  cleared: '封（ふう）じられた日記（にっき）の、最後（さいご）の一行（いちぎょう）がひらいた。'
      '書庫番（しょこばん）ミネが しずかに読（よ）み上（あ）げる――'
      '「わたしは、しずけさを まもっていた つもりだった」。\n'
      '三（みっ）つ目（め）の〈声（こえ）の石（いし）〉を手（て）に。'
      '人々（ひとびと）が、また自分（じぶん）の物語（ものがたり）を語（かた）り出（だ）した。',
  hotspots: [
    // ── NPC 1: としょかんいん — 言葉（ことば）を まもる 司書 / 現在完了 for ──────
    // Encounter index 3: 「I have worked in this library ___ ten years…」(for).
    Hotspot.npc(
      pos: const Alignment(-0.48, -0.05),
      size: 0.19,
      step: _kStep3(3),
      teachCard: kPresentPerfectForSinceTeach,
      clueLineJa: '「この としょかんで、わたしは ずっと はたらいてきた。'
          'ことばが しんでも、わたしだけは のこす。」',
      framingJa: '学（まな）びの都（みやこ）の 大（だい）としょかん。'
          'たなは からっぽ、ほんの ことばが きえている。\n'
          '司書（ししょ）は「いままで ずっと」を かたる ことば — '
          '現在完了（げんざいかんりょう）で 期間（きかん）を あらわす ことば — を まもっている。\n'
          '「I have worked in this library ___ ten years.」— どの ことばが はいる？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_librarian_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_librarian_color.webp',
      // §3 lore drip — CH.3: the one white book at the library's centre.
      mysteryFragmentJa: 'たんていメモ：おおきな としょかんの まんなかの ほんだけ、'
          'まっしろ。\nことばが ぜんぶ きえている。',
    ),
    // ── NPC 2: がくせい — まだ よみおえていない 学生 / 現在完了 yet ────────────
    // Encounter index 4: 「I have to return this book, but I haven't finished it ___.」(yet)
    Hotspot.npc(
      pos: const Alignment(0.52, 0.10),
      size: 0.17,
      step: _kStep3(4),
      teachCard: kPerfectYetAlreadyTeach,
      clueLineJa: '「この ほんを かえさなきゃ。でも… まだ よみおわっていないんだ。」',
      framingJa: '中庭（なかにわ）の ベンチ。学生（がくせい）が ほんを かかえて'
          'こまっている。\n'
          '「まだ〜していない」を いう ことば — 現在完了（かんりょう）で つかう ことば — が でてこない。\n'
          '「I haven\'t finished it ___.」— 否定（ひてい）の文（ぶん）に あう ことばは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_scholar_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_scholar_color.webp',
      // §3 lore drip — CH.3: the white book is someone's OWN torn story.
      mysteryFragmentJa: 'たんていメモ：あの しろい ほんは、だれかの じぶんの ものがたり。\n'
          'ページが やぶられて、7まいの しおりに なった。',
    ),
    // ── NPC 3: タロ — 都（みやこ）で 再会（さいかい）した なかま / 過去形 ────────
    // Encounter index 0: タロ reunion — 「Where did you sleep last night?」
    Hotspot.npc(
      pos: const Alignment(0.02, 0.40),
      size: 0.15,
      step: _kStep3(0),
      teachCard: kSimplePastCuedTeach,
      clueLineJa: 'タロ：「やっと 都（みやこ）に ついた！ ぼく、ひとばんじゅう '
          'ことばの れんしゅうを したんだ。きみは どこで ねた？」',
      framingJa: 'タロは 風（かぜ）の街（まち）から きみを おいかけて、'
          'この 都（みやこ）まで きた。\n'
          'いまでは「きのうの こと」を じぶんから 話（はな）せる。'
          'いちほ うしろの なかまが、すこし 大（おお）きくなった。',
      // §3 lore drip — CH.3: Bookmark #3 ("and the whole") + サイレント's true name.
      mysteryFragmentJa: 'たんていメモ：3まいめの しおり――「and the whole」。\n'
          'サイレントの ほんとうの なまえは、アイラ というらしい。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.webp',
    ),
    // ── Coin: hidden among the library's high shelves ───────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.78, -0.48),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ たかい たなの うえで、なにかが ひかってる。'
          'あんなところ、どうやって とるの…？」',
    ),
    // ── Coin 2: hidden on a high reading lamp ───────────────────────────────
    Hotspot.coin(
      pos: const Alignment(0.68, -0.42),
      size: 0.10,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ よみかけランプの かさの うえ… '
          'そこにも、ちいさく ひかるものが あるよ！」',
    ),
    // ── Observation points (#90 density): tap-to-look 探偵メモ, no puzzle ─────
    Hotspot.observation(
      pos: const Alignment(-0.20, -0.55),
      clueLineJa: 'たんていメモ：ほんを ひらいても、もじが ひとつも ない。'
          'だれかが、ことばだけを つれさったのだ。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.65, 0.35),
      clueLineJa: 'たんていメモ：よみかけの にっきが ひらいたまま。'
          'インクが かすれ、ぶんが とちゅうで とまっている。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.35, 0.55),
      clueLineJa: 'たんていメモ：ゆかに おちた しおり。「and the whole」――'
          '7まいの うちの、1まいだ。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.10, -0.60),
      clueLineJa: 'たんていメモ：ほんだなの すみに、ちいさな らくがき。'
          '「アイラ、ここに いた」。サイレントは、もとは ここの ひと…？',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[2] (英検3級) at const-eval time.
QuestStep _kStep3(int i) => kQuestTowns[2].encounters[i];

// ── 英検準2級 scene — 社会（しゃかい）の港町（みなとまち） ──────────────────────

/// Wave 2 vertical-slice scene: the fourth コトバ探偵 district.
///
/// 社会の港町 is a GRAND trade-port city (distinct from 4級's small fishing
/// harbour) whose public commerce stilled when the words of society — the
/// passive voice, relative clauses — were carried off. NPC ナゾ steps are
/// REFERENCED from kQuestTowns[3].encounters; framingJa only adds flavour.
///
/// Art: town_pre2_port.webp + merchant/captain grey→colour pairs. とうだいもり
/// reuses 4級's lampkeeper art (the same kind of harbour-light keeper).
final SceneDef kTownPre2Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town_pre2_port.webp',
  parallaxLayers: const [],
  titleJa: '社会（しゃかい）の港町（みなとまち）',
  // タロ arrival line — 準2, case 4: big port but two guilds won't talk to each
  // other; タロ is bolder now, frames the social problem.
  companionArrivalJa: 'でっかい 港（みなと）だ… でも あっちと こっちで、'
      'みんな そっぽを むいてる。「じぶんはこう思（おも）う」が、きえちゃったのかな。',
  // Sourced from kQuestTowns[3].cleared (英検準2級 — 社会の港町).
  cleared: '港（みなと）の案内人（あんないにん）ナギが、はじめて自分（じぶん）の言葉（ことば）で言（い）った――'
      '「わたしは、ちがうと思（おも）う」。\n'
      '港町（みなとまち）の人々（ひとびと）も、また「自分（じぶん）はこう思（おも）う」と言（い）えるようになった。四（よっ）つ目（め）の〈声（こえ）の石（いし）〉。'
      'クワイエは、ことばが二人（ふたり）を仲直（なかなお）りさせるのを見（み）て、ちいさくふるえた――'
      '「…ことばで、きずを なおせるの…？」 そっと、きみのあとを ついてくる。\n'
      'タロが しずかに つぶやいた――「サイレントも、むかし ことばで だれかを '
      'きずつけて しまって、もう だれも きずつけたくなくて、だまる ことを '
      'えらんだのかな…」。〈サイレント〉の なぞが、また ひとつ ふかくなった。',
  hotspots: [
    // ── NPC 1: しょうにん — 波止場（はとば）の商人 / 受動態 ───────────────────
    // Encounter index 2: 「Do you know where they are grown?」(passive voice).
    Hotspot.npc(
      pos: const Alignment(-0.50, 0.12),
      size: 0.18,
      step: _kStepPre2(2),
      teachCard: kPassiveVoiceTeach,
      clueLineJa: '「この香辛料（こうしんりょう）が どこで”育（そだ）てられて”いるか… '
          'それを いう ことばが、波（なみ）に さらわれた。」',
      framingJa: '社会（しゃかい）の港町（みなとまち）。世界中（せかいじゅう）の '
          'しなものが あつまる 大（おお）きな 波止場（はとば）。\n'
          '商人（しょうにん）は「〜される」を かたる ことば — 受動態（じゅどうたい） — '
          'を なくした。\n'
          '「Do you know where they ___ ?」— ものが どう されるかを いう かたちは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_merchant_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_merchant_color.webp',
      // §3 lore drip — CH.4: the lost words of disagreement-with-respect.
      mysteryFragmentJa: 'たんていメモ：ことばを なくした ひとは、こえも なく にらみあう。\n'
          '「ちがう、でも きみを みとめる」――それが いえないだけ。',
    ),
    // ── NPC 2: せんちょう — 大船（おおぶね）の船長 / 関係代名詞 who ────────────
    // Encounter index 3: 「What kind of sailor do you respect?」(relative who).
    Hotspot.npc(
      pos: const Alignment(0.50, -0.08),
      size: 0.18,
      step: _kStepPre2(3),
      teachCard: kRelativePronounWhoTeach,
      clueLineJa: '「信（しん）じられる 仲間（なかま）を いい表（あらわ）す ことばが、'
          'もう 出（で）てこないんだ。」',
      framingJa: '埠頭（ふとう）に つながれた 大船（おおぶね）。'
          '船長（せんちょう）が きみを 見定（みさだ）める。\n'
          '「どんな 人（ひと）か」を つなぐ ことば — 関係代名詞（かんけいだいめいし）'
          'who — を なくした。\n'
          '「A sailor ___ never gives up in a storm.」— 人（ひと）を つなぐ かたちは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_captain_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_captain_color.webp',
      // §3 lore drip — CH.4: the WHY — this port once BEGGED for silence.
      mysteryFragmentJa: 'たんていメモ：クワイエが つぶやく――\n'
          '「ことばは ひとを きずつける。だから、ない ほうが いいんだ。」',
    ),
    // ── NPC 3: とうだいもり — 港（みなと）の灯（あか）り守 / 関係副詞 where ──────
    // Encounter index 4: 「describe the place ships feel safe」(relative where).
    Hotspot.npc(
      pos: const Alignment(0.78, -0.42),
      size: 0.16,
      step: _kStepPre2(4),
      teachCard: kRelativeAdverbWhereTeach,
      clueLineJa: '「船（ふね）が やすらぐ”場所（ばしょ）”を いい表（あらわ）す ことば… '
          'それが きえると、灯台（とうだい）の あかりも にぶる。」',
      framingJa: '港（みなと）の はずれの 灯台（とうだい）。'
          'ふるい 灯（あか）り守（もり）が 海（うみ）を みつめている。\n'
          '「〜する 場所（ばしょ）」を つなぐ ことば — 関係副詞（かんけいふくし）'
          'where — を なくした。\n'
          '「the harbour ___ the storms cannot reach」— 場所（ばしょ）を つなぐ かたちは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_lampkeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_lampkeeper_color.webp',
      // §3 lore drip — CH.4: Bookmark #4 ("grey world") + words can HEAL.
      mysteryFragmentJa: 'たんていメモ：4まいめの しおり――「grey world」。\n'
          'ことばが もどると、にくみあいが あくしゅに かわった。',
    ),
    // ── Coin: hidden among the moored ships' rigging ────────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.80, -0.50),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ ふねの ロープの あいだで、なにかが ゆれて ひかってる。'
          'たかい ところだなぁ…！」',
    ),
    // ── Coin 2: hidden on a harbour-side crane ──────────────────────────────
    Hotspot.coin(
      pos: const Alignment(0.58, 0.52),
      size: 0.10,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ にもつを つるす クレーンの さきっぽ… '
          'あそこにも ひかるものが ぶらさがってる！」',
    ),
    // ── Observation points (#90 density): tap-to-look 探偵メモ, no puzzle ─────
    Hotspot.observation(
      pos: const Alignment(0.10, -0.62),
      clueLineJa: 'たんていメモ：ふたつの ギルドの はたが、たがいに そっぽを '
          'むいて かかげられている。ことばが ないと、せなかしか みえない。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.35, 0.55),
      clueLineJa: 'たんていメモ：せかいじゅうの こうしんりょうの はこ。'
          'でも ラベルの もじが きえ、どこから きたのか だれにも わからない。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.32, 0.30),
      clueLineJa: 'たんていメモ：はしらの かげに、ちいさな かげが ひとつ。'
          'じっと こちらを みて、なにも いわない。…だれ？',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.62, 0.28),
      clueLineJa: 'たんていメモ：かぜに とんできた しおり――「grey world」。'
          '7まいの うちの、4まいめだ。',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[3] (英検準2級) at const-eval time.
QuestStep _kStepPre2(int i) => kQuestTowns[3].encounters[i];

// ── 英検準2級プラス scene — 試練（しれん）の橋（はし） ──────────────────────────

/// The bridge district between 準2級 and 2級 (the 2025 新設 grade).
/// Reuses gatekeeper (番人) + fisher (渡し守) archetype art; only the background
/// is new. Steps referenced from kQuestTowns[4].encounters.
final SceneDef kTownPre2PlusScene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town_pre2plus_bridge.webp',
  parallaxLayers: const [],
  titleJa: '試練（しれん）の橋（はし）',
  // タロ arrival line — 準2プラス, case 5: fog on the bridge, タロ steadier now,
  // understands meaning must carry across.
  companionArrivalJa: 'むこう岸（ぎし）が… みえない。きりが ぜんぶ おおってる。\n'
      'ことばを ちゃんと わたせたら、きりも はれると おもう。',
  // Sourced from kQuestTowns[4].cleared (英検準2級プラス — 試練の橋).
  cleared: '橋守（はしもり）ロウは、灯（あか）りを掲（かか）げたまま動（うご）かない――けれど、'
      '向（む）こう岸（ぎし）の声（こえ）が、たしかに届（とど）いた。「…ことばは、無事（ぶじ）に渡（わた）れるのか。知（し）らなかった」。\n'
      '橋（はし）の向（む）こうに、城（しろ）の灯（あか）りが見（み）えた。五（いつ）つ目（め）の〈声（こえ）の石（いし）〉を手（て）に。'
      '橋守（はしもり）ロウが、はじめて灯（あか）りを下（お）ろして言（い）う――「のこる石（いし）はあと一（ひと）つ。さいごの ひろばに、しずけさ〈サイレント〉が いる」。',
  hotspots: [
    // はしの番人 — 現在完了 (idx 0): "I ___ on this bridge since 2025."
    Hotspot.npc(
      pos: const Alignment(-0.48, -0.02),
      size: 0.18,
      step: _kStepPre2Plus(0),
      teachCard: kPresentPerfectSinceTeach,
      clueLineJa: '「2025年（ねん）、この橋（はし）が あらたに かけられて から、'
          'わたしは ずっと ここに 立（た）ってきた。」',
      framingJa: '準2級（きゅう）と 2級（きゅう）の あいだに かかる、'
          '長（なが）い 石（いし）の橋（はし）。\n'
          '番人（ばんにん）は「ずっと〜してきた」を かたる ことば — '
          '現在完了（げんざいかんりょう） — で きみの 覚悟（かくご）を 問（と）う。\n'
          '「I ___ on this bridge since 2025.」— どの かたちが はいる？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_gatekeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_gatekeeper_color.webp',
      // §3 lore drip — CH.5: each solved ナゾ lights the next lantern in the fog.
      mysteryFragmentJa: 'たんていメモ：ナゾを とくたびに、つぎの ランプが ともる。\n'
          'ともった ぶんだけ、きりの むこうが みえてくる。',
    ),
    // 渡し守 — 関係副詞 where (idx 1): "the place ___ many travellers turn back."
    Hotspot.npc(
      pos: const Alignment(0.50, 0.16),
      size: 0.17,
      step: _kStepPre2Plus(1),
      teachCard: kRelativeWhereVsWhichTeach,
      clueLineJa: '「ここは、おおくの 旅人（たびびと）が ひきかえす”場所（ばしょ）”…'
          'それを いい表（あらわ）す ことばを、きみは もっているか？」',
      framingJa: '橋（はし）の なかほど。渡（わた）し守（もり）が ふかい きりの '
          'たにを 見下（みお）ろしている。\n'
          '「〜する 場所（ばしょ）」を つなぐ ことば — 関係副詞（かんけいふくし）'
          '— が ためされる。\n'
          '「This is the place ___ many travellers turn back.」',
      npcGreyAsset: 'assets/art/scenes_layton/npc_fisher_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_fisher_color.webp',
      // §3 lore drip — CH.5: the FIRST sight of サイレント, resting not blocking,
      // + Bookmark #5 ("turned to").
      mysteryFragmentJa: 'たんていメモ：はしの まんなかに、はいいろの ひとが すわっている。\n'
          '「ここまで きたの…つかれたら、すわっても いいんだよ。」 5まいめ――「turned to」。',
    ),
    // Coin — タロ (the companion) voices the hint here, as in every district.
    Hotspot.coin(
      pos: const Alignment(0.04, 0.42),
      size: 0.12,
      coinValue: 1,
      clueLineJa: 'タロ：「この橋（はし）、たかいね…！ でも、らんかんの うえで '
          'なにか ひかってる。きみが いくなら、ぼくも いく。いちほ うしろで。」',
    ),
    // ── Coin 2: hidden on a far lantern post in the fog ─────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.68, 0.40),
      size: 0.10,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ きりの むこうの ランプの ねもとで、'
          'ちいさく ひかるものが ある… みえる？」',
    ),
    // ── Observation points (#90 density): tap-to-look 探偵メモ, no puzzle ─────
    Hotspot.observation(
      pos: const Alignment(0.30, -0.58),
      clueLineJa: 'たんていメモ：きりの なかに、ランプが いくつも ならんでいる。'
          'ともっているのは、まだ ほんの すこしだけ。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.32, 0.52),
      clueLineJa: 'たんていメモ：らんかんから したを のぞくと、ふかい きりの たに。'
          'おちたら もどれない、と わたしもりが いっていた。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.22, -0.50),
      clueLineJa: 'たんていメモ：はしの ずっと さきに、はいいろの ひとかげが ひとつ。'
          'たたかう かまえも なく、ただ しずかに うごかない。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.70, -0.28),
      clueLineJa: 'たんていメモ：らんかんに ひっかかった しおり――「turned to」。'
          '7まいの うちの、5まいめだ。',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[4] (準2級プラス) at const-eval time.
QuestStep _kStepPre2Plus(int i) => kQuestTowns[4].encounters[i];

// ── 英検2級 scene — 学者（がくしゃ）の城下町（じょうかまち） ────────────────────

/// Reuses librarian (せんせい) + captain (やくにん) + scholar (がくせい) art;
/// only the background is new. Steps from kQuestTowns[5].encounters.
final SceneDef kTown2Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town_2_castle.webp',
  parallaxLayers: const [],
  titleJa: '学者（がくしゃ）の城下町（じょうかまち）',
  // タロ arrival line — 2級, case 6: formal castle gates, タロ senses power
  // behind the silence, speaks for the first time about speaking FOR someone.
  companionArrivalJa: 'たかい 門（もん）…。なんか、しずかすぎて こわい。\n'
      'ここの ひとたち、「だまっていれば あんぜん」と おもって いるのかも。',
  // Sourced from kQuestTowns[5].cleared (英検2級 — 学者の城下町).
  cleared: '学士（がくし）オーレンは、静（しず）かに門（もん）をひらいた――'
      '「私（わたし）は まちがっていた。沈黙（ちんもく）は、安全（あんぜん）などではなかった」。\n'
      '六（むっ）つ目（め）――最後（さいご）の〈声（こえ）の石（いし）〉がそろった！ むねの石（いし）と合（あ）わせ、〈ことばの紋章（もんしょう）〉が かんせいする。'
      'それは、きみが すべての こえを かえしてきた、たしかな あかし。\n'
      'そのとき、ひろばの すみで ちいさな こえがした――クワイエの おとうとが、ずっと さがしていたのだ。'
      'クワイエは、きみが おしえてくれた ことばで、はじめて じぶんから あやまった――'
      '「あのとき、ひどいこと いって ごめん。…また、きみと はなしたい」。'
      'おとうとは ないて うなずき、クワイエの フードが するりと おちた。'
      '「ことばは、きずつけるだけじゃ なかったんだね。さいごまで、きみと いくよ」。クワイエが、なかまに なった。\n'
      'さいごの ひろばへの みちが、ひとりでに ひらいた。',
  hotspots: [
    // せんせい — academic-register response (idx 0)
    Hotspot.npc(
      pos: const Alignment(-0.50, -0.05),
      size: 0.18,
      step: _kStep2(0),
      teachCard: kEmpathyResponseTeach,
      clueLineJa: '「もう 十年（じゅうねん）、ここで おしえている… '
          'こういう 話（はなし）に、なんと こたえるのが ふさわしい？」',
      framingJa: '城（しろ）を のぞむ 学者（がくしゃ）の 城下町（じょうかまち）。\n'
          '大人（おとな）どうしの 会話（かいわ）に ふさわしい こたえ方（かた） — '
          '英検2級（きゅう）の 社会（しゃかい）的な やりとり — が ためされる。\n'
          'せんせいの ことばに、ていねいに 共感（きょうかん）する こたえを えらべ。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_librarian_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_librarian_color.webp',
      // §3 lore drip — CH.6: クワイエ's arc — she wants to apologise.
      mysteryFragmentJa: 'たんていメモ：クワイエが、ずっと だれかに あやまりたがっている。\n'
          'ことばが もどれば、その きもちを つたえられる。',
    ),
    // やくにん — passive voice (idx 2): "The new library ___ by the city council."
    Hotspot.npc(
      pos: const Alignment(0.50, -0.10),
      size: 0.17,
      step: _kStep2(2),
      teachCard: kPastPassiveTeach,
      clueLineJa: '「あたらしい 図書館（としょかん）は、市（し）の 議会（ぎかい）に'
          'よって どう されたか… その ことばが 出（で）てこない。」',
      framingJa: '城下町（じょうかまち）の 役所（やくしょ）。\n'
          '「〜された」を かたる ことば — 受動態（じゅどうたい） — が ためされる。\n'
          '「The new library ___ by the city council two years ago.」',
      npcGreyAsset: 'assets/art/scenes_layton/npc_captain_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_captain_color.webp',
      // §3 lore drip — CH.6: Clue #6 — the King and the First Speaker are ONE.
      mysteryFragmentJa: 'たんていメモ：がくしゃたちの ぎろんから、ひとつの こたえが みえた。\n'
          '「おうさま」と「さいしょに はなした ひと」は、おなじ ひと らしい。',
    ),
    // がくせい — relative pronoun who (idx 3)
    Hotspot.npc(
      pos: const Alignment(0.06, 0.40),
      size: 0.15,
      step: _kStep2(3),
      teachCard: kRelativeWhoSubjectTeach,
      clueLineJa: '「この本（ほん）を かいた 教授（きょうじゅ）が、'
          'こんや 城（しろ）の ホールで 講演（こうえん）する… のに、'
          'その”人（ひと）”を つなぐ ことばが…」',
      framingJa: '人（ひと）を つなぐ ことば — 関係代名詞（かんけいだいめいし）'
          '— が ためされる。\n'
          '「The professor ___ wrote this book is giving a lecture tonight.」',
      npcGreyAsset: 'assets/art/scenes_layton/npc_scholar_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_scholar_color.webp',
      // §3 lore drip — CH.6: Bookmark #6 ("colour.") — one word left.
      mysteryFragmentJa: 'たんていメモ：6まいめ――「colour.」。\n'
          'しおりが あと ひとつで そろう。のこるは、たった ひとつの ことば。',
    ),
    Hotspot.coin(
      pos: const Alignment(-0.80, -0.48),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ 城（しろ）への かいだんの うえで、'
          'なにか きらっと ひかった！」',
    ),
    // ── Coin 2: hidden in a high castle-tower window ────────────────────────
    Hotspot.coin(
      pos: const Alignment(0.74, -0.42),
      size: 0.10,
      coinValue: 1,
      clueLineJa: 'タロ：「…あっ、みつけたっ！ たかい とうの まどの おくで、'
          'なにかが きらっと… あんな たかいところ、どうやって…！」',
    ),
    // ── Observation points (#90 density): tap-to-look 探偵メモ, no puzzle ─────
    Hotspot.observation(
      pos: const Alignment(0.18, -0.60),
      clueLineJa: 'たんていメモ：たかい もんの まえ。えいへいも はたも、'
          'こおりついたように うごかない。だまることが、ここでは ルールなのだ。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.62, 0.35),
      clueLineJa: 'たんていメモ：がくしゃの メモが おちている。'
          '「王（おう）＝さいしょに はなした ひと？」と、なんども かきなおした あと。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.25, -0.45),
      clueLineJa: 'たんていメモ：フードの クワイエが、もんの かげから みている。'
          'なにか いいたげに くちを ひらいて――また、とじた。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.40, 0.52),
      clueLineJa: 'たんていメモ：かいだんに おちた しおり――「colour.」。'
          'これで 6まい。のこるは、たった ひとつの ことばだけ。',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[5] (英検2級) at const-eval time.
QuestStep _kStep2(int i) => kQuestTowns[5].encounters[i];

// ── 英検準1級 scene — 灰色（はいいろ）の ひろば / The Grey Square ───────────────

/// The CLIMAX district: the heart of the サイレント. The square art is itself
/// colour-drained; colour returns only as the player restores its NPCs. Reuses
/// gatekeeper (門の守り手); the 元・宰相 + 城の治癒師 get NEW art for the climax.
/// Steps from kQuestTowns[6].encounters.
final SceneDef kTownPre1Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town_pre1_grey_square.webp',
  parallaxLayers: const [],
  titleJa: '灰色（はいいろ）の ひろば',
  // タロ arrival line — 準1, case 7: the grey heart of the world; タロ is steady
  // and brave, acknowledges what's at stake, stands beside きみ.
  companionArrivalJa: 'ここが… まんなか。いろが、ぜんぶ きえてる。\n'
      'ぼく、こわいけど── きみの となりに いる。',
  // Sourced from kQuestTowns[6].cleared (英検準1級 — 灰色のひろば).
  cleared: 'あなたの言葉（ことば）が、アイラの胸（むね）に そっと とどいた。なくしていた「声（こえ）」が、アイラに もどってくる。'
      '灰色（はいいろ）の ひろばに 色（いろ）が あふれ、その色（いろ）は はしを わたり、すべての まちへ ながれていく。だれも やっつけなかった。ただ、アイラは もう ひとりじゃない。あなたは 世界（せかい）に ──そして アイラに── ことばの かえしかたを、おもいださせたんだ。',
  hotspots: [
    // 門の守り手 — advanced collocation make a decision (idx 0)
    Hotspot.npc(
      pos: const Alignment(-0.52, 0.02),
      size: 0.18,
      step: _kStepPre1(0),
      teachCard: kCollocationMakeDoTeach,
      clueLineJa: '「ここから さきは、サイレントの こころの まんなか。'
          'はいる”決断（けつだん）”を、きみは くだせるか？」',
      framingJa: 'すべての 色（いろ）が きえた、しずかな ひろば。'
          'ここが サイレントの こころの まんなか。\n'
          '英検準1級（きゅう）の こなれた 言（い）い回（まわ）し — '
          '「決断（けつだん）を くだす」と いう 動詞（どうし）と 名詞（めいし）の 組（く）み合（あ）わせ — が ためされる。\n'
          '正（ただ）しい ことばが、灰色（はいいろ）に 最初（さいしょ）の 色（いろ）を もどす。',
      // Authored 3-tier ladder — concept-only, names neither answer nor any
      // distractor (anti-leak rail: hintViolatesAnswerRail).
      hints: const [
        NazoHint(
          tier: 1,
          textJa: '【ヒント T1】「決断（けつだん）を くだす」のような〈動詞（どうし）＋名詞（めいし）〉の '
              '言（い）い回（まわ）しは、英語（えいご）では 決（き）まった ペアが あるよ。'
              '意味（いみ）だけで えらぶと ひっかかる。',
        ),
        NazoHint(
          tier: 2,
          textJa: '【ヒント T2】ここでの 動詞（どうし）は「(決断や 計画を) あたらしく つくり出（だ）す」'
              'イメージ。「すでに ある ことを おこなう」系（けい）の 動詞（どうし）とは ちがうよ。',
        ),
        NazoHint(
          tier: 3,
          textJa: '【ヒント T3】"a decision / a plan / a promise" の まえに おく 動詞（どうし）は、'
              '4つの 中（なか）で いちばん「ゼロから うみ出（だ）す」感（かん）じの もの。'
              '手（て）に とる・あたえる では ないよ。',
        ),
      ],
      npcGreyAsset: 'assets/art/scenes_layton/npc_gatekeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_gatekeeper_color.webp',
      // §3 lore drip — CH.7 finale: the grey heart, アイラ at the centre.
      mysteryFragmentJa: 'たんていメモ：いろが ぜんぶ きえた、しずかな ひろば。\n'
          'まんなかに、はいいろの ひとが しずかに すわっている。ここが、すべての はじまり。',
    ),
    // 元・宰相 — phrasal verb carry out (idx 2)
    Hotspot.npc(
      pos: const Alignment(0.48, -0.12),
      size: 0.19,
      step: _kStepPre1(2),
      teachCard: kPhrasalVerbCarryTeach,
      clueLineJa: '「わたしは かつて、この くにの すべてを とりしきって きた…'
          'いまは、その「やりとげる」という ことばさえ おもいだせない。」',
      framingJa: 'ひろばの 中央（ちゅうおう）、ひびわれた 石（いし）の 円卓（えんたく）の そばに、'
          '元（もと）・宰相（さいしょう）が ひとり すわっている。\n'
          'かれは サイレントが くる まえ、この くにを うごかしていた 人（ひと）。\n'
          '句動詞（くどうし）の せいかくな いみ ──「やりとげる・実行（じっこう）する」── '
          'を とりもどせ。',
      hints: const [
        NazoHint(
          tier: 1,
          textJa: '【ヒント T1】句動詞（くどうし）は〈動詞（どうし）＋小（ちい）さな語（ご）〉の セット。'
              'うしろの 小（ちい）さな語（ご）で 意味（いみ）が 大（おお）きく かわるよ。',
        ),
        NazoHint(
          tier: 2,
          textJa: '【ヒント T2】ここでの 意味（いみ）は「(計画や 命令を) やりとげる・実行（じっこう）する」。'
              '「つづける」「あとまわしに する」「(人に) にる」では ない ものを えらぼう。',
        ),
        NazoHint(
          tier: 3,
          textJa:
              '【ヒント T3】"an experiment / an order / a plan" を「実行（じっこう）する」ときの '
              '句動詞（くどうし）。うしろの 語（ご）は「外（そと）へ・さいごまで 出（だ）しきる」 むきの もの。'
              '「つづける」むきでは ないよ。',
        ),
      ],
      npcGreyAsset: 'assets/art/scenes_layton/npc_chancellor_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_chancellor_color.webp',
      // §3 lore drip — CH.7: King = First Speaker; the last word is a NAME.
      mysteryFragmentJa: 'たんていメモ：もと・さいしょうが おしえてくれた――\n'
          '「おう」と「さいしょに はなした ひと」は おなじ。'
          'のこる ことばは、その ひとの なまえ ひとつ。',
    ),
    // 城の治癒師 — abstract derivational noun resilience (idx 3)
    Hotspot.npc(
      pos: const Alignment(0.04, 0.40),
      size: 0.16,
      step: _kStepPre1(3),
      teachCard: kDerivationalNounTeach,
      clueLineJa: '「おれた こころが、また 立（た）ちあがる ちから… '
          'その ことばを とりもどせば、この くにも たちなおれる。」',
      framingJa: 'ひろばの すみ、こわれた ふんすいの そばに 治癒師（ちゆし）が いる。\n'
          '英検準1級（きゅう）の ぬきだし語（ご） — '
          '「立（た）ちなおる ちから」を あらわす ちゅうしょう名詞（めいし） — を えらべ。\n'
          'この ことばが もどれば、ひろばに ひかりが さしはじめる。',
      hints: const [
        NazoHint(
          tier: 1,
          textJa: '【ヒント T1】"such ___" の ___ に 入（はい）るのは 名詞（めいし）。'
              '形容詞（けいようし）や 副詞（ふくし）は ここには 入（はい）らないよ。',
        ),
        NazoHint(
          tier: 2,
          textJa: '【ヒント T2】4つは おなじ もとの 語（ご）の 仲間（なかま）。語尾（ごび）で 品詞（ひんし）が きまる。'
              '「〜さ・〜性（せい）」と いう 意味（いみ）の 名詞（めいし）の 形（かたち）を さがそう。',
        ),
        NazoHint(
          tier: 3,
          textJa: '【ヒント T3】語尾（ごび）「-ent」は 形容詞（けいようし）、「-ently」は 副詞（ふくし）、'
              '短（みじか）い もとの 形（かたち）は 動詞（どうし）。のこる 名詞（めいし）── '
              '「立（た）ちなおる ちから」を あらわす 語（ご）が 答（こた）え。',
        ),
      ],
      npcGreyAsset: 'assets/art/scenes_layton/npc_healer_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_healer_color.webp',
      // §3 lore drip — CH.7 PAYOFF: Bookmark #7 completes the sentence + the
      // name; the centre→edge clue (seeded 5級) resolves — colour returns from
      // the centre, mirroring how the silence once spread from it.
      mysteryFragmentJa: 'たんていメモ：7まいめ。しおりが ぜんぶ つながった――\n'
          '「Once, I told a story, and the whole grey world turned to colour.」\n'
          'しずけさは まんなかから ひろがった。いま、いろが まんなかから もどっていく。'
          'さいごの ことばは――「アイラ」。',
    ),
    Hotspot.coin(
      pos: const Alignment(-0.80, -0.50),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'タロ：「…ここ、さむいね。でも きみが ことばを もどすたび、'
          'すこしずつ あたたかくなる。あそこにも、ひとつ…！」',
    ),
    // ── Coin 2: hidden by a colour-drained archway ──────────────────────────
    Hotspot.coin(
      pos: const Alignment(0.72, 0.42),
      size: 0.10,
      coinValue: 1,
      clueLineJa: 'タロ：「…はいいろの アーチの したで、ひとつだけ '
          'いろを なくさずに ひかってる。きみと いっしょに、とりに いこう。」',
    ),
    // ── Observation points (#90 density): tap-to-look 探偵メモ, no puzzle. The
    //    climax — reverent, non-combat; the 7th bookmark stays the healer's payoff.
    Hotspot.observation(
      pos: const Alignment(-0.22, -0.58),
      clueLineJa: 'たんていメモ：いしだたみも、そらも、ぜんぶ はいいろ。'
          'けれど きみが ことばを もどすたび、あしもとから ほんの すこし、いろが にじむ。',
    ),
    Hotspot.observation(
      pos: const Alignment(0.28, 0.18),
      clueLineJa: 'たんていメモ：ひびわれた いしの えんたく。むかし ここで、'
          'くにの だいじな ことが きめられた…と もと・さいしょうが いっていた。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.38, 0.48),
      clueLineJa: 'たんていメモ：かれた ふんすい。みずも こえも、とまって ひさしい。'
          'でも いしの すきまに、ちいさな めが ひとつ だけ のびていた。',
    ),
    Hotspot.observation(
      pos: const Alignment(-0.10, -0.22),
      clueLineJa: 'たんていメモ：ひろばの まんなかに、はいいろの ひとが ひとり。'
          'ひざを かかえ、うつむいている。…ずっと、ひとりだったんだ。',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[6] (英検準1級) at const-eval time.
QuestStep _kStepPre1(int i) => kQuestTowns[6].encounters[i];

// ── Scene registry ──────────────────────────────────────────────────────────

/// Painted コトバ探偵 scenes keyed by 英検 grade. Grades without a scene yet are
/// absent — callers fall back to QuestMapScreen (see [sceneForGrade]).
final Map<String, SceneDef> kScenesByGrade = {
  '5': kTown5Scene,
  '4': kTown4Scene,
  '3': kTown3Scene,
  'pre2': kTownPre2Scene,
  'pre2plus': kTownPre2PlusScene,
  '2': kTown2Scene,
  'pre1': kTownPre1Scene,
};

/// Returns the painted scene for [grade], or null when that grade has no scene
/// yet (caller should route to the level-select map instead).
SceneDef? sceneForGrade(String grade) => kScenesByGrade[grade];

/// The 7 案件 (chapters) in canonical play order, edge→centre (5級→準1級). The
/// 事件簿 ([kCaseLogGradeOrder]) mirrors this; a drift test keeps them identical.
const List<String> kChapterGradeOrder = [
  '5',
  '4',
  '3',
  'pre2',
  'pre2plus',
  '2',
  'pre1',
];

/// The title of the NEXT chapter's scene after [grade] in play order, for the
/// "to be continued" forward-pull on a chapter-clear (episodic narrative hook —
/// NARRATIVE-PRODUCER-RUBRIC N6/N12). Returns null when [grade] is the final
/// chapter (準1級) or is not a known chapter — the caller then shows the arc
/// finale instead of teasing a non-existent next case. Purely a narrative tease:
/// it names the next town, it does NOT navigate (the paywall still gates entry).
String? nextChapterTitleJa(String grade) {
  final i = kChapterGradeOrder.indexOf(grade);
  if (i < 0 || i + 1 >= kChapterGradeOrder.length) return null;
  return kScenesByGrade[kChapterGradeOrder[i + 1]]?.titleJa;
}

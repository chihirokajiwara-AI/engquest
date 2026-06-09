// lib/features/explore/hotspot.dart
// Wave 1 — コトバ探偵 scene model.
//
// Pure-Dart models; NO dart:io, NO Firebase. Every class is const-constructible
// so SceneDef literals live entirely in this file's initialiser.

import 'package:flutter/material.dart';
import '../quest/quest_data.dart';

// ── Hotspot kind ──────────────────────────────────────────────────────────────

/// What kind of tap-target a Hotspot represents.
enum HotspotKind {
  /// A villager NPC that throws a ナゾ (英検 quiz item).
  npc,

  /// A hidden ひらめきコイン in the scenery.
  coin,
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
/// [clueLineJa] for the slime-companion word-clue toward this coin.
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
        kind = HotspotKind.coin;
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
class SceneDef {
  final String backgroundAsset;
  final List<String> parallaxLayers;
  final List<Hotspot> hotspots;
  final String titleJa;

  const SceneDef({
    required this.backgroundAsset,
    this.parallaxLayers = const [],
    required this.hotspots,
    required this.titleJa,
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
/// Teach-first lesson for スラ's greeting ナゾ (_kStep(12), choices Goodbye /
/// Hello! / Thank you / I am sorry). A true beginner can't pick こんにちは out of
/// four untaught English phrases — so we teach all four meanings first.
const TeachCard kGreetingTeach = TeachCard(
  titleJa: 'まず、4つの あいさつを おぼえよう',
  leadJa: 'スラに ことばを かえす まえに、いみを たしかめよう。',
  items: [
    TeachItem('Hello!', 'こんにちは', 'ひとに であった ときの あいさつ'),
    TeachItem('Goodbye.', 'さようなら', 'わかれる ときの あいさつ'),
    TeachItem('Thank you.', 'ありがとう', 'おれいを いう ことば'),
    TeachItem('I am sorry.', 'ごめんなさい', 'あやまる ときの ことば'),
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

final SceneDef kTown5Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town5_lane.webp',
  // Single painted plate for now (parallax drifts the whole plate); sliced
  // far/mid/near bands are a later generation pass.
  parallaxLayers: const [],
  titleJa: 'ことばを失（うしな）った村（むら）',
  hotspots: [
    // ── NPC 1: 灰守（はいもり）セル — the Ember-Keeper / first phonics step ──
    // Encounter index 0 from kQuestTowns[0].encounters (TeachSound /s/).
    // セル tends the village hearth — the only fire that never went out.
    // Her mini-mystery: 「なぜ かまどの ひは きえないの？」→ she was waiting for a listener.
    Hotspot.npc(
      pos: const Alignment(-0.45, 0.10),
      size: 0.20,
      step: _kStep(0),
      clueLineJa: '「かまどの ひが、まだ きえていない。'
          'まだ きける ひとを、まっていたんだ。」',
      framingJa: '灰守（はいもり）セルは、ずっと かまどを まもっていた。\n'
          'サイレントが きてから、村（むら）の ひとは「ひとつの おと」しか だせない。\n'
          'セルの くちから もれる おとは… 「ssss…」\n'
          'ヘビのように、ながく のばす音（おと）。きこえる？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_clockmaker_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_clockmaker_color.webp',
    ),
    // ── NPC 2: スラ — きみの かがみ、いちほ うしろの なかま ─────────────────
    // Encounter index 12 = first QuestEncounter (「Hello!」greeting).
    // スラ is always one step behind: きみが いえたから、ぼくも いえる。
    Hotspot.npc(
      pos: const Alignment(0.30, 0.30),
      size: 0.16,
      step: _kStep(12),
      teachCard: kGreetingTeach,
      clueLineJa: 'ちいさなスライムが口（くち）をひらく… 「…ヘッ…ど…？」\n'
          'ことばが、もうすこしのところで 出（で）てこない。',
      framingJa: 'このスライムの名前（なまえ）は まだ ない。\n'
          'きみが いえたとき、はじめて ぼくも いえる。\n'
          'あいさつの ことばを、きみから おしえてあげよう。\n'
          'スラは いつも、きみの いちほ うしろに いる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.webp',
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
    ),
    // ── Coin: hidden on the lamppost ────────────────────────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.75, -0.35),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'スラ：「…ぷる？ ひかりが どこかに…！ ランプの ちかくかな？ '
          'ぼく、まだ うまく いえないけど… あっち！」',
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
/// scripts/generate_scene_art.py). スラ the companion reuses the 5級 slime art —
/// she travels with the player across every district. SceneView's errorBuilder
/// falls back to the dq night-gradient so the scene renders before art exists.
final SceneDef kTown4Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town4_harbor.webp',
  parallaxLayers: const [],
  titleJa: '風（かぜ）の街（まち）',
  hotspots: [
    // ── NPC 1: りょうし — 川（かわ）べりの漁師（りょうし） / to不定詞 ──────────
    // Encounter index 9: 「Did you come here ___ fish?」(to catch).
    // The harbour's nets hang empty: the word for "why" he came blew away too.
    Hotspot.npc(
      pos: const Alignment(-0.50, 0.18),
      size: 0.19,
      step: _kStep4(9),
      clueLineJa: '「なぜ ここに いるか、だって…？ '
          'それを いう ことばが、かぜに さらわれて しまったんだ。」',
      framingJa: '風（かぜ）の街（まち）の 港（みなと）。あみは からっぽ、ふねは とまったまま。\n'
          'サイレントが きてから、漁師（りょうし）は「なぜ」つりに きたのか'
          '言（い）えなくなった。\n'
          '「Did you come here ___ fish?」— ただしい かたちを えらべ。\n'
          'ことばが もどれば、また うみへ こぎだせる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_fisher_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_fisher_color.webp',
    ),
    // ── NPC 2: 灯台（とうだい）守（もり）の おじいさん / 未来 will ─────────────
    // Encounter index 4: 「I think it ___ rain soon.」(will).
    // He watches the storm wind from the lighthouse; he lost the word for what
    // the sky is about to do.
    Hotspot.npc(
      pos: const Alignment(0.55, -0.28),
      size: 0.18,
      step: _kStep4(4),
      clueLineJa: '「そらが くらい。なにかが おきる…と わかるのに、'
          'それを いう ことばが でてこない。」',
      framingJa: '灯台（とうだい）の うえ。おじいさんが くろい そらを みあげている。\n'
          '「あした」を かたる ことば — 未来（みらい）の will — が きえかけている。\n'
          '「I think it ___ rain soon.」— これから おきる ことを いう かたちは？\n'
          '正（ただ）しく いえたら、おじいさんは かさを かしてくれる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_lampkeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_lampkeeper_color.webp',
    ),
    // ── NPC 3: スラ — きみの いちほ うしろの なかま / 過去 -ed ────────────────
    // Encounter index 2: 「Where did you go?」→「I went to the zoo.」
    // スラ has travelled with you from 5級. Now she tries to tell you where SHE
    // went yesterday — learning the past tense one step behind you, as always.
    Hotspot.npc(
      pos: const Alignment(0.05, 0.34),
      size: 0.15,
      step: _kStep4(2),
      clueLineJa: 'スラ：「…きのう、ぼく、どこかへ いった。'
          'でも それを いう ことばが… きみ、おしえて？」',
      framingJa: 'スラは 5級（きゅう）の村（むら）から ずっと きみと あるいてきた。\n'
          'いまは「きのう」を かたる ことば — 過去（かこ）の かたち — を'
          'おぼえようとしている。\n'
          'きみが いえたら、スラも いえる。いつものように、いちほ うしろで。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.webp',
    ),
    // ── Coin: hidden by the lighthouse lamp ─────────────────────────────────
    Hotspot.coin(
      pos: const Alignment(0.78, -0.55),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'スラ：「…ぷる！ とうだいの あかりの ちかくで、'
          'なにかが きらっと… あそこ、たかいところ！」',
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
/// Art: town3_academy.webp + the librarian/scholar grey→colour pairs. スラ the
/// companion reuses the slime art (she has travelled here from 5級→4級→3級).
final SceneDef kTown3Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town3_academy.webp',
  parallaxLayers: const [],
  titleJa: '学（まな）びの都（みやこ）',
  hotspots: [
    // ── NPC 1: としょかんいん — 言葉（ことば）を まもる 司書 / 現在完了 for ──────
    // Encounter index 3: 「I have worked in this library ___ ten years…」(for).
    Hotspot.npc(
      pos: const Alignment(-0.48, -0.05),
      size: 0.19,
      step: _kStep3(3),
      clueLineJa: '「この としょかんで、わたしは ずっと はたらいてきた。'
          'ことばが しんでも、わたしだけは のこす。」',
      framingJa: '学（まな）びの都（みやこ）の 大（だい）としょかん。'
          'たなは からっぽ、ほんの ことばが きえている。\n'
          '司書（ししょ）は「いままで ずっと」を かたる ことば — '
          '現在完了（げんざいかんりょう）の for — を まもっている。\n'
          '「I have worked in this library ___ ten years.」— どの ことばが はいる？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_librarian_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_librarian_color.webp',
    ),
    // ── NPC 2: がくせい — まだ よみおえていない 学生 / 現在完了 yet ────────────
    // Encounter index 4: 「I have to return this book, but I haven't finished it ___.」(yet)
    Hotspot.npc(
      pos: const Alignment(0.52, 0.10),
      size: 0.17,
      step: _kStep3(4),
      clueLineJa: '「この ほんを かえさなきゃ。でも… まだ よみおわっていないんだ。」',
      framingJa: '中庭（なかにわ）の ベンチ。学生（がくせい）が ほんを かかえて'
          'こまっている。\n'
          '「まだ〜していない」を いう ことば — 現在完了の yet — が でてこない。\n'
          '「I haven\'t finished it ___.」— 否定（ひてい）の文（ぶん）に あう ことばは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_scholar_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_scholar_color.webp',
    ),
    // ── NPC 3: スラ — 都（みやこ）で 再会（さいかい）した なかま / 過去形 ────────
    // Encounter index 0: スラ reunion — 「Where did you sleep last night?」
    Hotspot.npc(
      pos: const Alignment(0.02, 0.40),
      size: 0.15,
      step: _kStep3(0),
      clueLineJa: 'スラ：「やっと 都（みやこ）に ついた！ ぼく、ひとばんじゅう '
          'ことばの れんしゅうを したんだ。きみは どこで ねた？」',
      framingJa: 'スラは 風（かぜ）の街（まち）から きみを おいかけて、'
          'この 都（みやこ）まで きた。\n'
          'いまでは「きのうの こと」を じぶんから 話（はな）せる。'
          'いちほ うしろの なかまが、すこし 大（おお）きくなった。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.webp',
    ),
    // ── Coin: hidden among the library's high shelves ───────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.78, -0.48),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'スラ：「…ぷる！ たかい たなの うえで、なにかが ひかってる。'
          'あんなところ、どうやって とるの…？」',
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
  hotspots: [
    // ── NPC 1: しょうにん — 波止場（はとば）の商人 / 受動態 ───────────────────
    // Encounter index 2: 「Do you know where they are grown?」(passive voice).
    Hotspot.npc(
      pos: const Alignment(-0.50, 0.12),
      size: 0.18,
      step: _kStepPre2(2),
      clueLineJa: '「この香辛料（こうしんりょう）が どこで“育（そだ）てられて”いるか… '
          'それを いう ことばが、波（なみ）に さらわれた。」',
      framingJa: '社会（しゃかい）の港町（みなとまち）。世界中（せかいじゅう）の '
          'しなものが あつまる 大（おお）きな 波止場（はとば）。\n'
          '商人（しょうにん）は「〜される」を かたる ことば — 受動態（じゅどうたい） — '
          'を なくした。\n'
          '「Do you know where they ___ ?」— ものが どう されるかを いう かたちは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_merchant_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_merchant_color.webp',
    ),
    // ── NPC 2: せんちょう — 大船（おおぶね）の船長 / 関係代名詞 who ────────────
    // Encounter index 3: 「What kind of sailor do you respect?」(relative who).
    Hotspot.npc(
      pos: const Alignment(0.50, -0.08),
      size: 0.18,
      step: _kStepPre2(3),
      clueLineJa: '「信（しん）じられる 仲間（なかま）を いい表（あらわ）す ことばが、'
          'もう 出（で）てこないんだ。」',
      framingJa: '埠頭（ふとう）に つながれた 大船（おおぶね）。'
          '船長（せんちょう）が きみを 見定（みさだ）める。\n'
          '「どんな 人（ひと）か」を つなぐ ことば — 関係代名詞（かんけいだいめいし）'
          'who — を なくした。\n'
          '「A sailor ___ never gives up in a storm.」— 人（ひと）を つなぐ かたちは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_captain_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_captain_color.webp',
    ),
    // ── NPC 3: とうだいもり — 港（みなと）の灯（あか）り守 / 関係副詞 where ──────
    // Encounter index 4: 「describe the place ships feel safe」(relative where).
    Hotspot.npc(
      pos: const Alignment(0.78, -0.42),
      size: 0.16,
      step: _kStepPre2(4),
      clueLineJa: '「船（ふね）が やすらぐ“場所（ばしょ）”を いい表（あらわ）す ことば… '
          'それが きえると、灯台（とうだい）の あかりも にぶる。」',
      framingJa: '港（みなと）の はずれの 灯台（とうだい）。'
          'ふるい 灯（あか）り守（もり）が 海（うみ）を みつめている。\n'
          '「〜する 場所（ばしょ）」を つなぐ ことば — 関係副詞（かんけいふくし）'
          'where — を なくした。\n'
          '「the harbour ___ the storms cannot reach」— 場所（ばしょ）を つなぐ かたちは？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_lampkeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_lampkeeper_color.webp',
    ),
    // ── Coin: hidden among the moored ships' rigging ────────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.80, -0.50),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'スラ：「…ぷる！ ふねの ロープの あいだで、なにかが ゆれて ひかってる。'
          'たかい ところだなぁ…！」',
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
  hotspots: [
    // はしの番人 — 現在完了 (idx 0): "I ___ on this bridge since 2025."
    Hotspot.npc(
      pos: const Alignment(-0.48, -0.02),
      size: 0.18,
      step: _kStepPre2Plus(0),
      clueLineJa: '「2025年（ねん）、この橋（はし）が あらたに かけられて から、'
          'わたしは ずっと ここに 立（た）ってきた。」',
      framingJa: '準2級（きゅう）と 2級（きゅう）の あいだに かかる、'
          '長（なが）い 石（いし）の橋（はし）。\n'
          '番人（ばんにん）は「ずっと〜してきた」を かたる ことば — '
          '現在完了（げんざいかんりょう） — で きみの 覚悟（かくご）を 問（と）う。\n'
          '「I ___ on this bridge since 2025.」— どの かたちが はいる？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_gatekeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_gatekeeper_color.webp',
    ),
    // 渡し守 — 関係副詞 where (idx 1): "the place ___ many travellers turn back."
    Hotspot.npc(
      pos: const Alignment(0.50, 0.16),
      size: 0.17,
      step: _kStepPre2Plus(1),
      clueLineJa: '「ここは、おおくの 旅人（たびびと）が ひきかえす“場所（ばしょ）”…'
          'それを いい表（あらわ）す ことばを、きみは もっているか？」',
      framingJa: '橋（はし）の なかほど。渡（わた）し守（もり）が ふかい きりの '
          'たにを 見下（みお）ろしている。\n'
          '「〜する 場所（ばしょ）」を つなぐ ことば — 関係副詞（かんけいふくし）'
          'where — が ためされる。\n'
          '「This is the place ___ many travellers turn back.」',
      npcGreyAsset: 'assets/art/scenes_layton/npc_fisher_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_fisher_color.webp',
    ),
    // Coin — スラ (the companion) voices the hint here, as in every district.
    Hotspot.coin(
      pos: const Alignment(0.04, 0.42),
      size: 0.12,
      coinValue: 1,
      clueLineJa: 'スラ：「この橋（はし）、たかいね…！ でも、らんかんの うえで '
          'なにか ひかってる。きみが いくなら、ぼくも いく。いちほ うしろで。」',
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
  hotspots: [
    // せんせい — academic-register response (idx 0)
    Hotspot.npc(
      pos: const Alignment(-0.50, -0.05),
      size: 0.18,
      step: _kStep2(0),
      clueLineJa: '「もう 十年（じゅうねん）、ここで おしえている… '
          'こういう 話（はなし）に、なんと こたえるのが ふさわしい？」',
      framingJa: '城（しろ）を のぞむ 学者（がくしゃ）の 城下町（じょうかまち）。\n'
          '大人（おとな）どうしの 会話（かいわ）に ふさわしい こたえ方（かた） — '
          '英検2級（きゅう）の 社会（しゃかい）的な やりとり — が ためされる。\n'
          'せんせいの ことばに、ていねいに 共感（きょうかん）する こたえを えらべ。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_librarian_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_librarian_color.webp',
    ),
    // やくにん — passive voice (idx 2): "The new library ___ by the city council."
    Hotspot.npc(
      pos: const Alignment(0.50, -0.10),
      size: 0.17,
      step: _kStep2(2),
      clueLineJa: '「あたらしい 図書館（としょかん）は、市（し）の 議会（ぎかい）に'
          'よって どう されたか… その ことばが 出（で）てこない。」',
      framingJa: '城下町（じょうかまち）の 役所（やくしょ）。\n'
          '「〜された」を かたる ことば — 受動態（じゅどうたい） — が ためされる。\n'
          '「The new library ___ by the city council two years ago.」',
      npcGreyAsset: 'assets/art/scenes_layton/npc_captain_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_captain_color.webp',
    ),
    // がくせい — relative pronoun who (idx 3)
    Hotspot.npc(
      pos: const Alignment(0.06, 0.40),
      size: 0.15,
      step: _kStep2(3),
      clueLineJa: '「この本（ほん）を かいた 教授（きょうじゅ）が、'
          'こんや 城（しろ）の ホールで 講演（こうえん）する… のに、'
          'その“人（ひと）”を つなぐ ことばが…」',
      framingJa: '人（ひと）を つなぐ ことば — 関係代名詞（かんけいだいめいし）'
          'who — が ためされる。\n'
          '「The professor ___ wrote this book is giving a lecture tonight.」',
      npcGreyAsset: 'assets/art/scenes_layton/npc_scholar_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_scholar_color.webp',
    ),
    Hotspot.coin(
      pos: const Alignment(-0.80, -0.48),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'スラ：「…ぷる！ 城（しろ）への かいだんの うえで、'
          'なにか きらっと ひかった！」',
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
  hotspots: [
    // 門の守り手 — advanced collocation make a decision (idx 0)
    Hotspot.npc(
      pos: const Alignment(-0.52, 0.02),
      size: 0.18,
      step: _kStepPre1(0),
      clueLineJa: '「ここから さきは、サイレントの こころの まんなか。'
          'はいる“決断（けつだん）”を、きみは くだせるか？」',
      framingJa: 'すべての 色（いろ）が きえた、しずかな ひろば。'
          'ここが サイレントの こころの まんなか。\n'
          '英検準1級（きゅう）の こなれた 言（い）い回（まわ）し — '
          '「決断（けつだん）を くだす」は make — が ためされる。\n'
          '正（ただ）しい ことばが、灰色（はいいろ）に 最初（さいしょ）の 色（いろ）を もどす。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_gatekeeper_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_gatekeeper_color.webp',
    ),
    // 元・宰相 — phrasal verb carry out (idx 2)
    Hotspot.npc(
      pos: const Alignment(0.48, -0.12),
      size: 0.19,
      step: _kStepPre1(2),
      clueLineJa: '「わたしは かつて、この くにの すべてを “carry out” してきた…'
          'いまは、その ことばさえ おもいだせない。」',
      framingJa: 'ひろばの 中央（ちゅうおう）、ひびわれた 石（いし）の 円卓（えんたく）の そばに、'
          '元（もと）・宰相（さいしょう）が ひとり すわっている。\n'
          'かれは サイレントが くる まえ、この くにを うごかしていた 人（ひと）。\n'
          '句動詞（くどうし）の せいかくな いみ — carry out =「やりとげる」 — '
          'を とりもどせ。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_chancellor_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_chancellor_color.webp',
    ),
    // 城の治癒師 — abstract derivational noun resilience (idx 3)
    Hotspot.npc(
      pos: const Alignment(0.04, 0.40),
      size: 0.16,
      step: _kStepPre1(3),
      clueLineJa: '「おれた こころが、また 立（た）ちあがる ちから… '
          'その ことばを とりもどせば、この くにも たちなおれる。」',
      framingJa: 'ひろばの すみ、こわれた ふんすいの そばに 治癒師（ちゆし）が いる。\n'
          '英検準1級（きゅう）の ぬきだし語（ご） — '
          '「立（た）ちなおる ちから」= resilience（ちゅうしょう名詞） — を えらべ。\n'
          'この ことばが もどれば、ひろばに ひかりが さしはじめる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_healer_grey.webp',
      npcColorAsset: 'assets/art/scenes_layton/npc_healer_color.webp',
    ),
    Hotspot.coin(
      pos: const Alignment(-0.80, -0.50),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'スラ：「…ぷる。ここ、さむいね。でも きみが ことばを もどすたび、'
          'すこしずつ あたたかくなる。あそこにも、ひとつ…！」',
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

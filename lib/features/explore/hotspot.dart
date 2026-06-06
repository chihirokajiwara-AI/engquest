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
  }) : kind = HotspotKind.coin;
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
final SceneDef kTown5Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town5_lane.png',
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
      npcGreyAsset: 'assets/art/scenes_layton/npc_clockmaker_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_clockmaker_color.png',
    ),
    // ── NPC 2: スラ — きみの かがみ、いちほ うしろの なかま ─────────────────
    // Encounter index 12 = first QuestEncounter (「Hello!」greeting).
    // スラ is always one step behind: きみが いえたから、ぼくも いえる。
    Hotspot.npc(
      pos: const Alignment(0.30, 0.30),
      size: 0.16,
      step: _kStep(12),
      clueLineJa: 'ちいさなスライムが口（くち）をひらく… 「…ヘッ…ど…？」\n'
          'ことばが、もうすこしのところで 出（で）てこない。',
      framingJa: 'このスライムの名前（なまえ）は まだ ない。\n'
          'きみが いえたとき、はじめて ぼくも いえる。\n'
          'あいさつの ことばを、きみから おしえてあげよう。\n'
          'スラは いつも、きみの いちほ うしろに いる。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.png',
    ),
    // ── NPC 3: 門番（もんばん） と 時計じい — be動詞 are (Quiz, cloze) ─────────
    // Encounter index 15 = be動詞 人称一致「You ___ a traveller.」cloze.
    // 時計じい stands beside the frozen gate-clock; the gate guard echoes his mystery.
    Hotspot.npc(
      pos: const Alignment(0.68, -0.20),
      size: 0.17,
      step: _kStep(15),
      clueLineJa: '「ここを通（とお）りたいなら……正（ただ）しい言葉（ことば）で答（こた）えてみよ。」\n'
          '門（もん）の かたわらで、おじいさんが とまった 時計（とけい）を みつめている。',
      framingJa: '村（むら）の門（もん）。門番（もんばん）が 立（た）ちはだかる。\n'
          '「You ___ a traveller.」— ことばの かたちを えらべ。\n'
          'かたわらの 時計（とけい）は サイレントが きてから ずっと とまったまま。\n'
          '正（ただ）しい ことばが もどれば、とけいも うごきだす かもしれない。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_gatekeeper_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_gatekeeper_color.png',
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
/// Art: town4_harbor.png + the fisher/lampkeeper grey→colour pairs (generated by
/// scripts/generate_scene_art.py). スラ the companion reuses the 5級 slime art —
/// she travels with the player across every district. SceneView's errorBuilder
/// falls back to the dq night-gradient so the scene renders before art exists.
final SceneDef kTown4Scene = SceneDef(
  backgroundAsset: 'assets/art/scenes_layton/town4_harbor.png',
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
      npcGreyAsset: 'assets/art/scenes_layton/npc_fisher_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_fisher_color.png',
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
      npcGreyAsset: 'assets/art/scenes_layton/npc_lampkeeper_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_lampkeeper_color.png',
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
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.png',
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

// ── Scene registry ──────────────────────────────────────────────────────────

/// Painted コトバ探偵 scenes keyed by 英検 grade. Grades without a scene yet are
/// absent — callers fall back to QuestMapScreen (see [sceneForGrade]).
final Map<String, SceneDef> kScenesByGrade = {
  '5': kTown5Scene,
  '4': kTown4Scene,
};

/// Returns the painted scene for [grade], or null when that grade has no scene
/// yet (caller should route to the level-select map instead).
SceneDef? sceneForGrade(String grade) => kScenesByGrade[grade];

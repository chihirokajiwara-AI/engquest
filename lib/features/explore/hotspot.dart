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
    // ── NPC 1: 時計職人（灰守セル） — the /s/ phoneme phonics step ────────────
    // Encounter index 0 from kQuestTowns[0].encounters (TeachSound /s/).
    // The framing re-casts the phonics ナゾ as a mystery beat.
    Hotspot.npc(
      pos: const Alignment(-0.45, 0.10),
      size: 0.20,
      step: _kStep(0),
      clueLineJa: '「あの時計（とけい）、ずっと止（と）まったまま……'
          'もしかして、なにかの音（おと）がいるのかな？」',
      framingJa: 'この時計台（とけいだい）、サイレントが来（き）てから動（うご）かなくなった。'
          '「ssss…」——ヘビのように ながく のばす音（おと）が 聞（き）こえる？',
      npcGreyAsset: 'assets/art/scenes_layton/npc_clockmaker_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_clockmaker_color.png',
    ),
    // ── NPC 2: スラ（小スライム） — the first greeting QuestEncounter ─────────
    // Encounter index 12 = first QuestEncounter (「Hello!」greeting).
    // framingJa sets up the silent-slime story beat.
    Hotspot.npc(
      pos: const Alignment(0.30, 0.30),
      size: 0.16,
      step: _kStep(12),
      clueLineJa: 'ちいさなスライムが口（くち）をひらく……でも、なんにも出（で）てこない。',
      framingJa: 'このスライム、ずっと ことばを さがしてる。'
          'あいさつの ことばを おしえてあげよう！',
      npcGreyAsset: 'assets/art/scenes_layton/npc_slime_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_slime_color.png',
    ),
    // ── NPC 3: 門番（もんばん） — be動詞 are (Quiz, cloze) ────────────────────
    // Encounter index 15 = be動詞 人称一致「You ___ a traveller.」cloze.
    Hotspot.npc(
      pos: const Alignment(0.68, -0.20),
      size: 0.17,
      step: _kStep(15),
      clueLineJa: '「ここを通（とお）りたいなら……正（ただ）しい言葉（ことば）で答（こた）えてみよ！」',
      framingJa: '村（むら）の門（もん）。門番（もんばん）が立（た）ちはだかる。'
          '正（ただ）しい形（かたち）の動詞（どうし）を選（えら）べ。',
      npcGreyAsset: 'assets/art/scenes_layton/npc_gatekeeper_grey.png',
      npcColorAsset: 'assets/art/scenes_layton/npc_gatekeeper_color.png',
    ),
    // ── Coin: hidden on the lamppost ────────────────────────────────────────
    Hotspot.coin(
      pos: const Alignment(-0.75, -0.35),
      size: 0.11,
      coinValue: 1,
      clueLineJa: 'スラ：「光（ひかり）がどこかに……ランプの近（ちか）くかな？」',
    ),
  ],
);

/// Helper: look up encounter [i] from kQuestTowns[0] at const-eval time.
/// Using a top-level function keeps the SceneDef final initialiser clean while
/// confirming the index is valid. Throws at startup (not runtime) if the town
/// changes structure — an intentional safety trip.
QuestStep _kStep(int i) => kQuestTowns[0].encounters[i];

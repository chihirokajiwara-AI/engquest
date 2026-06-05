// lib/features/quest/battle/quest_town_battle_flow.dart
//
// Drives the complete town playthrough using the サイレントバトル system:
//
//   intro (QuestScreen-style narration)
//     → battle 0 (slice 0, SilentBattleScreen)
//     → battle 1 (slice 1, SilentBattleScreen)
//     → … (one battle per slice)
//     → cleared (QuestScreen-style 声の石 reward)
//
// Pops true when the town is fully cleared (same contract as QuestScreen),
// so QuestMapScreen.onTown does not need to change.
//
// Also acts as the owner of the SilentBattleControllers so they are
// disposed when this widget is removed from the tree.

import 'package:flutter/material.dart';

import '../../../core/fsrs/fsrs_card_repository.dart';
import '../quest_data.dart';
import '../ui/dq_ui.dart';
import 'silent_battle_controller.dart';
import 'silent_battle_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuestTownBattleFlow
// ─────────────────────────────────────────────────────────────────────────────

class QuestTownBattleFlow extends StatefulWidget {
  final QuestTown town;
  final FsrsCardRepository? repository;
  final String? uid;

  /// Design-audit only: skip the intro narration and open straight in battle.
  final bool previewStraightToBattle;

  const QuestTownBattleFlow({
    super.key,
    required this.town,
    this.repository,
    this.uid,
    this.previewStraightToBattle = false,
  });

  @override
  State<QuestTownBattleFlow> createState() => _QuestTownBattleFlowState();
}

enum _FlowPhase { intro, battle, cleared }

class _QuestTownBattleFlowState extends State<QuestTownBattleFlow> {
  static const _stoneNames = [
    'あいさつの石', 'くらしの石', 'まなびの石', 'しゃかいの石',
    'しれんの石', 'がくもんの石', '王（おう）の石',
  ];
  static const _stoneColors = [
    Color(0xFF6FC9FF), Color(0xFF7BE08B), Color(0xFFFFC857),
    Color(0xFF4FD6E0), Color(0xFFC58BEA), Color(0xFFFF8A8A),
    Color(0xFFFFD86A),
  ];

  _FlowPhase _phase = _FlowPhase.intro;
  int _battleIndex = 0;

  late final List<({List<QuestStep> steps, List<int> offsets})> _slices;
  late final List<SilentBattleController> _controllers;

  // Total 声のかけら shards earned across all battles.
  int _totalShards = 0;

  @override
  void initState() {
    super.initState();
    _slices = sliceBattles(widget.town.encounters, sliceSize: 4);
    _controllers = [
      for (final s in _slices)
        SilentBattleController(
          townId: widget.town.id,
          steps: s.steps,
          stepOffsets: s.offsets,
        ),
    ];
    if (widget.previewStraightToBattle) _phase = _FlowPhase.battle;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _townIdx =>
      kQuestTowns.indexWhere((t) => t.id == widget.town.id);
  String get _stoneName =>
      _townIdx >= 0 && _townIdx < _stoneNames.length
          ? _stoneNames[_townIdx]
          : 'こえの石';
  Color get _stoneColor =>
      _townIdx >= 0 && _townIdx < _stoneColors.length
          ? _stoneColors[_townIdx]
          : dqGold;

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _onBattleVictory() {
    // Accumulate shards from the completed battle.
    _totalShards += _controllers[_battleIndex].shards;

    final nextBattle = _battleIndex + 1;
    if (nextBattle >= _slices.length) {
      // All battles done → cleared!
      setState(() => _phase = _FlowPhase.cleared);
    } else {
      setState(() => _battleIndex = nextBattle);
    }
  }

  void _onBattleDefeat() {
    // Keep shards; stay on the same battle (controller already reset).
    setState(() {}); // trigger rebuild so SilentBattleScreen refreshes.
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // If the town has no encounters, fall through to cleared immediately.
    if (widget.town.encounters.isEmpty) {
      return _buildCleared();
    }

    return switch (_phase) {
      _FlowPhase.intro => _buildIntro(),
      _FlowPhase.battle => _buildBattle(),
      _FlowPhase.cleared => _buildCleared(),
    };
  }

  // ── Intro ────────────────────────────────────────────────────────────────

  Widget _buildIntro() {
    return DqScene(
      backgroundAsset:
          'assets/art/scenes/town_${widget.town.eikenLevel}.png',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: dqInk),
                ),
                Expanded(
                  child: Text(
                    '${widget.town.name}（英検${widget.town.eikenLevel}級）',
                    textAlign: TextAlign.center,
                    style: dqText(
                        size: 18, w: FontWeight.w800, color: dqGold),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const Spacer(),
            DqDialogBox(
              speaker: 'ものがたり',
              child: Text(widget.town.intro, style: dqText(size: 15)),
            ),
            const SizedBox(height: 24),
            DqButton(
              label: '▶ ぼうけんを はじめる',
              onTap: () => setState(() => _phase = _FlowPhase.battle),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ── Battle ───────────────────────────────────────────────────────────────

  Widget _buildBattle() {
    final ctrl = _controllers[_battleIndex];
    return SilentBattleScreen(
      key: ValueKey('battle_${widget.town.id}_$_battleIndex'),
      controller: ctrl,
      repository: widget.repository,
      uid: widget.uid,
      onVictory: _onBattleVictory,
      onDefeat: _onBattleDefeat,
    );
  }

  // ── Cleared ──────────────────────────────────────────────────────────────

  Widget _buildCleared() {
    return DqScene(
      backgroundAsset:
          'assets/art/scenes/town_${widget.town.eikenLevel}.png',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            _voiceStone(),
            const SizedBox(height: 20),
            Text(
              '〈$_stoneName〉を手（て）に入（い）れた！',
              textAlign: TextAlign.center,
              style: dqText(
                  size: 18, w: FontWeight.w800, color: _stoneColor),
            ),
            if (_totalShards > 0) ...[
              const SizedBox(height: 8),
              Text(
                '声のかけら × $_totalShards',
                style: dqText(size: 14, color: dqGold),
              ),
            ],
            const SizedBox(height: 16),
            DqDialogBox(
              child: Text(
                widget.town.cleared ??
                    '街（まち）に「ことば」がもどった。つぎの街へ、旅（たび）はつづく。',
                style: dqText(size: 14),
              ),
            ),
            const SizedBox(height: 24),
            DqButton(
              label: '▶ 地図（ちず）にもどる',
              onTap: () => Navigator.of(context).pop(true),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _voiceStone() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 750),
        curve: Curves.elasticOut,
        builder: (context, t, _) => Transform.scale(
          scale: t.clamp(0.0, 1.0),
          child: Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white,
                  _stoneColor,
                  _stoneColor.withAlpha(170),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                    color: _stoneColor.withAlpha(150),
                    blurRadius: 34,
                    spreadRadius: 4),
              ],
            ),
            child:
                const Center(child: Text('💎', style: TextStyle(fontSize: 46))),
          ),
        ),
      );
}

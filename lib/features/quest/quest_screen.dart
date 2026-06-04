// lib/features/quest/quest_screen.dart
// A-KEN Quest — play one town in the 本格 scene framework:
// intro (narration box) → villager dialogue + English quiz (NPC portrait,
// dialogue box, command-window choices) → cleared (声の石 reward).

import 'package:flutter/material.dart';

import '../../core/sound/sound_service.dart';
import 'quest_data.dart';
import 'ui/dq_ui.dart';

class QuestScreen extends StatefulWidget {
  final QuestTown town;

  /// Design-audit only: jump straight to this encounter index (skips intro).
  final int? previewEncounterIndex;
  const QuestScreen({super.key, required this.town, this.previewEncounterIndex});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

enum _Phase { intro, encounter, cleared }

class _QuestScreenState extends State<QuestScreen> {
  // 声の石 per town, by order.
  static const _stoneNames = [
    'あいさつの石', 'くらしの石', 'まなびの石', 'しゃかいの石',
    'しれんの石', 'がくもんの石', '王（おう）の石',
  ];
  static const _stoneColors = [
    Color(0xFF6FC9FF), Color(0xFF7BE08B), Color(0xFFFFC857), Color(0xFF4FD6E0),
    Color(0xFFC58BEA), Color(0xFFFF8A8A), Color(0xFFFFD86A),
  ];

  final _sound = SoundService();
  _Phase _phase = _Phase.intro;
  int _index = 0;
  int? _picked;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    final p = widget.previewEncounterIndex;
    if (p != null && _hasEncounters) {
      _phase = _Phase.encounter;
      _index = p.clamp(0, widget.town.encounters.length - 1);
    }
  }

  QuestEncounter get _enc => widget.town.encounters[_index];
  bool get _hasEncounters => widget.town.encounters.isNotEmpty;
  int get _townIdx => kQuestTowns.indexWhere((t) => t.id == widget.town.id);
  String get _stoneName =>
      _townIdx >= 0 && _townIdx < _stoneNames.length ? _stoneNames[_townIdx] : 'こえの石';
  Color get _stoneColor =>
      _townIdx >= 0 && _townIdx < _stoneColors.length ? _stoneColors[_townIdx] : dqGold;

  // Optional per-town scene art (falls back to the night gradient).
  String get _sceneAsset => 'assets/art/scenes/town_${widget.town.eikenLevel}.png';

  void _start() => setState(() => _phase = _hasEncounters ? _Phase.encounter : _Phase.cleared);

  void _choose(int i) {
    if (_revealed) return;
    setState(() {
      _picked = i;
      _revealed = i == _enc.correctIndex;
      if (_revealed) _sound.playCorrect();
    });
  }

  void _next() {
    setState(() {
      if (_index < widget.town.encounters.length - 1) {
        _index++;
        _picked = null;
        _revealed = false;
      } else {
        _phase = _Phase.cleared;
        _sound.playLevelUp();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      backgroundAsset: _sceneAsset,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: switch (_phase) {
          _Phase.intro => _intro(),
          _Phase.encounter => _encounter(),
          _Phase.cleared => _cleared(),
        },
      ),
    );
  }

  Widget _header(String title) => Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: dqInk),
          ),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: dqText(size: 18, w: FontWeight.w800, color: dqGold)),
          ),
          const SizedBox(width: 48),
        ],
      );

  Widget _intro() {
    return Column(
      children: [
        _header('${widget.town.name}（英検${widget.town.eikenLevel}級）'),
        const Spacer(),
        DqDialogBox(
          speaker: 'ものがたり',
          child: Text(widget.town.intro, style: dqText(size: 15)),
        ),
        const SizedBox(height: 24),
        DqButton(label: _hasEncounters ? '▶ ぼうけんを はじめる' : '準備中', onTap: _hasEncounters ? _start : null),
        const Spacer(),
      ],
    );
  }

  Widget _encounter() {
    final total = widget.town.encounters.length;
    return SingleChildScrollView(
      child: Column(
        children: [
          _header('${_index + 1} / $total'),
          const SizedBox(height: 4),
          // NPC portrait, centered above the dialogue.
          DqPortrait(emoji: _enc.npcEmoji, size: 76),
          const SizedBox(height: 16),
          DqDialogBox(
            speaker: _enc.npcName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_enc.npcLine, style: dqText(size: 19, w: FontWeight.w700)),
                if (_enc.npcLineJa != null) ...[
                  const SizedBox(height: 8),
                  Text(_enc.npcLineJa!, style: dqText(size: 12, color: dqInk, w: FontWeight.w400)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('正（ただ）しい返事（へんじ）をえらぼう', style: dqText(size: 12, color: dqGold)),
          ),
          const SizedBox(height: 8),
          ...List.generate(_enc.choices.length, (i) {
            DqChoiceState st = DqChoiceState.normal;
            if (_revealed && i == _enc.correctIndex) {
              st = DqChoiceState.correct;
            } else if (_picked == i && i != _enc.correctIndex) {
              st = DqChoiceState.wrong;
            }
            return DqChoice(
              label: _enc.choices[i],
              state: st,
              onTap: _revealed ? null : () => _choose(i),
            );
          }),
          if (_revealed) ...[
            const SizedBox(height: 8),
            DqDialogBox(
              speaker: _enc.npcName,
              child: Text(_enc.onCorrect, style: dqText(size: 15)),
            ),
            const SizedBox(height: 16),
            DqButton(label: _index < total - 1 ? '▶ つぎへ' : '▶ 街（まち）をクリア！', onTap: _next),
          ],
          const SizedBox(height: 20),
          _party(),
        ],
      ),
    );
  }

  Widget _cleared() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        _voiceStone(),
        const SizedBox(height: 20),
        Text('〈$_stoneName〉を手（て）に入（い）れた！',
            textAlign: TextAlign.center,
            style: dqText(size: 18, w: FontWeight.w800, color: _stoneColor)),
        const SizedBox(height: 16),
        DqDialogBox(
          child: Text(
            widget.town.cleared ?? '街（まち）に「ことば」がもどった。つぎの街へ、旅（たび）はつづく。',
            style: dqText(size: 14),
          ),
        ),
        const SizedBox(height: 24),
        DqButton(label: '▶ 地図（ちず）にもどる', onTap: () => Navigator.of(context).pop(true)),
        const Spacer(),
      ],
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
                colors: [Colors.white, _stoneColor, _stoneColor.withAlpha(170)],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [BoxShadow(color: _stoneColor.withAlpha(150), blurRadius: 34, spreadRadius: 4)],
            ),
            child: const Center(child: Text('💎', style: TextStyle(fontSize: 46))),
          ),
        ),
      );

  Widget _party() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(children: [
            const DqPortrait(imageAsset: 'assets/art/masters/prince.png', emoji: '🤴', size: 44),
            const SizedBox(height: 2),
            Text('あなた', style: dqText(size: 10, color: dqInk, w: FontWeight.w400)),
          ]),
          const SizedBox(width: 22),
          Column(children: [
            const DqPortrait(imageAsset: 'assets/art/masters/slime.png', emoji: '🟢', size: 44),
            const SizedBox(height: 2),
            Text('スラ', style: dqText(size: 10, color: dqInk, w: FontWeight.w400)),
          ]),
        ],
      );
}

// lib/features/quest/quest_screen.dart
// A-KEN Quest — play one town: intro → choice-based NPC encounters → cleared.

import 'package:flutter/material.dart';

import '../../core/sound/sound_service.dart';
import 'quest_data.dart';

class QuestScreen extends StatefulWidget {
  final QuestTown town;
  const QuestScreen({super.key, required this.town});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

enum _Phase { intro, encounter, cleared }

class _QuestScreenState extends State<QuestScreen> {
  static const _bg = Color(0xFFF5F7FA);
  static const _sky = Color(0xFF4FC3F7);
  static const _ink = Color(0xFF263238);

  // 声の石 (Voice Stone) earned on clearing each town — the DQ-style reward.
  static const _stoneNames = [
    'あいさつの石', 'くらしの石', 'まなびの石', 'しゃかいの石',
    'しれんの石', 'がくもんの石', '王（おう）の石',
  ];
  static const _stoneColors = [
    Color(0xFF4FC3F7), Color(0xFF66BB6A), Color(0xFFFFB300), Color(0xFF26C6DA),
    Color(0xFFAB47BC), Color(0xFFEF5350), Color(0xFFFFD54F),
  ];
  int get _townIdx => kQuestTowns.indexWhere((t) => t.id == widget.town.id);
  String get _stoneName =>
      _townIdx >= 0 && _townIdx < _stoneNames.length ? _stoneNames[_townIdx] : 'こえの石';
  Color get _stoneColor =>
      _townIdx >= 0 && _townIdx < _stoneColors.length ? _stoneColors[_townIdx] : _sky;

  final _sound = SoundService();
  _Phase _phase = _Phase.intro;
  int _index = 0;
  int? _picked;
  bool _revealed = false;

  QuestEncounter get _enc => widget.town.encounters[_index];
  bool get _hasEncounters => widget.town.encounters.isNotEmpty;

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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_sky, Color(0xFF29B6F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${widget.town.name}（英検${widget.town.eikenLevel}級）',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _buildIntro(),
          _Phase.encounter => _buildEncounter(),
          _Phase.cleared => _buildCleared(),
        },
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(color: _sky.withAlpha(20), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: child,
      );

  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(widget.town.name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.town.tagline,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14)),
          const SizedBox(height: 20),
          _card(
            child: Text(widget.town.intro,
                style: const TextStyle(color: Color(0xFF455A64), fontSize: 15, height: 1.6)),
          ),
          const SizedBox(height: 28),
          _primaryButton(_hasEncounters ? 'ぼうけんをはじめる' : '準備中（じゅんびちゅう）', _start,
              enabled: _hasEncounters),
          if (!_hasEncounters) ...[
            const SizedBox(height: 12),
            const Text('この街の会話は準備中です。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildEncounter() {
    final total = widget.town.encounters.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_index + 1) / total,
              minHeight: 8,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation(_sky),
            ),
          ),
          const SizedBox(height: 6),
          Text('${_index + 1} / $total',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
          const SizedBox(height: 12),
          // NPC speech
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _sky.withAlpha(26),
                      shape: BoxShape.circle,
                      border: Border.all(color: _sky.withAlpha(120), width: 2),
                    ),
                    child: Center(
                        child: Text(_enc.npcEmoji, style: const TextStyle(fontSize: 30))),
                  ),
                  const SizedBox(width: 12),
                  Text(_enc.npcName,
                      style: const TextStyle(color: _ink, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                Text(_enc.npcLine,
                    style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
                if (_enc.npcLineJa != null) ...[
                  const SizedBox(height: 6),
                  Text(_enc.npcLineJa!,
                      style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('正しい返事をえらぼう',
              style: TextStyle(color: Color(0xFF607D8B), fontSize: 13)),
          const SizedBox(height: 8),
          ...List.generate(_enc.choices.length, (i) => _choiceTile(i)),
          if (_revealed) ...[
            const SizedBox(height: 8),
            _card(
              child: Row(children: [
                const Text('💬', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_enc.onCorrect,
                      style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _primaryButton(
                _index < total - 1 ? 'つぎへ' : '街（まち）をクリア！', _next),
          ],
          const SizedBox(height: 24),
          _partyFooter(),
        ],
      ),
    );
  }

  /// The hero + companion shown on every encounter — "this is my party".
  Widget _partyFooter() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _partyMember('assets/art/masters/prince.png', 'あなた'),
          const SizedBox(width: 24),
          _partyMember('assets/art/masters/slime.png', 'スラ'),
        ],
      );

  Widget _partyMember(String asset, String label) => Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _sky.withAlpha(120), width: 2),
              boxShadow: [BoxShadow(color: _sky.withAlpha(30), blurRadius: 4)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, color: _sky)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
        ],
      );

  Widget _choiceTile(int i) {
    final isPicked = _picked == i;
    final isCorrect = i == _enc.correctIndex;
    Color border = const Color(0xFFE0E0E0);
    Color bg = Colors.white;
    if (_revealed && isCorrect) {
      border = const Color(0xFF66BB6A);
      bg = const Color(0xFFE8F5E9);
    } else if (isPicked && !isCorrect) {
      border = const Color(0xFFEF9A9A);
      bg = const Color(0xFFFFEBEE);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _revealed ? null : () => _choose(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(children: [
              Expanded(
                child: Text(_enc.choices[i],
                    style: const TextStyle(color: _ink, fontSize: 16)),
              ),
              if (_revealed && isCorrect)
                const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 22)
              else if (isPicked && !isCorrect)
                const Icon(Icons.refresh, color: Color(0xFFEF5350), size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCleared() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _voiceStone(),
            const SizedBox(height: 18),
            Text('${widget.town.name} クリア！',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('〈$_stoneName〉を手（て）に入（い）れた！',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _stoneColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                widget.town.cleared ??
                    '村のみんなと話せたね。つぎの街でも、英語で話してみよう！',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF607D8B), fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            _primaryButton('地図（ちず）にもどる', () => Navigator.of(context).pop(true)),
          ],
        ),
      ),
    );
  }

  /// The recovered 声の石 — blooms in with an elastic pop + colored glow.
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
              boxShadow: [
                BoxShadow(color: _stoneColor.withAlpha(150), blurRadius: 32, spreadRadius: 4),
              ],
            ),
            child: const Center(child: Text('💎', style: TextStyle(fontSize: 46))),
          ),
        ),
      );

  Widget _primaryButton(String label, VoidCallback onTap, {bool enabled = true}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _sky,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCFD8DC),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

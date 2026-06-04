// lib/features/quest/quest_screen.dart
// A-KEN Quest — play one town: intro → choice-based NPC encounters → cleared.

import 'package:flutter/material.dart';

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
      if (!_revealed) _picked = i; // wrong: show feedback, allow retry
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
                  Text(_enc.npcEmoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 10),
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
        ],
      ),
    );
  }

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
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('${widget.town.name} クリア！',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.bold)),
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

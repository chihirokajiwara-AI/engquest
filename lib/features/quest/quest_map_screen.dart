// lib/features/quest/quest_map_screen.dart
// A-KEN Quest — the town map. The hero travels level by level; a student begins
// in the town matching their 英検 level and unlocks the next by clearing a town.

import 'package:flutter/material.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'quest_data.dart';
import 'quest_screen.dart';

class QuestMapScreen extends StatefulWidget {
  /// 英検 level the student starts at ('5','4','3','pre2','2','pre1').
  final String startLevel;
  const QuestMapScreen({super.key, this.startLevel = '5'});

  @override
  State<QuestMapScreen> createState() => _QuestMapScreenState();
}

class _QuestMapScreenState extends State<QuestMapScreen> {
  static const _bg = Color(0xFFF5F7FA);
  static const _sky = Color(0xFF4FC3F7);
  static const _ink = Color(0xFF263238);
  static const _prefKey = 'quest_unlocked_index';

  late final int _startIdx = startingTownIndex(widget.startLevel);
  int _unlocked = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PreferencesService.getInstance();
    final stored = prefs.getInt(_prefKey);
    setState(() {
      _unlocked = stored < _startIdx ? _startIdx : stored;
      _loaded = true;
    });
  }

  Future<void> _saveUnlocked(int idx) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setInt(_prefKey, idx);
  }

  Future<void> _openTown(int i) async {
    final cleared = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => QuestScreen(town: kQuestTowns[i])),
    );
    if (cleared == true && i + 1 > _unlocked) {
      setState(() => _unlocked = i + 1);
      _saveUnlocked(i + 1);
    }
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
        title: const Text('🗺️ ぼうけんの地図',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator(color: _sky))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _prologueCard(),
                  const SizedBox(height: 16),
                  for (var i = 0; i < kQuestTowns.length; i++) _townTile(i),
                ],
              ),
      ),
    );
  }

  Widget _prologueCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF8E1), Color(0xFFFFFDF7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Text('👑', style: TextStyle(fontSize: 28)),
              SizedBox(width: 8),
              Text('あなたの物語（ものがたり）',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 10),
            const Text(kQuestPrologue,
                style: TextStyle(color: Color(0xFF5D4037), fontSize: 14, height: 1.6)),
          ],
        ),
      );

  Widget _townTile(int i) {
    final town = kQuestTowns[i];
    final isSkipped = i < _startIdx; // below the student's starting level
    final isUnlocked = i >= _startIdx && i <= _unlocked;
    final isLocked = i > _unlocked;
    final isStart = i == _startIdx;

    final Color accent = isLocked || isSkipped ? const Color(0xFFB0BEC5) : _sky;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isUnlocked ? () => _openTown(i) : null,
          child: Opacity(
            opacity: isLocked ? 0.5 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withAlpha(isStart ? 180 : 60), width: isStart ? 2 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(28),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('英検${town.eikenLevel}',
                          style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(town.name,
                                style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.bold)),
                          ),
                          if (isStart) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _sky.withAlpha(28),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('スタート',
                                  style: TextStyle(color: _sky, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(
                          isSkipped ? '（あなたのレベルより前の街）' : town.tagline,
                          style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isLocked
                        ? Icons.lock
                        : (isSkipped ? Icons.remove : Icons.arrow_forward_ios),
                    color: const Color(0xFFB0BEC5),
                    size: isLocked || isSkipped ? 20 : 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

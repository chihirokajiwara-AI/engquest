// lib/features/quest/quest_map_screen.dart
// A-KEN Quest — the journey map. The hero travels level by level; a student
// begins in the town matching their 英検 level and unlocks the next by clearing
// a town. Rebuilt to the 本格 (Dragon-Quest-grade) look: a deep-night field, a
// 声の石 / Stones of Voice progress row, and town nodes strung along a glowing
// trail as command-window tiles. Behavior, persistence keys, the level picker,
// and the QuestScreen push are all preserved exactly.

import 'package:flutter/material.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'ui/dq_ui.dart';
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
  static const _prefKey = 'quest_unlocked_index';
  static const _levelKey = 'quest_start_level';

  int _startIdx = 0;
  int _unlocked = 0;
  bool _loaded = false;
  bool _needsPick = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PreferencesService.getInstance();
    final level = prefs.getString(_levelKey);
    if (level == null) {
      setState(() {
        _needsPick = true;
        _loaded = true;
      });
      return;
    }
    final stored = prefs.getInt(_prefKey);
    _startIdx = startingTownIndex(level);
    setState(() {
      _unlocked = stored < _startIdx ? _startIdx : stored;
      _needsPick = false;
      _loaded = true;
    });
  }

  Future<void> _chooseLevel(String level) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setString(_levelKey, level);
    _startIdx = startingTownIndex(level);
    setState(() {
      _unlocked = _startIdx;
      _needsPick = false;
    });
    _saveUnlocked(_startIdx);
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

  /// Number of 声の石 recovered so far: every town strictly below the furthest
  /// unlocked town counts as cleared. Capped at the town count.
  int get _stonesWon => _unlocked.clamp(0, kQuestTowns.length);

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        children: [
          _header(),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator(color: dqGold))
                : _needsPick
                    ? _buildLevelPicker()
                    : _buildJourney(),
          ),
        ],
      ),
    );
  }

  // ── Title bar (replaces the old bright AppBar) ──
  Widget _header() {
    final canBack = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        children: [
          if (canBack)
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios_new, color: dqGold, size: 20),
              ),
            )
          else
            const SizedBox(width: 36),
          Expanded(
            child: Center(
              child: dqBilingual('ぼうけんの地図', 'World Map', jpSize: 19),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ── The journey: prologue, 声の石 progress, then the town trail ──
  Widget _buildJourney() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        _prologuePanel(),
        const SizedBox(height: 14),
        _stonesPanel(),
        const SizedBox(height: 18),
        for (var i = 0; i < kQuestTowns.length; i++) _townNode(i),
      ],
    );
  }

  Widget _prologuePanel() => DqPanel(
        title: 'あなたの物語 / Your Story',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DqPortrait(imageAsset: 'assets/art/masters/hero.png', emoji: '🧭', size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                kQuestPrologue,
                style: dqText(size: 13.5, w: FontWeight.w500, color: dqInk).copyWith(height: 1.7),
              ),
            ),
          ],
        ),
      );

  // ── 声の石 progress: one gem per town, lit gold as it is recovered ──
  Widget _stonesPanel() {
    return DqPanel(
      title: 'こえのいし / Stones of Voice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < kQuestTowns.length; i++) _stone(i < _stonesWon),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: dqBilingual(
              '$_stonesWon / ${kQuestTowns.length} こ',
              'collected',
              jpSize: 13,
              jpColor: dqGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stone(bool lit) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: lit
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [dqGold, dqGoldDeep],
              )
            : null,
        color: lit ? null : dqNight0,
        border: Border.all(color: lit ? dqBorder : dqGoldDeep.withAlpha(110), width: 1.6),
        boxShadow: lit ? [BoxShadow(color: dqGold.withAlpha(150), blurRadius: 8)] : null,
      ),
      child: Icon(
        Icons.brightness_1,
        size: 10,
        color: lit ? const Color(0xFFFFF6DA) : dqGoldDeep.withAlpha(80),
      ),
    );
  }

  /// First-time level select: a student already at, say, 準2級 starts in the
  /// 準2級 town instead of replaying the easy ones.
  Widget _buildLevelPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        const SizedBox(height: 4),
        Center(child: dqBilingual('どの級からはじめますか？', 'Choose your level', jpSize: 20, align: TextAlign.center)),
        const SizedBox(height: 12),
        DqDialogBox(
          child: Text(
            'いま持っている英検の級をえらぶと、その街から旅がはじまります。\n'
            'Pick the Eiken grade you hold — your journey begins from that town.',
            style: dqText(size: 13, w: FontWeight.w500, color: dqInk).copyWith(height: 1.7),
          ),
        ),
        const SizedBox(height: 18),
        for (final t in kQuestTowns)
          DqTile(
            jp: '${_eikenLabel(t.eikenLevel)}・${t.name}',
            en: t.cefr,
            icon: Icons.shield_moon_outlined,
            onTap: () => _chooseLevel(t.eikenLevel),
          ),
      ],
    );
  }

  // ── A town node on the trail ──
  Widget _townNode(int i) {
    final town = kQuestTowns[i];
    final isSkipped = i < _startIdx; // below the student's starting level
    final isUnlocked = i >= _startIdx && i <= _unlocked;
    final isCleared = i < _unlocked && !isSkipped;
    final isLocked = i > _unlocked;
    final isStart = i == _startIdx;
    final isLast = i == kQuestTowns.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The vertical trail + waypoint marker.
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _waypoint(isCleared: isCleared, isUnlocked: isUnlocked, isStart: isStart, isLocked: isLocked || isSkipped),
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : Container(
                          width: 3,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: (isCleared ? dqGold : dqGoldDeep).withAlpha(isLocked ? 50 : 150),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // The town card.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _townCard(
                town: town,
                isStart: isStart,
                isSkipped: isSkipped,
                isCleared: isCleared,
                isLocked: isLocked,
                isUnlocked: isUnlocked,
                onTap: isUnlocked ? () => _openTown(i) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waypoint({
    required bool isCleared,
    required bool isUnlocked,
    required bool isStart,
    required bool isLocked,
  }) {
    final lit = isCleared || isUnlocked;
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCleared ? dqGold : (lit ? dqNight1 : dqNight0),
        border: Border.all(color: lit ? dqBorder : dqGoldDeep.withAlpha(110), width: 2),
        boxShadow: (lit && !isLocked) ? [BoxShadow(color: dqGold.withAlpha(120), blurRadius: 7)] : null,
      ),
      child: Icon(
        isCleared
            ? Icons.check
            : (isLocked ? Icons.lock : Icons.place),
        size: 13,
        color: isCleared ? const Color(0xFF2A1C00) : (isLocked ? dqGoldDeep.withAlpha(120) : dqGold),
      ),
    );
  }

  Widget _townCard({
    required QuestTown town,
    required bool isStart,
    required bool isSkipped,
    required bool isCleared,
    required bool isLocked,
    required bool isUnlocked,
    required VoidCallback? onTap,
  }) {
    final dim = isLocked || isSkipped;
    final borderColor = isStart ? dqGold : dqBorder;
    final borderWidth = isStart ? 2.4 : 2.0;

    return Opacity(
      opacity: isLocked ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dim
                  ? [dqNight0.withAlpha(230), dqNight0.withAlpha(230)]
                  : [dqBox.withAlpha(238), dqNight1.withAlpha(238)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: dim ? dqGoldDeep.withAlpha(120) : borderColor, width: borderWidth),
            boxShadow: dim
                ? null
                : [const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              // Eiken grade crest.
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dqNight0,
                  border: Border.all(color: dim ? dqGoldDeep.withAlpha(130) : dqGold, width: 2),
                  boxShadow: dim ? null : [BoxShadow(color: dqGold.withAlpha(60), blurRadius: 8)],
                ),
                child: Text(
                  _eikenShort(town.eikenLevel),
                  textAlign: TextAlign.center,
                  style: dqText(size: 12, w: FontWeight.w800, color: dim ? dqInk.withAlpha(150) : dqGold, spacing: 0),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            town.name,
                            style: dqText(size: 16, w: FontWeight.w700, color: dim ? dqInk.withAlpha(170) : Colors.white),
                          ),
                        ),
                        if (isStart) ...[
                          const SizedBox(width: 8),
                          _badge('スタート / Start'),
                        ] else if (isCleared) ...[
                          const SizedBox(width: 8),
                          _badge('クリア / Clear'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isSkipped ? '（あなたのレベルより前の街） / Below your level' : town.tagline,
                      style: dqText(size: 12, w: FontWeight.w500, color: dim ? dqInk.withAlpha(130) : dqGold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLocked
                    ? Icons.lock
                    : (isSkipped ? Icons.remove : Icons.play_arrow),
                color: dim ? dqGoldDeep.withAlpha(130) : dqGold,
                size: isUnlocked && !isSkipped ? 22 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: dqBorder, width: 1),
        ),
        child: Text(
          text,
          style: dqText(size: 10, w: FontWeight.w800, color: const Color(0xFF2A1C00), spacing: 0.5),
        ),
      );

  // ── Eiken label helpers (5級 / 準2級 / 準2級+ etc.) ──
  static String _eikenLabel(String level) {
    switch (level) {
      case 'pre2':
        return '英検準2級';
      case 'pre2plus':
        return '英検準2級+';
      case 'pre1':
        return '英検準1級';
      default:
        return '英検$level級';
    }
  }

  static String _eikenShort(String level) {
    switch (level) {
      case 'pre2':
        return '準2\n級';
      case 'pre2plus':
        return '準2+\n級';
      case 'pre1':
        return '準1\n級';
      default:
        return '$level\n級';
    }
  }
}

// lib/features/achievements/achievements_screen.dart
// ENG Quest — Achievement / Badge Gallery (T06)
//
// Displays all achievements in a grid with progress indicators.
// Unlocked badges show in full color; locked ones are dimmed with a progress bar.

import 'package:flutter/material.dart';

import '../../core/firebase/auth_service.dart';
import '../../core/gamification/achievement.dart';
import '../../core/gamification/achievement_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _achievementService = AchievementService();
  final _auth = AuthService();
  Map<String, AchievementState> _states = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = await _auth.getOrCreateUid();
      final states = await _achievementService.init(uid);
      if (mounted) setState(() { _states = states; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'バッジコレクション',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final unlocked = kAchievements
        .where((d) => _states[d.id]?.unlocked == true)
        .toList();
    final locked = kAchievements
        .where((d) => _states[d.id]?.unlocked != true)
        .toList();
    final sorted = [...unlocked, ...locked];

    final unlockedCount =
        _states.values.where((s) => s.unlocked).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                '$unlockedCount / ${kAchievements.length} バッジ獲得',
                style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.85,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final def = sorted[i];
              final state = _states[def.id] ?? AchievementState.empty(def.id);
              return _BadgeCard(def: def, state: state);
            },
          ),
        ),
      ],
    );
  }
}

// ── Badge card widget ─────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final AchievementDef def;
  final AchievementState state;

  const _BadgeCard({required this.def, required this.state});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = state.unlocked;
    final progress = (state.progress / def.target).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: isUnlocked
            ? LinearGradient(
                colors: def.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUnlocked ? null : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? Colors.amber.withAlpha(120)
              : const Color(0xFFE0E0E0),
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: def.gradient.first.withAlpha(80),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? Colors.white.withAlpha(30)
                    : const Color(0xFFF5F7FA),
                border: Border.all(
                  color: isUnlocked
                      ? Colors.white.withAlpha(80)
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Icon(
                def.icon,
                color: isUnlocked ? Colors.white : const Color(0xFFB0BEC5),
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              def.titleJa,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnlocked ? Colors.white : const Color(0xFF607D8B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              def.titleEn,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnlocked ? Colors.white70 : const Color(0xFFB0BEC5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            // Progress bar or "獲得！"
            if (isUnlocked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '獲得！',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        def.gradient.first.withAlpha(180),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.progress} / ${def.target}',
                    style: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

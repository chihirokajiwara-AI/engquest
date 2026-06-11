// lib/features/achievements/achievements_screen.dart
// A-KEN Quest — Achievement / Badge Gallery (T06)
//
// 本格 Dragon-Quest-grade restyle: dark atmospheric scene, navy+cream command
// windows, gold ▶ accents. Unlocked badges glow gold; locked ones are dimmed
// with a progress bar. Achievement data + logic unchanged — UI only.

import 'package:flutter/material.dart';

import '../../core/firebase/auth_service.dart';
import '../../core/gamification/achievement.dart';
import '../../core/gamification/achievement_service.dart';
import '../quest/ui/dq_ui.dart';

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
      if (mounted) {
        setState(() {
          _states = states;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: Column(
        children: [
          _header(context),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: dqGold),
                  )
                : _buildGrid(),
          ),
        ],
      ),
    );
  }

  // ── Dark header: back arrow + gold serif title ──
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: dqInk),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.emoji_events, color: dqGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: dqBilingual(
              '実績',
              'Achievements',
              jpSize: 20,
              jpColor: dqGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final unlocked =
        kAchievements.where((d) => _states[d.id]?.unlocked == true).toList();
    final locked =
        kAchievements.where((d) => _states[d.id]?.unlocked != true).toList();
    final sorted = [...unlocked, ...locked];

    final unlockedCount = _states.values.where((s) => s.unlocked).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: DqPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: dqGold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: dqBilingual(
                    '獲得バッジ',
                    'Badges Earned',
                    jpSize: 14,
                  ),
                ),
                Text(
                  '$unlockedCount / ${kAchievements.length}',
                  style: dqText(size: 18, w: FontWeight.w800, color: dqGold),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
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

    // Unlocked: gold-framed navy panel that glows. Locked: dim navy, faded ink.
    final Color frame = isUnlocked ? dqGold : dqGoldDeep.withAlpha(90);
    final Color iconColor = isUnlocked ? dqGold : dqInk.withAlpha(90);
    final Color titleColor = isUnlocked ? Colors.white : dqInk.withAlpha(120);
    final Color subColor = isUnlocked ? dqGold : dqGoldDeep.withAlpha(120);

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? dqBox.withAlpha(235) : dqNight1.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: frame, width: 2),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: dqGold.withAlpha(70),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon medallion
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dqNight0,
                border: Border.all(color: frame, width: 2),
                boxShadow: isUnlocked
                    ? [BoxShadow(color: dqGold.withAlpha(80), blurRadius: 10)]
                    : null,
              ),
              child: Icon(
                isUnlocked ? def.icon : Icons.lock_outline,
                color: iconColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            // Bilingual title (JP)
            Text(
              def.titleJa,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dqText(size: 13, w: FontWeight.w700, color: titleColor),
            ),
            const SizedBox(height: 2),
            // Bilingual title (EN)
            Text(
              def.titleEn,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dqText(
                  size: 10, w: FontWeight.w600, color: subColor, spacing: 1),
            ),
            const SizedBox(height: 8),
            // Earned nameplate or progress bar
            if (isUnlocked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: dqBorder, width: 1),
                ),
                child: Text(
                  '獲得 / Earned',
                  style: dqText(
                    size: 10,
                    w: FontWeight.w800,
                    color: const Color(0xFF2A1C00),
                    spacing: 0.5,
                  ).copyWith(shadows: const []),
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
                      backgroundColor: dqNight0,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(dqGoldDeep),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.progress} / ${def.target}',
                    style: dqText(
                      size: 10,
                      w: FontWeight.w600,
                      color: dqInk.withAlpha(140),
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

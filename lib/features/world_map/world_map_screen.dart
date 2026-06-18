// lib/features/world_map/world_map_screen.dart
// A-KEN Quest — World Map (はじまりの村 / Village Square)
//
// 本格 (Dragon-Quest-grade) rebuild:
//   - DqScene atmospheric night/gradient field (no bright pastel scaffold)
//   - Player HUD in a DqPanel: gold-framed portrait, Lv + bilingual XP bar, streak
//   - Each zone is a command-window node (DqTile-style) with a bilingual label,
//     a dq-palette icon medallion, and a ▶ cursor
//   - Staggered slide-in entrance preserved
//
// PRESERVED EXACTLY: zone definitions, navigation (pushTarget / route handling),
// childAge, XpService wiring, constructor signatures, public APIs.

import 'package:flutter/material.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/gamification/xp_profile.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/core/ui/page_transitions.dart';
import 'package:engquest/features/battle/grade_selector_screen.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/quest/quest_map_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

// ── Mock player data (fallback when Firestore unavailable) ───────────────────
const _kMockAvatarEmoji = '🧙';
const _kMockStreak = 0; // shown when offline

// ── Zone definition ──────────────────────────────────────────────────────────
// `gradient` is retained as the constructor contract; its first colour is reused
// as the dq-palette accent that tints the zone's icon medallion (frame stays
// navy+cream — never candy-bright).
class _ZoneDef {
  final String label;
  final String en; // English label (bilingual, CEO directive)
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String route;
  final Widget? pushTarget;

  const _ZoneDef({
    required this.label,
    required this.en,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.route,
    this.pushTarget,
  });
}

final List<_ZoneDef> _kZones = [
  _ZoneDef(
    label: 'ぼうけん',
    en: 'Quest',
    subtitle: '街をめぐる英語の旅',
    icon: Icons.map_outlined,
    accent: dqGold,
    route: '/quest',
    pushTarget: const QuestMapScreen(),
  ),
  _ZoneDef(
    label: '鍛冶屋',
    en: 'Blacksmith',
    subtitle: '単語と戦え！',
    icon: Icons.shield_outlined,
    accent: Color(0xFFE0A878), // forge ember (warm bronze, dq-tuned)
    route: '/battle',
  ),
  _ZoneDef(
    label: '広場',
    en: 'Town Crier',
    subtitle: 'NPCと話そう',
    icon: Icons.chat_bubble_outline,
    accent: Color(0xFF8FB8D8), // moonlit slate-blue
    route: '/dialog',
  ),
  _ZoneDef(
    label: 'こだまの洞窟',
    en: 'Echo Cave',
    subtitle: '声に出して練習',
    icon: Icons.mic_none_rounded,
    accent: Color(0xFF9DC9A0), // mossy green
    route: '/voice',
  ),
  _ZoneDef(
    label: '闘技場',
    en: 'Arena',
    subtitle: '英検模擬試験',
    icon: Icons.assignment_outlined,
    accent: Color(0xFFD9A0A0), // arena crimson (dimmed)
    route: '/exam',
  ),
  _ZoneDef(
    label: '学者の塔',
    en: "Scholar's Tower",
    subtitle: '成長を確認',
    icon: Icons.admin_panel_settings_outlined,
    accent: Color(0xFFC2A8DA), // arcane amethyst
    route: '/parent',
    pushTarget: const ParentDashboardScreen(),
  ),
];

// ── WorldMapScreen ────────────────────────────────────────────────────────────

class WorldMapScreen extends StatefulWidget {
  /// Child's age in years — passed to BattleScreen for vocabulary filtering.
  final int childAge;
  const WorldMapScreen({super.key, this.childAge = 8});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _slideCtls;
  late List<Animation<Offset>> _slideAnims;

  // ── XP / Level (P2-7) ──────────────────────────────────────────────────────
  final _xpService = XpService();
  final _auth = AuthService();
  XpProfile? _xpProfile; // null until loaded; UI shows skeleton
  bool _entranceFired = false; // staggered entrance runs once, in didChangeDeps

  @override
  void initState() {
    super.initState();
    _slideCtls = List.generate(
      _kZones.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _slideAnims = _slideCtls
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.6),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    // The staggered entrance is started in didChangeDependencies (it needs a
    // BuildContext to honour prefersReducedMotion — the primary nav hub must not
    // fire a large vestibular-triggering slide when the OS asks for reduced motion).

    // Load real XP profile from Firestore
    _loadXpProfile();

    // Listen to XpService for live updates (e.g. returning from BattleScreen)
    _xpService.profileNotifier.addListener(_onXpProfileUpdated);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fire the entrance ONCE. Honour reduced-motion: a large staggered slide on
    // the primary nav hub is a vestibular trigger (WCAG 2.3.3), so when the OS
    // asks for reduced motion we snap the cards to their final position —
    // visible, zero motion. Mirrors the guard every other animated screen uses.
    if (_entranceFired) return;
    _entranceFired = true;
    final reduce = prefersReducedMotion(context);
    for (var i = 0; i < _slideCtls.length; i++) {
      if (reduce) {
        _slideCtls[i].value = 1.0;
      } else {
        Future.delayed(Duration(milliseconds: i * 200), () {
          if (mounted) _slideCtls[i].forward();
        });
      }
    }
  }

  void _onXpProfileUpdated() {
    final updated = _xpService.profileNotifier.value;
    if (updated != null && mounted) {
      setState(() => _xpProfile = updated);
    }
  }

  Future<void> _loadXpProfile() async {
    try {
      final uid = await _auth.getOrCreateUid();
      if (!mounted) return;
      final profile = await _xpService.init(uid);
      if (mounted) setState(() => _xpProfile = profile);
    } catch (_) {
      // Firebase unavailable — use zero profile (offline cold start)
      if (mounted) setState(() => _xpProfile = XpProfile.zero('offline'));
    }
  }

  @override
  void dispose() {
    _xpService.profileNotifier.removeListener(_onXpProfileUpdated);
    for (final c in _slideCtls) {
      c.dispose();
    }
    super.dispose();
  }

  void _enterZone(_ZoneDef zone) {
    if (zone.pushTarget != null) {
      Navigator.push(
        context,
        FadeSlideRoute(builder: (_) => zone.pushTarget!),
      );
    } else if (zone.route == '/battle') {
      Navigator.push(
        context,
        FadeSlideRoute(
          builder: (_) => GradeSelectorScreen(childAge: widget.childAge),
        ),
      );
    } else if (zone.route == '/exam') {
      Navigator.push(
        context,
        FadeSlideRoute(
          builder: (_) => const ExamPracticeScreen(eikenGrade: '5'),
        ),
      );
    } else {
      Navigator.pushNamed(context, zone.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Scene title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              children: [
                Text(
                  'はじまりの村',
                  textAlign: TextAlign.center,
                  style: dqText(size: 22, w: FontWeight.w800, color: dqGold),
                ),
                const SizedBox(height: 2),
                Text(
                  'VILLAGE SQUARE',
                  textAlign: TextAlign.center,
                  style: dqText(
                      size: 11, w: FontWeight.w700, color: dqInk, spacing: 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Player HUD ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _xpProfile == null
                ? const _XpLoadingSkeleton()
                : _PlayerStatsBar(
                    avatarEmoji: _kMockAvatarEmoji,
                    level: _xpProfile!.level,
                    xp: _xpProfile!.currentLevelXp,
                    xpToNext: _xpProfile!.levelXpSpan,
                    streak: _kMockStreak,
                  ),
          ),
          const SizedBox(height: 16),
          // ── Prompt ───────────────────────────────────────────────────────
          dqBilingual(
            'どこへ行く？',
            'Where to?',
            jpSize: 15,
            jpColor: dqInk,
            align: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // ── Zone command-window nodes ────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              itemCount: _kZones.length,
              itemBuilder: (context, i) {
                final zone = _kZones[i];
                return SlideTransition(
                  position: _slideAnims[i],
                  child: FadeTransition(
                    opacity: _slideCtls[i],
                    child: _ZoneNode(
                      zone: zone,
                      onTap: () => _enterZone(zone),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── XP Loading Skeleton ───────────────────────────────────────────────────────

/// Shown while XpProfile is being loaded from Firestore.
class _XpLoadingSkeleton extends StatelessWidget {
  const _XpLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return DqPanel(
      child: Row(
        children: [
          const DqPortrait(emoji: '…', size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 14,
                  width: 90,
                  decoration: BoxDecoration(
                    color: dqNight1,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: dqNight1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: dqGoldDeep, width: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player Stats Bar ──────────────────────────────────────────────────────────

class _PlayerStatsBar extends StatelessWidget {
  final String avatarEmoji;
  final int level;
  final int xp;
  final int xpToNext;
  final int streak;

  const _PlayerStatsBar({
    required this.avatarEmoji,
    required this.level,
    required this.xp,
    required this.xpToNext,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final xpFraction = (xp / xpToNext).clamp(0.0, 1.0);
    return DqPanel(
      child: Row(
        children: [
          // Gold-framed portrait
          DqPortrait(emoji: avatarEmoji, size: 52),
          const SizedBox(width: 14),
          // Level + bilingual XP bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Lv.$level',
                      style:
                          dqText(size: 18, w: FontWeight.w800, color: dqGold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$xp / $xpToNext XP',
                      style: dqText(size: 12, w: FontWeight.w600, color: dqInk),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Gold XP bar in a cream-bordered well
                Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: dqNight0,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: dqGoldDeep, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: xpFraction,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [dqGold, dqGoldDeep],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Day streak badge
          if (streak > 0) _StreakBadge(streak: streak),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dqNight0,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dqGold, width: 1.5),
        boxShadow: [
          BoxShadow(color: dqGold.withAlpha(60), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            '$streak',
            style: dqText(size: 13, w: FontWeight.w800, color: dqGold),
          ),
          Text(
            'れんぞく',
            style:
                dqText(size: 8, w: FontWeight.w600, color: dqInk, spacing: 1),
          ),
        ],
      ),
    );
  }
}

// ── Zone command-window node ──────────────────────────────────────────────────

class _ZoneNode extends StatefulWidget {
  final _ZoneDef zone;
  final VoidCallback onTap;

  const _ZoneNode({
    required this.zone,
    required this.onTap,
  });

  @override
  State<_ZoneNode> createState() => _ZoneNodeState();
}

class _ZoneNodeState extends State<_ZoneNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final accent = zone.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            widget.onTap();
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [dqBox, dqNight1],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _hovered ? dqGold : dqBorder,
                  width: 2,
                ),
                boxShadow: [
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                  if (_hovered)
                    BoxShadow(color: dqGold.withAlpha(70), blurRadius: 14),
                ],
              ),
              child: Row(
                children: [
                  // Icon medallion (accent-tinted, dq frame)
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dqNight0,
                      border: Border.all(color: accent, width: 2),
                      boxShadow: [
                        BoxShadow(color: accent.withAlpha(70), blurRadius: 8),
                      ],
                    ),
                    child: Icon(zone.icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 16),
                  // Bilingual label + subtitle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        dqBilingual(zone.label, zone.en, jpSize: 17),
                        const SizedBox(height: 3),
                        Text(
                          zone.subtitle,
                          style: dqText(
                              size: 12, w: FontWeight.w500, color: dqInk),
                        ),
                      ],
                    ),
                  ),
                  // ▶ cursor
                  const Icon(Icons.play_arrow, color: dqGold, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// lib/features/world_map/world_map_screen.dart
// ENG Quest — World Map (Village Square) — UI Polish v2 + P2-7 XP wiring
//
// UI Polish sprint additions:
//   - Gradient Card widgets for each zone (using LinearGradient)
//   - Zone-specific icons (sword, speech bubble, mic, shield)
//   - Animated entrance: each card slides in with 200ms stagger from bottom
//   - Player stats bar at top: avatar + level + XP progress bar (real data)
//   - Day streak badge: 🔥 N日連続 when streak > 0
//
// P2-7 XP System wiring:
//   - Loads real XpProfile from XpService (Firestore-backed)
//   - Shows actual level, XP progress bar, totalXp
//   - Falls back to Lv.1 / 0 XP if Firebase unavailable (offline cold start)
//   - Listens to XpService.profileNotifier for live updates after Battle

import 'package:flutter/material.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/gamification/xp_profile.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

// ── Mock player data (fallback when Firestore unavailable) ───────────────────
const _kMockAvatarEmoji = '🧙';
const _kMockStreak     = 0;  // shown when offline

// ── Zone definition ──────────────────────────────────────────────────────────
class _ZoneDef {
  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String route;
  final Widget? pushTarget;

  const _ZoneDef({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.route,
    this.pushTarget,
  });
}

final List<_ZoneDef> _kZones = [
  _ZoneDef(
    label:    'Blacksmith',
    subtitle: 'Battle — 単語と戦え！',
    icon:     Icons.shield_outlined,       // closest to sword in Material
    gradient: [const Color(0xFFB71C1C), const Color(0xFF7F0000)],
    route:    '/battle',
  ),
  _ZoneDef(
    label:    'Town Crier',
    subtitle: 'Dialog — NPCと話そう',
    icon:     Icons.chat_bubble_outline,
    gradient: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
    route:    '/dialog',
  ),
  _ZoneDef(
    label:    'Echo Cave',
    subtitle: 'Voice — 声に出して練習',
    icon:     Icons.mic_none_rounded,
    gradient: [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
    route:    '/voice',
  ),
  _ZoneDef(
    label:    "Scholar's Tower",
    subtitle: 'Parent — 成長を確認',
    icon:     Icons.admin_panel_settings_outlined,
    gradient: [const Color(0xFF4A148C), const Color(0xFF311B92)],
    route:    '/parent',
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
  late List<Animation<Offset>>   _slideAnims;

  // ── XP / Level (P2-7) ──────────────────────────────────────────────────────
  final _xpService = XpService();
  final _auth      = AuthService();
  XpProfile? _xpProfile;  // null until loaded; UI shows skeleton

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

    // Staggered entrance: each card starts 200 ms after the previous
    for (int i = 0; i < _slideCtls.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _slideCtls[i].forward();
      });
    }

    // Load real XP profile from Firestore
    _loadXpProfile();

    // Listen to XpService for live updates (e.g. returning from BattleScreen)
    _xpService.profileNotifier.addListener(_onXpProfileUpdated);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '🏰 Village Square',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Player Stats Bar ─────────────────────────────────────────────
            _xpProfile == null
                // Loading skeleton
                ? const _XpLoadingSkeleton()
                : _PlayerStatsBar(
                    avatarEmoji: _kMockAvatarEmoji,
                    level: _xpProfile!.level,
                    xp: _xpProfile!.currentLevelXp,
                    xpToNext: _xpProfile!.levelXpSpan,
                    streak: _kMockStreak,
                  ),
            const SizedBox(height: 8),
            // ── Zone title ───────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Where will you go?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Zone cards ───────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: _kZones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final zone = _kZones[i];
                  return SlideTransition(
                    position: _slideAnims[i],
                    child: FadeTransition(
                      opacity: _slideCtls[i],
                      child: _GradientZoneCard(
                        zone: zone,
                        onTap: () {
                          if (zone.pushTarget != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => zone.pushTarget!),
                            );
                          } else if (zone.route == '/battle') {
                            // Pass childAge for age-appropriate vocab filtering
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BattleScreen(
                                  childAge: widget.childAge,
                                ),
                              ),
                            );
                          } else {
                            Navigator.pushNamed(context, zone.route);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white12,
              border: Border.all(color: Colors.white12, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(height: 14, width: 80, color: Colors.white12),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(3),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F3460),
              border: Border.all(
                color: const Color(0xFFFFD700).withAlpha(160),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                avatarEmoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Level + XP bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Lv.$level',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$xp / $xpToNext XP',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpFraction,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFD700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Day streak badge
          if (streak > 0)
            _StreakBadge(streak: streak),
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
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6D00), Color(0xFFFF3D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withAlpha(120),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          Text(
            '$streak日連続',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient zone card ────────────────────────────────────────────────────────

class _GradientZoneCard extends StatefulWidget {
  final _ZoneDef zone;
  final VoidCallback onTap;

  const _GradientZoneCard({
    required this.zone,
    required this.onTap,
  });

  @override
  State<_GradientZoneCard> createState() => _GradientZoneCardState();
}

class _GradientZoneCardState extends State<_GradientZoneCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

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
    return GestureDetector(
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
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: zone.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: zone.gradient.first.withAlpha(120),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Icon in frosted circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
                    border: Border.all(
                      color: Colors.white.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    zone.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Labels
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        zone.subtitle,
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

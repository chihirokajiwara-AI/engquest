// lib/features/home/daily_home_screen.dart
// ENG Quest — Daily Home Screen (Retention Hub)
//
// Shown to returning users (onboarding complete) on every app launch.
// Displays:
//   1. Greeting with avatar + level badge
//   2. Streak card: fire emoji + X日連続 + weekly dot indicators
//   3. Today's progress card: goal, session count, FSRS due count
//   4. Quick action 2×2 grid: battle / exam / dialog / voice
//   5. "ワールドマップ" bottom link to WorldMapScreen
//
// Streak data is loaded via StreakService (SharedPreferences-backed).
// XP/level data is loaded via XpService (Firestore-backed, offline-tolerant).

import 'package:flutter/material.dart';
import 'package:engquest/app.dart' show OnboardingStorage;
import 'package:engquest/core/gamification/xp_profile.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/ui/page_transitions.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/battle/grade_selector_screen.dart';
import 'package:engquest/features/dialog/dialog_screen.dart';
import 'package:engquest/features/voice/voice_screen.dart';
import 'package:engquest/features/world_map/world_map_screen.dart';

// ── Avatar mapping ────────────────────────────────────────────────────────────

const Map<String, String> _kAvatarEmoji = {
  'knight': '🧙',
  'mage': '🧝',
  'archer': '🏹',
  'healer': '🌟',
};

String _avatarEmoji(String? avatarId) =>
    _kAvatarEmoji[avatarId] ?? '🧙';

// ── Week day labels ───────────────────────────────────────────────────────────

const List<String> _kDayLabels = ['月', '火', '水', '木', '金', '土', '日'];

// ── Quick action definition ───────────────────────────────────────────────────

class _QuickAction {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}

// ── DailyHomeScreen ───────────────────────────────────────────────────────────

class DailyHomeScreen extends StatefulWidget {
  /// Child age in years — forwarded to BattleScreen / WorldMapScreen.
  final int childAge;

  const DailyHomeScreen({super.key, this.childAge = 8});

  @override
  State<DailyHomeScreen> createState() => _DailyHomeScreenState();
}

class _DailyHomeScreenState extends State<DailyHomeScreen> {
  // ── Services ────────────────────────────────────────────────────────────────
  final _streakService = StreakService();
  // XpService and AuthService are Firebase-backed; created lazily inside the
  // try/catch so that test environments (no Firebase) fall back gracefully
  // without crashing the widget at construction.
  XpService? _xpService;
  AuthService? _auth;

  // ── State ───────────────────────────────────────────────────────────────────
  StreakState _streak = const StreakState.zero();
  XpProfile? _xpProfile;
  String? _avatarId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _onXpUpdated() {
    final updated = _xpService?.profileNotifier.value;
    if (updated != null && mounted) {
      setState(() => _xpProfile = updated);
    }
  }

  Future<void> _loadData() async {
    // Load streak and onboarding prefs (SharedPreferences — always available).
    final streakFuture = _streakService.load();
    final onboardingFuture = OnboardingStorage.loadAsync();

    // Load XP profile (Firestore — may be unavailable in test environments).
    XpProfile xpProfile;
    try {
      // Instantiate inside try/catch: FirebaseAuth.instance throws synchronously
      // if Firebase.initializeApp() has not been called (e.g. unit-test env).
      _auth = AuthService();
      _xpService = XpService();
      _xpService!.profileNotifier.addListener(_onXpUpdated);

      final uid = await _auth!.getOrCreateUid();
      xpProfile = await _xpService!.init(uid);
    } catch (_) {
      xpProfile = XpProfile.zero('offline');
    }

    final streak = await streakFuture;
    final onboarding = await onboardingFuture;

    if (!mounted) return;
    setState(() {
      _streak = streak;
      _avatarId = onboarding?.avatarId;
      _xpProfile = xpProfile;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _xpService?.profileNotifier.removeListener(_onXpUpdated);
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _goToWorldMap() {
    Navigator.of(context).pushReplacement(
      FadeSlideRoute(
        builder: (_) => WorldMapScreen(childAge: widget.childAge),
      ),
    );
  }

  List<_QuickAction> _buildActions() => [
        _QuickAction(
          label: '単語バトル',
          icon: Icons.shield_outlined,
          gradient: const [Color(0xFFFF7043), Color(0xFFE64A19)],
          onTap: () => Navigator.of(context).push(
            FadeSlideRoute(
              builder: (_) => GradeSelectorScreen(childAge: widget.childAge),
            ),
          ),
        ),
        _QuickAction(
          label: '模擬試験',
          icon: Icons.assignment_outlined,
          gradient: const [Color(0xFF5C6BC0), Color(0xFF3949AB)],
          onTap: () => Navigator.of(context).push(
            // Default to 英検5級 — the GradeSelectorScreen can refine grade.
            // We route via GradeSelectorScreen to let users pick their grade
            // before entering the exam, consistent with world map flow.
            FadeSlideRoute(
              builder: (_) => GradeSelectorScreen(childAge: widget.childAge),
            ),
          ),
        ),
        _QuickAction(
          label: '会話練習',
          icon: Icons.chat_bubble_outline,
          gradient: const [Color(0xFF29B6F6), Color(0xFF0288D1)],
          onTap: () => Navigator.of(context).push(
            FadeSlideRoute(builder: (_) => const DialogScenariosScreen()),
          ),
        ),
        _QuickAction(
          label: '発音チェック',
          icon: Icons.mic_none_rounded,
          gradient: const [Color(0xFF66BB6A), Color(0xFF388E3C)],
          onTap: () => Navigator.of(context).push(
            FadeSlideRoute(builder: (_) => const VoiceScreen()),
          ),
        ),
      ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGreeting(context),
              const SizedBox(height: 16),
              _buildStreakCard(context),
              const SizedBox(height: 16),
              _buildTodayCard(context),
              const SizedBox(height: 16),
              _buildQuickActionsGrid(context),
              const SizedBox(height: 24),
              _buildWorldMapLink(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section: Greeting ─────────────────────────────────────────────────────

  Widget _buildGreeting(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final level = _xpProfile?.level ?? 1;

    return Row(
      children: [
        // Avatar circle
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [primary, primary.withAlpha(180)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withAlpha(80),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _avatarEmoji(_avatarId),
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'おかえり！',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF263238),
                    ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Lv.$level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section: Streak Card ──────────────────────────────────────────────────

  Widget _buildStreakCard(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final streak = _streak.currentStreak;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(
                  '$streak日連続',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF7043),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Weekly dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final studied = _streak.studiedOn(i);
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: studied ? primary : const Color(0xFFE0E0E0),
                        boxShadow: studied
                            ? [
                                BoxShadow(
                                  color: primary.withAlpha(100),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: studied
                            ? const Text('✓',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kDayLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: studied
                            ? primary
                            : const Color(0xFF9E9E9E),
                        fontWeight: studied
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section: Today's Progress ─────────────────────────────────────────────

  Widget _buildTodayCard(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Use streak.todayCount as a proxy for sessions completed today.
    // Target: 5 sessions per day (configurable goal).
    const dailyGoal = 5;
    final done = _streak.todayCount.clamp(0, dailyGoal);
    final progress = dailyGoal > 0 ? done / dailyGoal : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today_outlined, color: primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  '今日の目標',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF263238),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$done / $dailyGoal 回',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  done >= dailyGoal ? '達成！🎉' : 'あと${dailyGoal - done}回',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF757575),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 10,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  done >= dailyGoal ? const Color(0xFF66BB6A) : primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // XP progress row
            if (_xpProfile != null) ...[
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '総経験値: ${_xpProfile!.totalXp} XP',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF263238),
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section: Quick Actions Grid ───────────────────────────────────────────

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = _buildActions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'クイックスタート',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF263238),
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: actions.map((a) => _QuickActionCard(action: a)).toList(),
        ),
      ],
    );
  }

  // ── Section: World Map Link ───────────────────────────────────────────────

  Widget _buildWorldMapLink(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: _goToWorldMap,
      icon: Icon(Icons.map_outlined, color: primary),
      label: Text(
        'ワールドマップを見る',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ── Quick Action Card widget ──────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: action.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: action.gradient.first.withAlpha(100),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

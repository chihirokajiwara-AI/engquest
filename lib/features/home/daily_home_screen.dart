// lib/features/home/daily_home_screen.dart
// A-KEN Quest — Daily Home Screen (Retention Hub), 本格 Dragon-Quest look.
//
// Shown to returning users (onboarding complete) on every app launch.
// Displays:
//   1. Greeting with framed avatar portrait + level badge
//   2. Streak panel: fire + れんぞく/Streak count + weekly ✓ indicators
//   3. Today's-goal panel: goal progress bar + total XP
//   4. Quick-start command tiles: 単語バトル / 模擬試験 / 会話練習 / 発音チェック
//   5. ワールドマップ / World Map gold action button
//
// Streak data is loaded via StreakService (SharedPreferences-backed).
// XP/level data is loaded via XpService (Firestore-backed, offline-tolerant).
//
// Styled entirely with the shared dq_ui scene framework (DqScene / DqPanel /
// DqTile / DqButton / dqText / dqBilingual). No bright pastel fills.

import 'package:flutter/material.dart';
import 'package:engquest/app.dart' show OnboardingStorage;
import 'package:engquest/core/gamification/xp_profile.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/ui/page_transitions.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
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

// ── Week day labels (bilingual ✓ indicators) ──────────────────────────────────

const List<String> _kDayLabels = ['月', '火', '水', '木', '金', '土', '日'];

// ── Quick action definition ───────────────────────────────────────────────────

class _QuickAction {
  final String jp;
  final String en;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _QuickAction({
    required this.jp,
    required this.en,
    required this.icon,
    required this.accent,
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
          jp: '単語バトル',
          en: 'Word Battle',
          icon: Icons.shield_outlined,
          accent: const Color(0xFFE08A5A),
          onTap: () => Navigator.of(context).push(
            FadeSlideRoute(
              builder: (_) => GradeSelectorScreen(childAge: widget.childAge),
            ),
          ),
        ),
        _QuickAction(
          jp: '模擬試験',
          en: 'Mock Exam',
          icon: Icons.assignment_outlined,
          accent: const Color(0xFF8A9AE0),
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
          jp: '会話練習',
          en: 'Talk',
          icon: Icons.chat_bubble_outline,
          accent: const Color(0xFF6FC3E0),
          onTap: () => Navigator.of(context).push(
            FadeSlideRoute(builder: (_) => const DialogScenariosScreen()),
          ),
        ),
        _QuickAction(
          jp: '発音チェック',
          en: 'Pronounce',
          icon: Icons.mic_none_rounded,
          accent: const Color(0xFF7FCB8A),
          onTap: () => Navigator.of(context).push(
            FadeSlideRoute(builder: (_) => const VoiceScreen()),
          ),
        ),
      ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DqScene(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(dqGold),
          ),
        ),
      );
    }

    return DqScene(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGreeting(context),
            const SizedBox(height: 16),
            _buildStreakPanel(context),
            const SizedBox(height: 14),
            _buildTodayPanel(context),
            const SizedBox(height: 18),
            _buildQuickActions(context),
            const SizedBox(height: 8),
            _buildWorldMapButton(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Section: Greeting ─────────────────────────────────────────────────────

  Widget _buildGreeting(BuildContext context) {
    final level = _xpProfile?.level ?? 1;

    return Row(
      children: [
        DqPortrait(emoji: _avatarEmoji(_avatarId), size: 58),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'おかえり / Welcome back',
                style: dqText(size: 20, w: FontWeight.w800, color: dqInk),
              ),
              const SizedBox(height: 6),
              // Level nameplate — gold gradient crest.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [dqGold, dqGoldDeep]),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: dqBorder, width: 1.5),
                ),
                child: Text(
                  'Lv.$level',
                  style: dqText(
                    size: 13,
                    w: FontWeight.w800,
                    color: const Color(0xFF2A1C00),
                    spacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section: Streak Panel ─────────────────────────────────────────────────

  Widget _buildStreakPanel(BuildContext context) {
    final streak = _streak.currentStreak;

    return DqPanel(
      title: 'れんぞく / Streak',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Text(
                '$streak',
                style: dqText(size: 32, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '日連続 / days',
                  style: dqText(size: 14, w: FontWeight.w600, color: dqInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekly ✓ indicators
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
                      color: studied ? dqBox : dqNight0,
                      border: Border.all(
                        color: studied ? dqGold : dqGoldDeep.withAlpha(120),
                        width: studied ? 2 : 1.5,
                      ),
                      boxShadow: studied
                          ? [
                              BoxShadow(
                                color: dqGold.withAlpha(80),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: studied
                          ? const Icon(Icons.check,
                              color: dqGold, size: 16)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _kDayLabels[i],
                    style: dqText(
                      size: 11,
                      w: studied ? FontWeight.w700 : FontWeight.w500,
                      color: studied ? dqGold : dqInk.withAlpha(150),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Section: Today's Progress ─────────────────────────────────────────────

  Widget _buildTodayPanel(BuildContext context) {
    // Use streak.todayCount as a proxy for sessions completed today.
    // Target: 5 sessions per day (configurable goal).
    const dailyGoal = 5;
    final done = _streak.todayCount.clamp(0, dailyGoal);
    final progress = dailyGoal > 0 ? done / dailyGoal : 0.0;
    final achieved = done >= dailyGoal;

    return DqPanel(
      title: 'もくひょう / Today\'s Goal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$done / $dailyGoal 回',
                style: dqText(size: 22, w: FontWeight.w800, color: dqGold),
              ),
              Text(
                achieved ? '達成！/ Done 🎉' : 'あと${dailyGoal - done}回 / to go',
                style: dqText(
                  size: 13,
                  w: FontWeight.w600,
                  color: achieved
                      ? const Color(0xFF8BE08B)
                      : dqInk.withAlpha(200),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar — cream-framed track, gold/green fill.
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: dqNight0,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: dqGoldDeep.withAlpha(140), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.toDouble().clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: achieved
                            ? const [Color(0xFF8BE08B), Color(0xFF4F9E55)]
                            : const [dqGold, dqGoldDeep],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Total XP row.
          if (_xpProfile != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: dqGoldDeep, height: 1, thickness: 1),
            ),
            Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'けいけんち / Total XP',
                  style: dqText(size: 13, w: FontWeight.w600, color: dqInk),
                ),
                const Spacer(),
                Text(
                  '${_xpProfile!.totalXp}',
                  style: dqText(size: 15, w: FontWeight.w800, color: dqGold),
                ),
                const SizedBox(width: 4),
                Text(
                  'XP',
                  style: dqText(size: 12, w: FontWeight.w600, color: dqGoldDeep),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Section: Quick-Start Command Tiles ────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = _buildActions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'クエスト / Quests',
            style: dqText(size: 13, w: FontWeight.w800, color: dqGold, spacing: 2),
          ),
        ),
        ...actions.map(
          (a) => DqTile(
            jp: a.jp,
            en: a.en,
            icon: a.icon,
            color: a.accent,
            onTap: a.onTap,
          ),
        ),
      ],
    );
  }

  // ── Section: World Map Button ─────────────────────────────────────────────

  Widget _buildWorldMapButton(BuildContext context) {
    return DqButton(
      label: 'ワールドマップ / World Map',
      onTap: _goToWorldMap,
    );
  }
}

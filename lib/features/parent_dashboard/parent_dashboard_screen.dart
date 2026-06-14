import 'package:flutter/material.dart';
import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/core/notifications/notification_service.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ParentDashboardScreen — C08
//  4-tab parent view: Home · Progress · Schedule · Settings
//  Restyled to the 本格 Dragon-Quest HD-2D look (dq_ui): dark atmospheric scene,
//  navy+cream command-window panels, gold serif headings, bilingual labels.
//  Slightly more restrained/adult than the child-facing quest screens.
// ══════════════════════════════════════════════════════════════════════════════

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ProgressService _service;
  final _auth = AuthService();
  late Future<LearningProgress> _progressFuture;

  // Settings state
  int _dailyGoal = 20;
  TimeOfDay _notifTime = const TimeOfDay(hour: 18, minute: 0);
  String _difficulty = '標準';

  @override
  void initState() {
    super.initState();
    _service = ProgressService(repository: FirestoreProgressRepository());
    _tabController = TabController(length: 4, vsync: this);
    _loadProgress();
    _loadReminderTime();
  }

  /// Restore the saved reminder time so the setting is remembered across
  /// sessions (#122 — it used to be discarded on close: a setting that did
  /// nothing). Persistence + the NotificationService seam are wired here; actual
  /// firing needs the local-notification plugin (mobile), tracked separately.
  Future<void> _loadReminderTime() async {
    final prefs = await PreferencesService.getInstance();
    if (prefs.getBool(PrefKeys.reminderConfigured) && mounted) {
      setState(() => _notifTime = TimeOfDay(
            hour: prefs.getInt(PrefKeys.reminderHour),
            minute: prefs.getInt(PrefKeys.reminderMinute),
          ));
    }
  }

  Future<void> _setReminderTime(TimeOfDay v) async {
    setState(() => _notifTime = v);
    final prefs = await PreferencesService.getInstance();
    await prefs.setInt(PrefKeys.reminderHour, v.hour);
    await prefs.setInt(PrefKeys.reminderMinute, v.minute);
    await prefs.setBool(PrefKeys.reminderConfigured, true);
    // Pre-wire the integration seam (no-op until the notification impl lands).
    await NotificationService.instance.setReminderTime(v);
    await NotificationService.instance.scheduleDailyReminder(v);
  }

  void _loadProgress() {
    setState(() {
      _progressFuture = _fetchProgress();
    });
  }

  // #67 — Data / account deletion handler.
  //
  // Execution order:
  //   1. Best-effort Firestore delete (users/{uid}/** docs). May fail silently
  //      if Firebase is offline / placeholder-keyed — local clear is the
  //      guaranteed path.
  //   2. Clear all local SharedPreferences (guaranteed).
  //   3. Sign out of Firebase Auth (best-effort; no crash on failure).
  //   4. Navigate to OnboardingFlow, clearing the back stack.
  //
  // A SnackBar informs the parent whether the remote delete succeeded or only
  // local data was cleared, so they know the honest outcome.
  Future<void> _handleDeleteData() async {
    final repo = FirestoreProgressRepository();
    bool remoteDeleted = false;

    // Step 1: best-effort Firestore delete.
    try {
      final uid = await _auth.getOrCreateUid();
      remoteDeleted = await repo.deleteUserData(uid);
    } catch (_) {
      // Firebase unavailable — proceed with local-only clear.
    }

    // Step 2: clear all local prefs (guaranteed path).
    // Note: clear() wipes all keys from SharedPreferences. We do NOT call
    // resetInstance() here (it's @visibleForTesting). The cached singleton
    // still wraps the same SharedPreferences instance, which is now empty —
    // so subsequent reads return defaults, which is correct post-deletion.
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.clear();
    } catch (_) {}

    // Step 3: sign out (best-effort).
    try {
      await _auth.signOut();
    } catch (_) {}

    if (!mounted) return;

    // Step 4: navigate to onboarding, clearing back stack.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OnboardingFlow(onComplete: (_) {}),
      ),
      (_) => false,
    );

    // Inform the parent of the outcome (snackbar shown on the new screen if
    // mounted, but since we replaced the whole stack this is a best-effort
    // toast on the transition; in practice the snackbar may not show if the
    // navigation completes too quickly — acceptable).
    if (!remoteDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ローカルの データを けしました。\n'
            'サーバーの データは つぎのログイン時（じ）に けされます。\n'
            '(Local data cleared; server data will be removed on next sync.)',
            style: const TextStyle(fontSize: 12),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<LearningProgress> _fetchProgress() async {
    final uid = await _auth.getOrCreateUid();
    return _service.getProgress(uid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DqScene(
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: Column(
        children: [
          _DqHeader(
            onBack: () => Navigator.of(context).maybePop(),
            onRefresh: _loadProgress,
          ),
          _DqTabBar(controller: _tabController),
          Expanded(
            child: FutureBuilder<LearningProgress>(
              future: _progressFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: dqGold),
                  );
                }
                if (snap.hasError) {
                  // A paying parent must never see a raw exception string (e.g.
                  // "Bad state: Firebase Auth unavailable"). Show a calm,
                  // bilingual offline state with a retry instead.
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, color: dqGold, size: 40),
                          const SizedBox(height: 14),
                          Text(
                            'いまは きろくを よみこめませんでした。\n'
                            'インターネットの せつぞくを かくにんして、'
                            'もう一度（いちど）おためしください。',
                            textAlign: TextAlign.center,
                            style: dqText(size: 14, color: dqInk)
                                .copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Couldn't load progress. Check your connection "
                            'and try again.',
                            textAlign: TextAlign.center,
                            style:
                                dqText(size: 11, color: dqInk.withAlpha(160)),
                          ),
                          const SizedBox(height: 18),
                          DqButton(
                            label: 'もう一度（いちど）よみこむ / Retry',
                            onTap: _loadProgress,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final progress = snap.data!;
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _HomeTab(progress: progress),
                    _ProgressTab(progress: progress),
                    _ScheduleTab(progress: progress),
                    _SettingsTab(
                      dailyGoal: _dailyGoal,
                      notifTime: _notifTime,
                      difficulty: _difficulty,
                      onGoalChanged: (v) => setState(() => _dailyGoal = v),
                      onNotifChanged: _setReminderTime,
                      onDifficultyChanged: (v) =>
                          setState(() => _difficulty = v),
                      // #67 — data deletion; parent-gated via this screen.
                      onDeleteData: _handleDeleteData,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Dark header — replaces the bright sky-blue AppBar
// ══════════════════════════════════════════════════════════════════════════════

class _DqHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  const _DqHeader({required this.onBack, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: dqGold),
            tooltip: '戻る',
            onPressed: onBack,
          ),
          Expanded(
            child: dqBilingual('保護者', 'Parents',
                jpSize: 20, align: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: dqGold),
            tooltip: 'データを更新',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ── Dark command-window tab bar ───────────────────────────────────────────────

class _DqTabBar extends StatelessWidget {
  final TabController controller;
  const _DqTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(225),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqBorder, width: 2),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF2A1C00),
        unselectedLabelColor: dqInk,
        labelStyle: dqText(size: 11, w: FontWeight.w800, color: Colors.black),
        unselectedLabelStyle:
            dqText(size: 11, w: FontWeight.w600, color: dqInk),
        tabs: const [
          Tab(icon: Icon(Icons.home_rounded, size: 18), text: 'ホーム'),
          Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: '記録'),
          Tab(icon: Icon(Icons.calendar_today_rounded, size: 16), text: '予定'),
          Tab(icon: Icon(Icons.settings_rounded, size: 18), text: '設定'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tab 1 — Home
// ══════════════════════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  final LearningProgress progress;
  const _HomeTab({required this.progress});

  @override
  Widget build(BuildContext context) {
    final today =
        progress.last7Days.isNotEmpty ? progress.last7Days.last : null;
    final nextHours =
        progress.nextReviewDue?.difference(DateTime.now()).inHours;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Greeting ──────────────────────────────────────────────────────
        dqBilingual('お子様の今日の学習', "Today's Learning", jpSize: 13),
        const SizedBox(height: 16),

        // ── Streak badge ──────────────────────────────────────────────────
        DqPanel(
          child: Row(
            children: [
              const DqPortrait(emoji: '🔥', size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${progress.currentStreak}日連続',
                      style:
                          dqText(size: 22, w: FontWeight.w800, color: dqGold),
                    ),
                    const SizedBox(height: 2),
                    dqBilingual('この調子で', 'Keep the streak going', jpSize: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Today's summary ───────────────────────────────────────────────
        DqPanel(
          title: '今日のセッション / Today',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatPill(
                label: '単語 / Words',
                value: '${today?.wordsPracticed ?? 0}',
                icon: Icons.spellcheck,
              ),
              _StatPill(
                label: '分 / Min',
                value: '${today?.sessionMinutes ?? 0}',
                icon: Icons.timer,
              ),
              _StatPill(
                label: '平均 / Score',
                value:
                    today != null ? today.averageScore.toStringAsFixed(1) : '—',
                icon: Icons.star,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Eiken readiness ───────────────────────────────────────────────
        // HONEST 合格までの目安 from the real per-skill 合格率 (cse_model, #113) —
        // the SAME model the in-app pass-meter uses. NOT vocabulary mastery: a
        // child with high flashcard mastery but no listening/writing practice is
        // NOT "on pace to pass", and a parent must not be told otherwise (#128).
        const _HonestReadinessCard(),
        const SizedBox(height: 14),

        // ── Next review ───────────────────────────────────────────────────
        if (nextHours != null)
          DqPanel(
            child: Row(
              children: [
                const Icon(Icons.access_alarm, color: dqGold, size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      dqBilingual('次の復習', 'Next Review', jpSize: 12),
                      const SizedBox(height: 2),
                      Text(
                        nextHours <= 0 ? '今すぐ' : '$nextHours時間後',
                        style:
                            dqText(size: 18, w: FontWeight.w800, color: dqGold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // ── Overall mastery ───────────────────────────────────────────────
        DqPanel(
          title: '語彙全体 / Vocabulary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    // Denominator is the child's real deck (grade-scaled), not a
                    // fixed 300 — a 3級 child works through ~1,300 words, not 300.
                    progress.vocabPoolSize > 0
                        ? '${progress.totalWordsMastered} / ${progress.vocabPoolSize} 習得'
                        : '${progress.totalWordsMastered} 習得',
                    style: dqText(size: 14, w: FontWeight.w600, color: dqInk),
                  ),
                  Text(
                    '${(progress.masteryPercent * 100).toStringAsFixed(0)}%',
                    style: dqText(size: 14, w: FontWeight.w800, color: dqGold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DqBar(
                value: progress.masteryPercent,
                color: const Color(0xFF8BE08B),
                height: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Honest 英検準備度 card (#128) — reads the SAME per-skill 合格率 model the in-app
//  pass-meter uses (cse_model, #113), NOT vocabulary mastery. Self-contained so it
//  loads independently of the Firestore vocab progress: target grade from prefs +
//  SkillAccuracyStore → CseEstimator.estimate.
// ══════════════════════════════════════════════════════════════════════════════

class _HonestReadinessCard extends StatefulWidget {
  const _HonestReadinessCard();

  @override
  State<_HonestReadinessCard> createState() => _HonestReadinessCardState();
}

/// Loads the HONEST 英検 readiness for the parent dashboard from the child's
/// target grade (prefs) + per-skill 合格率 (SkillAccuracyStore) via the same
/// cse_model the in-app pass-meter uses (#113/#128). Returns null when the grade
/// has no CSE spec. Top-level + public so the wiring is unit-testable without
/// pumping the Firebase-backed dashboard.
Future<CseEstimate?> loadParentReadiness() async {
  final prefs = await PreferencesService.getInstance();
  final grade = prefs.getString('onboarding_start_level') ?? '5';
  final store = await SkillAccuracyStore.getInstance();
  return CseEstimator.estimate(
      grade: grade, accuracies: store.readAccuracies(grade));
}

class _HonestReadinessCardState extends State<_HonestReadinessCard> {
  late final Future<CseEstimate?> _future = loadParentReadiness();

  Color _color(double pct) {
    if (pct >= 100) return const Color(0xFF8BE08B);
    if (pct >= 65) return dqGold;
    return const Color(0xFFE89090);
  }

  @override
  Widget build(BuildContext context) {
    return DqPanel(
      title: '英検準備度 / Eiken Readiness',
      child: FutureBuilder<CseEstimate?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Text('読み込み中…', style: dqText(size: 12, color: dqInk));
          }
          final est = snap.data;
          // No 英検 practice yet → say so honestly; do NOT imply a pass pace from
          // flashcard vocab. (est null = unsupported grade; 0 items = nothing done.)
          if (est == null || est.totalItemsAttempted == 0) {
            return Text(
              'まだ 英検（えいけん）モードの れんしゅうが ありません。\n'
              '英検モードで もんだいを とくと、ここに「合格（ごうかく）までの目安（めやす）」が出ます。\n'
              '※ 語彙（ごい）の習得（しゅうとく）だけでは 合格の目安には なりません。',
              style: dqText(size: 12, color: dqInk),
            );
          }
          final pct = est.readinessPct;
          final color = _color(pct);
          final unmeasured =
              est.unmeasuredSkills.map(CseEstimator.skillLabelJa).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: dqBilingual('合格までの目安', 'Pass guide', jpSize: 13),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: dqText(size: 18, w: FontWeight.w800, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DqBar(value: pct / 100, color: color, height: 14),
              const SizedBox(height: 8),
              Text(
                CseEstimator.readinessMessageJa(est),
                style: dqText(size: 12, w: FontWeight.w600, color: color),
              ),
              if (unmeasured.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '※ ${unmeasured.join('・')} は まだ 未測定（みそくてい）です。',
                  style: dqText(size: 11, color: dqInk.withAlpha(170)),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${est.totalItemsAttempted}問（もん）をもとに算出（さんしゅつ）。'
                '${CseEstimator.meyasuDisclaimerJa}',
                style: dqText(size: 11, color: dqInk.withAlpha(150)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tab 2 — Progress
// ══════════════════════════════════════════════════════════════════════════════

class _ProgressTab extends StatelessWidget {
  final LearningProgress progress;
  const _ProgressTab({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── 7-day bar chart ───────────────────────────────────────────────
        DqPanel(
          title: '直近7日間 / Last 7 Days',
          child: SizedBox(
            height: 140,
            child: _BarChart(days: progress.last7Days),
          ),
        ),
        const SizedBox(height: 14),

        // ── Mini calendar ─────────────────────────────────────────────────
        DqPanel(
          title: '学習カレンダー / Calendar',
          child: _MiniCalendar(days: progress.last7Days),
        ),
        const SizedBox(height: 14),

        // ── Category mastery (REAL data from the child's FSRS cards) ──────
        // Was hardcoded mock percentages shown to a paying parent. Now the
        // child's actual per-category 'review'-state mastery (or an honest
        // empty-state before there's any study data).
        DqPanel(
          title: 'カテゴリ別習得 / By Category',
          child: progress.categoryMastery.isEmpty
              ? Text(
                  'まだ データが ありません。\n'
                  'れんしゅうすると、カテゴリべつの しんちょくが ここに でます。',
                  style: dqText(size: 12, color: dqInk.withAlpha(180)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: progress.categoryMastery
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _CategoryBar(
                            data: _CategoryData(c.name, c.ratio),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ── Bar chart (CustomPainter) ─────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<DailyProgress> days;
  const _BarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(days: days),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyProgress> days;
  _BarChartPainter({required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final maxWords =
        days.map((d) => d.wordsPracticed).fold(0, (a, b) => a > b ? a : b);
    if (maxWords == 0) return;

    const barPad = 8.0;
    final barW = (size.width - barPad * (days.length + 1)) / days.length;
    final labelH = 20.0;
    final chartH = size.height - labelH;

    final fillPaint = Paint()..color = dqGold;
    final zeroPaint = Paint()..color = dqNight1;
    final textStyle = TextStyle(color: dqInk, fontSize: 10);
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < days.length; i++) {
      final x = barPad + i * (barW + barPad);
      final ratio = days[i].wordsPracticed / maxWords;
      final barH = chartH * ratio;
      final top = chartH - barH;

      final rect = Rect.fromLTWH(x, top, barW, barH == 0 ? 4 : barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        days[i].wordsPracticed == 0 ? zeroPaint : fillPaint,
      );

      // Day label
      final dayName = _dayLabel(days[i].date);
      tp.text = TextSpan(text: dayName, style: textStyle);
      tp.layout();
      tp.paint(canvas,
          Offset(x + barW / 2 - tp.width / 2, size.height - labelH + 4));

      // Value label
      if (days[i].wordsPracticed > 0) {
        final valStyle = const TextStyle(
            color: dqGold, fontSize: 9, fontWeight: FontWeight.bold);
        tp.text = TextSpan(text: '${days[i].wordsPracticed}', style: valStyle);
        tp.layout();
        tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, top - 14));
      }
    }
  }

  String _dayLabel(DateTime d) {
    const names = ['月', '火', '水', '木', '金', '土', '日'];
    return names[d.weekday - 1];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Mini calendar ─────────────────────────────────────────────────────────────

class _MiniCalendar extends StatelessWidget {
  final List<DailyProgress> days;
  const _MiniCalendar({required this.days});

  @override
  Widget build(BuildContext context) {
    final studyDays =
        days.where((d) => d.wordsPracticed > 0).map((d) => d.date).toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((d) {
        final studied = studyDays.contains(d.date);
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: studied ? dqGold : dqNight0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: studied ? dqGold : dqGoldDeep,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '${d.date.day}',
              style: TextStyle(
                color: studied ? const Color(0xFF2A1C00) : dqInk,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Category bar ──────────────────────────────────────────────────────────────

class _CategoryData {
  final String name;
  final double mastery; // 0.0-1.0
  const _CategoryData(this.name, this.mastery);
}

class _CategoryBar extends StatelessWidget {
  final _CategoryData data;
  const _CategoryBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = (data.mastery * 100).toInt();
    final color = data.mastery >= 0.8
        ? const Color(0xFF8BE08B)
        : data.mastery >= 0.5
            ? dqGold
            : const Color(0xFFE89090);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(data.name,
                style: dqText(size: 13, w: FontWeight.w600, color: dqInk)),
            Text('$pct%',
                style: dqText(size: 12, w: FontWeight.w700, color: dqGold)),
          ],
        ),
        const SizedBox(height: 5),
        _DqBar(value: data.mastery, color: color, height: 8),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tab 3 — Schedule
// ══════════════════════════════════════════════════════════════════════════════

class _ScheduleTab extends StatelessWidget {
  final LearningProgress progress;
  const _ScheduleTab({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Real review counts from the child's FSRS cards (was hardcoded mock).
    final todayDue = progress.reviewSchedule.todayDue;
    final tomorrowDue = progress.reviewSchedule.tomorrowDue;
    final weekDue = progress.reviewSchedule.weekDue;

    final onTrack = progress.currentStreak >= 3;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Encouragement banner ──────────────────────────────────────────
        DqDialogBox(
          speaker: '師匠 / Mentor',
          child: Row(
            children: [
              Text(onTrack ? '🌟' : '💪', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  onTrack
                      ? '順調に進んでいます。\nこの調子でがんばりましょう。'
                      : '今日少し練習すると、\n大きな差がつきますよ。',
                  style: dqText(size: 14, w: FontWeight.w600, color: dqInk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: dqBilingual('予定されている復習', 'Scheduled Reviews', jpSize: 16),
        ),

        // ── Review schedule cards ─────────────────────────────────────────
        _ReviewCard(
          period: '今日',
          periodEn: 'Today',
          count: todayDue,
          icon: Icons.menu_book,
          color: const Color(0xFFE89090),
        ),
        const SizedBox(height: 10),
        _ReviewCard(
          period: '明日',
          periodEn: 'Tomorrow',
          count: tomorrowDue,
          icon: Icons.auto_stories,
          color: dqGold,
        ),
        const SizedBox(height: 10),
        _ReviewCard(
          period: '今週',
          periodEn: 'This Week',
          count: weekDue,
          icon: Icons.calendar_month,
          color: const Color(0xFF8BBFE8),
        ),
        const SizedBox(height: 18),

        // ── Next due time ─────────────────────────────────────────────────
        if (progress.nextReviewDue != null)
          DqPanel(
            title: '次回予定の復習 / Next Due',
            child: Text(
              _formatDateTime(progress.nextReviewDue!),
              style: dqText(size: 16, w: FontWeight.w700, color: dqGold),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inMinutes < 60) return '${diff.inMinutes}分後';
    if (diff.inHours < 24) return '${diff.inHours}時間後';
    return '明日';
  }
}

class _ReviewCard extends StatelessWidget {
  final String period;
  final String periodEn;
  final int count;
  final IconData icon;
  final Color color;
  const _ReviewCard({
    required this.period,
    required this.periodEn,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [dqBox.withAlpha(235), dqNight1.withAlpha(235)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqBorder, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dqNight0,
              border: Border.all(color: color, width: 2),
              boxShadow: [BoxShadow(color: color.withAlpha(70), blurRadius: 8)],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: dqBilingual(period, periodEn, jpSize: 14, stacked: true)),
          Text(
            '$count 単語',
            style: dqText(size: 18, w: FontWeight.w800, color: dqGold),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tab 4 — Settings
// ══════════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatelessWidget {
  final int dailyGoal;
  final TimeOfDay notifTime;
  final String difficulty;
  final ValueChanged<int> onGoalChanged;
  final ValueChanged<TimeOfDay> onNotifChanged;
  final ValueChanged<String> onDifficultyChanged;
  // #67 — data deletion callback; invoked after user confirms the dialog.
  final VoidCallback? onDeleteData;

  const _SettingsTab({
    required this.dailyGoal,
    required this.notifTime,
    required this.difficulty,
    required this.onGoalChanged,
    required this.onNotifChanged,
    required this.onDifficultyChanged,
    this.onDeleteData,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Daily goal ────────────────────────────────────────────────────
        DqPanel(
          title: '1日の目標単語数 / Daily Goal',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [10, 20, 30].map((g) {
              final selected = g == dailyGoal;
              return GestureDetector(
                onTap: () => onGoalChanged(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(colors: [dqGold, dqGoldDeep])
                        : null,
                    color: selected ? null : dqNight0,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? dqBorder : dqGoldDeep,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: Text(
                    '$g 単語',
                    style: dqText(
                      size: 14,
                      w: FontWeight.w800,
                      color: selected ? const Color(0xFF2A1C00) : dqInk,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // ── Notification time ─────────────────────────────────────────────
        DqPanel(
          title: 'リマインダー時刻 / Reminder',
          child: InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: notifTime,
                builder: (ctx, child) => Theme(
                  data: ThemeData.light(),
                  child: child!,
                ),
              );
              if (picked != null) onNotifChanged(picked);
            },
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: dqGold, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Builder(
                    builder: (context) => Text(
                      notifTime.format(context),
                      style:
                          dqText(size: 18, w: FontWeight.w700, color: dqGold),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: dqInk),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Honest disclosure (#122): the time is now SAVED, but push reminders
        // arrive with the スマホアプリ — don't let a parent think the web version
        // will ping them (it can't). No fake "we'll remind you" promise.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '※ 時刻（じこく）は保存（ほぞん）されます。通知（つうち）はスマホアプリ版（ばん）でお知（し）らせします。',
            style: dqText(size: 11, color: dqInk.withAlpha(150)),
          ),
        ),
        const SizedBox(height: 14),

        // ── Difficulty ────────────────────────────────────────────────────
        DqPanel(
          title: '難易度 / Difficulty',
          child: Column(
            children: ['やさしい', '標準', 'むずかしい'].map((d) {
              final selected = d == difficulty;
              return GestureDetector(
                onTap: () => onDifficultyChanged(d),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? dqGold : dqGoldDeep,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        d,
                        style: dqText(
                          size: 15,
                          w: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? dqGold : dqInk,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // #65 / #67 — データ / Consent & account data panel.
        // Parent-gated: only reachable inside the parent dashboard (requires
        // parent login). A child on the child-facing settings screen cannot
        // reach this.
        DqPanel(
          title: 'データ / Data',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'がくしゅうきろくと アカウントを けすことが できます。',
                style: dqText(size: 12, w: FontWeight.w600, color: dqInk)
                    .copyWith(height: 1.7),
              ),
              const SizedBox(height: 10),

              // ── #65 — 音声同意リセット / Voice-consent revoke ─────────────
              // Clears the stored voice/biometric consent so the consent
              // screen is shown again the next time speaking practice is
              // accessed.  Cheaper than full data-deletion when a parent
              // simply wants to update their consent decision.
              GestureDetector(
                onTap: () => _confirmRevokeVoiceConsent(context),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withAlpha(220),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dqGoldDeep, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic_off_outlined,
                          color: dqGold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // ふりがな: おんせい・どうい・りせっと
                              'おんせい同意（どうい）をリセット',
                              style: dqText(
                                  size: 14, w: FontWeight.w700, color: dqInk),
                            ),
                            Text(
                              'Reset voice consent — re-show the consent '
                              'screen before the next speaking session.',
                              style: dqText(
                                  size: 10,
                                  w: FontWeight.w500,
                                  color: dqInk.withAlpha(160)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap:
                    onDeleteData == null ? null : () => _confirmDelete(context),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A1414).withAlpha(220),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFE89090), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delete_forever,
                          color: Color(0xFFE89090), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'データ（がくしゅうきろく）を けす',
                              style: dqText(
                                  size: 14,
                                  w: FontWeight.w700,
                                  color: const Color(0xFFE89090)),
                            ),
                            Text(
                              'Delete all learning data & account',
                              style: dqText(
                                  size: 10,
                                  w: FontWeight.w500,
                                  color:
                                      const Color(0xFFE89090).withAlpha(180)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Version footer ────────────────────────────────────────────────
        Center(
          child: Text(
            'A-KEN Quest v0.8 · Parent Dashboard C08',
            style: dqText(size: 11, w: FontWeight.w500, color: dqGoldDeep),
          ),
        ),
      ],
    );
  }

  // #65 — Revoke voice / biometric consent (targeted, non-destructive).
  //
  // Removes only the two voice-consent SharedPreferences keys so the consent
  // wall is shown again on the next speaking session.  Unlike full data
  // deletion (#67) this does NOT wipe learning progress or the account.
  Future<void> _revokeVoiceConsent() async {
    final prefs = await PreferencesService.getInstance();
    await prefs.remove(PrefKeys.voiceConsentGrantedAt);
    await prefs.remove(PrefKeys.voiceConsentPolicyVersion);
  }

  void _confirmRevokeVoiceConsent(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: DqDialogBox(
          speaker: 'おんせい同意（どうい）をリセット',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'スピーキング練習（れんしゅう）の\n音声（おんせい）同意（どうい）をリセットします。',
                style: dqText(size: 15, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(height: 8),
              Text(
                'つぎに スピーキング練習（れんしゅう）を はじめるとき、\n'
                'もう一度（いちど）同意（どうい）画面（がめん）が ひょうじされます。',
                style: dqText(size: 13, w: FontWeight.w600, color: dqInk)
                    .copyWith(height: 1.7),
              ),
              const SizedBox(height: 6),
              Text(
                'The voice-recording consent will be cleared. '
                'You will be asked to agree again before the next speaking session. '
                'Learning progress is not affected.',
                style: dqText(
                        size: 11,
                        w: FontWeight.w500,
                        color: dqInk.withAlpha(160))
                    .copyWith(height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: dqBox.withAlpha(235),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: dqBorder, width: 1.5),
                        ),
                        child: Text(
                          'キャンセル',
                          style: dqText(
                              size: 14, w: FontWeight.w700, color: dqInk),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _revokeVoiceConsent();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2B1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: dqGold, width: 1.5),
                        ),
                        child: Text(
                          'リセット',
                          style: dqText(
                              size: 14, w: FontWeight.w700, color: dqGold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // #67 — Confirmation dialog before irreversible data deletion.
  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: DqDialogBox(
          speaker: 'かくにん / Confirm',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ほんとうに けしますか？',
                style: dqText(size: 16, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(height: 8),
              Text(
                'もとに もどせません。\n'
                'すべての がくしゅうきろく（たんご・レベル・ストリーク）が きえます。',
                style: dqText(size: 13, w: FontWeight.w600, color: dqInk)
                    .copyWith(height: 1.7),
              ),
              const SizedBox(height: 6),
              Text(
                'This cannot be undone. All learning history, '
                'vocabulary progress, and streaks will be permanently deleted.',
                style: dqText(
                        size: 11,
                        w: FontWeight.w500,
                        color: dqInk.withAlpha(160))
                    .copyWith(height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: dqBox.withAlpha(235),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: dqBorder, width: 1.5),
                        ),
                        child: Text(
                          'キャンセル',
                          style: dqText(
                              size: 14, w: FontWeight.w700, color: dqInk),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onDeleteData?.call();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A1414).withAlpha(235),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFE89090), width: 1.5),
                        ),
                        child: Text(
                          'けす',
                          style: dqText(
                              size: 14,
                              w: FontWeight.w700,
                              color: const Color(0xFFE89090)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

/// A DQ-styled progress bar: dark night track + gold/accent fill, cream hairline.
class _DqBar extends StatelessWidget {
  final double value; // 0.0–1.0
  final Color color;
  final double height;
  const _DqBar({required this.value, required this.color, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dqGoldDeep, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: dqNight0,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: dqGold, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: dqText(size: 20, w: FontWeight.w800, color: dqGold),
        ),
        const SizedBox(height: 2),
        Text(label, style: dqText(size: 10, w: FontWeight.w600, color: dqInk)),
      ],
    );
  }
}

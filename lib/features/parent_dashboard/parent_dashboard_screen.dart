import 'package:flutter/material.dart';
import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/core/notifications/notification_service.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

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
                            style: dqText(size: 14, color: dqInk).copyWith(
                                height: 1.6),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Couldn't load progress. Check your connection "
                            'and try again.',
                            textAlign: TextAlign.center,
                            style: dqText(
                                size: 11, color: dqInk.withAlpha(160)),
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
        unselectedLabelStyle: dqText(size: 11, w: FontWeight.w600, color: dqInk),
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
                      style: dqText(
                          size: 22, w: FontWeight.w800, color: dqGold),
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
                value: today != null
                    ? today.averageScore.toStringAsFixed(1)
                    : '—',
                icon: Icons.star,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Eiken readiness ───────────────────────────────────────────────
        DqPanel(
          title: '英検準備度 / Eiken Readiness',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: dqBilingual('合格までの目安', 'Progress', jpSize: 13),
                  ),
                  Text(
                    '${progress.eikenReadiness.toStringAsFixed(1)}%',
                    style: dqText(
                        size: 18, w: FontWeight.w800, color: dqGold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DqBar(
                value: progress.eikenReadiness / 100,
                color: _readinessColor(progress.eikenReadiness),
                height: 14,
              ),
              const SizedBox(height: 8),
              Text(
                _readinessLabel(progress.eikenReadiness),
                style: dqText(
                    size: 12,
                    w: FontWeight.w600,
                    color: _readinessColor(progress.eikenReadiness)),
              ),
            ],
          ),
        ),
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
                        style: dqText(
                            size: 18, w: FontWeight.w800, color: dqGold),
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
                    '${progress.totalWordsMastered} / 300 習得',
                    style: dqText(size: 14, w: FontWeight.w600, color: dqInk),
                  ),
                  Text(
                    '${(progress.masteryPercent * 100).toStringAsFixed(0)}%',
                    style: dqText(
                        size: 14, w: FontWeight.w800, color: dqGold),
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

  Color _readinessColor(double r) {
    if (r >= 80) return const Color(0xFF8BE08B);
    if (r >= 50) return dqGold;
    return const Color(0xFFE89090);
  }

  String _readinessLabel(double r) {
    if (r >= 80) return '英検5級合格ペースです';
    if (r >= 50) return '順調に進んでいます';
    return 'もう少し練習しましょう';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tab 2 — Progress
// ══════════════════════════════════════════════════════════════════════════════

class _ProgressTab extends StatelessWidget {
  final LearningProgress progress;
  const _ProgressTab({required this.progress});

  // Category mock data
  static const _categories = [
    _CategoryData('Animals 🐾', 0.82),
    _CategoryData('Food 🍎', 0.65),
    _CategoryData('Colors 🎨', 0.91),
    _CategoryData('Numbers 🔢', 0.74),
    _CategoryData('Family 👨‍👩‍👧', 0.55),
    _CategoryData('Transport 🚗', 0.40),
  ];

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

        // ── Category mastery ──────────────────────────────────────────────
        DqPanel(
          title: 'カテゴリ別習得 / By Category',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _categories
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _CategoryBar(data: c),
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
    // Mock review counts
    const todayDue = 12;
    const tomorrowDue = 8;
    const weekDue = 45;

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
        const _ReviewCard(
          period: '今日',
          periodEn: 'Today',
          count: todayDue,
          icon: Icons.menu_book,
          color: Color(0xFFE89090),
        ),
        const SizedBox(height: 10),
        const _ReviewCard(
          period: '明日',
          periodEn: 'Tomorrow',
          count: tomorrowDue,
          icon: Icons.auto_stories,
          color: dqGold,
        ),
        const SizedBox(height: 10),
        const _ReviewCard(
          period: '今週',
          periodEn: 'This Week',
          count: weekDue,
          icon: Icons.calendar_month,
          color: Color(0xFF8BBFE8),
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
          Expanded(child: dqBilingual(period, periodEn, jpSize: 14, stacked: true)),
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

  const _SettingsTab({
    required this.dailyGoal,
    required this.notifTime,
    required this.difficulty,
    required this.onGoalChanged,
    required this.onNotifChanged,
    required this.onDifficultyChanged,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
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
                      style: dqText(size: 18, w: FontWeight.w700, color: dqGold),
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
        Text(label,
            style: dqText(size: 10, w: FontWeight.w600, color: dqInk)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';
import 'package:engquest/core/firebase/auth_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ParentDashboardScreen — C08
//  4-tab parent view: Home · Progress · Schedule · Settings
//
//  All data is real — loaded from Firestore FSRS card state and session docs.
//  No hardcoded mock values. When data is absent, honest "no data yet" messages
//  are shown instead of fabricated progress.
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
  late final AuthService _authService;
  late Future<LearningProgress> _progressFuture;

  // Settings state
  int _dailyGoal = 20;
  TimeOfDay _notifTime = const TimeOfDay(hour: 18, minute: 0);
  String _difficulty = 'Normal';

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _service = ProgressService(repository: FirestoreProgressRepository());
    _tabController = TabController(length: 4, vsync: this);
    _loadProgress();
  }

  void _loadProgress() {
    setState(() {
      _progressFuture = _fetchProgress();
    });
  }

  Future<LearningProgress> _fetchProgress() async {
    final uid = await _authService.getOrCreateUid();
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
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          '📊 保護者ダッシュボード / Parent Dashboard',
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'データを更新 / Refresh',
            onPressed: _loadProgress,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.home_rounded), text: 'ホーム'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: '進捗'),
            Tab(icon: Icon(Icons.calendar_today_rounded), text: 'スケジュール'),
            Tab(icon: Icon(Icons.settings_rounded), text: '設定'),
          ],
        ),
      ),
      body: FutureBuilder<LearningProgress>(
        future: _progressFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'データを読み込めませんでした\nFailed to load data',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.redAccent, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProgress,
                      child: const Text('再試行 / Retry'),
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
                onNotifChanged: (v) => setState(() => _notifTime = v),
                onDifficultyChanged: (v) => setState(() => _difficulty = v),
              ),
            ],
          );
        },
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
    final today = progress.last7Days.isNotEmpty ? progress.last7Days.last : null;
    final nextHours = progress.nextReviewDue != null
        ? progress.nextReviewDue!.difference(DateTime.now()).inHours
        : null;
    final hasActivity = progress.totalWordsPracticed > 0 ||
        progress.totalWordsMastered > 0 ||
        progress.currentStreak > 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Greeting ──────────────────────────────────────────────────────
        const Text(
          '今日の学習 / Today\'s Learning',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 20),

        // ── No activity yet banner ─────────────────────────────────────────
        if (!hasActivity) ...[
          _Card(
            color: const Color(0xFF1A2744),
            child: Column(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'まだ学習が始まっていません\nLearning hasn\'t started yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'お子様がゲームをプレイすると\nここに学習の進捗が表示されます',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Streak badge ──────────────────────────────────────────────────
        if (hasActivity || progress.currentStreak > 0) ...[
          _Card(
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.currentStreak > 0
                          ? '${progress.currentStreak}日連続！/ ${progress.currentStreak} day streak!'
                          : '今日から始めよう！/ Start today!',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      progress.currentStreak > 0
                          ? 'すごい！続けましょう！/ Amazing work!'
                          : '毎日少しずつ練習しよう / Practice a little each day',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Today's summary ───────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📚 今日のセッション / Today\'s Session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatPill(
                    label: '単語 / Words',
                    value: '${today?.wordsPracticed ?? 0}',
                    icon: Icons.spellcheck,
                    color: Colors.greenAccent,
                  ),
                  _StatPill(
                    label: '分 / Minutes',
                    value: '${today?.sessionMinutes ?? 0}',
                    icon: Icons.timer,
                    color: Colors.lightBlueAccent,
                  ),
                  _StatPill(
                    label: 'スコア / Score',
                    value: today != null && today.averageScore > 0
                        ? today.averageScore.toStringAsFixed(1)
                        : '—',
                    icon: Icons.star,
                    color: Colors.orangeAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Eiken readiness ───────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '🏆 英検準備度 / Eiken Readiness',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${progress.eikenReadiness.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.eikenReadiness / 100,
                  minHeight: 14,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _readinessColor(progress.eikenReadiness),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _readinessLabel(progress.eikenReadiness),
                style: TextStyle(
                  color: _readinessColor(progress.eikenReadiness),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Next review ───────────────────────────────────────────────────
        if (nextHours != null)
          _Card(
            child: Row(
              children: [
                const Icon(Icons.access_alarm,
                    color: Colors.purpleAccent, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '次の復習 / Next Review Due',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    Text(
                      nextHours <= 0
                          ? '今すぐ！/ Now!'
                          : '$nextHours時間後 / In $nextHours hour${nextHours == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // ── Overall mastery ───────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📖 総合語彙 / Overall Vocabulary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.totalWordsMastered} / 300 習得 / mastered',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '${(progress.masteryPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.masteryPercent,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.greenAccent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _readinessColor(double r) {
    if (r >= 80) return Colors.greenAccent;
    if (r >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _readinessLabel(double r) {
    if (r >= 80) return '🌟 英検5級に向けて順調！/ On track for Eiken Grade 5!';
    if (r >= 50) return '📈 よく頑張っています！/ Good progress — keep it up!';
    if (r > 0) return '💪 もっと練習しましょう / More practice needed';
    return '🌱 学習を始めましょう！/ Start learning to see progress!';
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
    final hasSessionData =
        progress.last7Days.any((d) => d.wordsPracticed > 0);
    final hasCategoryData = progress.categoryMastery.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── 7-day bar chart ───────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 過去7日間 / Last 7 Days',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (!hasSessionData)
                const _NoDataMessage(
                  message: 'まだ学習データがありません\n3日間の学習後にグラフが表示されます',
                  subMessage: 'No data yet — charts appear after 3 days of study',
                )
              else
                SizedBox(
                  height: 140,
                  child: _BarChart(days: progress.last7Days),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Mini calendar ─────────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📅 学習カレンダー / Study Calendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _MiniCalendar(days: progress.last7Days),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Category mastery ──────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🗂️ カテゴリー別習熟度 / Category Mastery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (!hasCategoryData)
                const _NoDataMessage(
                  message: 'まだデータがありません\nカードの学習後に表示されます',
                  subMessage:
                      'No data yet — appears after your child studies cards',
                )
              else
                ...progress.categoryMastery.map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _CategoryBar(data: c),
                  ),
                ),
            ],
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
    const labelH = 20.0;
    final chartH = size.height - labelH;

    final fillPaint = Paint()..color = const Color(0xFFFFB300);
    final zeroPaint = Paint()..color = Colors.white12;
    const textStyle = TextStyle(color: Colors.white54, fontSize: 10);
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
        const valStyle = TextStyle(
            color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold);
        tp.text =
            TextSpan(text: '${days[i].wordsPracticed}', style: valStyle);
        tp.layout();
        tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, top - 14));
      }
    }
  }

  String _dayLabel(DateTime d) {
    // Japanese weekday abbreviations
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
            color: studied ? Colors.amber : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: studied ? Colors.amber : Colors.white12,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              '${d.date.day}',
              style: TextStyle(
                color: studied ? Colors.black : Colors.white38,
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

class _CategoryBar extends StatelessWidget {
  final CategoryMastery data;
  const _CategoryBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = (data.ratio * 100).toInt();
    final mastery = data.ratio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                data.name,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$pct% (${data.masteredCount}/${data.totalCount})',
              style: const TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: mastery,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              mastery >= 0.8
                  ? Colors.greenAccent
                  : mastery >= 0.5
                      ? Colors.orangeAccent
                      : Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }
}

// ── No data placeholder ───────────────────────────────────────────────────────

class _NoDataMessage extends StatelessWidget {
  final String message;
  final String subMessage;
  const _NoDataMessage({required this.message, required this.subMessage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
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
    final schedule = progress.reviewSchedule;
    final onTrack = progress.currentStreak >= 3;
    final hasCards = schedule.todayDue > 0 ||
        schedule.tomorrowDue > 0 ||
        schedule.weekDue > 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Encouragement banner ──────────────────────────────────────────
        _Card(
          color: onTrack
              ? const Color(0xFF1B5E20)
              : const Color(0xFF4E342E),
          child: Row(
            children: [
              Text(onTrack ? '🌟' : '💪',
                  style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  onTrack
                      ? 'お子様は順調です！\nこの調子で続けましょう 🚀\nYour child is on track!'
                      : 'もう少し練習しましょう\nA little more practice today\nwill make a big difference!',
                  style: TextStyle(
                    color:
                        onTrack ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          '予定されている復習 / Upcoming Reviews',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // ── Review schedule cards ─────────────────────────────────────────
        if (!hasCards)
          _Card(
            child: const _NoDataMessage(
              message: 'まだ復習カードがありません\nカードの学習後にスケジュールが表示されます',
              subMessage:
                  'No cards scheduled yet — appears after studying cards',
            ),
          )
        else ...[
          _ReviewCard(
            period: '今日 / Today',
            count: schedule.todayDue,
            icon: '📖',
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          _ReviewCard(
            period: '明日 / Tomorrow',
            count: schedule.tomorrowDue,
            icon: '📚',
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
          _ReviewCard(
            period: '今週 / This Week',
            count: schedule.weekDue,
            icon: '🗓️',
            color: Colors.blueAccent,
          ),
        ],
        const SizedBox(height: 20),

        // ── Next due time ─────────────────────────────────────────────────
        if (progress.nextReviewDue != null)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⏰ 次の復習予定 / Next Scheduled Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(progress.nextReviewDue!),
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inMinutes < 60) return '${diff.inMinutes}分後 / In ${diff.inMinutes} minutes';
    if (diff.inHours < 24) return '${diff.inHours}時間後 / In ${diff.inHours} hours';
    return '明日 / Tomorrow';
  }
}

class _ReviewCard extends StatelessWidget {
  final String period;
  final int count;
  final String icon;
  final Color color;
  const _ReviewCard({
    required this.period,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(period,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              Text(
                '$count 単語 / words',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(20),
      children: [
        // ── Daily goal ────────────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎯 1日の目標 / Daily Word Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
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
                        color: selected ? Colors.amber : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$g 単語',
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Notification time ─────────────────────────────────────────────
        _Card(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active,
                color: Colors.purpleAccent, size: 28),
            title: const Text('リマインダー / Reminder Time',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: Text(
              notifTime.format(context),
              style:
                  const TextStyle(color: Colors.purpleAccent, fontSize: 18),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: notifTime,
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark(),
                  child: child!,
                ),
              );
              if (picked != null) onNotifChanged(picked);
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── Difficulty ────────────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚡ 難易度 / Difficulty',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...['かんたん / Easy', 'ふつう / Normal', 'むずかしい / Hard']
                  .map((d) {
                final selected = d == difficulty;
                return RadioListTile<String>(
                  value: d,
                  groupValue: difficulty,
                  onChanged: (v) {
                    if (v != null) onDifficultyChanged(v);
                  },
                  title: Text(
                    d,
                    style: TextStyle(
                      color: selected ? Colors.amber : Colors.white54,
                    ),
                  ),
                  activeColor: Colors.amber,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Version footer ────────────────────────────────────────────────
        const Center(
          child: Text(
            'ENG Quest v0.8 · Parent Dashboard C08',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

const Color _kBg = Color(0xFF1A1A2E);
const Color _kSurface = Color(0xFF16213E);

class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Card({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? _kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

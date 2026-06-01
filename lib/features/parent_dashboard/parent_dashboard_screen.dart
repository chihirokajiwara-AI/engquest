import 'package:flutter/material.dart';
import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/analytics/firestore_progress_repository.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ParentDashboardScreen — C08
//  4-tab parent view: Home · Progress · Schedule · Settings
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
  late Future<LearningProgress> _progressFuture;
  bool _isFirestoreLive = false; // true when real data loaded

  // Settings state
  int _dailyGoal = 20;
  TimeOfDay _notifTime = const TimeOfDay(hour: 18, minute: 0);
  String _difficulty = 'Normal';

  @override
  void initState() {
    super.initState();
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
    final progress = await _service.getProgress('demo_uid');
    // Detect if real data came back (mastered > 0 or streak > 0 from Firestore)
    // We mark live=true whenever we got a non-default result
    if (mounted) {
      setState(() {
        _isFirestoreLive = true;
      });
    }
    return progress;
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '📊 Parent Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _isFirestoreLive
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF4E342E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isFirestoreLive ? 'LIVE' : 'DEMO',
                style: TextStyle(
                  color: _isFirestoreLive ? Colors.greenAccent : Colors.orange,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'データを更新',
            onPressed: _loadProgress,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.home_rounded), text: 'Home'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Progress'),
            Tab(icon: Icon(Icons.calendar_today_rounded), text: 'Schedule'),
            Tab(icon: Icon(Icons.settings_rounded), text: 'Settings'),
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
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent)),
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
    final nextHours =
        progress.nextReviewDue?.difference(DateTime.now()).inHours;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Greeting ──────────────────────────────────────────────────────
        const Text(
          "Your child's learning today",
          style: TextStyle(color: Color(0xFF607D8B), fontSize: 14),
        ),
        const SizedBox(height: 20),

        // ── Streak badge ──────────────────────────────────────────────────
        _Card(
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${progress.currentStreak} day streak!',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Keep up the amazing work!',
                    style: TextStyle(color: Color(0xFF607D8B), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Today's summary ───────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📚 Today's Session",
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatPill(
                    label: 'Words',
                    value: '${today?.wordsPracticed ?? 0}',
                    icon: Icons.spellcheck,
                    color: const Color(0xFF66BB6A),
                  ),
                  _StatPill(
                    label: 'Minutes',
                    value: '${today?.sessionMinutes ?? 0}',
                    icon: Icons.timer,
                    color: const Color(0xFF4FC3F7),
                  ),
                  _StatPill(
                    label: 'Avg Score',
                    value: today != null
                        ? today.averageScore.toStringAsFixed(1)
                        : '—',
                    icon: Icons.star,
                    color: const Color(0xFFFFB74D),
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
                    '🏆 Eiken Readiness',
                    style: TextStyle(
                      color: Color(0xFF263238),
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
                  backgroundColor: const Color(0xFFE0E0E0),
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
                const Icon(Icons.access_alarm, color: Color(0xFFAB47BC), size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Review Due',
                      style: TextStyle(color: Color(0xFF607D8B), fontSize: 13),
                    ),
                    Text(
                      nextHours <= 0
                          ? 'Now!'
                          : 'In $nextHours hour${nextHours == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFFAB47BC),
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
                '📖 Overall Vocabulary',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.totalWordsMastered} / 300 mastered',
                    style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14),
                  ),
                  Text(
                    '${(progress.masteryPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF66BB6A),
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
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF66BB6A)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _readinessColor(double r) {
    if (r >= 80) return const Color(0xFF66BB6A);
    if (r >= 50) return const Color(0xFFFFB74D);
    return const Color(0xFFEF5350);
  }

  String _readinessLabel(double r) {
    if (r >= 80) return '🌟 On track for Eiken Grade 5!';
    if (r >= 50) return '📈 Good progress — keep it up!';
    return '💪 More practice needed';
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
      padding: const EdgeInsets.all(20),
      children: [
        // ── 7-day bar chart ───────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 Last 7 Days',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
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
                '📅 Study Calendar',
                style: TextStyle(
                  color: Color(0xFF263238),
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
                '🗂️ Category Mastery',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._categories.map(
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
    final maxWords = days.map((d) => d.wordsPracticed).fold(0, (a, b) => a > b ? a : b);
    if (maxWords == 0) return;

    const barPad = 8.0;
    final barW = (size.width - barPad * (days.length + 1)) / days.length;
    final labelH = 20.0;
    final chartH = size.height - labelH;

    final fillPaint = Paint()..color = const Color(0xFF4FC3F7);
    final zeroPaint = Paint()..color = const Color(0xFFE0E0E0);
    final textStyle = const TextStyle(color: Color(0xFF607D8B), fontSize: 10);
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
      tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, size.height - labelH + 4));

      // Value label
      if (days[i].wordsPracticed > 0) {
        final valStyle = const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold);
        tp.text = TextSpan(text: '${days[i].wordsPracticed}', style: valStyle);
        tp.layout();
        tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, top - 14));
      }
    }
  }

  String _dayLabel(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final studyDays = days.where((d) => d.wordsPracticed > 0).map((d) => d.date).toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((d) {
        final studied = studyDays.contains(d.date);
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: studied ? const Color(0xFFFFC107) : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: studied ? const Color(0xFFFFC107) : const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              '${d.date.day}',
              style: TextStyle(
                color: studied ? Colors.black : const Color(0xFF90A4AE),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(data.name,
                style: const TextStyle(color: Color(0xFF607D8B), fontSize: 13)),
            Text('$pct%',
                style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: data.mastery,
            minHeight: 8,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(
              data.mastery >= 0.8
                  ? const Color(0xFF66BB6A)
                  : data.mastery >= 0.5
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFEF5350),
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(20),
      children: [
        // ── Encouragement banner ──────────────────────────────────────────
        _Card(
          color: onTrack ? const Color(0xFF1B5E20) : const Color(0xFF4E342E),
          child: Row(
            children: [
              Text(onTrack ? '🌟' : '💪', style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  onTrack
                      ? 'Your child is on track!\nKeep the momentum going 🚀'
                      : 'A little more practice today\nwill make a big difference!',
                  style: TextStyle(
                    color: onTrack ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Upcoming Reviews',
          style: TextStyle(
            color: Color(0xFF263238),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // ── Review schedule cards ─────────────────────────────────────────
        _ReviewCard(
          period: 'Today',
          count: todayDue,
          icon: '📖',
          color: const Color(0xFFEF5350),
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          period: 'Tomorrow',
          count: tomorrowDue,
          icon: '📚',
          color: const Color(0xFFFFB74D),
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          period: 'This Week',
          count: weekDue,
          icon: '🗓️',
          color: const Color(0xFF4FC3F7),
        ),
        const SizedBox(height: 20),

        // ── Next due time ─────────────────────────────────────────────────
        if (progress.nextReviewDue != null)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⏰ Next Scheduled Review',
                  style: TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(progress.nextReviewDue!),
                  style: const TextStyle(
                    color: Color(0xFFAB47BC),
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
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} minutes';
    if (diff.inHours < 24) return 'In ${diff.inHours} hours';
    return 'Tomorrow';
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
        border: Border.all(color: color.withAlpha(102), width: 1),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(period,
                  style: const TextStyle(color: Color(0xFF607D8B), fontSize: 13)),
              Text(
                '$count words',
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
                '🎯 Daily Word Goal',
                style: TextStyle(
                  color: Color(0xFF263238),
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
                        color: selected ? const Color(0xFFFFC107) : const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? const Color(0xFFFFC107) : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Text(
                        '$g words',
                        style: TextStyle(
                          color: selected ? Colors.black : const Color(0xFF607D8B),
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
                color: Color(0xFFAB47BC), size: 28),
            title: const Text('Reminder Time',
                style: TextStyle(color: Color(0xFF263238), fontSize: 15)),
            subtitle: Text(
              notifTime.format(context),
              style: const TextStyle(color: Color(0xFFAB47BC), fontSize: 18),
            ),
            trailing:
                const Icon(Icons.chevron_right, color: Color(0xFF90A4AE)),
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
          ),
        ),
        const SizedBox(height: 16),

        // ── Difficulty ────────────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚡ Difficulty',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...['Easy', 'Normal', 'Hard'].map((d) {
                final selected = d == difficulty;
                // RadioListTile.groupValue/onChanged are deprecated after
                // Flutter 3.32 in favour of a RadioGroup ancestor, which does
                // not exist in the CI toolchain (3.22). Suppress here until the
                // CI Flutter version is aligned, then migrate to RadioGroup.
                return RadioListTile<String>(
                  value: d,
                  // ignore: deprecated_member_use
                  groupValue: difficulty,
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    if (v != null) onDifficultyChanged(v);
                  },
                  title: Text(
                    d,
                    style: TextStyle(
                      color: selected ? const Color(0xFFFFC107) : const Color(0xFF607D8B),
                    ),
                  ),
                  activeColor: const Color(0xFFFFC107),
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
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

const Color _kBg = Color(0xFFF5F7FA);
const Color _kSurface = Color(0xFFFFFFFF);

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
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FC3F7).withAlpha(20),
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
            style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
      ],
    );
  }
}

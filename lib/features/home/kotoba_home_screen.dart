// lib/features/home/kotoba_home_screen.dart
// A-KEN Quest — コトバ探偵 Daily Home (retention hub).
//
// This is the child's LANDING screen on every post-onboarding app launch.
// Design constraints:
//   R4: NO Firebase / network in build or initState.  All Firebase-backed data
//       is lazy+guarded (try/catch from SchedulerBinding.addPostFrameCallback).
//   R3: paired with test/features/home/kotoba_home_smoke_test.dart.
//   STRATEGY: streak is a 探偵の捜査日誌 (case-log), not a guilt nag.
//             FSRS due-count is framed as 「館に新しいナゾが届いた」.
//             Never show loss-aversion UI. Keep it calm, celebratory.
//
// Elements:
//   1. 探偵の捜査日誌 streak display (「N日 れんぞく」) — gentle, gold.
//   2. 「きょうの ナゾ」— FSRS-due item count, diegetically framed.
//   3. Primary CTA 「▶ じけんげんばへ / つづける」— SceneView (kTown5Scene),
//      or QuestMapScreen for higher levels whose SceneView is not yet built.
//   4. Secondary 「ちずを みる」— QuestMapScreen (level-select stays reachable).
//
// All data is injected via constructor so ?preview=kotobahome works with NO
// Firebase (R4).  Internal async loads are guarded with try/catch.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:engquest/core/audio/nav_speak.dart';
import 'package:engquest/features/character/progress_tinted_character.dart';
import 'package:engquest/core/data/vocab_repository.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
import 'package:engquest/features/exam_practice/pass/pass_gauge.dart';
import 'package:engquest/features/quest/quest_map_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/settings/settings_screen.dart';
import 'package:engquest/core/sound/sound_service.dart';
import 'package:engquest/core/audio/audio_mute.dart';

// ---------------------------------------------------------------------------
// KotobaHomeScreen
// ---------------------------------------------------------------------------

/// The コトバ探偵 daily-return home.
///
/// [streakService]: injected for testability (defaults to a real instance).
/// [cardRepository]: injected for testability (defaults to InMemory impl; the
///   caller may swap in a Firestore-backed repo once Firebase is wired).
/// [initialEikenLevel]: read from prefs at construction time for routing — safe
///   to override in tests.
class KotobaHomeScreen extends StatefulWidget {
  /// StreakService to load the 捜査日誌 streak from.
  final StreakService? streakService;

  /// FSRS repository for today's due-count.  If null the screen uses a fresh
  /// [InMemoryFsrsCardRepository] (always 0 items — safe empty-state).
  final FsrsCardRepository? cardRepository;

  /// Override the 英検 level used for scene routing (for tests / preview).
  /// If null the screen reads `onboarding_start_level` from SharedPreferences.
  final String? initialEikenLevel;

  const KotobaHomeScreen({
    super.key,
    this.streakService,
    this.cardRepository,
    this.initialEikenLevel,
  });

  @override
  State<KotobaHomeScreen> createState() => _KotobaHomeScreenState();
}

class _KotobaHomeScreenState extends State<KotobaHomeScreen> {
  // ── Services (lazily created — never in build/initState) ──────────────────
  late final StreakService _streakService;
  late final FsrsCardRepository _repo;

  // ── State ────────────────────────────────────────────────────────────────
  StreakState _streak = const StreakState.zero();
  int _dueCount = 0; // FSRS due items today
  String _eikenLevel = '5'; // used to route to the right scene
  int _childAge = 8; // used to age-filter the FSRS review deck
  CseEstimate? _estimate; // live 合格率, null until the child has practice data
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Use injected instances or safe defaults — no Firebase touch here.
    _streakService = widget.streakService ?? StreakService();
    _repo = widget.cardRepository ?? InMemoryFsrsCardRepository();

    if (widget.initialEikenLevel != null) {
      _eikenLevel = widget.initialEikenLevel!;
    }

    // R4: all async data loads happen after first frame, never in initState.
    SchedulerBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    // 0. Apply persisted audio settings app-wide (SFX + Voice channels) so a
    //    child's mute choice is honoured everywhere, not just in Battle.
    await SoundService().loadPreferences();
    await AudioMute.loadVoicePreference();

    // 1. Streak — SharedPreferences backed, always safe.
    StreakState streak = const StreakState.zero();
    try {
      streak = await _streakService.load();
    } catch (_) {
      // Prefs unavailable (rare in tests): stay at zero.
    }

    // 2. Eiken level — read from SharedPreferences (safe, no Firebase).
    if (widget.initialEikenLevel == null) {
      try {
        final prefs = await PreferencesService.getInstance();
        final stored = prefs.getString('onboarding_start_level');
        if (stored != null && stored.isNotEmpty) {
          _eikenLevel = stored;
        }
        final age = prefs.getInt('onboarding_age');
        if (age > 0) _childAge = age;
      } catch (_) {
        // Keep defaults — safe.
      }
    }

    // 2.5 Pre-warm the selected grade's vocab DB during idle. The multi-MB
    //     load+decode (3.89MB for 準1級) is the verified cause of the "tap into
    //     vocab practice feels frozen" lag (#52); warming it here, off the tap,
    //     means the later entry hits VocabRepository's session cache instead of
    //     blocking the (single-threaded, on web) UI thread on decode.
    if (VocabRepository.hasGrade(_eikenLevel)) {
      unawaited(VocabRepository.prewarm(_eikenLevel));
    }

    // 3. FSRS due-count — guarded; repo may be empty or throw.
    // #134: read under the child's REAL anonymous Firebase UID (the identity Battle
    // writes FSRS under) so a returning child sees their actual due-count, not a
    // false 0 from a fake shared key against an empty store. Falls back to 'local'
    // only when Auth is unavailable (offline / tests) — InMemory repos key on that.
    int dueCount = 0;
    String userId = 'local';
    try {
      userId = await AuthService().getOrCreateUid();
    } catch (_) {
      // Auth/Firebase unavailable → keep the 'local' fallback.
    }
    try {
      final due = await _repo.getDueCards(userId, DateTime.now());
      dueCount = due.length;
    } catch (_) {
      // Firestore repo not reachable → show 0 (no fake count).
      dueCount = 0;
    }

    // Live 合格率 for the home readiness card (null until there is practice data).
    final estimate = await liveCseEstimate(_eikenLevel);

    if (!mounted) return;
    setState(() {
      _streak = streak;
      _dueCount = dueCount;
      _estimate = estimate;
      _loading = false;
    });
  }

  // ── Routing ───────────────────────────────────────────────────────────────

  /// Navigate to the painted scene (primary CTA).
  ///
  /// 英検5級 and 4級 have painted SceneViews (see [kScenesByGrade]).  Grades
  /// without a scene yet fall back to QuestMapScreen (level-select) — honest,
  /// and consistent with the current build-out where painted districts are
  /// shipping grade-by-grade.
  /// Push a screen and RELOAD home state when the child returns. Every practice
  /// surface writes streak / daily-goal / 合格率 progress, so the home must
  /// re-read on pop — otherwise the「きょうの目標」ring, the due-count and the
  /// 合格率 card all stay frozen at their mount-time values for the whole session
  /// (the daily-return loop would be cosmetically present but behaviourally dead).
  Future<void> _pushThenRefresh(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    await _loadData();
  }

  Future<void> _goToScene() async {
    final scene = sceneForGrade(_eikenLevel);
    if (scene != null) {
      // SceneView pops true when all NPCs are solved (G2: scene-clear → map
      // advance). On clear, advance the shared quest_unlocked_index pref so
      // QuestMapScreen shows the next node unlocked on the next visit.
      final cleared = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SceneView(scene: scene, eikenLevel: _eikenLevel),
        ),
      );
      if (!mounted) return;
      if (cleared == true) {
        try {
          final prefs = await PreferencesService.getInstance();
          final startIdx = _startingIndexForLevel(_eikenLevel);
          final stored = prefs.getInt('quest_unlocked_index');
          // Only advance if the next node is beyond the current high-water mark.
          if (startIdx + 1 > stored) {
            await prefs.setInt('quest_unlocked_index', startIdx + 1);
          }
        } catch (_) {
          // Prefs unavailable — the map will just re-derive on next open.
        }
      }
      // Always reload home state so streak/due-count/合格率 reflect the session.
      await _loadData();
    } else {
      // Grades without a painted district yet — send to the map where the child
      // can pick their town. Further districts are shipping grade-by-grade.
      _goToQuestMap();
    }
  }

  /// Returns the quest town index for [level], mirroring [startingTownIndex]
  /// from quest_data.dart without importing it into the home layer.
  int _startingIndexForLevel(String level) {
    const order = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];
    final i = order.indexOf(level);
    return i < 0 ? 0 : i;
  }

  /// Navigate to QuestMapScreen (secondary CTA / fallback).
  void _goToQuestMap() {
    _pushThenRefresh(QuestMapScreen(startLevel: _eikenLevel));
  }

  /// Navigate to the 英検 practice hub (vocab/grammar 大問, listening, writing,
  /// full mock 模試, and the 合格メーター). This is the app's core 合格 surface and
  /// was previously reachable ONLY from the now-orphaned WorldMapScreen hub, so
  /// no live user could open it — this CTA restores access from the home.
  void _goToExamPractice() {
    _pushThenRefresh(ExamPracticeScreen(eikenGrade: _eikenLevel));
  }

  /// Navigate to the FSRS vocabulary review (BattleScreen) — the daily
  /// spaced-repetition drill that the「きょうの ナゾ」due-count refers to. Before
  /// #66 this screen was only reachable via the orphaned WorldMapScreen, so the
  /// home told the child "N reviews are due" then stranded them.
  void _goToReview() {
    _pushThenRefresh(
      BattleScreen(childAge: _childAge, eikenGrade: _eikenLevel),
    );
  }

  /// Open the full 合格メーター from the home readiness card. With no data yet,
  /// send the child to practice (so a meter can be produced). If the meter pops
  /// a weak skill ("practise X"), route to the exam hub to do so. #66/#68.
  Future<void> _goToPassMeter() async {
    final est = _estimate;
    if (est == null) {
      _goToExamPractice();
      return;
    }
    final weak = await Navigator.of(context).push<EikenSkill?>(
      MaterialPageRoute(builder: (_) => PassMeterScreen(estimate: est)),
    );
    if (!mounted) return;
    if (weak != null) {
      // The meter pointed at a weak skill → go practise it (that screen reloads
      // home state on its own return via _pushThenRefresh).
      _goToExamPractice();
    } else {
      // Plain back from the meter — reload so the ring/合格率 reflect any change.
      await _loadData();
    }
  }

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
      contentMaxWidth:
          600, // #144: centre the hub column on tablet, full-width on phone
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            // ── 合格率 readiness, surfaced at the top (#66/#68) — the parent's
            // first signal of "is my kid on track to pass". ──────────────────
            _buildReadinessCard(),
            const SizedBox(height: 14),
            // ── 英検 core, foregrounded (#66, CEO 2026-06-08) ──────────────
            // The primary daily path is 英検 practice + the FSRS review the
            // 合格率 is built on — not the RPG world (which is now an optional
            // reward below).
            _buildExamCta(), // PRIMARY: 英検れんしゅう / 合格率
            const SizedBox(height: 12),
            _buildNazoPanel(), // tappable → FSRS vocabulary review
            const SizedBox(height: 14),
            _buildStreakPanel(),
            const SizedBox(height: 18),
            // ── ぼうけん (おまけ・任意) — demoted game world ──────────────────
            _buildAdventureSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Section: Header ───────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Settings gear (mute / how-to-play) — top-right, title stays centred.
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: Container(
              // ≥44px hit target for small fingers.
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.settings, color: dqGold, size: 24),
            ),
          ),
        ),
        Text(
          'コトバ探偵',
          textAlign: TextAlign.center,
          style:
              dqText(size: 28, w: FontWeight.w800, color: dqGold, spacing: 4),
        ),
        const SizedBox(height: 6),
        Text(
          '言葉（ことば）の ナゾを 解（と）け！',
          textAlign: TextAlign.center,
          style: dqText(size: 13, w: FontWeight.w500, color: dqInk),
        ),
      ],
    );
  }

  // ── Section: 合格率 readiness card (#66/#68) ──────────────────────────────

  Widget _buildReadinessCard() {
    final est = _estimate;
    // #58/#110 home hero (CEO-1197 character decision): the child's chosen
    // detective greys→colours with the HONEST readiness — a "bring my detective
    // to life by getting closer to 合格" hook on the front door. Colour == real
    // progress only (0 when there is no practice data yet).
    final readiness = (est?.readinessPct ?? 0) / 100.0;
    return GestureDetector(
      onTap: _goToPassMeter,
      child: DqPanel(
        title: '合格率（ごうかくりつ） / Pass readiness',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProgressTintedCharacter(
              asset: HeroChoice.asset,
              readiness: readiness,
              width: 44,
              height: 64,
              semanticLabel: 'あなたの たんてい。れんしゅうするほど 色（いろ）がつくよ。',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: est == null
                  ? Row(
                      children: [
                        const Icon(Icons.insights_outlined,
                            color: dqGold, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'れんしゅうすると、合格（ごうかく）まで あと どれくらいか'
                            ' わかるよ。タップして はじめよう！',
                            style: dqText(size: 13, color: dqInk)
                                .copyWith(height: 1.5),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: dqGold, size: 22),
                      ],
                    )
                  : _buildReadinessData(est),
            ),
          ],
        ),
      ),
    );
  }

  // Honesty (audit 2026-06-08): a 5級 child who maxes R+L on a handful of items
  // would otherwise see a confident green 100% with no basis — reading as
  // fabricated to a paying parent. Below a minimum sample we show a MUTED
  // "still diagnosing" gauge with the answers-remaining count; only above it do
  // we show the gold/green confident state + the basis. Mirrors the PassMeter's
  // #68 basis disclosure.
  static const int _kReadinessMinItems = 20;

  Widget _buildReadinessData(CseEstimate est) {
    final n = est.totalItemsAttempted;
    final thin = n < _kReadinessMinItems;
    final color = thin
        ? const Color(0xFF8A93B5) // muted neutral while diagnosing
        : (est.isPredictedPass ? const Color(0xFF8BE08B) : dqGold);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Compact arc gauge — the same designed meter as the full PassMeter,
        // so the 合格率 reads as one thing everywhere (#68).
        PassGauge(
            pct: est.readinessPct,
            color: color,
            size: 66,
            stroke: 7,
            fontSize: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thin
                    ? 'しんだんちゅう……'
                    : (est.isPredictedPass
                        ? 'ごうかくけんの 目安（めやす）！'
                        : (est.readinessPct >= 65
                            ? '合格（ごうかく）の目安（めやす）まで あと少（すこ）し'
                            : 'コツコツ 目安（めやす）に ちかづこう')),
                style: dqText(size: 13, w: FontWeight.w700, color: dqInk),
              ),
              const SizedBox(height: 3),
              Text(
                thin
                    ? 'あと ${_kReadinessMinItems - n}問で けっかが でるよ'
                    : '$n問の けっかで けいさん',
                style: dqText(size: 11, color: dqInk.withAlpha(160)),
              ),
              const SizedBox(height: 3),
              Text('タップで くわしく / Details',
                  style: dqText(size: 11, color: dqGold)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: dqGold, size: 22),
      ],
    );
  }

  // ── Section: 探偵の捜査日誌 (Streak) ──────────────────────────────────────

  Widget _buildStreakPanel() {
    final streak = _streak.currentStreak;
    // Build a gentle, celebratory message — no guilt, no red countdown. A
    // lapsed returner (#123) gets a warm 「おかえり！」 instead of the first-time
    // line, and the count honestly reads 0 (the broken streak), not a stale value.
    final String streakMessage =
        _streakMessage(streak, broken: _streak.streakBroken);

    return DqPanel(
      title: '探偵（たんてい）の捜査日誌（そうさにっし）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak count — full width (kept as-is so it never crowds; #65).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vector icon, not an emoji — consistent across browsers and with
              // the rest of the home's gold iconography (#71).
              const Icon(Icons.menu_book_rounded, color: dqGold, size: 30),
              const SizedBox(width: 10),
              Text(
                '$streak',
                style: dqText(size: 40, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'にち れんぞく',
                    style: dqText(size: 16, w: FontWeight.w700, color: dqInk),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            streakMessage,
            style: dqText(
                    size: 13, w: FontWeight.w500, color: dqInk.withAlpha(210))
                .copyWith(height: 1.6),
          ),
          const SizedBox(height: 14),
          // 「きょうの目標」daily-goal: ring + caption. The caption is Expanded so
          // the only fixed-width child (the ring) can never overflow (#65).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DailyGoalRing(
                done: _streak.problemsToday,
                goal: _streak.dailyGoal,
              ),
              const SizedBox(width: 14),
              Expanded(child: _buildGoalCaption()),
            ],
          ),
          const SizedBox(height: 14),
          // Weekly dots — subtle, no red "missed day" highlight.
          _buildWeekDots(),
        ],
      ),
    );
  }

  /// The「きょうの目標」progress line beside the ring — honest, never shaming.
  Widget _buildGoalCaption() {
    final s = _streak;
    final String title;
    final String text;
    final Color color;
    if (s.goalMet) {
      title = 'きょうの目標（もくひょう）達成（たっせい）！';
      text = 'さすが 名探偵（めいたんてい）。';
      color = dqGold;
    } else if (s.problemsToday > 0) {
      title = 'あと ${s.remainingToGoal}問（もん）！';
      text = 'きょうの目標（もくひょう）まで もうすこし。';
      color = dqInk;
    } else {
      title = 'きょうの目標（もくひょう）：${s.dailyGoal}問（もん）';
      text = 'さあ はじめよう！';
      color = dqInk.withAlpha(210);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: dqText(size: 14, w: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(
          text,
          style:
              dqText(size: 12, w: FontWeight.w500, color: dqInk.withAlpha(200)),
        ),
      ],
    );
  }

  /// Returns a calm, diegetic streak message that never shames.
  String _streakMessage(int n, {bool broken = false}) {
    if (n == 0 && broken) {
      return 'おかえり！ また きょうから つづけよう。';
    }
    if (n == 0) return 'はじめての じけん、はじまる……';
    if (n == 1) return 'さあ、最初（さいしょ）の ページを開（ひら）いた！';
    if (n < 5) return 'じっくり 記録（きろく）が 積（つ）みあがってきた。';
    if (n < 10) return 'すごい！探偵（たんてい）の 手帳（てちょう）が 充実（じゅうじつ）してきた。';
    if (n < 30) return '$n日分（にちぶん）の じけん記録（きろく）！ たいした 探偵（たんてい）だ。';
    return '$n日（にち）！ 伝説（でんせつ）の 名探偵（めいたんてい）……';
  }

  Widget _buildWeekDots() {
    const dayLabels = ['月', '火', '水', '木', '金', '土', '日'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final studied = _streak.studiedOn(i);
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: studied ? dqBox : dqNight0,
                border: Border.all(
                  color: studied ? dqGold : dqGoldDeep.withAlpha(100),
                  width: studied ? 2 : 1.5,
                ),
                boxShadow: studied
                    ? [BoxShadow(color: dqGold.withAlpha(70), blurRadius: 6)]
                    : null,
              ),
              child: Center(
                child: studied
                    ? const Icon(Icons.auto_stories, color: dqGold, size: 13)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dayLabels[i],
              style: dqText(
                size: 10,
                w: studied ? FontWeight.w700 : FontWeight.w400,
                color: studied ? dqGold : dqInk.withAlpha(130),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Section: きょうの ナゾ (FSRS due-count) ───────────────────────────────

  Widget _buildNazoPanel() {
    final hasDue = _dueCount > 0;

    // Tappable → FSRS vocabulary review (#66): the panel announces the due-count
    // and now actually opens the review, instead of stranding the child.
    return GestureDetector(
      onTap: _goToReview,
      child: DqPanel(
        title: 'きょうの ナゾ（たんごの ふくしゅう）',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, color: dqGold, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDue) ...[
                    // Two separate Text widgets so find.textContaining works in
                    // tests (RichText TextSpan children are not matched by the
                    // text-finder in flutter_test).
                    Text(
                      '館（やかた）に あたらしい ナゾが $_dueCount つ とどいた！',
                      style: dqText(size: 14, w: FontWeight.w500, color: dqInk),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'タップして たんごを ふくしゅうしよう / Review',
                      style:
                          dqText(size: 12, w: FontWeight.w500, color: dqGold),
                    ),
                  ] else ...[
                    Text(
                      '館（やかた）は しずか……',
                      style: dqText(size: 14, w: FontWeight.w600, color: dqInk),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'タップして たんごを ふくしゅうしよう / Review',
                      style:
                          dqText(size: 12, w: FontWeight.w500, color: dqGold),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: dqGold, size: 24),
          ],
        ),
      ),
    );
  }

  // ── PRIMARY CTA: 英検れんしゅう / 合格率 (the core 合格 surface) ─────────────
  // Foregrounded per #66 (CEO 2026-06-08): 英検 practice + the 合格率 it builds is
  // the product's primary daily path — the prominent gold action.

  Widget _buildExamCta() {
    return GestureDetector(
      onTap: _goToExamPractice,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [dqGold, dqGoldDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dqBorder, width: 2),
          boxShadow: [
            BoxShadow(
                color: dqGoldDeep.withAlpha(140),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fact_check_rounded,
                color: Color(0xFF2A1C00), size: 26),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '英検（えいけん）れんしゅう　／　合格率（ごうかくりつ）',
                  maxLines: 1,
                  style: dqText(
                    size: 16,
                    w: FontWeight.w800,
                    color: const Color(0xFF2A1C00),
                    spacing: 1,
                  ),
                ),
              ),
            ),
            // #133 pre-literacy: a non-reader taps this speaker to HEAR the label.
            // Additive — tapping the button itself still navigates to practice.
            const SizedBox(width: 4),
            const SpeakerButton('exam', color: Color(0xFF2A1C00), size: 22),
          ],
        ),
      ),
    );
  }

  // ── ぼうけん (おまけ・任意) — the RPG world, demoted per #66 ─────────────────
  // The story/scene and map are now an OPTIONAL reward, not the front door.

  Widget _buildAdventureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'おまけ：ぼうけん / Adventure（あそび）',
            style: dqText(
                size: 12, w: FontWeight.w600, color: dqInk.withAlpha(150)),
          ),
        ),
        _adventureButton(
          icon: Icons.play_arrow_rounded,
          label: 'じけんげんばへ　／　Story',
          onTap: _goToScene,
        ),
        const SizedBox(height: 10),
        _adventureButton(
          icon: Icons.map_outlined,
          label: 'ちずを みる　／　Adventure Map',
          onTap: _goToQuestMap,
        ),
      ],
    );
  }

  Widget _adventureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: dqBox.withAlpha(160),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dqBorder.withAlpha(120), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: dqGold.withAlpha(200), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: dqText(
                      size: 13,
                      w: FontWeight.w600,
                      color: dqInk.withAlpha(210)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── きょうの目標 daily-goal ring ──────────────────────────────────────────────

/// A compact circular progress ring for today's question goal — the visible
/// daily-return target the child fills each day (the engagement spine, not
/// decoration). Gold fill, dark track; centre shows done/goal, or a check once
/// the goal is met.
class _DailyGoalRing extends StatelessWidget {
  final int done;
  final int goal;
  const _DailyGoalRing({required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 0.0 : (done / goal).clamp(0.0, 1.0).toDouble();
    final met = done >= goal && goal > 0;
    const size = 76.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoalRingPainter(ratio: ratio, met: met),
        child: Center(
          // #114/WCAG SC 1.4.4: the ring is a fixed 76px visual; shrink the inner
          // number to fit at large text scales (2.0x) instead of clipping.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: met
                ? const Icon(Icons.check_rounded, color: dqGold, size: 34)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$done',
                        style:
                            dqText(size: 24, w: FontWeight.w900, color: dqGold),
                      ),
                      Text(
                        '/$goal問',
                        style: dqText(
                            size: 11,
                            w: FontWeight.w600,
                            color: dqInk.withAlpha(190)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  final double ratio; // 0..1
  final bool met;
  _GoalRingPainter({required this.ratio, required this.met});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );
    // Full-circle track.
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = dqNight1,
    );
    // Progress fill — starts at 12 o'clock, sweeps clockwise.
    if (ratio > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = met ? dqGold : dqGoldDeep,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) =>
      old.ratio != ratio || old.met != met;
}

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

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:engquest/core/data/vocab_repository.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
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
      } catch (_) {
        // Keep default '5' — safe.
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
    int dueCount = 0;
    try {
      // Use a stable anonymous userId key consistent with the rest of the app.
      // The InMemory repo will simply return [] for any unknown user.
      const userId = 'local';
      final due = await _repo.getDueCards(userId, DateTime.now());
      dueCount = due.length;
    } catch (_) {
      // Firebase/Firestore repo not available or prefs missing → show 0.
      dueCount = 0;
    }

    if (!mounted) return;
    setState(() {
      _streak = streak;
      _dueCount = dueCount;
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
  void _goToScene() {
    final scene = sceneForGrade(_eikenLevel);
    if (scene != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SceneView(scene: scene, eikenLevel: _eikenLevel),
        ),
      );
    } else {
      // Grades without a painted district yet — send to the map where the child
      // can pick their town. Further districts are shipping grade-by-grade.
      _goToQuestMap();
    }
  }

  /// Navigate to QuestMapScreen (secondary CTA / fallback).
  void _goToQuestMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestMapScreen(startLevel: _eikenLevel),
      ),
    );
  }

  /// Navigate to the 英検 practice hub (vocab/grammar 大問, listening, writing,
  /// full mock 模試, and the 合格メーター). This is the app's core 合格 surface and
  /// was previously reachable ONLY from the now-orphaned WorldMapScreen hub, so
  /// no live user could open it — this CTA restores access from the home.
  void _goToExamPractice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamPracticeScreen(eikenGrade: _eikenLevel),
      ),
    );
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildStreakPanel(),
            const SizedBox(height: 14),
            _buildNazoPanel(),
            const SizedBox(height: 24),
            _buildPrimaryCta(),
            const SizedBox(height: 12),
            _buildSecondaryMap(),
            const SizedBox(height: 12),
            _buildExamCta(),
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

  // ── Section: 探偵の捜査日誌 (Streak) ──────────────────────────────────────

  Widget _buildStreakPanel() {
    final streak = _streak.currentStreak;
    // Build a gentle, celebratory message — no guilt, no red countdown.
    final String streakMessage = _streakMessage(streak);

    return DqPanel(
      title: '探偵（たんてい）の捜査日誌（そうさにっし）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('📒', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Text(
                '$streak',
                style: dqText(size: 40, w: FontWeight.w800, color: dqGold),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'にち れんぞく',
                  style: dqText(size: 16, w: FontWeight.w700, color: dqInk),
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
          // Weekly dots — subtle, no red "missed day" highlight.
          _buildWeekDots(),
        ],
      ),
    );
  }

  /// Returns a calm, diegetic streak message that never shames.
  String _streakMessage(int n) {
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

    return DqPanel(
      title: 'きょうの ナゾ',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 28)),
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
                    'じけんげんばへ むかおう。',
                    style: dqText(
                        size: 12,
                        w: FontWeight.w500,
                        color: dqInk.withAlpha(180)),
                  ),
                ] else ...[
                  Text(
                    '館（やかた）は しずか……',
                    style: dqText(size: 14, w: FontWeight.w600, color: dqInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '新しい ナゾを 探（さが）しに 出（で）かけよう！',
                    style: dqText(
                        size: 12,
                        w: FontWeight.w500,
                        color: dqInk.withAlpha(180)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Primary CTA: じけんげんばへ ──────────────────────────────────────────

  Widget _buildPrimaryCta() {
    return GestureDetector(
      onTap: _goToScene,
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
            const Icon(Icons.play_arrow_rounded,
                color: Color(0xFF2A1C00), size: 28),
            const SizedBox(width: 8),
            // FittedBox scaleDown keeps the full label (no clip/ellipsis) on
            // narrow phones (#65: overflowed at ~360px logical width).
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'じけんげんばへ　／　つづける',
                  maxLines: 1,
                  style: dqText(
                    size: 17,
                    w: FontWeight.w800,
                    color: const Color(0xFF2A1C00),
                    spacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Secondary CTA: ちずを みる ───────────────────────────────────────────

  Widget _buildSecondaryMap() {
    return GestureDetector(
      onTap: _goToQuestMap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: dqBox.withAlpha(200),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dqBorder.withAlpha(180), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: dqGold, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ちずを みる　／　Adventure Map',
                  maxLines: 1,
                  style: dqText(size: 14, w: FontWeight.w700, color: dqInk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tertiary CTA: 英検れんしゅう (the exam-practice hub + 合格メーター) ──────
  // Restores access to the core 合格 surface (大問 practice / 模試 / 合格率),
  // which was previously reachable only from the orphaned WorldMapScreen hub.

  Widget _buildExamCta() {
    return GestureDetector(
      onTap: _goToExamPractice,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: dqBox.withAlpha(200),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dqBorder.withAlpha(180), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fact_check_outlined, color: dqGold, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '英検（えいけん）れんしゅう　／　Eiken Practice',
                  maxLines: 1,
                  style: dqText(size: 14, w: FontWeight.w700, color: dqInk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/features/battle/battle_screen.dart
// ENG Quest — C05 Battle Module: FSRS-4.5 Retrieval Loop (UI Polish v2 + P0.2 + P2-7)
//
// Game flow:
//   1. Build a deck of FSRSCards — loaded from Firestore (FirestoreFsrsCardRepository)
//      Falls back to InMemory on first launch / offline
//   2. Show the English word face-up ("cat")
//   3. Tap to flip card → Japanese translation + example sentence
//   4. Rate with 4 buttons: Again / Hard / Good / Easy
//   5. FSRSAlgorithm.schedule() computes next due date
//   6. Card state saved to Firestore immediately after grading
//   7. Cycle through due cards; show session summary when done
//   Progress persists across app restarts (Firestore offline cache)
//
// P2-7 XP System additions:
//   - Grade-aware XP (Again=0, Hard=5, Good=10, Easy=15) via XpService
//   - Level-up detection + celebratory dialog (レベルアップ！🎉)
//   - XP popup shows correct per-grade amount (not constant 10)
//   - Session summary shows XP earned this session
//
// UI Polish sprint additions:
//   - 3D perspective card flip (400 ms, easeInOut)
//   - Scale-bounce grade buttons (0.95→1.0, 150 ms)
//   - Golden shimmer overlay on correct answer (300 ms)
//   - Streak counter with fire emoji (🔥 × N) when streak ≥ 3
//   - +XP floating text animation (TweenAnimationBuilder, 800 ms)
//   - Animated star-burst on session complete (CustomPainter)
//   - SoundService stubs + HapticFeedback

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/analytics/firestore_progress_repository.dart';
import '../../core/analytics/progress_service.dart';
import '../../core/content/vocab_age_filter.dart';
import '../../core/firebase/auth_service.dart';
import '../../core/fsrs/firestore_card_repository.dart';
import '../../core/fsrs/fsrs_algorithm.dart';
import '../../core/fsrs/fsrs_card.dart';
import '../../core/fsrs/fsrs_card_repository.dart';
import '../../core/gamification/achievement.dart';
import '../../core/gamification/achievement_service.dart';
import '../../core/gamification/xp_service.dart';
import '../../core/gamification/xp_profile.dart';
import '../../core/audio/word_audio_player_service.dart';
import '../../core/sound/sound_service.dart';
import '../../core/data/vocab_repository.dart';
import '../../core/models/vocab_item.dart';
import '../exam_practice/pass/cse_model.dart';
import '../exam_practice/pass/skill_accuracy_store.dart';
import '../exam_practice/pass/pass_progress_card.dart';
import '../home/streak_service.dart';
import '../quest/ui/dq_ui.dart';

// ── Bilingual + interval labels for the Grade enum (DQ command-window tiles) ──
String _gradeJp(Grade g) {
  switch (g) {
    case Grade.again:
      return 'もういちど';
    case Grade.hard:
      return 'むずかしい';
    case Grade.good:
      return 'できた';
    case Grade.easy:
      return 'かんたん';
  }
}

// ── Session result per card ───────────────────────────────────────────────────
class _CardResult {
  final String word;
  final Grade grade;
  const _CardResult(this.word, this.grade);
}

/// Bounded reading-skill contribution from a daily vocab Battle session, so the
/// daily practice loop actually moves the 合格率 (#35).
///
/// - Vocab Battle = 大問1-type vocabulary knowledge → [EikenSkill.reading] (the
///   SAME mapping exam vocabGrammar practice already uses). It does not invent a
///   new signal — it makes the daily loop consistent with exam practice.
/// - Correct = Good|Easy (matches Battle's own `isCorrect`; CONSERVATIVE — a
///   'Hard' recall is treated as not-yet-mastered, so 合格率 never inflates upward).
/// - CAPPED per session ([cap]) so a long FSRS review binge of easy cards cannot
///   swamp the reading bucket and overstate comprehension; one session contributes
///   at most ~one 大問1's worth of evidence, accruing steadily like exam practice.
({int correct, int total}) battleReadingContribution(
  Iterable<Grade> grades, {
  int cap = 10,
}) {
  final list = grades.toList();
  final total = list.length;
  if (total == 0) return (correct: 0, total: 0);
  final correct = list.where((g) => g == Grade.good || g == Grade.easy).length;
  if (total <= cap) return (correct: correct, total: total);
  final scaled = (correct * cap / total).round().clamp(0, cap);
  return (correct: scaled, total: cap);
}

// ── XP floating label data ────────────────────────────────────────────────────
class _XpPopup {
  final int xp;
  final int id; // unique key to allow overlapping popups
  const _XpPopup(this.xp, this.id);
}

// ── BattleScreen ─────────────────────────────────────────────────────────────

/// FSRS-based vocabulary flashcard battle screen — UI Polish v2 + Firestore persistence.
///
/// [repository] — injectable for testing; defaults to FirestoreFsrsCardRepository.
/// [childAge]   — filters vocabulary by age (age < 8 → animals/colors/food/family only).
class BattleScreen extends StatefulWidget {
  final FsrsCardRepository? repository;

  /// Child's age in years (from OnboardingResult). Defaults to 8 (full A1 deck).
  final int childAge;

  /// Eiken grade to study (e.g. "5", "4", "3", "pre2"). Defaults to "5".
  final String eikenGrade;

  const BattleScreen({
    super.key,
    this.repository,
    this.childAge = 8,
    this.eikenGrade = '5',
  });

  /// Computes elapsed session time in whole minutes, rounded to the nearest
  /// minute with a floor of 1 (a completed session always counts as ≥ 1 min,
  /// so study-time analytics never record a zero-minute session).
  ///
  /// Exposed as a static pure function so the rounding logic is unit-testable
  /// without constructing the full widget/animation stack.
  ///   - [start] null            → 1 (defensive fallback)
  ///   - non-positive duration   → 1 (clock skew / instant complete)
  ///   - otherwise               → round to nearest minute, floor of 1
  static int elapsedMinutes(DateTime? start, DateTime end) {
    if (start == null) return 1;
    final seconds = end.difference(start).inSeconds;
    if (seconds <= 0) return 1;
    final minutes = (seconds + 30) ~/ 60;
    return minutes < 1 ? 1 : minutes;
  }

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  // ── FSRS engine + persistence ──────────────────────────────────────────────
  final FSRSAlgorithm _fsrs = FSRSAlgorithm();
  final _sound = SoundService();
  final _wordAudio = WordAudioPlayerService();
  late final FsrsCardRepository _repository;
  final _auth = AuthService();
  final _vocabRepo = VocabRepository();
  final _xpService = XpService();
  final _achievementService = AchievementService();
  String? _userId;
  bool _repoLoading = true; // true while we await uid + loadDeck

  // ── Deck state ─────────────────────────────────────────────────────────────
  List<VocabItem> _vocab = const [];
  List<FSRSCard> _deck = const [];
  List<int> _queue = const [];
  int _queueIdx = 0;

  // ── Session stats ──────────────────────────────────────────────────────────
  final List<_CardResult> _sessionResults = [];
  bool _sessionDone = false;

  // 合格率 before this session (baseline) and after (for the session-end progress
  // moment). Null until computed / when the grade has no estimate yet.
  CseEstimate? _preEstimate;
  CseEstimate? _postEstimate;

  // ── Session timer (P0.1) ────────────────────────────────────────────────────
  /// Wall-clock timestamp captured when the deck finishes loading and the first
  /// card becomes visible. Used to compute real elapsed minutes on completion.
  DateTime? _sessionStartTime;

  // ── Streak ─────────────────────────────────────────────────────────────────
  int _streak = 0; // consecutive Good/Easy answers
  int _totalXp = 0;

  // ── Card flip animation ────────────────────────────────────────────────────
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  bool _isFlipped = false;

  // ── Shimmer overlay (correct answer) ──────────────────────────────────────
  bool _showShimmer = false;

  // ── XP popup list ──────────────────────────────────────────────────────────
  final List<_XpPopup> _xpPopups = [];
  int _xpPopupIdCounter = 0;

  // ── Session-complete star burst animation ──────────────────────────────────
  late AnimationController _starsCtrl;
  late Animation<double> _starsAnim;

  // ── Colours ────────────────────────────────────────────────────────────────
  // Muted accents for the four grades — used only as small icon-medallion / dot
  // tints inside the dq palette (never as candy-bright fills).
  static const _gradeColors = {
    Grade.again: Color(0xFFC76B6B), // dusty red
    Grade.hard: Color(0xFFCB9A4E), // dim amber
    Grade.good: Color(0xFF7FB87F), // sage green
    Grade.easy: Color(0xFF6FA8C9), // slate blue
  };

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Resolve repository: injected (tests) or production Firestore
    _repository = widget.repository ?? FirestoreFsrsCardRepository();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _starsAnim = CurvedAnimation(parent: _starsCtrl, curve: Curves.easeOut);
    _sound.loadPreferences().then((_) {
      if (mounted) setState(() {});
    });
    _initDeckAsync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect OS reduce-motion: make the card flip + stars instant (they still
    // happen — the answer reveals, stars appear — just without the transition).
    // Vestibular/seizure-safe. (#76)
    if (prefersReducedMotion(context)) {
      _flipCtrl.duration = Duration.zero;
      _starsCtrl.duration = Duration.zero;
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _starsCtrl.dispose();
    _wordAudio.dispose();
    super.dispose();
  }

  // ── Deck initialisation (async — loads from Firestore) ────────────────────

  Future<void> _initDeckAsync() async {
    // 1. Get or create anonymous uid
    String uid;
    try {
      uid = await _auth.getOrCreateUid();
    } catch (_) {
      // Firebase Auth unavailable (offline cold start) — use local fallback uid
      uid = 'offline_user';
    }
    if (!mounted) return;
    _userId = uid;

    // 2. Load vocab list from repository — filtered by child's age
    await _vocabRepo.initialize(eikenGrade: widget.eikenGrade);
    _vocab = filterVocabByAge(_vocabRepo.getAll().toList(), widget.childAge);
    final vocabIds = _vocab.map((v) => v.id).toList();

    // 2.5. Prefetch word audio for this session (fire-and-forget)
    _wordAudio.initialize().then((_) {
      final audioWords = _vocab
          .map((v) => (id: v.id, word: v.word))
          .take(20) // prefetch first 20 to avoid blocking
          .toList();
      _wordAudio.prefetchSession(audioWords);
    }).catchError((_) {});

    // 3. Load persisted cards from Firestore (or InMemory fallback)
    List<FSRSCard> persistedCards;
    try {
      persistedCards = await _repository.loadDeck(uid);
    } catch (_) {
      persistedCards = [];
    }

    // 4. Merge: use persisted state for known words, new card for unknowns
    final cardMap = {for (final c in persistedCards) c.vocabId: c};
    final deck =
        vocabIds.map((id) => cardMap[id] ?? FSRSCard(vocabId: id)).toList();

    // 5. Seed missing new cards to Firestore in batch (first launch)
    final newCards =
        deck.where((c) => !cardMap.containsKey(c.vocabId)).toList();
    if (newCards.isNotEmpty) {
      try {
        await _repository.saveCards(uid, newCards);
      } catch (_) {
        // Non-fatal: will retry on next save
      }
    }

    // 6. Compute due queue. Guarded: a Firestore error here must not leave the
    // child stuck on the loading spinner — fall back to "everything is due" so
    // the deck still opens (#40 render integrity).
    if (!mounted) return;
    final now = DateTime.now();
    List<FSRSCard> dueCards;
    try {
      dueCards = await _repository.getDueCards(uid, now);
    } catch (_) {
      dueCards = const [];
    }
    final dueIds = dueCards.map((c) => c.vocabId).toSet();

    final queue = <int>[];
    for (var i = 0; i < deck.length; i++) {
      if (dueIds.contains(deck[i].vocabId)) queue.add(i);
    }
    queue.shuffle(math.Random());

    // Re-check: getDueCards above is an await AFTER the line-317 mounted check,
    // so a child navigating away mid-load could otherwise setState on a disposed
    // State (a "setState after dispose" crash). Guard right before the mutation.
    if (!mounted) return;
    setState(() {
      _deck = deck;
      _queue = queue.isNotEmpty ? queue : List.generate(deck.length, (i) => i)
        ..shuffle(math.Random());
      _queueIdx = 0;
      _sessionResults.clear();
      _sessionDone = false;
      _isFlipped = false;
      _streak = 0;
      _totalXp = 0;
      _xpPopups.clear();
      _starsCtrl.reset();
      _repoLoading = false;
      // Session begins now — first card is visible. Capture start timestamp
      // so we can compute real elapsed minutes when the session completes.
      _sessionStartTime = DateTime.now();
      // Clear last session's progress snapshot so the summary recomputes fresh.
      _preEstimate = null;
      _postEstimate = null;
    });
  }

  // ── Current card helpers ───────────────────────────────────────────────────

  int get _currentDeckIdx => _queue[_queueIdx];
  VocabItem get _currentVocab => _vocab[_currentDeckIdx];
  FSRSCard get _currentCard => _deck[_currentDeckIdx];

  int get _totalCards => _queue.length;
  int get _doneCards => _queueIdx;

  // ── Flip ───────────────────────────────────────────────────────────────────

  void _flipCard() {
    if (_isFlipped) return;
    HapticFeedback.lightImpact();
    _sound.playFlip();
    // Auto-play word pronunciation on flip
    WordAudioAutoPlay.trigger(
      player: _wordAudio,
      vocabId: _currentVocab.id,
      word: _currentVocab.word,
    );
    setState(() => _isFlipped = true);
    _flipCtrl.forward();
  }

  void _resetFlip() {
    _flipCtrl.reset();
    setState(() => _isFlipped = false);
  }

  // ── Grade ──────────────────────────────────────────────────────────────────

  void _gradeCard(Grade grade) {
    HapticFeedback.mediumImpact();

    final isCorrect = grade == Grade.good || grade == Grade.easy;
    if (isCorrect) {
      _sound.playCorrect();
      // Shimmer
      setState(() => _showShimmer = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showShimmer = false);
      });
      // Streak
      _streak++;
    } else {
      _sound.playWrong();
      _streak = 0;
    }

    // ── Grade-aware XP (P2-7) ─────────────────────────────────────────────
    // XP per grade: Again=0, Hard=5, Good=10, Easy=15
    final xpGain = kGradeXp[grade.name.toLowerCase()] ?? 0;
    _totalXp += xpGain;
    final popupId = ++_xpPopupIdCounter;

    // Show popup only when XP > 0 (Again gives no XP — no popup)
    if (xpGain > 0) {
      _sound.playXpGain();
      setState(() => _xpPopups.add(_XpPopup(xpGain, popupId)));
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() => _xpPopups.removeWhere((p) => p.id == popupId));
        }
      });
    }

    // Persist XP to Firestore (fire-and-forget); check for level-up
    final uid = _userId;
    if (uid != null) {
      _xpService.awardXp(uid, grade).then((result) {
        if (result.didLevelUp && mounted) {
          _showLevelUpDialog(result.after);
        }
      }).catchError((_) {
        // Non-fatal: XP syncs later via Firestore offline cache
      });
    }

    final now = DateTime.now();
    final updated = _fsrs.schedule(_currentCard, grade, now);
    _deck[_currentDeckIdx] = updated;
    _sessionResults.add(_CardResult(_currentVocab.word, grade));

    // Persist updated card to Firestore (fire-and-forget; offline cache handles it)
    if (uid != null) {
      _repository.saveCard(uid, updated).catchError((_) {
        // Non-fatal: offline writes are cached by Firestore SDK and synced later
      });
    }

    if (updated.state == CardState.learning ||
        updated.state == CardState.relearning) {
      final insertAt = math.min(_queueIdx + 3, _queue.length);
      _queue.insert(insertAt, _currentDeckIdx);
    }

    final nextIdx = _queueIdx + 1;
    if (nextIdx >= _queue.length) {
      _sound.playSessionComplete();
      HapticFeedback.heavyImpact();
      setState(() => _sessionDone = true);
      _starsCtrl.forward();
      _recordSessionToFirestore();
      _recordSkillAccuracy();
      _recordDailyHabit();
      return;
    }

    setState(() => _queueIdx = nextIdx);
    _resetFlip();
  }

  // ── Session persistence ────────────────────────────────────────────────────

  /// Bridges the daily vocab Battle into the 合格率 (#35): records this session's
  /// vocab accuracy into [SkillAccuracyStore] as reading-skill evidence, so daily
  /// practice actually moves the pass-probability (it previously did not). Bounded
  /// + conservative — see [battleReadingContribution]. Then recomputes the live
  /// 合格率 so the session-end [PassProgressCard] shows the child their movement
  /// toward 合格. Fire-and-forget; storage errors are swallowed by the store's
  /// guarded in-memory fallback.
  void _recordSkillAccuracy() {
    unawaited(() async {
      // Capture the baseline BEFORE recording this session — deterministically,
      // in the same closure, so the +delta can never be collapsed by a race with
      // an async pre-capture (the pre always reflects prior sessions only).
      final pre = await liveCseEstimate(widget.eikenGrade);

      final c = battleReadingContribution(_sessionResults.map((r) => r.grade));
      if (c.total > 0) {
        try {
          final store = await SkillAccuracyStore.getInstance();
          await store.record(
            grade: widget.eikenGrade,
            skill: EikenSkill.reading,
            correct: c.correct,
            total: c.total,
          );
        } catch (_) {
          // Non-fatal: in-memory fallback handles store errors.
        }
      }
      // Recompute AFTER recording so the summary reflects this session.
      final post = await liveCseEstimate(widget.eikenGrade);
      if (mounted) {
        setState(() {
          _preEstimate = pre;
          _postEstimate = post;
        });
      }
    }());
  }

  /// Records the daily-return habit: counts this review toward today's streak
  /// and the「きょうの目標」daily-goal ring (one per card answered). The primary
  /// FSRS review previously did NOT touch the day-streak/goal — only the quest
  /// サイレント battle did — so a child who only did vocab review saw the home
  /// streak/goal never move. Fire-and-forget; prefs failures are swallowed.
  void _recordDailyHabit() {
    final answered = _sessionResults.length;
    if (answered <= 0) return;
    unawaited(() async {
      final streak = StreakService();
      try {
        await streak.recordStudySession();
        await streak.recordProgress(answered);
      } catch (_) {
        // Non-fatal: SharedPreferences failure is rare.
      }
    }());
  }

  /// Writes session stats to Firestore after session completes.
  /// Fire-and-forget — offline Firestore cache will sync when connection returns.
  void _recordSessionToFirestore() {
    final uid = _userId;
    if (uid == null) return;

    final total = _sessionResults.length;
    if (total == 0) return;

    final gradeSum =
        _sessionResults.fold(0.0, (sum, r) => sum + r.grade.index1.toDouble());
    final avgScore = gradeSum / total;

    // Count 'review' state cards as mastered
    final masteredCount =
        _deck.where((c) => c.state == CardState.review).length;

    // Real elapsed study time (P0.1) — computed from session start timestamp.
    final minutes =
        BattleScreen.elapsedMinutes(_sessionStartTime, DateTime.now());

    final progressService = ProgressService(
      repository: FirestoreProgressRepository(),
    );

    progressService
        .recordSession(
      uid: uid,
      wordsPracticed: total,
      minutes: minutes,
      avgScore: avgScore,
      totalMastered: masteredCount,
      totalPracticed: _deck.length,
      streak: 1, // server will recalculate from session history
    )
        .catchError((_) {
      // Non-fatal: offline writes queued by Firestore SDK
    });

    // Check achievements after session (T06)
    _checkAchievements(uid, masteredCount, total);
  }

  // ── Achievement check (T06) ───────────────────────────────────────────────

  Future<void> _checkAchievements(
      String uid, int masteredCount, int totalPracticed) async {
    final profile = _xpService.currentProfile(uid);
    // Load the REAL streak so the streak_3/7/10 milestones can actually unlock.
    // Was hard-coded to 1 ("server-side best-effort"), but the server isn't
    // deployed (#7) → those achievements never fired even for a genuine 7-day
    // streak. A failed load falls back to 0 and never blocks the other unlocks.
    int currentStreak = 0;
    try {
      currentStreak = (await StreakService().load()).currentStreak;
    } catch (_) {}
    if (!mounted) return;
    try {
      final newlyUnlocked = await _achievementService.checkAndUpdate(
        uid: uid,
        totalMastered: masteredCount,
        currentStreak: currentStreak,
        totalPracticed: totalPracticed,
        level: profile?.level ?? 1,
      );
      if (newlyUnlocked.isNotEmpty && mounted) {
        _showAchievementUnlocked(newlyUnlocked);
      }
    } catch (_) {}
  }

  void _showAchievementUnlocked(List<String> ids) {
    if (!mounted) return;
    _sound.playAchievement();
    HapticFeedback.heavyImpact();
    final def = achievementDefById(ids.first);
    if (def == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: DqPanel(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: dqBilingual(
                    'バッジ獲得！',
                    'BADGE EARNED',
                    jpSize: 20,
                    jpColor: dqGold,
                    stacked: true,
                    align: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: def.gradient),
                    border: Border.all(color: dqBorder, width: 2),
                  ),
                  child: Icon(def.icon, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 14),
                Text(def.titleJa,
                    textAlign: TextAlign.center,
                    style: dqText(size: 18, w: FontWeight.w800, color: dqInk)),
                const SizedBox(height: 6),
                Text(def.descriptionJa,
                    textAlign: TextAlign.center,
                    style: dqText(size: 14, color: dqInk)),
                if (ids.length > 1) ...[
                  const SizedBox(height: 8),
                  Text('+${ids.length - 1}個のバッジも獲得！',
                      style: dqText(size: 12, color: dqGoldDeep)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Level-up dialog (P2-7) ────────────────────────────────────────────────

  /// Shows a celebratory dialog when the player reaches a new level.
  /// Auto-dismisses after 3 seconds; user can also tap to dismiss.
  void _showLevelUpDialog(XpProfile newProfile) {
    if (!mounted) return;
    _sound.playLevelUp();
    HapticFeedback.heavyImpact();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(180),
      builder: (ctx) {
        // Auto-close after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: DqPanel(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('🌟', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Center(
                  child: dqBilingual(
                    'レベルアップ！',
                    'LEVEL UP',
                    jpSize: 26,
                    jpColor: dqGold,
                    stacked: true,
                    align: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Lv.${newProfile.level} に到達！',
                    style: dqText(size: 19, color: dqInk)),
                const SizedBox(height: 4),
                Text('合計 ${newProfile.totalXp} XP',
                    style: dqText(size: 13, color: dqGoldDeep)),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: newProfile.levelProgress,
                    backgroundColor: dqNight0,
                    valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                    '${newProfile.currentLevelXp} / ${newProfile.levelXpSpan} XP',
                    style: dqText(size: 12, color: dqGoldDeep)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Key changes when the body state changes, triggering AnimatedSwitcher.
    final bodyKey = _repoLoading
        ? const ValueKey('loading')
        : _sessionDone
            ? const ValueKey('summary')
            : const ValueKey('session');
    final body = _repoLoading
        ? _buildLoadingSpinner()
        : _sessionDone
            ? _buildSummary()
            : _buildCardSession();

    return DqScene(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: bodyKey, child: body),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSpinner() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: dqGold, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('カードを読み込んでいます…', style: dqText(size: 14, color: dqInk)),
        ],
      ),
    );
  }

  // ── Dark header (replaces the bright AppBar): back arrow + gold serif title,
  // streak badge, mute toggle, and the N / total counter. ──────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: dqInk),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Icon(Icons.style_rounded, color: dqGold, size: 22),
          const SizedBox(width: 8),
          // #114/WCAG SC 1.4.4: Flexible so the title wraps/shrinks at large text
          // scales instead of pushing the header Row into a ~57px overflow.
          Flexible(
            child: dqBilingual('たんごバトル', 'Word Battle',
                jpSize: 17, jpColor: dqGold, stacked: true),
          ),
          if (_streak >= 3) ...[
            const SizedBox(width: 10),
            _StreakBadge(streak: _streak),
          ],
          const Spacer(),
          IconButton(
            icon: Icon(
              _sound.muted ? Icons.volume_off : Icons.volume_up,
              color: dqInk,
              size: 22,
            ),
            tooltip: _sound.muted ? 'サウンドON' : 'サウンドOFF',
            onPressed: () => setState(() => _sound.muted = !_sound.muted),
          ),
          if (!_repoLoading && !_sessionDone)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text('${_doneCards + 1} / $_totalCards',
                  style: dqText(size: 14, color: dqGoldDeep)),
            ),
        ],
      ),
    );
  }

  // ── Session screen ─────────────────────────────────────────────────────────

  Widget _buildCardSession() {
    return Stack(
      children: [
        Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: _buildFlipCardWithShimmer(),
            ),
            if (!_isFlipped) _buildTapHint(),
            if (_isFlipped) _buildGradeButtons(),
            const SizedBox(height: 24),
          ],
        ),
        // XP floating popups
        ..._xpPopups.map((popup) => _XpFloatLabel(
              key: ValueKey(popup.id),
              xp: popup.xp,
            )),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _totalCards == 0 ? 0.0 : _doneCards / _totalCards;
    // HP-style bar: cream-bordered navy track with a gold fill.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: dqNight0,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: dqBorder, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
          ),
        ),
      ),
    );
  }

  Widget _buildFlipCardWithShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: _isFlipped ? null : _flipCard,
            child: _buildFlipCard(),
          ),
          // Golden shimmer overlay on correct answer
          if (_showShimmer)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showShimmer ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: RadialGradient(
                      colors: [
                        dqGold.withAlpha(110),
                        dqGold.withAlpha(0),
                      ],
                      radius: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlipCard() {
    return AnimatedBuilder(
      animation: _flipAnim,
      builder: (context, _) {
        final angle = _flipAnim.value * math.pi;
        final isFrontVisible = angle < math.pi / 2;
        final displayAngle = isFrontVisible ? angle : math.pi - angle;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(displayAngle),
          child: isFrontVisible ? _buildCardFace() : _buildCardBack(),
        );
      },
    );
  }

  Widget _buildCardFace() {
    final vocab = _currentVocab;
    return _cardContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            vocab.word,
            style: dqText(
              size: 48,
              w: FontWeight.w800,
              color: dqInk,
              spacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Speaker icon — tap to hear pronunciation
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            iconSize: 28,
            color: dqGold,
            tooltip: '発音を聞く',
            onPressed: () {
              WordAudioAutoPlay.trigger(
                player: _wordAudio,
                vocabId: vocab.id,
                word: vocab.word,
              );
            },
          ),
          const SizedBox(height: 4),
          Text(vocab.reading, style: dqText(size: 18, color: dqGoldDeep)),
          const SizedBox(height: 10),
          if (vocab.pos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: dqGold.withAlpha(150), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(vocab.pos.first.name,
                  style: dqText(size: 12, color: dqGold)),
            ),
          const SizedBox(height: 28),
          dqBilingual('タップしてめくる', 'Tap to flip',
              jpSize: 13, jpColor: dqGoldDeep, enColor: dqGoldDeep),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final vocab = _currentVocab;
    final example =
        vocab.exampleSentences.isNotEmpty ? vocab.exampleSentences.first : '';
    return _cardContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(vocab.word, style: dqText(size: 22, color: dqGoldDeep)),
          const SizedBox(height: 16),
          Text(
            vocab.jpTranslation,
            style: dqText(size: 42, w: FontWeight.w800, color: dqInk),
            textAlign: TextAlign.center,
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: dqNight0.withAlpha(160),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dqGoldDeep.withAlpha(120)),
              ),
              child: Text(
                example,
                style: dqText(size: 15, w: FontWeight.w500, color: dqInk),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // The flashcard rendered as a DQ command/dialogue window: navy fill, cream
  // double-border, deep shadow. (Both faces share this frame.)
  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(238),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dqBorder, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: child,
    );
  }

  Widget _buildTapHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: dqBilingual('カードをタップして答えを確認', 'Tap the card to reveal',
          jpSize: 13, jpColor: dqGoldDeep, enColor: dqGoldDeep),
    );
  }

  // ── Grade buttons ──────────────────────────────────────────────────────────

  Widget _buildGradeButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: Grade.values.map((g) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _GradeButton(
                grade: g,
                accent: _gradeColors[g]!,
                fsrs: _fsrs,
                card: _currentCard,
                onTap: () => _gradeCard(g),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Session summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final total = _sessionResults.length;
    final counts = <Grade, int>{for (final g in Grade.values) g: 0};
    for (final r in _sessionResults) {
      counts[r.grade] = (counts[r.grade] ?? 0) + 1;
    }
    final gradeSum =
        _sessionResults.fold(0.0, (sum, r) => sum + r.grade.index1.toDouble());
    final avgGrade = total > 0 ? gradeSum / total : 0.0;

    return Stack(
      children: [
        // Animated star burst behind content
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _starsAnim,
            builder: (context, _) => CustomPaint(
              painter: _StarBurstPainter(_starsAnim.value),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech_rounded,
                    color: dqGold, size: 64),
                const SizedBox(height: 12),
                dqBilingual(
                  'セッション完了！',
                  'BATTLE CLEARED',
                  jpSize: 26,
                  jpColor: dqGold,
                  stacked: true,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text('$total 枚 完了 / $total cards',
                    style: dqText(size: 16, color: dqInk)),
                // XP earned
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: dqNight0.withAlpha(180),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: dqGold.withAlpha(160), width: 1.5),
                  ),
                  child: Text('✨ +$_totalXp XP 獲得！',
                      style:
                          dqText(size: 16, w: FontWeight.w800, color: dqGold)),
                ),
                // 合格率 progress moment — the in-context "I'm closer to 合格"
                // signal at peak engagement (the daily-return spine, CEO 951).
                // Skipped when there's no estimate yet (never fabricate).
                if (_postEstimate != null) ...[
                  const SizedBox(height: 22),
                  PassProgressCard(pre: _preEstimate, post: _postEstimate!),
                ],
                const SizedBox(height: 28),
                _SummaryCard(
                  title: 'けっか / Results',
                  children: Grade.values.map((g) {
                    return _SummaryRow(
                      label: '${_gradeJp(g)} / ${g.label}',
                      color: _gradeColors[g]!,
                      count: counts[g] ?? 0,
                      total: total,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  title: 'スタッツ / Stats',
                  children: [
                    _StatTile(
                      label: '平均評価 / Avg. grade',
                      value: avgGrade.toStringAsFixed(2),
                      icon: Icons.grade_rounded,
                    ),
                    const Divider(color: dqGoldDeep, height: 18),
                    _StatTile(
                      label: '正確さ / Accuracy',
                      value: total > 0
                          ? '${(((counts[Grade.good]! + counts[Grade.easy]!) / total) * 100).round()}%'
                          : '—',
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF8BE08B),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                DqButton(
                  label: 'もういちど / Again',
                  onTap: () => setState(() {
                    _initDeckAsync();
                  }),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: dqBilingual('ホームへ戻る', 'Back to town',
                        jpSize: 14, jpColor: dqInk, enColor: dqGoldDeep),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Streak badge widget ────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dqBorder, width: 1.5),
        boxShadow: [BoxShadow(color: dqGoldDeep.withAlpha(110), blurRadius: 8)],
      ),
      child: Text(
        '🔥 × $streak',
        style: dqText(
          size: 13,
          w: FontWeight.w800,
          color: const Color(0xFF2A1C00),
        ),
      ),
    );
  }
}

// ── Grade button widget (with scale-bounce) ────────────────────────────────────

class _GradeButton extends StatefulWidget {
  final Grade grade;
  final Color accent;
  final FSRSAlgorithm fsrs;
  final FSRSCard card;
  final VoidCallback onTap;

  const _GradeButton({
    required this.grade,
    required this.accent,
    required this.fsrs,
    required this.card,
    required this.onTap,
  });

  @override
  State<_GradeButton> createState() => _GradeButtonState();
}

class _GradeButtonState extends State<_GradeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  String _intervalLabel() {
    final simCard =
        widget.fsrs.schedule(widget.card, widget.grade, DateTime.now());
    final due = simCard.dueDate;
    if (due == null) return '—';
    final diff = due.difference(DateTime.now());
    final days = diff.inDays;
    if (days <= 0) return '今すぐ';
    if (days == 1) return '1日後';
    return '$days 日後';
  }

  @override
  Widget build(BuildContext context) {
    final interval = _intervalLabel();
    // A DQ command-window tile: cream-bordered navy fill, an accent dot for the
    // grade, bilingual JP/EN label, and the FSRS next-interval underneath.
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: dqBox.withAlpha(225),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: dqBorder, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: dqBorder, width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: widget.accent.withAlpha(120), blurRadius: 6)
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _gradeJp(widget.grade),
                style: dqText(size: 12, w: FontWeight.w800, color: dqInk),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.grade.label,
                style: dqText(
                    size: 9, w: FontWeight.w600, color: dqGold, spacing: 0.8),
              ),
              const SizedBox(height: 3),
              Text(
                interval,
                style: dqText(size: 9, color: dqGoldDeep),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── XP floating label ──────────────────────────────────────────────────────────

class _XpFloatLabel extends StatelessWidget {
  final int xp;
  const _XpFloatLabel({super.key, required this.xp});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 140,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, t, _) {
          return Opacity(
            opacity: (1.0 - t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -60 * t),
              child: Center(
                child: Text(
                  '+$xp XP',
                  style: dqText(size: 22, w: FontWeight.w800, color: dqGold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Star burst painter (session complete) ─────────────────────────────────────

class _StarBurstPainter extends CustomPainter {
  final double progress; // 0..1
  _StarBurstPainter(this.progress);

  static final _rng = math.Random(42);
  static final List<_StarParticle> _particles = List.generate(
    30,
    (_) => _StarParticle(
      angle: _rng.nextDouble() * 2 * math.pi,
      speed: 150 + _rng.nextDouble() * 250,
      size: 6 + _rng.nextDouble() * 10,
      // Muted gold/cream sparks — stays within the DQ palette.
      color: [
        dqGold,
        dqGoldDeep,
        dqInk,
        const Color(0xFFD9B25A),
        const Color(0xFFEED9A0),
      ][_rng.nextInt(5)],
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    final alpha = ((1 - progress) * 255).clamp(0, 255).toInt();

    for (final p in _particles) {
      final dist = p.speed * progress;
      final x = cx + math.cos(p.angle) * dist;
      final y = cy + math.sin(p.angle) * dist + 180 * progress * progress;
      final paint = Paint()
        ..color = p.color.withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_StarBurstPainter old) => old.progress != progress;
}

class _StarParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  const _StarParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

// ── Summary widgets ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final List<Widget> children;
  final String? title;
  const _SummaryCard({required this.children, this.title});

  @override
  Widget build(BuildContext context) {
    return DqPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  final int total;

  const _SummaryRow({
    required this.label,
    required this.color,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: dqBorder, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: dqText(size: 11, w: FontWeight.w600, color: dqInk),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: dqNight0,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: dqGoldDeep.withAlpha(120), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 7,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: dqText(size: 13, color: dqInk)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = dqGold,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: dqText(size: 13, color: dqInk)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: dqText(size: 15, w: FontWeight.w800, color: dqGold)),
        ],
      ),
    );
  }
}

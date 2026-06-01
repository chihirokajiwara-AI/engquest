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
import '../../core/sound/sound_service.dart';
import '../../core/data/vocab_repository.dart';
import '../../core/models/vocab_item.dart';

// ── Session result per card ───────────────────────────────────────────────────
class _CardResult {
  final String word;
  final Grade grade;
  const _CardResult(this.word, this.grade);
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
  static const _bgColor = Color(0xFFF5F7FA);
  static const _cardFront = Color(0xFFFFFFFF);
  static const _cardBack = Color(0xFFE3F2FD);
  static const _accentGold = Color(0xFFFFD700);

  static const _gradeColors = {
    Grade.again: Color(0xFFE53935),
    Grade.hard: Color(0xFFF57C00),
    Grade.good: Color(0xFF43A047),
    Grade.easy: Color(0xFF1E88E5),
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
  void dispose() {
    _flipCtrl.dispose();
    _starsCtrl.dispose();
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

    // 6. Compute due queue
    if (!mounted) return;
    final now = DateTime.now();
    final dueCards = await _repository.getDueCards(uid, now);
    final dueIds = dueCards.map((c) => c.vocabId).toSet();

    final queue = <int>[];
    for (var i = 0; i < deck.length; i++) {
      if (dueIds.contains(deck[i].vocabId)) queue.add(i);
    }
    queue.shuffle(math.Random());

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
      return;
    }

    setState(() => _queueIdx = nextIdx);
    _resetFlip();
  }

  // ── Session persistence ────────────────────────────────────────────────────

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

  void _checkAchievements(String uid, int masteredCount, int totalPracticed) {
    final profile = _xpService.currentProfile(uid);
    _achievementService
        .checkAndUpdate(
      uid: uid,
      totalMastered: masteredCount,
      currentStreak: 1, // streak is computed server-side; best-effort here
      totalPracticed: totalPracticed,
      level: profile?.level ?? 1,
    )
        .then((newlyUnlocked) {
      if (newlyUnlocked.isNotEmpty && mounted) {
        _showAchievementUnlocked(newlyUnlocked);
      }
    }).catchError((_) {});
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
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: def.gradient.first.withAlpha(160)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'バッジ獲得！',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: def.gradient),
                  ),
                  child: Icon(def.icon, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  def.titleJa,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  def.descriptionJa,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
                if (ids.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${ids.length - 1}個のバッジも獲得！',
                    style: TextStyle(
                      color: Colors.amber.withAlpha(180),
                      fontSize: 12,
                    ),
                  ),
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
      builder: (ctx) {
        // Auto-close after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
        });

        return Dialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _accentGold, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star burst
                const Text('🌟', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  'レベルアップ！',
                  style: const TextStyle(
                    color: _accentGold,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lv.${newProfile.level} に到達！',
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '合計 ${newProfile.totalXp} XP',
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // XP progress bar for new level
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: newProfile.levelProgress,
                    backgroundColor: Colors.black12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_accentGold),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${newProfile.currentLevelXp} / ${newProfile.levelXpSpan} XP',
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
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

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(key: bodyKey, child: body),
      ),
    );
  }

  Widget _buildLoadingSpinner() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFFD700),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'カードを読み込んでいます…',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black54),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⚔️ Battle',
            style: TextStyle(
              color: _accentGold,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          if (_streak >= 3) ...[
            const SizedBox(width: 8),
            _StreakBadge(streak: _streak),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _sound.muted ? Icons.volume_off : Icons.volume_up,
            color: Colors.black45,
            size: 22,
          ),
          tooltip: _sound.muted ? 'サウンドON' : 'サウンドOFF',
          onPressed: () {
            setState(() => _sound.muted = !_sound.muted);
          },
        ),
        if (!_repoLoading && !_sessionDone)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_doneCards + 1} / $_totalCards',
                style: const TextStyle(color: Colors.black45, fontSize: 14),
              ),
            ),
          ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: Colors.black12,
          valueColor: const AlwaysStoppedAnimation<Color>(_accentGold),
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
                    borderRadius: BorderRadius.circular(20),
                    gradient: RadialGradient(
                      colors: [
                        _accentGold.withAlpha(100),
                        _accentGold.withAlpha(0),
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
      color: _cardFront,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            vocab.word,
            style: const TextStyle(
              color: Color(0xFF263238),
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            vocab.reading,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          if (vocab.pos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _accentGold.withAlpha(128)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                vocab.pos.first.name,
                style: const TextStyle(
                  color: _accentGold,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            'タップしてめくる',
            style: TextStyle(color: Colors.black38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final vocab = _currentVocab;
    final example =
        vocab.exampleSentences.isNotEmpty ? vocab.exampleSentences.first : '';
    return _cardContainer(
      color: _cardBack,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            vocab.word,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vocab.jpTranslation,
            style: const TextStyle(
              color: Color(0xFF263238),
              fontSize: 44,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                example,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _cardContainer({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: child,
    );
  }

  Widget _buildTapHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '👆 カードをタップして答えを確認',
        style: TextStyle(color: Colors.black38, fontSize: 13),
      ),
    );
  }

  // ── Grade buttons ──────────────────────────────────────────────────────────

  Widget _buildGradeButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: Grade.values.map((g) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _GradeButton(
                grade: g,
                color: _gradeColors[g]!,
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
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'セッション完了！',
                  style: TextStyle(
                    color: _accentGold,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$total 枚 完了',
                  style: const TextStyle(color: Colors.black54, fontSize: 18),
                ),
                // XP earned
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accentGold.withAlpha(128)),
                  ),
                  child: Text(
                    '✨ +$_totalXp XP 獲得！',
                    style: const TextStyle(
                      color: _accentGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _SummaryCard(
                  children: Grade.values.map((g) {
                    return _SummaryRow(
                      label: g.label,
                      color: _gradeColors[g]!,
                      count: counts[g] ?? 0,
                      total: total,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _SummaryCard(
                  children: [
                    _StatTile(
                      label: '平均評価',
                      value: avgGrade.toStringAsFixed(2),
                      icon: '⭐',
                    ),
                    const Divider(color: Colors.black12),
                    _StatTile(
                      label: '正確さ (Good + Easy)',
                      value: total > 0
                          ? '${(((counts[Grade.good]! + counts[Grade.easy]!) / total) * 100).round()}%'
                          : '—',
                      icon: '✅',
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('もう一度'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => setState(() {
                      _initDeckAsync();
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text(
                    'ホームへ戻る',
                    style: TextStyle(color: Colors.black54),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6D00).withAlpha(220),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(100),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        '🔥 × $streak',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Grade button widget (with scale-bounce) ────────────────────────────────────

class _GradeButton extends StatefulWidget {
  final Grade grade;
  final Color color;
  final FSRSAlgorithm fsrs;
  final FSRSCard card;
  final VoidCallback onTap;

  const _GradeButton({
    required this.grade,
    required this.color,
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.color.withAlpha(204),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(77),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.grade.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                interval,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
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
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
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
      color: [
        const Color(0xFFFFD700),
        const Color(0xFFFF8F00),
        const Color(0xFFFF4081),
        const Color(0xFF40C4FF),
        const Color(0xFF69F0AE),
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
  const _SummaryCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF263238),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

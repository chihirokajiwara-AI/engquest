// lib/features/battle/battle_screen.dart
// ENG Quest — C05 Battle Module: FSRS-4.5 4-Choice Quiz (v3)
//
// Game flow:
//   1. Show English word face-up with katakana reading
//   2. Show 4 Japanese answer buttons (1 correct + 3 distractors)
//   3. User taps an answer:
//      CORRECT → card flips to green, shows example sentence, "+XP" animation,
//                FSRS Grade.good applied
//      WRONG   → card flips to red, correct answer highlighted,
//                FSRS Grade.again applied
//   4. After 1.5 s, advance automatically to the next card
//   5. Session summary shown when all cards are graded
//
// XP System (P2-7):
//   - Correct answer = Grade.good → +10 XP
//   - Wrong answer   = Grade.again → +0 XP
//   - Level-up detection + celebratory dialog
//   - Session summary shows XP earned
//
// Animations:
//   - 3D perspective card flip (400 ms, easeInOut)
//   - Golden shimmer overlay on correct answer (300 ms)
//   - Streak counter with fire emoji (🔥 × N) when streak ≥ 3
//   - +XP floating text animation (TweenAnimationBuilder, 800 ms)
//   - Animated star-burst on session complete (CustomPainter)
//   - Scale-bounce answer buttons (0.95→1.0, 150 ms)

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
import '../../core/gamification/xp_service.dart';
import '../../core/gamification/xp_profile.dart';
import '../../core/models/vocab_item.dart';
import '../../core/sound/sound_service.dart';
import '../../data/content/vocab_a1.dart';
import '../../data/content/vocab_a2.dart';

// ── Vocab source selection by CEFR level ────────────────────────────────────

/// Returns the seed vocab for the given CEFR level, filtered by age.
List<VocabItem> _vocabForLevel(String cefrLevel, int age) {
  final source = cefrLevel == 'A2' ? kSeedVocabA2 : kSeedVocabA1;
  // Age filtering only applies to A1 (young learners get a subset).
  // A2 content is for older/advanced learners — no age filtering needed.
  if (cefrLevel == 'A2') return List<VocabItem>.from(source);
  return filterVocabByAge(source, age);
}

// ── Session result per card ───────────────────────────────────────────────────
class _CardResult {
  final String word;
  final Grade  grade;
  const _CardResult(this.word, this.grade);
}

// ── XP floating label data ────────────────────────────────────────────────────
class _XpPopup {
  final int xp;
  final int id; // unique key to allow overlapping popups
  const _XpPopup(this.xp, this.id);
}

// ── BattleScreen ─────────────────────────────────────────────────────────────

/// FSRS-based vocabulary flashcard battle screen — 4-choice quiz mode.
///
/// [repository] — injectable for testing; defaults to FirestoreFsrsCardRepository.
/// [childAge]   — filters vocabulary by age (age < 8 → animals/colors/food/family only).
class BattleScreen extends StatefulWidget {
  final FsrsCardRepository? repository;
  /// Child's age in years (from OnboardingResult). Defaults to 8 (full A1 deck).
  final int childAge;
  /// CEFR level to determine which vocab set to use ('A1' or 'A2').
  final String cefrLevel;

  const BattleScreen({
    super.key,
    this.repository,
    this.childAge = 8,
    this.cefrLevel = 'A1',
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
  final _xpService = XpService();
  String? _userId;
  bool _repoLoading = true; // true while we await uid + loadDeck

  // ── Deck state ─────────────────────────────────────────────────────────────
  List<VocabItem>  _vocab = const [];
  List<FSRSCard>   _deck  = const [];
  List<int>        _queue = const [];
  int _queueIdx = 0;

  // ── Session stats ──────────────────────────────────────────────────────────
  final List<_CardResult> _sessionResults = [];
  bool _sessionDone = false;

  // ── Session timer (P0.1) ────────────────────────────────────────────────────
  /// Wall-clock timestamp captured when the deck finishes loading and the first
  /// card becomes visible. Used to compute real elapsed minutes on completion.
  DateTime? _sessionStartTime;

  // ── Streak ─────────────────────────────────────────────────────────────────
  int _streak = 0; // consecutive correct answers
  int _totalXp = 0;

  // ── Card flip animation ────────────────────────────────────────────────────
  late AnimationController _flipCtrl;
  late Animation<double>    _flipAnim;
  bool _isFlipped = false;

  // ── Quiz state ─────────────────────────────────────────────────────────────
  /// The 4 shuffled answer choices for the current card (1 correct + 3 distractors)
  List<String> _choices = const [];
  /// null = not answered yet; true = correct; false = wrong
  bool? _answerResult;
  /// The answer the user actually tapped (null if not answered yet)
  String? _selectedAnswer;
  /// Prevents double-tap on answer buttons
  bool _answerLocked = false;

  // ── Shimmer overlay (correct answer) ──────────────────────────────────────
  bool _showShimmer = false;

  // ── XP popup list ──────────────────────────────────────────────────────────
  final List<_XpPopup> _xpPopups = [];
  int _xpPopupIdCounter = 0;

  // ── Session-complete star burst animation ──────────────────────────────────
  late AnimationController _starsCtrl;
  late Animation<double>    _starsAnim;

  // ── Colours ────────────────────────────────────────────────────────────────
  static const _bgColor    = Color(0xFF1A1A2E);
  static const _cardFront  = Color(0xFF16213E);
  static const _cardCorrect = Color(0xFF1B5E20); // dark green
  static const _cardWrong   = Color(0xFFB71C1C); // dark red
  static const _accentGold = Color(0xFFFFD700);

  static const _correctColor = Color(0xFF43A047);
  static const _wrongColor   = Color(0xFFE53935);

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

    // 2. Load vocab list — selected by CEFR level, filtered by child's age
    _vocab = _vocabForLevel(widget.cefrLevel, widget.childAge);
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
    final deck = vocabIds
        .map((id) => cardMap[id] ?? FSRSCard(vocabId: id))
        .toList();

    // 5. Seed missing new cards to Firestore in batch (first launch)
    final newCards = deck.where((c) => !cardMap.containsKey(c.vocabId)).toList();
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
      _queue = queue.isNotEmpty ? queue : List.generate(deck.length, (i) => i)..shuffle(math.Random());
      _queueIdx = 0;
      _sessionResults.clear();
      _sessionDone = false;
      _isFlipped = false;
      _streak = 0;
      _totalXp = 0;
      _xpPopups.clear();
      _starsCtrl.reset();
      _repoLoading = false;
      _answerResult = null;
      _selectedAnswer = null;
      _answerLocked = false;
      // Session begins now — first card is visible. Capture start timestamp
      // so we can compute real elapsed minutes when the session completes.
      _sessionStartTime = DateTime.now();
    });
    _buildChoicesForCurrent();
  }

  // ── Choice generation ──────────────────────────────────────────────────────

  /// Builds the 4 shuffled answer choices for the current card.
  /// Uses VocabItem.distractors if available; falls back to other words in deck.
  void _buildChoicesForCurrent() {
    if (_vocab.isEmpty || _queue.isEmpty) return;
    final vocab = _currentVocab;
    final correct = vocab.jpTranslation;

    List<String> wrong;
    if (vocab.distractors.isNotEmpty) {
      // Use authored distractors (prefer first 3)
      wrong = vocab.distractors.take(3).toList();
    } else {
      // Fallback: pick random jpTranslations from other deck items
      final others = _vocab
          .where((v) => v.id != vocab.id)
          .map((v) => v.jpTranslation)
          .toList();
      others.shuffle(math.Random());
      wrong = others.take(3).toList();
    }

    final choices = [correct, ...wrong.take(3)]..shuffle(math.Random());
    setState(() => _choices = choices);
  }

  // ── Current card helpers ───────────────────────────────────────────────────

  int get _currentDeckIdx => _queue[_queueIdx];
  VocabItem get _currentVocab  => _vocab[_currentDeckIdx];
  FSRSCard  get _currentCard   => _deck[_currentDeckIdx];

  int get _totalCards => _queue.length;
  int get _doneCards  => _queueIdx;

  // ── Flip ───────────────────────────────────────────────────────────────────

  void _flipToResult(bool correct) {
    HapticFeedback.lightImpact();
    _sound.playFlip();
    setState(() => _isFlipped = true);
    _flipCtrl.forward();
  }

  void _resetFlip() {
    _flipCtrl.reset();
    setState(() {
      _isFlipped = false;
      _answerResult = null;
      _selectedAnswer = null;
      _answerLocked = false;
    });
  }

  // ── Answer handling ────────────────────────────────────────────────────────

  void _onAnswerTapped(String answer) {
    if (_answerLocked) return;
    setState(() {
      _answerLocked = true;
      _selectedAnswer = answer;
      _answerResult = answer == _currentVocab.jpTranslation;
    });

    final correct = _answerResult!;

    if (correct) {
      _sound.playCorrect();
      HapticFeedback.mediumImpact();
      // Golden shimmer on correct
      setState(() => _showShimmer = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showShimmer = false);
      });
      _streak++;
    } else {
      _sound.playWrong();
      HapticFeedback.heavyImpact();
      _streak = 0;
    }

    // Flip card to show result after brief visual feedback
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _flipToResult(correct);
    });

    // Grade: correct=good, wrong=again
    final grade = correct ? Grade.good : Grade.again;
    _gradeCard(grade);

    // Auto-advance after 1.5 s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isFlipped) _advanceToNext();
    });
  }

  // ── Grade ──────────────────────────────────────────────────────────────────

  void _gradeCard(Grade grade) {
    // ── Grade-aware XP ────────────────────────────────────────────────────
    final xpGain = kGradeXp[grade.name.toLowerCase()] ?? 0;
    _totalXp += xpGain;
    final popupId = ++_xpPopupIdCounter;

    // Show popup only when XP > 0 (Again gives no XP — no popup)
    if (xpGain > 0) {
      setState(() => _xpPopups.add(_XpPopup(xpGain, popupId)));
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _xpPopups.removeWhere((p) => p.id == popupId));
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
  }

  void _advanceToNext() {
    final nextIdx = _queueIdx + 1;
    if (nextIdx >= _queue.length) {
      setState(() => _sessionDone = true);
      _starsCtrl.forward();
      _recordSessionToFirestore();
      return;
    }

    setState(() => _queueIdx = nextIdx);
    _resetFlip();
    _buildChoicesForCurrent();
  }

  // ── Session persistence ────────────────────────────────────────────────────

  /// Writes session stats to Firestore after session completes.
  /// Fire-and-forget — offline Firestore cache will sync when connection returns.
  void _recordSessionToFirestore() {
    final uid = _userId;
    if (uid == null) return;

    final total = _sessionResults.length;
    if (total == 0) return;

    final gradeSum = _sessionResults.fold(
        0.0, (sum, r) => sum + r.grade.index1.toDouble());
    final avgScore = gradeSum / total;

    // Count 'review' state cards as mastered
    final masteredCount = _deck.where((c) => c.state == CardState.review).length;

    // Real elapsed study time (P0.1) — computed from session start timestamp.
    final minutes = BattleScreen.elapsedMinutes(_sessionStartTime, DateTime.now());

    final progressService = ProgressService(
      repository: FirestoreProgressRepository(),
    );

    progressService.recordSession(
      uid: uid,
      wordsPracticed: total,
      minutes: minutes,
      avgScore: avgScore,
      totalMastered: masteredCount,
      totalPracticed: _deck.length,
      streak: 1, // server will recalculate from session history
    ).catchError((_) {
      // Non-fatal: offline writes queued by Firestore SDK
    });
  }

  // ── Level-up dialog (P2-7) ────────────────────────────────────────────────

  /// Shows a celebratory dialog when the player reaches a new level.
  /// Auto-dismisses after 3 seconds; user can also tap to dismiss.
  void _showLevelUpDialog(XpProfile newProfile) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // Auto-close after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
        });

        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
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
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '合計 ${newProfile.totalXp} XP',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // XP progress bar for new level
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: newProfile.levelProgress,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_accentGold),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${newProfile.currentLevelXp} / ${newProfile.levelXpSpan} XP',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
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
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: _repoLoading
          ? _buildLoadingSpinner()
          : _sessionDone
              ? _buildSummary()
              : _buildCardSession(),
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
              color: Colors.white70,
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
        icon: const Icon(Icons.arrow_back, color: Colors.white70),
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
        if (!_repoLoading && !_sessionDone)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '${_doneCards + 1} / $_totalCards',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
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
            // Answer buttons shown while card is face-up (not yet answered)
            if (!_isFlipped) _buildAnswerButtons(),
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
          backgroundColor: Colors.white12,
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
            // Card is not tappable — answers come from the choice buttons
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
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            vocab.reading,
            style: const TextStyle(
              color: Colors.white54,
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
            '正しい日本語を選んでね',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final vocab = _currentVocab;
    final correct = _answerResult ?? false;
    final example = vocab.exampleSentences.isNotEmpty
        ? vocab.exampleSentences.first
        : '';
    final cardColor = correct ? _cardCorrect : _cardWrong;
    final resultIcon = correct ? '✅' : '❌';
    final resultLabel = correct ? 'せいかい！' : 'まちがい…';

    return _cardContainer(
      color: cardColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(resultIcon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            resultLabel,
            style: TextStyle(
              color: correct ? _correctColor : _wrongColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vocab.word,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vocab.jpTranslation,
            style: const TextStyle(
              color: Colors.white,
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
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                example,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardContainer({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(102),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: child,
    );
  }

  // ── 4-choice answer buttons ────────────────────────────────────────────────

  Widget _buildAnswerButtons() {
    if (_choices.isEmpty) return const SizedBox.shrink();
    final correctAnswer = _currentVocab.jpTranslation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: _choices.take(2).map((choice) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: _AnswerButton(
                    label: choice,
                    isCorrect: choice == correctAnswer,
                    isSelected: choice == _selectedAnswer,
                    isRevealed: _answerLocked,
                    onTap: () => _onAnswerTapped(choice),
                  ),
                ),
              );
            }).toList(),
          ),
          Row(
            children: _choices.skip(2).take(2).map((choice) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: _AnswerButton(
                    label: choice,
                    isCorrect: choice == correctAnswer,
                    isSelected: choice == _selectedAnswer,
                    isRevealed: _answerLocked,
                    onTap: () => _onAnswerTapped(choice),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Session summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final total  = _sessionResults.length;
    final correctCount = _sessionResults.where((r) => r.grade == Grade.good || r.grade == Grade.easy).length;
    final counts = <Grade, int>{for (final g in Grade.values) g: 0};
    for (final r in _sessionResults) {
      counts[r.grade] = (counts[r.grade] ?? 0) + 1;
    }
    final gradeSum = _sessionResults.fold(
        0.0, (sum, r) => sum + r.grade.index1.toDouble());
    final avgGrade = total > 0 ? gradeSum / total : 0.0;
    final accuracy = total > 0 ? (correctCount / total * 100).round() : 0;

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
                  '$total 問 完了',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                // XP earned
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  children: [
                    _StatTile(
                      label: '正解率',
                      value: '$accuracy%',
                      icon: '🎯',
                    ),
                    const Divider(color: Colors.white12),
                    _StatTile(
                      label: '正解',
                      value: '$correctCount / $total',
                      icon: '✅',
                    ),
                    const Divider(color: Colors.white12),
                    _StatTile(
                      label: '平均評価',
                      value: avgGrade.toStringAsFixed(2),
                      icon: '⭐',
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
                    onPressed: () => setState(() { _initDeckAsync(); }),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text(
                    'ホームへ戻る',
                    style: TextStyle(color: Colors.white54),
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

// ── 4-choice answer button (with scale-bounce) ─────────────────────────────────

class _AnswerButton extends StatefulWidget {
  final String label;
  final bool isCorrect;
  final bool isSelected;
  final bool isRevealed;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.isCorrect,
    required this.isSelected,
    required this.isRevealed,
    required this.onTap,
  });

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton>
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

  Color _buttonColor() {
    if (!widget.isRevealed) {
      return const Color(0xFF16213E);
    }
    if (widget.isCorrect) return const Color(0xFF2E7D32); // green
    if (widget.isSelected) return const Color(0xFFC62828); // red (wrong selection)
    return const Color(0xFF16213E).withAlpha(128); // dimmed unselected
  }

  Color _borderColor() {
    if (!widget.isRevealed) return const Color(0xFF3D5AFE).withAlpha(128);
    if (widget.isCorrect) return const Color(0xFF69F0AE);
    if (widget.isSelected) return const Color(0xFFEF9A9A);
    return Colors.white12;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isRevealed ? null : (_) => _scaleCtrl.forward(),
      onTapUp: widget.isRevealed
          ? null
          : (_) {
              _scaleCtrl.reverse();
              widget.onTap();
            },
      onTapCancel: widget.isRevealed ? null : () => _scaleCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: _buttonColor(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor(), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isRevealed && !widget.isCorrect && !widget.isSelected
                    ? Colors.white38
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
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
      size:  6 + _rng.nextDouble() * 10,
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
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
